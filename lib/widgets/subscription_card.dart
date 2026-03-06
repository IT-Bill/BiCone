import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/subscription.dart';

class SubscriptionCard extends StatelessWidget {
  final Subscription subscription;
  final VoidCallback? onMore;

  const SubscriptionCard({
    super.key,
    required this.subscription,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Avatar ──
          ClipOval(
            child: subscription.face.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: subscription.face,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 48,
                      height: 48,
                      color: CupertinoColors.systemGrey5
                          .resolveFrom(context),
                      child: const Icon(CupertinoIcons.person_fill,
                          size: 24, color: CupertinoColors.systemGrey),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 48,
                      height: 48,
                      color: CupertinoColors.systemGrey5
                          .resolveFrom(context),
                      child: const Icon(CupertinoIcons.person_fill,
                          size: 24, color: CupertinoColors.systemGrey),
                    ),
                  )
                : Container(
                    width: 48,
                    height: 48,
                    color: CupertinoColors.systemGrey5
                        .resolveFrom(context),
                    child: const Icon(CupertinoIcons.person_fill,
                        size: 24, color: CupertinoColors.systemGrey),
                  ),
          ),
          const SizedBox(width: 12),

          // ── Info ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subscription.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'UID: ${subscription.mid}',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel
                        .resolveFrom(context),
                  ),
                ),
                if (subscription.paused) ...[
                  const SizedBox(height: 2),
                  Text(
                    '已暂停',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemOrange
                          .resolveFrom(context),
                    ),
                  ),
                ] else if (subscription.downloadPaused) ...[
                  const SizedBox(height: 2),
                  Text(
                    '已暂停下载',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemOrange
                          .resolveFrom(context),
                    ),
                  ),
                ] else if (subscription.sign.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subscription.sign,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.tertiaryLabel
                          .resolveFrom(context),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── More ──
          if (onMore != null)
            CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 32,
              onPressed: onMore,
              child: Icon(
                CupertinoIcons.ellipsis,
                size: 20,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
        ],
      ),
    );
  }
}
