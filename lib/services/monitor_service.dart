import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'rss_service.dart';
import 'storage_service.dart';
import 'download_service.dart';
import 'notification_service.dart';
import '../models/video_item.dart';

/// Periodically checks RSSHub for new videos from subscribed UP主.
class MonitorService extends ChangeNotifier {
  final StorageService _storage;
  final DownloadService _downloadService;
  final NotificationService _notificationService;

  Timer? _timer;
  bool _isMonitoring = false;
  bool _isChecking = false;
  DateTime? _lastCheck;
  int _newVideoCount = 0;

  bool get isMonitoring => _isMonitoring;
  bool get isChecking => _isChecking;
  DateTime? get lastCheck => _lastCheck;
  int get newVideoCount => _newVideoCount;

  MonitorService(this._storage, this._downloadService, this._notificationService);

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

    final rssService = RssService(rssHubUrl: _storage.rssHubUrl, rssMode: _storage.rssMode);
    final subscriptions = _storage.subscriptions;

    for (final sub in subscriptions) {
      if (sub.paused) continue;
      try {
        final videos = await rssService.getLatestVideos(sub.mid);

        for (final video in videos) {
          // Skip videos that already exist (including deleted/invalidated ones)
          if (_storage.hasVideo(video.bvid)) {
            // Check if the existing video is in deleted/invalidated state — don't re-download
            final existingStatus = _storage.getVideoStatus(video.bvid);
            if (existingStatus == DownloadStatus.deleted) continue;
            if (existingStatus == DownloadStatus.invalidated) continue;
            continue;
          }

          await _storage.saveVideo(video);
          _newVideoCount++;

          // Skip notifications and auto-download for videos published before
          // the subscription was added — they are pre-existing, not "new".
          final videoPubDate = _parseDate(video.pubDate);
          if (videoPubDate != null && !videoPubDate.isAfter(sub.addedAt)) {
            continue;
          }

          // Auto-download only if enabled, download path is set, and downloads not paused
          final willAutoDownload =
              _storage.autoDownload && _storage.downloadPath.isNotEmpty && !sub.downloadPaused;
          bool didStartDownload = false;
          if (willAutoDownload && sub.matchesTitle(video.title)) {
            await _downloadService.addDownload(video);
            didStartDownload = true;
          }

          // Send local notification
          await _notificationService.showNewVideoNotification(
            upName: sub.name,
            title: video.title,
            autoDownloading: didStartDownload,
          );
        }
      } catch (e) {
        debugPrint('Error checking videos for ${sub.name}: $e');
      }
    }

    _lastCheck = DateTime.now();
    _isChecking = false;
    notifyListeners();
  }

  /// Try to parse various date formats (RFC 1123, ISO 8601, etc.)
  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    // Try ISO 8601 first
    final iso = DateTime.tryParse(dateStr);
    if (iso != null) return iso;
    // Try RFC 1123 (e.g., "Tue, 03 Mar 2026 20:19:17 GMT")
    try {
      return HttpDate.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
