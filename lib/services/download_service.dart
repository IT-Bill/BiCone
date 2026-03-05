import 'dart:io';
import 'package:dio/dio.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:flutter/foundation.dart';
import '../models/video_item.dart';
import 'api_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';

enum DownloadPhase { preparing, downloadingVideo, downloadingAudio, merging }

class StreamProgress {
  int receivedBytes = 0;
  int totalBytes = 0;
  double speed = 0;
  DateTime? _lastSpeedUpdate;
  int _lastReceivedBytes = 0;
  DateTime? _startTime;
  String? completeDuration;

  double get progress =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  String get formattedSize {
    final received = _formatBytes(receivedBytes);
    final total = totalBytes > 0 ? _formatBytes(totalBytes) : '?';
    return '$received / $total';
  }

  String get formattedSpeed {
    if (speed <= 0) return '';
    if (speed >= 1024 * 1024) {
      return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return '${(speed / 1024).toStringAsFixed(0)} KB/s';
  }

  String get formattedEta {
    if (speed <= 0 || totalBytes <= 0) return '';
    final remaining = totalBytes - receivedBytes;
    final seconds = (remaining / speed).round();
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m${seconds % 60}s';
    return '${seconds ~/ 3600}h${(seconds % 3600) ~/ 60}m';
  }

  void update(int received, int total) {
    receivedBytes = received;
    totalBytes = total;
    _startTime ??= DateTime.now();

    final now = DateTime.now();
    if (_lastSpeedUpdate != null) {
      final elapsed = now.difference(_lastSpeedUpdate!).inMilliseconds;
      if (elapsed >= 500) {
        final bytesDelta = received - _lastReceivedBytes;
        speed = bytesDelta / (elapsed / 1000);
        _lastSpeedUpdate = now;
        _lastReceivedBytes = received;
      }
    } else {
      _lastSpeedUpdate = now;
      _lastReceivedBytes = received;
    }
  }

  void markComplete() {
    if (_startTime != null) {
      final elapsed = DateTime.now().difference(_startTime!).inSeconds;
      if (elapsed < 60) {
        completeDuration = '${elapsed}s';
      } else if (elapsed < 3600) {
        completeDuration = '${elapsed ~/ 60}m${elapsed % 60}s';
      } else {
        completeDuration =
            '${elapsed ~/ 3600}h${(elapsed % 3600) ~/ 60}m';
      }
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }
}

class DownloadTask {
  final VideoItem video;
  double progress; // overall progress 0.0-1.0
  DownloadStatus status;
  CancelToken? cancelToken;
  DownloadPhase phase;
  final StreamProgress videoStream = StreamProgress();
  final StreamProgress audioStream = StreamProgress();

  DownloadTask({
    required this.video,
    this.progress = 0.0,
    this.status = DownloadStatus.queued,
    this.cancelToken,
    this.phase = DownloadPhase.preparing,
  });
}

class DownloadService extends ChangeNotifier {
  final ApiService _apiService;
  final StorageService _storage;
  final NotificationService _notificationService;
  final Dio _dio = Dio();

  final List<DownloadTask> _tasks = [];
  bool _isProcessing = false;
  String? _lastError;
  String? _lastErrorBvid; // BV号 of the video that caused the last error

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);
  String? get lastError => _lastError;
  String? get lastErrorBvid => _lastErrorBvid;

  /// Clear the last error after it's been shown to the user.
  void clearLastError() {
    _lastError = null;
    _lastErrorBvid = null;
    notifyListeners();
  }

  List<DownloadTask> get activeTasks => _tasks
      .where((t) =>
          t.status == DownloadStatus.downloading ||
          t.status == DownloadStatus.queued ||
          t.status == DownloadStatus.paused)
      .toList();

  List<DownloadTask> get completedTasks =>
      _tasks.where((t) => t.status == DownloadStatus.completed).toList();

  DownloadService(this._apiService, this._storage, this._notificationService) {
    _dio.options.headers['User-Agent'] =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    _dio.options.headers['Referer'] = 'https://www.bilibili.com';
  }

  Future<String> get _downloadDir async {
    final dirPath = _storage.downloadPath;
    if (dirPath.isEmpty) {
      throw Exception('下载路径未设置，请先在设置中选择下载路径');
    }
    final downloadDir = Directory(dirPath);
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir.path;
  }

  Future<void> addDownload(VideoItem video) async {
    // Remove any existing failed/completed task so it can be retried
    _tasks.removeWhere((t) =>
        t.video.bvid == video.bvid &&
        (t.status == DownloadStatus.failed ||
         t.status == DownloadStatus.completed ||
         t.status == DownloadStatus.none));

    // Skip if already downloading, queued, or paused
    if (_tasks.any((t) => t.video.bvid == video.bvid)) return;

    final task = DownloadTask(video: video);
    _tasks.add(task);

    await _storage.updateVideoStatus(video.bvid, DownloadStatus.queued);
    notifyListeners();

    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    while (true) {
      final nextTask = _tasks.cast<DownloadTask?>().firstWhere(
            (t) => t!.status == DownloadStatus.queued,
            orElse: () => null,
          );

      if (nextTask == null) break;
      await _downloadVideo(nextTask);
    }

    _isProcessing = false;
  }

  Future<void> _downloadVideo(DownloadTask task) async {
    task.status = DownloadStatus.downloading;
    task.cancelToken = CancelToken();
    task.phase = DownloadPhase.preparing;
    notifyListeners();

    try {
      // 1. Get video info → CID
      debugPrint('Download: fetching video info for ${task.video.bvid}');
      final videoInfo = await _apiService.getVideoInfo(task.video.bvid);
      if (videoInfo == null) throw Exception('获取视频信息失败');

      final cid = videoInfo['cid'] ?? videoInfo['pages']?[0]?['cid'];
      if (cid == null) throw Exception('获取视频CID失败');

      // 2. Get DASH streams (video + audio)
      debugPrint('Download: fetching DASH streams for ${task.video.bvid}, cid=$cid');
      final streams = await _apiService.getVideoDashStreams(
        task.video.bvid,
        cid,
        qn: _storage.videoQuality,
      );
      if (streams == null) throw Exception('获取下载地址失败');

      // 3. Prepare paths
      final dir = await _downloadDir;
      debugPrint('Download: saving to $dir');
      final sanitized =
          task.video.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final videoPath = '$dir/$sanitized.video.m4s';
      final audioPath = '$dir/$sanitized.audio.m4s';
      final outputPath = '$dir/$sanitized.mp4';

      // 4. Download video stream
      task.phase = DownloadPhase.downloadingVideo;
      notifyListeners();
      await _downloadStream(
        url: streams.videoUrl,
        savePath: videoPath,
        task: task,
        streamProgress: task.videoStream,
      );
      task.videoStream.markComplete();

      // 5. Download audio stream
      if (task.cancelToken!.isCancelled) return;
      task.cancelToken = CancelToken();
      task.phase = DownloadPhase.downloadingAudio;
      notifyListeners();
      await _downloadStream(
        url: streams.audioUrl,
        savePath: audioPath,
        task: task,
        streamProgress: task.audioStream,
      );
      task.audioStream.markComplete();

      // 6. Merge with FFmpeg
      if (task.cancelToken!.isCancelled) return;
      debugPrint('Download: merging video and audio...');
      task.phase = DownloadPhase.merging;
      task.progress = 0.99;
      _notificationService.showDownloadProgressNotification(
        title: task.video.title,
        progress: 99,
        status: '合并中...',
      );
      notifyListeners();
      await _mergeStreams(videoPath, audioPath, outputPath);

      // 7. Clean up temp files
      try { await File(videoPath).delete(); } catch (_) {}
      try { await File(audioPath).delete(); } catch (_) {}

      // 8. Done
      task.status = DownloadStatus.completed;
      task.progress = 1.0;
      int? fileSize;
      try {
        final file = File(outputPath);
        if (await file.exists()) {
          fileSize = await file.length();
        }
      } catch (_) {}
      await _storage.updateVideoStatus(
        task.video.bvid,
        DownloadStatus.completed,
        progress: 1.0,
        localPath: outputPath,
        fileSize: fileSize,
      );

      // Show download complete notification
      await _notificationService.showDownloadCompleteNotification(
        title: task.video.title,
      );
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        // Check if this was a pause (task still in list with paused status)
        if (_tasks.contains(task) && task.status == DownloadStatus.paused) {
          // Paused — keep partial file, don't remove task
          await _storage.updateVideoStatus(
            task.video.bvid,
            DownloadStatus.paused,
            progress: task.progress,
          );
          await _notificationService.cancelDownloadNotification();
        } else if (_tasks.contains(task)) {
          // Cancelled — clean up
          task.status = DownloadStatus.none;
          await _storage.updateVideoStatus(task.video.bvid, DownloadStatus.none,
              progress: 0.0);
          _tasks.remove(task);
          await _cleanPartialFile(task.video.bvid);
        }
      } else {
        debugPrint('Download failed for ${task.video.bvid}: $e');

        // Detect permission/path errors — these are unrecoverable
        final errorStr = e.toString();
        if (errorStr.contains('Operation not permitted') ||
            errorStr.contains('Permission denied') ||
            errorStr.contains('PathAccessException')) {
          task.status = DownloadStatus.failed;
          await _storage.updateVideoStatus(
              task.video.bvid, DownloadStatus.failed);
          _lastError = '下载路径无写入权限，请在设置中更换下载路径。\n'
              '推荐选择 Download 目录下的新文件夹。';
        } else if (errorStr.contains('获取视频信息失败') ||
            errorStr.contains('获取视频CID失败') ||
            errorStr.contains('获取下载地址失败')) {
          task.status = DownloadStatus.failed;
          await _storage.updateVideoStatus(
              task.video.bvid, DownloadStatus.failed);
          _lastError = '下载失败：视频已失效或网络异常';
          _lastErrorBvid = task.video.bvid;
        } else {
          // Network or other recoverable errors — pause instead of fail
          task.status = DownloadStatus.paused;
          await _storage.updateVideoStatus(
            task.video.bvid,
            DownloadStatus.paused,
            progress: task.progress,
          );
          _lastError = '下载中断（可继续）: $e';
        }
      }
    }

    notifyListeners();
  }

