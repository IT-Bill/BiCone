import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Manages local push notifications for new-video alerts and download progress.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Stable notification ID for the download progress notification.
  static const int _downloadProgressId = 9999;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final windowsSettings = WindowsInitializationSettings(
      appName: 'BiCone',
      appUserModelId: 'cn.itbill.bicone',
      guid: 'b9e7a08f-7529-4f77-b165-3f2a6525a684',
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      windows: windowsSettings,
    );

    await _plugin.initialize(settings: initSettings);
    _initialized = true;

    // Request notification permission on Android 13+
    if (!kIsWeb && Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  /// Show a notification about a newly discovered video.
  Future<void> showNewVideoNotification({
    required String upName,
    required String title,
    required bool autoDownloading,
  }) async {
    if (!_initialized) return;

    final body = autoDownloading
        ? '$title\n自动下载已开始…'
        : '$title\n自动下载未开启，请手动下载';

    const androidDetails = AndroidNotificationDetails(
      'new_video_channel',
      '新视频提醒',
      channelDescription: '当订阅的UP主发布新视频时通知',
      importance: Importance.high,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '$upName 发布了新视频',
      body: body,
      notificationDetails: details,
    );
  }

  /// Show or update the download progress notification.
  Future<void> showDownloadProgressNotification({
    required String title,
    required int progress,
    required String status,
  }) async {
    if (!_initialized) return;

    final androidDetails = AndroidNotificationDetails(
      'download_channel',
      '下载进度',
      channelDescription: '显示视频下载进度',
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      ongoing: true,
      autoCancel: false,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: false,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _plugin.show(
      id: _downloadProgressId,
      title: '正在下载: $title',
      body: status,
      notificationDetails: details,
    );
  }

  /// Show a download completed notification (replaces the progress one).
  Future<void> showDownloadCompleteNotification({
    required String title,
  }) async {
    if (!_initialized) return;

    // Cancel the progress notification first
    await _plugin.cancel(id: _downloadProgressId);

    const androidDetails = AndroidNotificationDetails(
      'download_channel',
      '下载进度',
      channelDescription: '显示视频下载进度',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '下载完成',
      body: title,
      notificationDetails: details,
    );
  }

  /// Cancel the download progress notification (e.g., when download is cancelled).
  Future<void> cancelDownloadNotification() async {
    if (!_initialized) return;
    await _plugin.cancel(id: _downloadProgressId);
  }
}
