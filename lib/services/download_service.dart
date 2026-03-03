import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/video_item.dart';
import 'api_service.dart';
import 'storage_service.dart';

class DownloadTask {
  final VideoItem video;
  double progress;
  DownloadStatus status;
  CancelToken? cancelToken;

  DownloadTask({
    required this.video,
    this.progress = 0.0,
    this.status = DownloadStatus.queued,
    this.cancelToken,
  });
}

class DownloadService extends ChangeNotifier {
  final ApiService _apiService;
  final StorageService _storage;
  final Dio _dio = Dio();

  final List<DownloadTask> _tasks = [];
  bool _isProcessing = false;

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);

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
    final customPath = _storage.downloadPath;
    if (customPath.isNotEmpty) return customPath;

    final dir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${dir.path}/Hamster/Downloads');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir.path;
  }

  Future<void> addDownload(VideoItem video) async {
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
      final videoInfo = await _apiService.getVideoInfo(task.video.bvid);
      if (videoInfo == null) throw Exception('获取视频信息失败');

      final cid = videoInfo['cid'] ?? videoInfo['pages']?[0]?['cid'];
      if (cid == null) throw Exception('获取视频CID失败');

      // 2. Get stream URL
      final downloadUrl = await _apiService.getVideoDownloadUrl(
        task.video.bvid,
        cid,
        qn: _storage.videoQuality,
      );
      if (downloadUrl == null) throw Exception('获取下载地址失败');

      // 3. Download
      final dir = await _downloadDir;
      final sanitized =
          task.video.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final savePath = '$dir/$sanitized.flv';

      await _dio.download(
        downloadUrl,
        savePath,
        cancelToken: task.cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            task.progress = received / total;
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
      await _storage.updateVideoStatus(
        task.video.bvid,
        DownloadStatus.completed,
        progress: 1.0,
        localPath: savePath,
      );
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        task.status = DownloadStatus.none;
        await _storage.updateVideoStatus(task.video.bvid, DownloadStatus.none);
      } else {
        task.status = DownloadStatus.failed;
        await _storage.updateVideoStatus(
            task.video.bvid, DownloadStatus.failed);
      }
    }

    notifyListeners();
  }

  void cancelDownload(String bvid) {
    final task = _tasks.cast<DownloadTask?>().firstWhere(
          (t) => t!.video.bvid == bvid,
          orElse: () => null,
        );
    if (task != null) {
      task.cancelToken?.cancel();
      task.status = DownloadStatus.none;
      _tasks.remove(task);
      notifyListeners();
    }
  }

  void clearCompleted() {
    _tasks.removeWhere((t) => t.status == DownloadStatus.completed);
    notifyListeners();
  }
}