  Future<void> pauseDownload(String bvid) async {
    final task = _tasks.cast<DownloadTask?>().firstWhere(
          (t) => t!.video.bvid == bvid,
          orElse: () => null,
        );
    if (task != null && task.status == DownloadStatus.downloading) {
      task.status = DownloadStatus.paused;
      task.cancelToken?.cancel(); // triggers DioExceptionType.cancel handler
    }
    notifyListeners();
  }

  Future<void> resumeDownload(String bvid) async {
    final task = _tasks.cast<DownloadTask?>().firstWhere(
          (t) => t!.video.bvid == bvid,
          orElse: () => null,
        );
    if (task != null && task.status == DownloadStatus.paused) {
      task.status = DownloadStatus.queued;
      await _storage.updateVideoStatus(
        task.video.bvid,
        DownloadStatus.queued,
        progress: task.progress,
      );
      notifyListeners();
      _processQueue();
    } else if (task == null) {
      // No in-memory task (app was restarted while paused) — re-enqueue
      final video = _storage.videos.cast<VideoItem?>().firstWhere(
            (v) => v!.bvid == bvid,
            orElse: () => null,
          );
      if (video != null) {
        await _cleanPartialFile(bvid);
        await addDownload(video);
      }
    }
  }

  Future<void> cancelDownload(String bvid) async {
    final task = _tasks.cast<DownloadTask?>().firstWhere(
          (t) => t!.video.bvid == bvid,
          orElse: () => null,
        );
    if (task != null) {
      task.cancelToken?.cancel();
      task.status = DownloadStatus.none;
      _tasks.remove(task);
    }
    // Always reset status in storage (handles orphaned tasks after app restart)
    await _storage.updateVideoStatus(bvid, DownloadStatus.none, progress: 0.0);
    // Clean up partial file on disk
    await _cleanPartialFile(bvid);
    // Cancel download progress notification
    await _notificationService.cancelDownloadNotification();
    notifyListeners();
  }

