import 'package:flutter/material.dart';
import 'package:provider/provider.dart';import 'package:path_provider/path_provider.dart';import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/monitor_service.dart';
import 'login_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Consumer3<StorageService, AuthService, MonitorService>(
        builder: (context, storage, auth, monitor, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Account ──
              const _SectionHeader(title: '账号'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            auth.userFace != null && auth.userFace!.isNotEmpty
                                ? NetworkImage(auth.userFace!)
                                : null,
                        child:
                            auth.userFace == null || auth.userFace!.isEmpty
                                ? const Icon(Icons.person)
                                : null,
                      ),
                      title: Text(auth.userName ?? '未登录'),
                      subtitle: Text('UID: ${auth.userId ?? 'N/A'}'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('退出登录'),
                      onTap: () => _confirmLogout(context, auth, monitor),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const _SectionHeader(title: '监控'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('自动监控'),
                      subtitle:
                          Text(monitor.isMonitoring ? '运行中' : '已停止'),
                      value: monitor.isMonitoring,
                      onChanged: (v) {
                        v
                            ? monitor.startMonitoring()
                            : monitor.stopMonitoring();
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('检查间隔'),
                      subtitle: Text('每 ${storage.checkInterval} 分钟'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          _showIntervalPicker(context, storage, monitor),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('RSSHub 地址'),
                      subtitle: Text(storage.rssHubUrl),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          _showRssHubUrlEditor(context, storage),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('自动下载'),
                      subtitle: const Text('仅自动下载订阅后发布的新视频，历史视频需手动下载'),
                      value: storage.autoDownload,
                      onChanged: (v) => storage.setAutoDownload(v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const _SectionHeader(title: '下载'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('视频质量'),
                      subtitle: Text(_qualityName(storage.videoQuality)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showQualityPicker(context, storage),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('下载路径'),
                      subtitle: FutureBuilder<String>(
                        future: _getDownloadPath(storage),
                        builder: (context, snapshot) {
                          return Text(snapshot.data ?? '加载中...');
                        },
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          _showDownloadPathEditor(context, storage),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const _SectionHeader(title: '关于'),
              Card(
                child: Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.pets),
                      title: Text('Hamster'),
                      subtitle: Text('版本 1.0.0'),
                    ),

                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  // ── Helpers ──

  Future<String> _getDownloadPath(StorageService storage) async {
    if (storage.downloadPath.isNotEmpty) return storage.downloadPath;
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/Hamster/Downloads';
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
      BuildContext context, AuthService auth, MonitorService monitor) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await auth.logout();
      monitor.stopMonitoring();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
      }
    }
  }

  void _showIntervalPicker(
      BuildContext context, StorageService storage, MonitorService monitor) {
    final intervals = [1, 3, 5, 10, 15, 30, 60, 120];
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('检查间隔'),
        children: intervals.map((i) {
          return SimpleDialogOption(
            onPressed: () {
              storage.setCheckInterval(i);
              monitor.updateInterval();
              Navigator.pop(ctx);
            },
            child: Text(
              i < 60 ? '$i 分钟' : '${i ~/ 60} 小时',
              style: TextStyle(
                fontWeight: storage.checkInterval == i
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: storage.checkInterval == i
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
            ),
          );
        }).toList(),
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
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('视频质量'),
        children: qualities.map((q) {
          return SimpleDialogOption(
            onPressed: () {
              storage.setVideoQuality(q.$1);
              Navigator.pop(ctx);
            },
            child: Text(
              q.$2,
              style: TextStyle(
                fontWeight: storage.videoQuality == q.$1
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: storage.videoQuality == q.$1
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showRssHubUrlEditor(BuildContext context, StorageService storage) {
    final controller = TextEditingController(text: storage.rssHubUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('RSSHub 地址'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '地址',
            hintText: 'http://localhost:12000',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          FilledButton(
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

  void _showDownloadPathEditor(BuildContext context, StorageService storage) {
    final controller = TextEditingController(text: storage.downloadPath);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('下载路径'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '路径',
            hintText: '留空使用默认路径',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          FilledButton(
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

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
