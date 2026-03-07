import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/monitor_service.dart';
import 'login_page.dart';
import 'feedback_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        transitionBetweenRoutes: false,
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
                      title: const Text('获取方式'),
                      additionalInfo: Text(
                        storage.rssMode == 'video' ? '视频接口' : '动态接口',
                      ),
                      trailing:
                          const CupertinoListTileChevron(),
                      onTap: () =>
                          _showRssModePicker(context, storage),
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
                    CupertinoListTile(
                      title: const Text('保存封面'),
                      subtitle: const Text(
                        '将视频封面保存到视频相同目录',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: CupertinoSwitch(
                        value: storage.saveCover,
                        onChanged: (v) => storage.setSaveCover(v),
                      ),
                    ),
                  ],
                ),

                // ── About ──
                CupertinoListSection.insetGrouped(
                  header: const Text('关于'),
                  children: [
                    CupertinoListTile(
                      leading: const Icon(CupertinoIcons.chat_bubble_text,
                          color: CupertinoColors.activeBlue),
                      title: const Text('意见反馈'),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (_) => const FeedbackPage(),
                          ),
                        );
                      },
                    ),
                    const CupertinoListTile(
                      leading: Icon(CupertinoIcons.paw),
                      title: Text('BiCone'),
                      additionalInfo: Text('0.2.7'),
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
    return '未设置（点击选择）';
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
      case 120:
        return '4K';
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
      (120, '4K (需要大会员)'),
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
      BuildContext context, StorageService storage) async {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('下载路径'),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'iOS 下载路径固定在应用沙盒内：\n${storage.downloadPath}\n\n可通过「文件」App 访问下载的视频。',
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      return;
    }
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择下载路径',
      initialDirectory: storage.downloadPath.isNotEmpty
          ? storage.downloadPath
          : null,
    );
    if (result != null) {
      storage.setDownloadPath(result);
    }
  }

  void _showRssModePicker(BuildContext context, StorageService storage) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('获取方式'),
        message: const Text(
          '动态接口：获取的历史视频较少（UP经常发动态时），但风控较少，成功率更高\n'
          '视频接口：获取的历史视频较多，但更可能触发风控导致获取失败\n'
          '两者获取最新视频的实时性一致（约1分钟延迟）',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              storage.setRssMode('dynamic');
              Navigator.pop(ctx);
            },
            child: Text(
              '动态接口（推荐）',
              style: TextStyle(
                fontWeight: storage.rssMode == 'dynamic'
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              storage.setRssMode('video');
              Navigator.pop(ctx);
            },
            child: Text(
              '视频接口',
              style: TextStyle(
                fontWeight: storage.rssMode == 'video'
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }
}
