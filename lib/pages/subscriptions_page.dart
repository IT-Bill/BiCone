import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../models/subscription.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../widgets/subscription_card.dart';

class SubscriptionsPage extends StatelessWidget {
  const SubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
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
                    onDelete: () =>
                        _confirmDelete(context, storage, sub),
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

  void _confirmDelete(
      BuildContext context, StorageService storage, Subscription sub) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('取消订阅'),
        content: Text('确定要取消订阅 ${sub.name} 吗？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              storage.removeSubscription(sub.mid);
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
