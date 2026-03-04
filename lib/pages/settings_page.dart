import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/monitor_service.dart';
import 'login_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('设置'),
      ),
      child: SafeArea(
        child: Consumer3<StorageService, AuthService, MonitorService>(
          builder: (context, storage, auth, monitor, _) {
            return ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                // ── Account ──
                CupertinoListSection.insetGrouped(
                  header: const Text('账号'),
                  children: [
                    CupertinoListTile(
                      leading: _buildAvatar(auth),
                      title: Text(auth.userName ?? '未登录'),
                      subtitle: Text('UID: ${auth.userId ?? 'N/A'}'),
                    ),
                    CupertinoListTile(
                      leading: const Icon(CupertinoIcons.square_arrow_right,
                          color: CupertinoColors.destructiveRed),
                      title: const Text('退出登录',
                          style:
                              TextStyle(color: CupertinoColors.destructiveRed)),
                      onTap: () =>
                          _confirmLogout(context, auth, monitor),
                    ),
                  ],
                ),

                // ── Monitor ──
                CupertinoListSection.insetGrouped(
                  header: const Text('监控'),
                  children: [
                    CupertinoListTile(
                      title: const Text('自动监控'),
                      subtitle:
                          Text(monitor.isMonitoring ? '运行中' : '已停止'),
                      trailing: CupertinoSwitch(
                        value: monitor.isMonitoring,
                        onChanged: (v) {
                          v
                              ? monitor.startMonitoring()
                              : monitor.stopMonitoring();
                        },
                      ),
                    ),
                    CupertinoListTile(
                      title: const Text('检查间隔'),
                      additionalInfo:
                          Text('每 ${storage.checkInterval} 分钟'),
                      trailing:
                          const CupertinoListTileChevron(),
                      onTap: () => _showIntervalPicker(
                          context, storage, monitor),
                    ),
                    CupertinoListTile(
                      title: const Text('RSSHub 地址'),
                      subtitle: Text(storage.rssHubUrl,
                          style: const TextStyle(fontSize: 12)),
                      trailing:
                          const CupertinoListTileChevron(),
                      onTap: () =>
                          _showRssHubUrlEditor(context, storage),
                    ),
                    CupertinoListTile(
                      title: const Text('自动下载'),
                      subtitle: const Text(
                        '仅自动下载订阅后发布的新视频',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: CupertinoSwitch(
                        value: storage.autoDownload,
                        onChanged: (v) => storage.setAutoDownload(v),
                      ),
                    ),
                  ],
                ),

                // ── Download ──
                CupertinoListSection.insetGrouped(
                  header: const Text('下载'),
                  children: [
                    CupertinoListTile(
                      title: const Text('视频质量'),
                      additionalInfo:
                          Text(_qualityName(storage.videoQuality)),
                      trailing:
                          const CupertinoListTileChevron(),
                      onTap: () =>
                          _showQualityPicker(context, storage),
                    ),
                    CupertinoListTile(
                      title: const Text('下载路径'),
                      subtitle: FutureBuilder<String>(
                        future: _getDownloadPath(storage),
                        builder: (context, snapshot) {
                          return Text(
                            snapshot.data ?? '加载中...',
                            style: const TextStyle(fontSize: 12),
                          );
                        },
                      ),
                      trailing:
                          const CupertinoListTileChevron(),
                      onTap: () =>
                          _showDownloadPathEditor(context, storage),
                    ),
                  ],
                ),

                // ── About ──
                CupertinoListSection.insetGrouped(
                  header: const Text('关于'),
                  children: [
                    const CupertinoListTile(
                      leading: Icon(CupertinoIcons.paw),
                      title: Text('Squirrel'),
                      additionalInfo: Text('0.1.0'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAvatar(AuthService auth) {
    if (auth.userFace != null && auth.userFace!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          auth.userFace!,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(CupertinoIcons.person_fill, size: 24),
        ),
      );
    }
    return const Icon(CupertinoIcons.person_fill, size: 24);
  }

  Future<String> _getDownloadPath(StorageService storage) async {
    if (storage.downloadPath.isNotEmpty) return storage.downloadPath;
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/Squirrel/Downloads';
  }

  String _qualityName(int qn) {
    switch (qn) {
      case 16:
        return '360P';
      case 32:
        return '480P';
      case 64:
        return '720P';
      case 80:
        return '1080P';
      case 112:
        return '1080P+';
      case 116:
        return '1080P60';
      default:
        return '未知';
    }
  }

  void _confirmLogout(
      BuildContext context, AuthService auth, MonitorService monitor) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await auth.logout();
              monitor.stopMonitoring();
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true)
                    .pushAndRemoveUntil(
                  CupertinoPageRoute(
                      builder: (_) => const LoginPage()),
                  (_) => false,
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showIntervalPicker(
      BuildContext context, StorageService storage, MonitorService monitor) {
    final intervals = [1, 3, 5, 10, 15, 30, 60, 120];
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('检查间隔'),
        actions: intervals.map((i) {
          final isSelected = storage.checkInterval == i;
          return CupertinoActionSheetAction(
            onPressed: () {
              storage.setCheckInterval(i);
              monitor.updateInterval();
              Navigator.pop(ctx);
            },
            child: Text(
              i < 60 ? '$i 分钟' : '${i ~/ 60} 小时',
              style: TextStyle(
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _showQualityPicker(BuildContext context, StorageService storage) {
    final qualities = [
      (16, '360P'),
      (32, '480P'),
      (64, '720P'),
      (80, '1080P'),
      (112, '1080P+ (需要大会员)'),
      (116, '1080P60 (需要大会员)'),
    ];
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('视频质量'),
        actions: qualities.map((q) {
          final isSelected = storage.videoQuality == q.$1;
          return CupertinoActionSheetAction(
            onPressed: () {
              storage.setVideoQuality(q.$1);
              Navigator.pop(ctx);
            },
            child: Text(
              q.$2,
              style: TextStyle(
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _showRssHubUrlEditor(BuildContext context, StorageService storage) {
    final controller = TextEditingController(text: storage.rssHubUrl);
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('RSSHub 地址'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'http://localhost:12000',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              storage.setRssHubUrl(controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showDownloadPathEditor(
      BuildContext context, StorageService storage) {
    final controller =
        TextEditingController(text: storage.downloadPath);
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('下载路径'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: CupertinoTextField(
            controller: controller,
            placeholder: '留空使用默认路径',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              storage.setDownloadPath(controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