  /// Delete any partial download file for [bvid].
  Future<void> _cleanPartialFile(String bvid) async {
    try {
      // Find the video to get its title for filename
      final video = _storage.videos.cast<VideoItem?>().firstWhere(
            (v) => v!.bvid == bvid,
            orElse: () => null,
          );
      if (video == null) return;

      final dir = await _downloadDir;
      final sanitized =
          video.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      for (final ext in ['.mp4', '.flv', '.video.m4s', '.audio.m4s']) {
        final file = File('$dir/$sanitized$ext');
        if (await file.exists()) {
          await file.delete();
          debugPrint('Cleaned partial file: ${file.path}');
        }
      }
    } catch (e) {
      debugPrint('Error cleaning partial file: $e');
    }
  }

  /// Download a single stream (video or audio) with resume support.
  Future<void> _downloadStream({
    required String url,
    required String savePath,
    required DownloadTask task,
    required StreamProgress streamProgress,
  }) async {
    int resumeFromBytes = 0;
    final partialFile = File(savePath);
    if (await partialFile.exists()) {
      resumeFromBytes = await partialFile.length();
    }

    await _dio.download(
      url,
      savePath,
      cancelToken: task.cancelToken,
      deleteOnError: false,
      options: resumeFromBytes > 0
          ? Options(headers: {'Range': 'bytes=$resumeFromBytes-'})
          : null,
      onReceiveProgress: (received, total) {
        if (total > 0 && !task.cancelToken!.isCancelled) {
          final streamTotal =
              resumeFromBytes > 0 ? total + resumeFromBytes : total;
          final streamReceived =
              resumeFromBytes > 0 ? received + resumeFromBytes : received;

          streamProgress.update(streamReceived, streamTotal);

          // Overall progress: video progress contributes 0.0-0.5, audio 0.5-1.0
          if (task.phase == DownloadPhase.downloadingVideo) {
            task.progress = (streamProgress.progress * 0.5).clamp(0.0, 0.5);
          } else if (task.phase == DownloadPhase.downloadingAudio) {
            task.progress = (0.5 + streamProgress.progress * 0.5).clamp(0.5, 0.98);
          }

          _storage.updateVideoStatus(
            task.video.bvid,
            DownloadStatus.downloading,
            progress: task.progress,
          );
          if (streamProgress.speed > 0) {
            final phaseLabel = task.phase == DownloadPhase.downloadingVideo
                ? '视频' : '音频';
            _notificationService.showDownloadProgressNotification(
              title: task.video.title,
              progress: (task.progress * 100).round(),
              status: '$phaseLabel ${streamProgress.formattedSize} ${streamProgress.formattedSpeed}',
            );
          }
          notifyListeners();
        }
      },
    );
  }

