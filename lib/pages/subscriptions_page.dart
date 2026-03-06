import 'dart:io' show Directory, Platform;
import 'package:flutter/cupertino.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../models/subscription.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../services/monitor_service.dart';
import '../services/download_service.dart';
import '../widgets/subscription_card.dart';

class SubscriptionsPage extends StatelessWidget {
  const SubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: const Text('我的订阅'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showAddDialog(context),
          child: const Icon(CupertinoIcons.add, size: 22),
        ),
      ),
      child: SafeArea(
        child: Consumer<StorageService>(
          builder: (context, storage, _) {
            final subs = storage.subscriptions;

            if (subs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.person_2,
                        size: 64,
                        color: CupertinoColors.tertiaryLabel
                            .resolveFrom(context)),
                    const SizedBox(height: 16),
                    Text(
                      '暂无订阅',
                      style: TextStyle(
                        fontSize: 17,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '点击右上角 + 添加UP主',
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.tertiaryLabel
                            .resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: subs.length,
              itemBuilder: (context, index) {
                final sub = subs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SubscriptionCard(
                    subscription: sub,
                    onMore: () =>
                        _showSubscriptionMenu(context, storage, sub),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final storage = context.read<StorageService>();

    // Check if download path is set; if not, prompt user to set it first
    if (storage.downloadPath.isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (dialogCtx) {
          return CupertinoAlertDialog(
            title: const Text('未设置下载路径'),
            content: const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('添加订阅前需要先设置视频下载路径。\n推荐在 Download 目录下创建新文件夹。'),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  if (Platform.isIOS) {
                    final docs = await getApplicationDocumentsDirectory();
                    final dlDir = Directory('${docs.path}/Downloads');
                    if (!await dlDir.exists()) await dlDir.create(recursive: true);
                    storage.setDownloadPath(dlDir.path);
                  } else {
                    final result = await FilePicker.platform.getDirectoryPath(
                      dialogTitle: '选择下载路径',
                    );
                    if (result != null) {
                      storage.setDownloadPath(result);
                    }
                  }
                  if (context.mounted) {
                    _showAddUPDialog(context);
                  }
                },
                child: const Text('去设置'),
              ),
            ],
          );
        },
      );
      return;
    }

    _showAddUPDialog(context);
  }

  void _showAddUPDialog(BuildContext context) {
    final controller = TextEditingController();
    bool isLoading = false;
    String? errorText;

    showCupertinoDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return CupertinoAlertDialog(
              title: const Text('添加 UP主'),
              content: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  children: [
                    CupertinoTextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      placeholder: '请输入UP主的UID',
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child:
                            Icon(CupertinoIcons.search, size: 18),
                      ),
                    ),
                    if (errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          errorText!,
                          style: const TextStyle(
                            color: CupertinoColors.destructiveRed,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: CupertinoActivityIndicator(),
                      ),
                  ],
                ),
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('取消'),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: isLoading
                      ? null
                      : () async {
                          final text = controller.text.trim();
                          if (text.isEmpty) {
                            setDialogState(() {
                              errorText = '请输入UID';
                            });
                            return;
                          }
                          final uid = int.tryParse(text);
                          if (uid == null) {
                            setDialogState(() {
                              errorText = 'UID 必须为数字';
                            });
                            return;
                          }

                          final storage =
                              context.read<StorageService>();

                          // Check if already subscribed
                          if (storage.subscriptions
                              .any((s) => s.mid == uid)) {
                            setDialogState(() {
                              errorText = '已订阅该UP主';
                            });
                            return;
                          }

                          setDialogState(() {
                            isLoading = true;
                            errorText = null;
                          });

                          final api = context.read<ApiService>();
                          final info = await api.getUserInfo(uid);

                          if (info != null) {
                            final sub = Subscription(
                              mid: uid,
                              name: info['name'] ?? 'Unknown',
                              face: info['face'] ?? '',
                              sign: info['sign'] ?? '',
                            );
                            await storage.addSubscription(sub);
                            // Immediately refresh videos for the new subscription
                            if (context.mounted) {
                              context.read<MonitorService>().checkForNewVideos();
                            }
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                          } else {
                            setDialogState(() {
                              isLoading = false;
                              errorText = '未找到该UP主，请检查UID';
                            });
                          }
                        },
                  child: const Text('添加'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSubscriptionMenu(
      BuildContext context, StorageService storage, Subscription sub) {
    // Determine current pause status text
    String pauseStatus = '';
    if (sub.paused) {
      pauseStatus = '（当前：完全暂停）';
    } else if (sub.downloadPaused) {
      pauseStatus = '（当前：仅暂停下载）';
    }

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(sub.name),
        message: pauseStatus.isNotEmpty ? Text(pauseStatus) : null,
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _showPauseMenu(context, storage, sub);
            },
            child: const Text('暂停/恢复 ▸'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDelete(context, storage, sub);
            },
            isDestructiveAction: true,
            child: const Text('取消订阅 ▸'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _showPauseMenu(
      BuildContext context, StorageService storage, Subscription sub) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('暂停选项 - ${sub.name}'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              storage.toggleDownloadPause(sub.mid);
            },
            child: Text(
              sub.downloadPaused
                  ? '恢复自动下载'
                  : '暂停自动下载（继续获取视频）',
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              storage.toggleSubscriptionPause(sub.mid);
            },
            child: Text(
              sub.paused
                  ? '恢复订阅'
                  : '完全暂停（不获取视频）',
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, StorageService storage, Subscription sub) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('取消订阅 ${sub.name}'),
        message: const Text(
          '请选择取消订阅后的处理方式\n\n'
          '· 仅取消订阅：保留已获取的动态和已下载的视频文件\n'
          '· 取消订阅并清除动态：移除该UP的所有动态记录，保留已下载文件\n'
          '· 取消订阅并删除所有：移除动态记录并删除已下载的视频文件',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              storage.removeSubscription(sub.mid);
              Navigator.pop(ctx);
            },
            child: const Text('仅取消订阅'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              await storage.removeVideosByAuthor(sub.mid);
              await storage.removeSubscription(sub.mid);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('取消订阅并清除动态'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              final download = context.read<DownloadService>();
              final removedVideos =
                  await storage.removeVideosByAuthor(sub.mid);
              await download.cancelAndDeleteByAuthor(removedVideos);
              await storage.removeSubscription(sub.mid);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('取消订阅并删除所有'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }
}
