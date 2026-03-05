import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'services/storage_service.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/download_service.dart';
import 'services/monitor_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(
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
  );
}
