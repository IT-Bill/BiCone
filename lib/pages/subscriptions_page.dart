import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/subscription.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../widgets/subscription_card.dart';

class SubscriptionsPage extends StatelessWidget {
  const SubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('我的订阅')),
      body: Consumer<StorageService>(
        builder: (context, storage, _) {
          final subs = storage.subscriptions;

          if (subs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: cs.outlineVariant),
                  const SizedBox(height: 16),
                  Text(
                    '暂无订阅',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击右下角按钮添加UP主',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.outline),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: subs.length,
            itemBuilder: (context, index) {
              final sub = subs[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SubscriptionCard(
                  subscription: sub,
                  onDelete: () => _confirmDelete(context, storage, sub),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('添加订阅'),
      ),
    );
  }

  // ── Add subscription dialog ──

  void _showAddDialog(BuildContext context) {
    final controller = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('添加 UP主'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'UP主 UID',
                      hintText: '请输入UP主的UID',
                      prefixIcon: Icon(Icons.person_search),
                    ),
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final uid = int.tryParse(controller.text.trim());
                          if (uid == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('请输入有效的UID')),
                            );
                            return;
                          }

                          setDialogState(() => isLoading = true);

                          final api = context.read<ApiService>();
                          final storage = context.read<StorageService>();
                          final info = await api.getUserInfo(uid);

                          if (info != null) {
                            final sub = Subscription(
                              mid: uid,
                              name: info['name'] ?? 'Unknown',
                              face: info['face'] ?? '',
                              sign: info['sign'] ?? '',
                            );
                            await storage.addSubscription(sub);

                            if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('已订阅 ${sub.name}')),
                              );
                            }
                          } else {
                            setDialogState(() => isLoading = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('未找到该用户，请检查UID')),
                              );
                            }
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

  // ── Confirm deletion ──

  void _confirmDelete(
      BuildContext context, StorageService storage, Subscription sub) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('取消订阅'),
        content: Text('确定要取消订阅 ${sub.name} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              storage.removeSubscription(sub.mid);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已取消订阅 ${sub.name}')),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
