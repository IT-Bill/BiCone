import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/video_item.dart';
import 'api_service.dart';
import 'storage_service.dart';

class DownloadTask {
  final VideoItem video;
  double progress;
  DownloadStatus status;
  CancelToken? cancelToken;
  int receivedBytes;
  int totalBytes;
  double speed; // bytes per second
  DateTime? _lastSpeedUpdate;
  int _lastReceivedBytes;

  DownloadTask({
    required this.video,
    this.progress = 0.0,
    this.status = DownloadStatus.queued,
    this.cancelToken,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.speed = 0,
  }) : _lastReceivedBytes = 0;

  String get formattedSpeed {
    if (speed <= 0) return '';
    if (speed >= 1024 * 1024) {
      return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return '${(speed / 1024).toStringAsFixed(0)} KB/s';
  }

  String get formattedSize {
    final received = _formatBytes(receivedBytes);
    final total = totalBytes > 0 ? _formatBytes(totalBytes) : '?';
    return '$received / $total';
  }

  String get formattedEta {
    if (speed <= 0 || totalBytes <= 0) return '';
    final remaining = totalBytes - receivedBytes;
    final seconds = (remaining / speed).round();
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m${seconds % 60}s';
    return '${seconds ~/ 3600}h${(seconds % 3600) ~/ 60}m';
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

  void updateProgress(int received, int total) {
    receivedBytes = received;
    totalBytes = total;
    if (total > 0) {
      progress = received / total;
    }

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
}

class DownloadService extends ChangeNotifier {
  final ApiService _apiService;
  final StorageService _storage;
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
          t.status == DownloadStatus.queued)
      .toList();

  List<DownloadTask> get completedTasks =>
      _tasks.where((t) => t.status == DownloadStatus.completed).toList();

  DownloadService(this._apiService, this._storage) {
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

    // Skip if already downloading or queued
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
    notifyListeners();

    try {
      // 1. Get video info → CID
      debugPrint('Download: fetching video info for ${task.video.bvid}');
      final videoInfo = await _apiService.getVideoInfo(task.video.bvid);
      if (videoInfo == null) throw Exception('获取视频信息失败');

      final cid = videoInfo['cid'] ?? videoInfo['pages']?[0]?['cid'];
      if (cid == null) throw Exception('获取视频CID失败');

      // 2. Get stream URL
      debugPrint('Download: fetching stream URL for ${task.video.bvid}, cid=$cid');
      final downloadUrl = await _apiService.getVideoDownloadUrl(
        task.video.bvid,
        cid,
        qn: _storage.videoQuality,
      );
      if (downloadUrl == null) throw Exception('获取下载地址失败');

      // 3. Download
      final dir = await _downloadDir;
      debugPrint('Download: saving to $dir');
      final sanitized =
          task.video.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final savePath = '$dir/$sanitized.flv';

      await _dio.download(
        downloadUrl,
        savePath,
        cancelToken: task.cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0 && !task.cancelToken!.isCancelled) {
            task.updateProgress(received, total);
            _storage.updateVideoStatus(
              task.video.bvid,
              DownloadStatus.downloading,
              progress: task.progress,
            );
            notifyListeners();
          }
        },
      );

      task.status = DownloadStatus.completed;
      task.progress = 1.0;
      // Get file size
      int? fileSize;
      try {
        final file = File(savePath);
        if (await file.exists()) {
          fileSize = await file.length();
        }
      } catch (_) {}
      await _storage.updateVideoStatus(
        task.video.bvid,
        DownloadStatus.completed,
        progress: 1.0,
        localPath: savePath,
        fileSize: fileSize,
      );
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        // cancelDownload() already handled status reset and file cleanup
        // Only handle if task is still in the list (shouldn't normally happen)
        if (_tasks.contains(task)) {
          task.status = DownloadStatus.none;
          await _storage.updateVideoStatus(task.video.bvid, DownloadStatus.none,
              progress: 0.0);
          _tasks.remove(task);
          await _cleanPartialFile(task.video.bvid);
        }
      } else {
        debugPrint('Download failed for ${task.video.bvid}: $e');
        task.status = DownloadStatus.failed;
        await _storage.updateVideoStatus(
            task.video.bvid, DownloadStatus.failed);

        // Detect permission/path errors and provide user-friendly message
        final errorStr = e.toString();
        if (errorStr.contains('Operation not permitted') ||
            errorStr.contains('Permission denied') ||
            errorStr.contains('PathAccessException')) {
          _lastError = '下载路径无写入权限，请在设置中更换下载路径。\n'
              '推荐选择 Download 目录下的新文件夹。';
        } else if (errorStr.contains('获取视频信息失败') ||
            errorStr.contains('获取视频CID失败') ||
            errorStr.contains('获取下载地址失败')) {
          _lastError = '下载失败：视频已失效或网络异常';
          _lastErrorBvid = task.video.bvid;
        } else {
          _lastError = '下载失败: $e';
        }
      }
    }

    notifyListeners();
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
      final file = File('$dir/$sanitized.flv');
      if (await file.exists()) {
        await file.delete();
        debugPrint('Cleaned partial file: ${file.path}');
      }
    } catch (e) {
      debugPrint('Error cleaning partial file: $e');
    }
  }

  /// Call on app startup to reset any orphaned downloading/queued statuses.
  Future<void> cleanupStuckDownloads() async {
    final stuck = _storage.videos.where((v) =>
        v.downloadStatus == DownloadStatus.downloading ||
        v.downloadStatus == DownloadStatus.queued);
    for (final video in stuck.toList()) {
      debugPrint('Cleaning stuck download: ${video.bvid} (${video.title})');
      await _cleanPartialFile(video.bvid);
      await _storage.updateVideoStatus(
          video.bvid, DownloadStatus.none, progress: 0.0);
    }
  }

  void clearCompleted() {
    _tasks.removeWhere((t) => t.status == DownloadStatus.completed);
    notifyListeners();
  }

  /// Cancel active downloads and delete local files for all videos by a given UP主.
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
