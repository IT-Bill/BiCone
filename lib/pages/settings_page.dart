import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show LinearProgressIndicator;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/monitor_service.dart';
import '../services/update_service.dart';
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
                    GestureDetector(
                      onLongPress: () => _showSourcePicker(context, storage),
                      child: CupertinoListTile(
                        leading: const Icon(CupertinoIcons.arrow_clockwise,
                            color: CupertinoColors.activeGreen),
                        title: const Text('检查更新'),
                        subtitle: Text(
                          '长按切换源，${_formatLastCheck(storage.lastUpdateCheck)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        additionalInfo: Text(
                          storage.updateSource == 'github' ? 'GitHub' : 'Gitee',
                        ),
                        trailing: const CupertinoListTileChevron(),
                        onTap: () => _doCheckUpdate(
                          context,
                          storage.updateSource == 'github'
                              ? UpdateSource.github
                              : UpdateSource.gitee,
                          storage,
                        ),
                      ),
                    ),
                    CupertinoListTile(
                      leading: const Icon(CupertinoIcons.paw),
                      title: const Text('BiCone'),
                      additionalInfo: FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (context, snapshot) {
                          return Text(snapshot.data?.version ?? '');
                        },
                      ),
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
          errorBuilder: (_, _, _) =>
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

  String _formatLastCheck(String isoString) {
    if (isoString.isEmpty) return '尚未检查';
    try {
      final dt = DateTime.parse(isoString);
      return '上次检查 ${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '尚未检查';
    }
  }

  void _showSourcePicker(BuildContext context, StorageService storage) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('选择更新源'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              storage.setUpdateSource('github');
              Navigator.pop(ctx);
            },
            child: Text(
              'GitHub',
              style: TextStyle(
                fontWeight: storage.updateSource == 'github'
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              storage.setUpdateSource('gitee');
              Navigator.pop(ctx);
            },
            child: Text(
              'Gitee（国内推荐）',
              style: TextStyle(
                fontWeight: storage.updateSource == 'gitee'
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

  void _doCheckUpdate(BuildContext context, UpdateSource source, StorageService storage) async {
    // Show loading
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CupertinoActivityIndicator(radius: 16)),
    );

    try {
      final currentVersion = await UpdateService.getCurrentVersion();
      final release = await UpdateService.checkForUpdate(source);

      if (!context.mounted) return;
      Navigator.pop(context); // dismiss loading
      storage.setLastUpdateCheck(DateTime.now());

      if (release == null) {
        _showSimpleDialog(context, '检查失败', '无法获取版本信息，请检查网络连接。');
        return;
      }

      if (!UpdateService.isNewer(currentVersion, release.version)) {
        _showSimpleDialog(context, '已是最新版本',
            '当前版本 $currentVersion 已是最新。');
        return;
      }

      // Show update dialog with changelog
      _showUpdateDialog(context, currentVersion, release, source);
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // dismiss loading
        _showSimpleDialog(context, '检查失败', '发生错误: $e');
      }
    }
  }

  void _showUpdateDialog(BuildContext context, String currentVersion,
      ReleaseInfo release, UpdateSource source) {
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍后'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _downloadAndInstall(context, release);
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }

  void _downloadAndInstall(BuildContext context, ReleaseInfo release) async {
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
                builder: (_, value, _) => LinearProgressIndicator(value: value),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<String>(
                valueListenable: progressNotifier,
                builder: (_, text, _) => Text(text,
                    style: const TextStyle(fontSize: 13)),
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

      if (!context.mounted) return;
      Navigator.pop(context); // dismiss download dialog

      await UpdateService.installUpdate(filePath);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      if (context.mounted) {
        Navigator.pop(context);
        _showSimpleDialog(context, '下载失败', '下载更新包失败: $e');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        _showSimpleDialog(context, '下载失败', '下载更新包失败: $e');
      }
    } finally {
      progressNotifier.dispose();
      valueNotifier.dispose();
    }
  }

  void _showSimpleDialog(BuildContext context, String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(message),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
