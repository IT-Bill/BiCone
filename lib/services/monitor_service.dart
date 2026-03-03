import 'dart:async';
import 'package:flutter/foundation.dart';
import 'rss_service.dart';
import 'storage_service.dart';
import 'download_service.dart';

/// Periodically checks RSSHub for new videos from subscribed UP主.
class MonitorService extends ChangeNotifier {
  final StorageService _storage;
  final DownloadService _downloadService;

  Timer? _timer;
  bool _isMonitoring = false;
  bool _isChecking = false;
  DateTime? _lastCheck;
  int _newVideoCount = 0;

  bool get isMonitoring => _isMonitoring;
  bool get isChecking => _isChecking;
  DateTime? get lastCheck => _lastCheck;
  int get newVideoCount => _newVideoCount;

  MonitorService(this._storage, this._downloadService);

  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;

    // Check immediately, then on an interval
    checkForNewVideos();

    _timer = Timer.periodic(
      Duration(minutes: _storage.checkInterval),
      (_) => checkForNewVideos(),
    );

    notifyListeners();
  }

  void stopMonitoring() {
    _timer?.cancel();
    _isMonitoring = false;
    notifyListeners();
  }

  void updateInterval() {
    if (_isMonitoring) {
      _timer?.cancel();
      _timer = Timer.periodic(
        Duration(minutes: _storage.checkInterval),
        (_) => checkForNewVideos(),
      );
    }
  }

  Future<void> checkForNewVideos() async {
    if (_isChecking) return;
    _isChecking = true;
    _newVideoCount = 0;
    notifyListeners();

    final rssService = RssService(rssHubUrl: _storage.rssHubUrl);
    final subscriptions = _storage.subscriptions;

    for (final sub in subscriptions) {
      try {
        final videos = await rssService.getLatestVideos(sub.mid);

        for (final video in videos) {
          if (!_storage.hasVideo(video.bvid)) {
            await _storage.saveVideo(video);
            _newVideoCount++;

            if (_storage.autoDownload) {
              await _downloadService.addDownload(video);
            }
          }
        }
      } catch (e) {
        debugPrint('Error checking videos for ${sub.name}: $e');
      }
    }

    _lastCheck = DateTime.now();
    _isChecking = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
