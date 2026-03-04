import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Manages local push notifications for new-video alerts.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidSettings,
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

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '$upName 发布了新视频',
      body: body,
      notificationDetails: details,
    );
  }
}
