import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/download_task.dart';
import '../models/video_item.dart';
import 'api_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';

export '../models/download_task.dart';

class _DownloadSegment {
  final int index;
  final int start;
  final int end;
  final String path;
  bool completed = false;

  _DownloadSegment({
    required this.index,
    required this.start,
    required this.end,
    required this.path,
  });
}

class DownloadService extends ChangeNotifier {
  final ApiService _apiService;
  final StorageService _storage;
  final NotificationService _notificationService;
  final Dio _dio = Dio();

  final List<DownloadTask> _tasks = [];
  final Set<String> _demoRunningBvids = <String>{};
  bool _isProcessing = false;
  String? _lastError;
  String? _lastErrorBvid; // BV号 of the video that caused the last error

  static const int _demoVideoTotal = 120 * 1024 * 1024;
  static const int _demoAudioTotal = 18 * 1024 * 1024;
  static const int _demoMergeTotal = _demoVideoTotal + _demoAudioTotal;

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
    _dio.options.headers['User-Agent'] = 'Mozilla/5.0';
    _dio.options.headers['Referer'] = 'https://www.bilibili.com';
  }

  Future<String> _downloadDir({int? authorMid}) async {
    final dirPath = _storage.downloadPath;
    if (dirPath.isEmpty) {
      throw Exception('下载路径未设置，请先在设置中选择下载路径');
    }
    final basePath = authorMid != null && authorMid > 0
        ? '$dirPath/$authorMid'
        : dirPath;
    final downloadDir = Directory(basePath);
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir.path;
  }

  /// On iOS, use tmp/ for intermediate .m4s files to reduce persistent storage.
  Future<String> _tempDownloadDir({int? authorMid}) async {
    if (Platform.isIOS) {
      final tmpDir = Directory('${Directory.systemTemp.path}/bicone_dl');
      if (!await tmpDir.exists()) {
        await tmpDir.create(recursive: true);
      }
      return tmpDir.path;
    }
    return _downloadDir(authorMid: authorMid);
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

    final task = DownloadTask(video: video)
      ..cancelToken = CancelToken();
    _tasks.add(task);

    await _storage.updateVideoStatus(video.bvid, DownloadStatus.queued);
    notifyListeners();

    if (_storage.isAppReviewMode) {
      unawaited(_simulateDemoDownload(task));
      return;
    }

    _processQueue();
  }

  Future<void> _waitIfPausedDemoTask(DownloadTask task) async {
    while (task.status == DownloadStatus.paused) {
      if (task.cancelToken?.isCancelled ?? false) return;
      if (!_tasks.contains(task)) return;
      await Future.delayed(const Duration(milliseconds: 180));
    }
  }

  Future<bool> _canContinueDemoTask(DownloadTask task) async {
    await _waitIfPausedDemoTask(task);
    return _tasks.contains(task) && !(task.cancelToken?.isCancelled ?? false);
  }

  Future<void> _simulateDemoDownload(DownloadTask task) async {
    if (!_demoRunningBvids.add(task.video.bvid)) return;

    try {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!await _canContinueDemoTask(task)) return;

      task.status = DownloadStatus.downloading;
      task.phase = task.videoStream.receivedBytes >= _demoVideoTotal
          ? DownloadPhase.downloadingAudio
          : DownloadPhase.downloadingVideo;
      notifyListeners();

      var videoReceived = task.videoStream.receivedBytes;
      while (videoReceived < _demoVideoTotal) {
        if (!await _canContinueDemoTask(task)) return;
        task.phase = DownloadPhase.downloadingVideo;
        videoReceived = (videoReceived + (_demoVideoTotal / 10).round())
            .clamp(0, _demoVideoTotal)
            .toInt();
        task.videoStream.update(videoReceived, _demoVideoTotal);
        _updateOverallProgress(task, task.videoStream);
        await _storage.updateVideoStatus(
          task.video.bvid,
          DownloadStatus.downloading,
          progress: task.progress,
        );
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 220));
      }
      task.videoStream.markComplete();

      var audioReceived = task.audioStream.receivedBytes;
      task.phase = DownloadPhase.downloadingAudio;
      notifyListeners();

      while (audioReceived < _demoAudioTotal) {
        if (!await _canContinueDemoTask(task)) return;
        task.phase = DownloadPhase.downloadingAudio;
        audioReceived = (audioReceived + (_demoAudioTotal / 8).round())
            .clamp(0, _demoAudioTotal)
            .toInt();
        task.audioStream.update(audioReceived, _demoAudioTotal);
        _updateOverallProgress(task, task.audioStream);
        await _storage.updateVideoStatus(
          task.video.bvid,
          DownloadStatus.downloading,
          progress: task.progress,
        );
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 180));
      }
      task.audioStream.markComplete();

      var mergeReceived = task.mergeStream.receivedBytes;
      task.phase = DownloadPhase.merging;
      task.progress = task.progress < 0.98 ? 0.99 : task.progress;
      notifyListeners();

      while (mergeReceived < _demoMergeTotal) {
        if (!await _canContinueDemoTask(task)) return;
        task.phase = DownloadPhase.merging;
        mergeReceived = (mergeReceived + (_demoMergeTotal / 4).round())
            .clamp(0, _demoMergeTotal)
            .toInt();
        task.mergeStream.update(mergeReceived, _demoMergeTotal);
        await _storage.updateVideoStatus(
          task.video.bvid,
          DownloadStatus.downloading,
          progress: 0.99,
        );
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 220));
      }
      task.mergeStream.markComplete();

      task.status = DownloadStatus.completed;
      task.progress = 1.0;
      await _storage.updateVideoStatus(
        task.video.bvid,
        DownloadStatus.completed,
        progress: 1.0,
        fileSize: _demoMergeTotal,
      );
      await _notificationService.showDownloadCompleteNotification(
        title: '${task.video.title}（演示）',
      );
    } catch (e) {
      debugPrint('Demo download failed for ${task.video.bvid}: $e');
      task.status = DownloadStatus.failed;
      await _storage.updateVideoStatus(task.video.bvid, DownloadStatus.failed);
    } finally {
      _demoRunningBvids.remove(task.video.bvid);
      notifyListeners();
    }
  }

  void _seedDemoTaskStreams(DownloadTask task, double overallProgress) {
    final progress = overallProgress.clamp(0.0, 1.0).toDouble();
    task.progress = progress;

    if (progress <= 0.5) {
      task.phase = DownloadPhase.downloadingVideo;
      task.videoStream.update(
        (_demoVideoTotal * (progress / 0.5)).round(),
        _demoVideoTotal,
      );
      return;
    }

    task.videoStream.update(_demoVideoTotal, _demoVideoTotal);
    task.videoStream.markComplete();

    if (progress < 0.98) {
      task.phase = DownloadPhase.downloadingAudio;
      final audioProgress = ((progress - 0.5) / 0.48).clamp(0.0, 1.0).toDouble();
      task.audioStream.update(
        (_demoAudioTotal * audioProgress).round(),
        _demoAudioTotal,
      );
      return;
    }

    task.audioStream.update(_demoAudioTotal, _demoAudioTotal);
    task.audioStream.markComplete();
    task.phase = DownloadPhase.merging;
    final mergeProgress = ((progress - 0.98) / 0.02).clamp(0.0, 1.0).toDouble();
    task.mergeStream.update(
      (_demoMergeTotal * mergeProgress).round(),
      _demoMergeTotal,
    );
  }

  Future<void> hydrateAppReviewDemoTasks() async {
    if (!_storage.isAppReviewMode) return;

    _tasks.removeWhere((t) => t.status != DownloadStatus.completed);

    for (final video in _storage.videos) {
      if (video.downloadStatus != DownloadStatus.paused &&
          video.downloadStatus != DownloadStatus.queued &&
          video.downloadStatus != DownloadStatus.downloading) {
        continue;
      }

      if (_tasks.any((t) => t.video.bvid == video.bvid)) continue;

      final task = DownloadTask(
        video: video,
        progress: video.downloadProgress,
        status: video.downloadStatus,
        cancelToken: CancelToken(),
      );
      _seedDemoTaskStreams(task, video.downloadProgress);
      _tasks.add(task);
    }

    notifyListeners();
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
      final dir = await _downloadDir(authorMid: task.video.authorMid);
      final tmpDir = await _tempDownloadDir(authorMid: task.video.authorMid);
      debugPrint('Download: saving to $dir (temp: $tmpDir)');
      final sanitized =
          task.video.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final videoPath = '$tmpDir/$sanitized.video.m4s';
      final audioPath = '$tmpDir/$sanitized.audio.m4s';
      final outputPath = '$dir/$sanitized.mp4';

      // 4. Download video stream (skip if already completed)
      final videoFile = File(videoPath);
      final videoExists = await videoFile.exists();
      final videoComplete = videoExists && await videoFile.length() > 0 &&
          !await File('$videoPath.seg0').exists(); // no segment files = merged
      if (videoComplete) {
        debugPrint('Download: video stream already complete, skipping');
        task.videoStream.receivedBytes = await videoFile.length();
        task.videoStream.totalBytes = task.videoStream.receivedBytes;
        task.videoStream.markComplete();
      } else {
        task.phase = DownloadPhase.downloadingVideo;
        notifyListeners();
        await _downloadStream(
          url: streams.videoUrl,
          savePath: videoPath,
          task: task,
          streamProgress: task.videoStream,
        );
        task.videoStream.markComplete();
      }

      // 5. Download audio stream (skip if already completed)
      if (task.cancelToken!.isCancelled) return;
      final audioFile = File(audioPath);
      final audioExists = await audioFile.exists();
      final audioComplete = audioExists && await audioFile.length() > 0 &&
          !await File('$audioPath.seg0').exists();
      if (audioComplete) {
        debugPrint('Download: audio stream already complete, skipping');
        task.audioStream.receivedBytes = await audioFile.length();
        task.audioStream.totalBytes = task.audioStream.receivedBytes;
        task.audioStream.markComplete();
      } else {
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
      }

      // 6. Merge with FFmpeg
      if (task.cancelToken!.isCancelled) return;
      debugPrint('Download: merging video and audio...');
      task.phase = DownloadPhase.merging;
      task.progress = 0.99;
      notifyListeners();
      await _mergeStreams(videoPath, audioPath, outputPath, task);

      // 7. Clean up temp files
      try { await File(videoPath).delete(); } catch (_) {}
      try { await File(audioPath).delete(); } catch (_) {}

      // 7.5. Download cover image if enabled
      if (_storage.saveCover && task.video.thumbnail.isNotEmpty) {
        try {
          final coverUrl = task.video.thumbnail;
          final coverExt = coverUrl.contains('.png') ? '.png' : '.jpg';
          final coverPath = '$dir/$sanitized$coverExt';
          await _dio.download(
            coverUrl,
            coverPath,
            cancelToken: task.cancelToken,
          );
          debugPrint('Cover saved: $coverPath');
        } catch (e) {
          debugPrint('Cover download failed (non-fatal): $e');
        }
      }

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
          _lastError = '未在源站中找到，\n可能已失效或网络异常';
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
      if (_storage.isAppReviewMode) {
        await _storage.updateVideoStatus(
          task.video.bvid,
          DownloadStatus.paused,
          progress: task.progress,
        );
      } else {
        task.cancelToken?.cancel(); // triggers DioExceptionType.cancel handler
      }
    }
    notifyListeners();
  }

  Future<void> resumeDownload(String bvid) async {
    final task = _tasks.cast<DownloadTask?>().firstWhere(
          (t) => t!.video.bvid == bvid,
          orElse: () => null,
        );
    if (task != null && task.status == DownloadStatus.paused) {
      if (_storage.isAppReviewMode) {
        task.status = DownloadStatus.downloading;
        await _storage.updateVideoStatus(
          task.video.bvid,
          DownloadStatus.downloading,
          progress: task.progress,
        );
        notifyListeners();
        if (!_demoRunningBvids.contains(task.video.bvid)) {
          unawaited(_simulateDemoDownload(task));
        }
        return;
      }

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
        if (!_storage.isAppReviewMode) {
          await _cleanPartialFile(bvid);
        }
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
    if (!_storage.isAppReviewMode) {
      await _cleanPartialFile(bvid);
    }
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

      final dir = await _downloadDir(authorMid: video.authorMid);
      final tmpDir = await _tempDownloadDir(authorMid: video.authorMid);
      final sanitized =
          video.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      // Clean .m4s intermediates from both temp and download dirs
      for (final searchDir in {dir, tmpDir}) {
        for (final ext in ['.video.m4s', '.audio.m4s']) {
          final file = File('$searchDir/$sanitized$ext');
          if (await file.exists()) {
            await file.delete();
            debugPrint('Cleaned partial file: ${file.path}');
          }
          for (int i = 0; i < 100; i++) {
            final segFile = File('$searchDir/$sanitized$ext.seg$i');
            if (await segFile.exists()) {
              await segFile.delete();
              debugPrint('Cleaned segment file: ${segFile.path}');
            } else {
              break;
            }
          }
        }
      }

      // Clean final output and cover from download dir
      for (final ext in ['.mp4', '.flv', '.jpg', '.png']) {
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

  /// Downgrade HTTPS to HTTP to avoid TLS overhead (like BBDown).
  String _forceHttp(String url) {
    if (url.startsWith('https://')) {
      // Don't downgrade mcdn domains
      if (url.contains('.mcdn.bilivideo.cn')) return url;
      return 'http://${url.substring(8)}';
    }
    return url;
  }

  static const int _segmentSize = 10 * 1024 * 1024; // 10 MB per segment
  static const int _maxConcurrent = 8; // Max parallel connections

  /// Download a single stream using multi-segment parallel download.
  Future<void> _downloadStream({
    required String url,
    required String savePath,
    required DownloadTask task,
    required StreamProgress streamProgress,
  }) async {
    final downloadUrl = _forceHttp(url);

    // Get file size via HEAD request
    int totalSize = 0;
    try {
      final headResp = await _dio.head<void>(
        downloadUrl,
        cancelToken: task.cancelToken,
        options: Options(headers: {
          if (_storage.sessdata != null)
            'Cookie': 'SESSDATA=${_storage.sessdata}',
        }),
      );
      final contentLength = headResp.headers.value('content-length');
      if (contentLength != null) {
        totalSize = int.tryParse(contentLength) ?? 0;
      }
    } catch (e) {
      debugPrint('HEAD request failed, falling back to single download: $e');
    }

    // Fall back to single-connection if size unknown or too small
    if (totalSize <= _segmentSize) {
      await _downloadSingleStream(
        url: downloadUrl,
        savePath: savePath,
        task: task,
        streamProgress: streamProgress,
      );
      return;
    }

    streamProgress.totalBytes = totalSize;

    // Calculate segments
    final segments = <_DownloadSegment>[];
    int offset = 0;
    int index = 0;
    while (offset < totalSize) {
      final end = min(offset + _segmentSize - 1, totalSize - 1);
      segments.add(_DownloadSegment(
        index: index,
        start: offset,
        end: end,
        path: '$savePath.seg$index',
      ));
      offset = end + 1;
      index++;
    }

    debugPrint('Multi-segment download: ${segments.length} segments, '
        'totalSize=${(totalSize / 1024 / 1024).toStringAsFixed(1)}MB');

    // Track per-segment received bytes
    final segmentReceived = List<int>.filled(segments.length, 0);

    // Check for already-completed segments (resume support)
    for (final seg in segments) {
      final segFile = File(seg.path);
      final expectedSize = seg.end - seg.start + 1;
      if (await segFile.exists()) {
        final fileLen = await segFile.length();
        if (fileLen >= expectedSize) {
          segmentReceived[seg.index] = expectedSize;
          seg.completed = true;
        } else {
          // Partial — count existing bytes for progress display
          segmentReceived[seg.index] = fileLen;
        }
      }
    }

    // Update initial progress from completed segments
    final initialReceived = segmentReceived.reduce((a, b) => a + b);
    if (initialReceived > 0) {
      streamProgress.update(initialReceived, totalSize);
      _updateOverallProgress(task, streamProgress);
      notifyListeners();
    }

    // Download remaining segments with concurrency limit
    final pending = segments.where((s) => !s.completed).toList();
    Future<void> downloadSegment(_DownloadSegment seg) async {
      // Per-segment resume: check how much is already saved
      final segFile = File(seg.path);
      int segDownloaded = 0;
      if (await segFile.exists()) {
        segDownloaded = await segFile.length();
      }
      final expectedSize = seg.end - seg.start + 1;
      if (segDownloaded >= expectedSize) {
        seg.completed = true;
        segmentReceived[seg.index] = expectedSize;
        return;
      }

      final response = await _dio.get<ResponseBody>(
        downloadUrl,
        cancelToken: task.cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Range': 'bytes=${seg.start + segDownloaded}-${seg.end}',
            if (_storage.sessdata != null)
              'Cookie': 'SESSDATA=${_storage.sessdata}',
          },
        ),
      );

      final raf = await segFile.open(mode: FileMode.append);
      try {
        await for (final chunk in response.data!.stream) {
          if (task.cancelToken!.isCancelled) break;
          raf.writeFromSync(chunk);
          segDownloaded += chunk.length;
          segmentReceived[seg.index] = segDownloaded;
          final totalReceived = segmentReceived.reduce((a, b) => a + b);
          streamProgress.update(totalReceived, totalSize);
          _updateOverallProgress(task, streamProgress);
          _notifyThrottled(task, streamProgress);
        }
      } finally {
        await raf.close();
      }
      seg.completed = true;
    }

    // Use a semaphore-like approach for concurrency control
    final completer = <Future<void>>[];
    for (int i = 0; i < pending.length; i++) {
      if (task.cancelToken!.isCancelled) break;
      final future = downloadSegment(pending[i]);
      completer.add(future);
      if (completer.length >= _maxConcurrent || i == pending.length - 1) {
        await Future.wait(completer);
        completer.clear();
      }
    }

    if (task.cancelToken!.isCancelled) return;

    // Merge segments into final file
    final outFile = File(savePath);
    final sink = outFile.openWrite();
    try {
      for (final seg in segments) {
        final segFile = File(seg.path);
        await sink.addStream(segFile.openRead());
      }
    } finally {
      await sink.close();
    }

    // Clean up segment files
    for (final seg in segments) {
      try { await File(seg.path).delete(); } catch (_) {}
    }
  }

  /// Single-connection download fallback for small files.
  Future<void> _downloadSingleStream({
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

    final response = await _dio.get<ResponseBody>(
      url,
      cancelToken: task.cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          if (resumeFromBytes > 0) 'Range': 'bytes=$resumeFromBytes-',
          if (_storage.sessdata != null)
            'Cookie': 'SESSDATA=${_storage.sessdata}',
        },
      ),
    );

    // Determine total size from Content-Range or Content-Length
    int streamTotal = 0;
    final contentRange = response.headers.value('content-range');
    if (contentRange != null) {
      // e.g. "bytes 1000-9999/10000"
      final match = RegExp(r'/(\d+)').firstMatch(contentRange);
      if (match != null) streamTotal = int.tryParse(match.group(1)!) ?? 0;
    }
    if (streamTotal == 0) {
      final cl = response.headers.value('content-length');
      streamTotal = resumeFromBytes + (int.tryParse(cl ?? '') ?? 0);
    }

    int streamReceived = resumeFromBytes;
    final raf = await partialFile.open(mode: FileMode.append);
    try {
      await for (final chunk in response.data!.stream) {
        if (task.cancelToken!.isCancelled) break;
        raf.writeFromSync(chunk);
        streamReceived += chunk.length;
        if (streamTotal > 0) {
          streamProgress.update(streamReceived, streamTotal);
          _updateOverallProgress(task, streamProgress);
          _notifyThrottled(task, streamProgress);
        }
      }
    } finally {
      await raf.close();
    }
  }

  void _updateOverallProgress(DownloadTask task, StreamProgress streamProgress) {
    if (task.phase == DownloadPhase.downloadingVideo) {
      task.progress = (streamProgress.progress * 0.5).clamp(0.0, 0.5);
    } else if (task.phase == DownloadPhase.downloadingAudio) {
      task.progress = (0.5 + streamProgress.progress * 0.5).clamp(0.5, 0.98);
    }
  }

  DateTime? _lastNotifyTime;

  void _notifyThrottled(DownloadTask task, StreamProgress streamProgress) {
    final now = DateTime.now();
    if (_lastNotifyTime != null &&
        now.difference(_lastNotifyTime!).inMilliseconds < 200) {
      return;
    }
    _lastNotifyTime = now;

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

  static const _mediaMuxerChannel =
      MethodChannel('cn.itbill.bicone/media_muxer');

  /// Merge separate video and audio streams into a single MP4.
  Future<void> _mergeStreams(
      String videoPath, String audioPath, String outputPath, DownloadTask task) async {
    // Estimate output size = video + audio for progress tracking
    final videoSize = await File(videoPath).length();
    final audioSize = await File(audioPath).length();
    final expectedSize = videoSize + audioSize;
    task.mergeStream.totalBytes = expectedSize;

    // Poll output file size periodically for progress
    Timer? progressTimer;
    if (expectedSize > 0) {
      progressTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
        try {
          final outFile = File(outputPath);
          if (await outFile.exists()) {
            final currentSize = await outFile.length();
            task.mergeStream.update(currentSize, expectedSize);
            _notificationService.showDownloadProgressNotification(
              title: task.video.title,
              progress: (99 * task.mergeStream.progress).round(),
              status: '合并中 ${task.mergeStream.formattedSize}',
            );
            notifyListeners();
          }
        } catch (_) {}
      });
    }

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        try {
          await _mediaMuxerChannel.invokeMethod('mergeStreams', {
            'videoPath': videoPath,
            'audioPath': audioPath,
            'outputPath': outputPath,
          });
        } on PlatformException catch (e) {
          throw Exception('合并失败: ${e.message}');
        }
      } else {
        // Windows / Linux: use bundled ffmpeg next to exe, fallback to system PATH
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        final bundled = File('$exeDir${Platform.pathSeparator}ffmpeg.exe');
        final ffmpegPath = await bundled.exists() ? bundled.path : 'ffmpeg';
        final result = await Process.run(ffmpegPath, [
          '-i', videoPath,
          '-i', audioPath,
          '-c', 'copy',
          '-y',
          outputPath,
        ]);
        if (result.exitCode != 0) {
          throw Exception('FFmpeg合并失败: ${result.stderr}');
        }
      }
    } finally {
      progressTimer?.cancel();
      task.mergeStream.receivedBytes = expectedSize;
      task.mergeStream.markComplete();
      notifyListeners();
    }
  }

  /// Call on app startup to reset any orphaned downloading/queued statuses.
  /// Paused downloads are preserved so the user can resume them.
  Future<void> cleanupStuckDownloads() async {
    if (_storage.isAppReviewMode) {
      await hydrateAppReviewDemoTasks();
      return;
    }

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

      await deleteVideoFiles(video);
    }
    notifyListeners();
  }

  /// Delete video file, cover images, and clean up empty UID folder.
  Future<void> deleteVideoFiles(VideoItem video) async {
    // Delete local video file
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

    // Delete cover images
    try {
      final dir = await _downloadDir(authorMid: video.authorMid);
      final sanitized =
          video.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      for (final ext in ['.jpg', '.png']) {
        final coverFile = File('$dir/$sanitized$ext');
        if (await coverFile.exists()) {
          await coverFile.delete();
          debugPrint('Deleted cover: ${coverFile.path}');
        }
      }

      // Clean up empty UID folder
      await _cleanEmptyUidFolder(dir);
    } catch (e) {
      debugPrint('Error deleting cover for ${video.bvid}: $e');
    }

    // Also clean partial files
    await _cleanPartialFile(video.bvid);
  }

  /// Remove the UID directory if empty.
  Future<void> _cleanEmptyUidFolder(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return;
      final entries = await dir.list().toList();
      if (entries.isEmpty) {
        await dir.delete();
        debugPrint('Removed empty UID folder: $dirPath');
      }
    } catch (e) {
      debugPrint('Error cleaning UID folder: $e');
    }
  }
}
