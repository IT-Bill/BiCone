import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'services/storage_service.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/download_service.dart';
import 'services/monitor_service.dart';
import 'services/notification_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

bool get isDesktop =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop window management
  if (isDesktop) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1280, 720),
      minimumSize: Size(800, 600),
      center: true,
      title: 'BiCone',
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Initialize persistent storage
  final storage = StorageService();
  await storage.init();

  // Wire up services
  final auth = AuthService(storage);
  final api = ApiService(storage);
  final notification = NotificationService();
  await notification.init();

  final download = DownloadService(api, storage, notification);
  final monitor = MonitorService(storage, download, notification);

  // Clean up any downloads that were interrupted by app exit
  await download.cleanupStuckDownloads();

  // Try to restore a previous session
  await auth.tryRestoreLogin();

  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://538393aafe3a2efdc95b9e3e4467146b@o4511002658930688.ingest.de.sentry.io/4511002691567696';
    },
    appRunner: () => runApp(SentryWidget(child: 
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: storage),
        ChangeNotifierProvider.value(value: auth),
        Provider.value(value: api),
        ChangeNotifierProvider.value(value: download),
        ChangeNotifierProvider.value(value: monitor),
      ],
      child: const BiConeApp(),
    ),
  )),
  );
}