  /// Merge separate video and audio streams into a single MP4.
  Future<void> _mergeStreams(
      String videoPath, String audioPath, String outputPath) async {
    if (Platform.isWindows || Platform.isLinux) {
      final result = await Process.run('ffmpeg', [
        '-i', videoPath,
        '-i', audioPath,
        '-c', 'copy',
        '-y',
        outputPath,
      ]);
      if (result.exitCode != 0) {
        throw Exception('FFmpeg合并失败: ${result.stderr}');
      }
    } else {
      final session = await FFmpegKit.execute(
          '-i "$videoPath" -i "$audioPath" -c copy -y "$outputPath"');
      final returnCode = await session.getReturnCode();
      if (!ReturnCode.isSuccess(returnCode)) {
        final output = await session.getOutput();
        throw Exception('FFmpeg合并失败: $output');
      }
    }
  }

  /// Call on app startup to reset any orphaned downloading/queued statuses.
  /// Paused downloads are preserved so the user can resume them.
  Future<void> cleanupStuckDownloads() async {
    final stuck = _storage.videos.where((v) =>
        v.downloadStatus == DownloadStatus.downloading ||
        v.downloadStatus == DownloadStatus.queued);
    for (final video in stuck.toList()) {
      debugPrint('Cleaning stuck download: ${video.bvid} (${video.title})');
      // Set stuck downloading/queued tasks to paused (preserving partial file)
      await _storage.updateVideoStatus(
          video.bvid, DownloadStatus.paused, progress: video.downloadProgress);
    }
  }

  void clearCompleted() {
    _tasks.removeWhere((t) => t.status == DownloadStatus.completed);
    notifyListeners();
  }

  /// Cancel active downloads and delete local files for all videos by a given UP主
  Future<void> cancelAndDeleteByAuthor(List<VideoItem> videos) async {
    for (final video in videos) {
      // Cancel any active download
      final task = _tasks.cast<DownloadTask?>().firstWhere(
            (t) => t!.video.bvid == video.bvid,
            orElse: () => null,
          );
      if (task != null) {
        task.cancelToken?.cancel();
        _tasks.remove(task);
      }

      // Delete local file if it exists
      if (video.localPath != null && video.localPath!.isNotEmpty) {
        try {
          final file = File(video.localPath!);
          if (await file.exists()) {
            await file.delete();
            debugPrint('Deleted file: ${file.path}');
          }
        } catch (e) {
          debugPrint('Error deleting file for ${video.bvid}: $e');
        }
      }

      // Also clean partial file
      await _cleanPartialFile(video.bvid);
    }
    notifyListeners();
  }
}
