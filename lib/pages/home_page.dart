import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../services/monitor_service.dart';
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
    });
  }

  @override
  Widget build(BuildContext context) {
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
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground
                        .resolveFrom(context)
                        .withOpacity(0.72),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: CupertinoColors.systemGrey4
                          .resolveFrom(context)
                          .withOpacity(0.3),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
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
      onTap: () {
        if (_currentIndex != index) {
          setState(() => _currentIndex = index);
        }
      },
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
