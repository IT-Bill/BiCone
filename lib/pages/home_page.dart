import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show LinearProgressIndicator, Material, NavigationRail, NavigationRailDestination, NavigationRailLabelType;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/monitor_service.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';
import '../theme.dart';
import 'feed_page.dart';
import 'subscriptions_page.dart';
import 'downloads_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final _pages = const [
    FeedPage(),
    SubscriptionsPage(),
    DownloadsPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MonitorService>().startMonitoring();
      _checkUpdateOnFirstLaunchOfDay();
    });
  }

  /// Check for updates once per day on first app launch.
  /// If the user previously skipped this version, don't prompt again.
  Future<void> _checkUpdateOnFirstLaunchOfDay() async {
    final storage = context.read<StorageService>();

    // Only check once per calendar day
    final lastCheck = storage.lastUpdateCheck;
    if (lastCheck.isNotEmpty) {
      try {
        final lastDate = DateTime.parse(lastCheck);
        final now = DateTime.now();
        if (lastDate.year == now.year &&
            lastDate.month == now.month &&
            lastDate.day == now.day) {
          return; // Already checked today
        }
      } catch (_) {}
    }

    final source = storage.updateSource == 'github'
        ? UpdateSource.github
        : UpdateSource.gitee;

    try {
      final currentVersion = await UpdateService.getCurrentVersion();
      final release = await UpdateService.checkForUpdate(source);
      storage.setLastUpdateCheck(DateTime.now());

      if (release == null) return;
      if (!UpdateService.isNewer(currentVersion, release.version)) return;

      // If user previously skipped this exact version, don't prompt
      if (storage.skippedVersion == release.version) return;

      if (!mounted) return;
      _showAutoUpdateDialog(currentVersion, release, storage);
    } catch (_) {
      // Silently ignore errors for background update checks
    }
  }

  void _showAutoUpdateDialog(
      String currentVersion, ReleaseInfo release, StorageService storage) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('发现新版本 ${release.version}'),
        content: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('当前版本: $currentVersion',
                  style: const TextStyle(fontSize: 13)),
            ),
            if (release.changelog.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 12),
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Text(
                    release.changelog,
                    style: const TextStyle(fontSize: 13),
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              storage.setSkippedVersion(release.version);
              Navigator.pop(ctx);
            },
            child: const Text('跳过此版本'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _downloadAndInstall(release);
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }

  void _downloadAndInstall(ReleaseInfo release) async {
    final cancelToken = CancelToken();
    final progressNotifier = ValueNotifier<String>('准备下载...');
    final valueNotifier = ValueNotifier<double?>(null);

    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('正在下载更新'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            children: [
              ValueListenableBuilder<double?>(
                valueListenable: valueNotifier,
                builder: (_, value, _) =>
                    LinearProgressIndicator(value: value),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<String>(
                valueListenable: progressNotifier,
                builder: (_, text, _) =>
                    Text(text, style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              cancelToken.cancel();
              Navigator.pop(ctx);
            },
            child: const Text('取消'),
          ),
        ],
      ),
    );

    try {
      final filePath = await UpdateService.downloadUpdate(
        release.downloadUrl,
        onProgress: (received, total) {
          if (total > 0) {
            valueNotifier.value = received / total;
            progressNotifier.value =
                '${(received / 1024 / 1024).toStringAsFixed(1)} / '
                '${(total / 1024 / 1024).toStringAsFixed(1)} MB';
          }
        },
        cancelToken: cancelToken,
      );

      if (!mounted) return;
      Navigator.pop(context); // dismiss download dialog

      await UpdateService.installUpdate(filePath);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        Navigator.pop(context);
      }
    } finally {
      progressNotifier.dispose();
      valueNotifier.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 720;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () => _switchTab(0),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () => _switchTab(1),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () => _switchTab(2),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true): () => _switchTab(3),
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () {
          context.read<MonitorService>().checkForNewVideos();
        },
      },
      child: Focus(
        autofocus: true,
        child: isWide ? _buildDesktopLayout(context) : _buildMobileLayout(context),
      ),
    );
  }

  void _switchTab(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return CupertinoPageScaffold(
      child: Row(
        children: [
          // ── Left NavigationRail ──
          Material(
            color: CupertinoColors.systemBackground.resolveFrom(context),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: CupertinoColors.systemGrey4
                        .resolveFrom(context)
                        .withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
              ),
              child: NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: _switchTab,
              labelType: NavigationRailLabelType.all,
              backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
              selectedIconTheme: const IconThemeData(color: AppTheme.biliPink),
              unselectedIconTheme: IconThemeData(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
              selectedLabelTextStyle: const TextStyle(
                color: AppTheme.biliPink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelTextStyle: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontSize: 12,
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(CupertinoIcons.play_rectangle),
                  selectedIcon: Icon(CupertinoIcons.play_rectangle_fill),
                  label: Text('视频'),
                ),
                NavigationRailDestination(
                  icon: Icon(CupertinoIcons.person_2),
                  selectedIcon: Icon(CupertinoIcons.person_2_fill),
                  label: Text('订阅'),
                ),
                NavigationRailDestination(
                  icon: Icon(CupertinoIcons.arrow_down_circle),
                  selectedIcon: Icon(CupertinoIcons.arrow_down_circle_fill),
                  label: Text('下载'),
                ),
                NavigationRailDestination(
                  icon: Icon(CupertinoIcons.gear),
                  selectedIcon: Icon(CupertinoIcons.gear_solid),
                  label: Text('设置'),
                ),
              ],
            ),
          ),
          ),  // closes Material
          // ── Page content ──
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return CupertinoPageScaffold(
      child: Stack(
        children: [
          // ── Page content ──
          Positioned.fill(
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),

          // ── Floating tab bar ──
          Positioned(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 12,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground
                        .resolveFrom(context)
                        .withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: CupertinoColors.systemGrey4
                          .resolveFrom(context)
                          .withValues(alpha: 0.4),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withValues(alpha: 0.05),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTab(0, CupertinoIcons.play_rectangle,
                          CupertinoIcons.play_rectangle_fill, '视频'),
                      _buildTab(1, CupertinoIcons.person_2,
                          CupertinoIcons.person_2_fill, '订阅'),
                      _buildTab(2, CupertinoIcons.arrow_down_circle,
                          CupertinoIcons.arrow_down_circle_fill, '下载'),
                      _buildTab(3, CupertinoIcons.gear,
                          CupertinoIcons.gear_solid, '设置'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(
      int index, IconData icon, IconData activeIcon, String label) {
    final isActive = _currentIndex == index;
    final color = isActive
        ? AppTheme.biliPink
        : CupertinoColors.secondaryLabel.resolveFrom(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _switchTab(index),
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? activeIcon : icon, size: 24, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
