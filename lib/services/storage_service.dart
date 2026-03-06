import 'dart:io' show Directory, Platform;
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/subscription.dart';
import '../models/video_item.dart';

class StorageService extends ChangeNotifier {
  static const String _authBoxName = 'auth';
  static const String _subsBoxName = 'subscriptions';
  static const String _videosBoxName = 'videos';
  static const String _settingsBoxName = 'settings';

  late Box _authBox;
  late Box _subsBox;
  late Box _videosBox;
  late Box _settingsBox;

  List<Subscription> _subscriptions = [];
  List<VideoItem> _videos = [];

  List<Subscription> get subscriptions => _subscriptions;
  List<VideoItem> get videos => _videos;

  Future<void> init() async {
    await Hive.initFlutter();
    _authBox = await Hive.openBox(_authBoxName);
    _subsBox = await Hive.openBox(_subsBoxName);
    _videosBox = await Hive.openBox(_videosBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
    _loadSubscriptions();
    _loadVideos();

    // On iOS, auto-set download path to app's Documents directory
    if (!kIsWeb && Platform.isIOS && downloadPath.isEmpty) {
      final docs = await getApplicationDocumentsDirectory();
      final dlDir = Directory('${docs.path}/Downloads');
      if (!await dlDir.exists()) await dlDir.create(recursive: true);
      await setDownloadPath(dlDir.path);
    }
  }

  // ─── Auth ──────────────────────────────────────────────

  Future<void> saveAuth({
    required String sessdata,
    required String biliJct,
    required String userId,
    required String refreshToken,
    String? userName,
    String? userFace,
  }) async {
    await _authBox.putAll({
      'sessdata': sessdata,
      'bili_jct': biliJct,
      'user_id': userId,
      'refresh_token': refreshToken,
      'user_name': userName ?? '',
      'user_face': userFace ?? '',
    });
  }

  String? get sessdata => _authBox.get('sessdata');
  String? get biliJct => _authBox.get('bili_jct');
  String? get userId => _authBox.get('user_id');
  String? get refreshToken => _authBox.get('refresh_token');
  String? get userName => _authBox.get('user_name');
  String? get userFace => _authBox.get('user_face');
  bool get isLoggedIn => sessdata != null && sessdata!.isNotEmpty;

  Future<void> clearAuth() async {
    await _authBox.clear();
    notifyListeners();
  }

  // ─── Subscriptions ────────────────────────────────────

  void _loadSubscriptions() {
    _subscriptions = [];
    for (var key in _subsBox.keys) {
      final data = _subsBox.get(key);
      if (data != null) {
        _subscriptions
            .add(Subscription.fromJson(Map<String, dynamic>.from(data)));
      }
    }
  }

  Future<void> addSubscription(Subscription sub) async {
    await _subsBox.put(sub.mid.toString(), sub.toJson());
    _loadSubscriptions();
    notifyListeners();
  }

  Future<void> removeSubscription(int mid) async {
    await _subsBox.delete(mid.toString());
    _loadSubscriptions();
    notifyListeners();
  }

  /// Remove all video records for a given UP主 (by mid).
  /// Returns the list of removed videos for potential file cleanup.
  Future<List<VideoItem>> removeVideosByAuthor(int mid) async {
    final toRemove =
        _videos.where((v) => v.authorMid == mid).toList();
    for (final video in toRemove) {
      await _videosBox.delete(video.bvid);
    }
    _loadVideos();
    notifyListeners();
    return toRemove;
  }

  bool isSubscribed(int mid) {
    return _subscriptions.any((s) => s.mid == mid);
  }

  // ─── Videos ───────────────────────────────────────────

  void _loadVideos() {
    _videos = [];
    for (var key in _videosBox.keys) {
      final data = _videosBox.get(key);
      if (data != null) {
        _videos.add(VideoItem.fromJson(Map<String, dynamic>.from(data)));
      }
    }
    _videos.sort((a, b) => b.pubDate.compareTo(a.pubDate));
  }

  Future<void> saveVideo(VideoItem video) async {
    await _videosBox.put(video.bvid, video.toJson());
    _loadVideos();
    notifyListeners();
  }

  Future<void> updateVideoStatus(
    String bvid,
    DownloadStatus status, {
    double? progress,
    String? localPath,
    int? fileSize,
  }) async {
    final data = _videosBox.get(bvid);
    if (data != null) {
      final map = Map<String, dynamic>.from(data);
      map['downloadStatus'] = status.index;
      if (progress != null) map['downloadProgress'] = progress;
      if (localPath != null) map['localPath'] = localPath;
      if (fileSize != null) map['fileSize'] = fileSize;
      if (status == DownloadStatus.completed) {
        map['downloadedAt'] = DateTime.now().toUtc().toIso8601String();
      }
      await _videosBox.put(bvid, map);
      _loadVideos();
      notifyListeners();
    }
  }

  bool hasVideo(String bvid) {
    return _videosBox.containsKey(bvid);
  }

  DownloadStatus getVideoStatus(String bvid) {
    final data = _videosBox.get(bvid);
    if (data == null) return DownloadStatus.none;
    final map = Map<String, dynamic>.from(data);
    final index = map['downloadStatus'] ?? 0;
    if (index >= 0 && index < DownloadStatus.values.length) {
      return DownloadStatus.values[index];
    }
    return DownloadStatus.none;
  }

  Future<void> deleteVideo(String bvid) async {
    final data = _videosBox.get(bvid);
    if (data != null) {
      final map = Map<String, dynamic>.from(data);
      map['downloadStatus'] = DownloadStatus.deleted.index;
      map['downloadProgress'] = 0.0;
      // Keep localPath for reference but mark as deleted
      await _videosBox.put(bvid, map);
      _loadVideos();
      notifyListeners();
    }
  }

  Future<void> restoreVideo(String bvid) async {
    final data = _videosBox.get(bvid);
    if (data != null) {
      final map = Map<String, dynamic>.from(data);
      map['downloadStatus'] = DownloadStatus.none.index;
      map['downloadProgress'] = 0.0;
      map['localPath'] = null;
      await _videosBox.put(bvid, map);
      _loadVideos();
      notifyListeners();
    }
  }

  Future<void> invalidateVideo(String bvid) async {
    final data = _videosBox.get(bvid);
    if (data != null) {
      final map = Map<String, dynamic>.from(data);
      map['downloadStatus'] = DownloadStatus.invalidated.index;
      map['downloadProgress'] = 0.0;
      await _videosBox.put(bvid, map);
      _loadVideos();
      notifyListeners();
    }
  }

  // ─── Settings ─────────────────────────────────────────

  String get rssHubUrl =>
      _settingsBox.get('rssHubUrl', defaultValue: 'https://squirrel.itbill.cn');
  Future<void> setRssHubUrl(String url) async {
    await _settingsBox.put('rssHubUrl', url);
    notifyListeners();
  }

  String get downloadPath =>
      _settingsBox.get('downloadPath', defaultValue: '');
  Future<void> setDownloadPath(String path) async {
    await _settingsBox.put('downloadPath', path);
    notifyListeners();
  }

  int get checkInterval =>
      _settingsBox.get('checkInterval', defaultValue: 3);
  Future<void> setCheckInterval(int minutes) async {
    await _settingsBox.put('checkInterval', minutes);
    notifyListeners();
  }

  int get videoQuality =>
      _settingsBox.get('videoQuality', defaultValue: 80);
  Future<void> setVideoQuality(int qn) async {
    await _settingsBox.put('videoQuality', qn);
    notifyListeners();
  }

  bool get autoDownload =>
      _settingsBox.get('autoDownload', defaultValue: true);
  Future<void> setAutoDownload(bool enabled) async {
    await _settingsBox.put('autoDownload', enabled);
    notifyListeners();
  }

  bool get hideUndownloaded =>
      _settingsBox.get('hideUndownloaded', defaultValue: false);
  Future<void> setHideUndownloaded(bool enabled) async {
    await _settingsBox.put('hideUndownloaded', enabled);
    notifyListeners();
  }

  /// RSS mode: 'dynamic' (default) or 'video'
  String get rssMode =>
      _settingsBox.get('rssMode', defaultValue: 'dynamic');
  Future<void> setRssMode(String mode) async {
    await _settingsBox.put('rssMode', mode);
    notifyListeners();
  }
}
