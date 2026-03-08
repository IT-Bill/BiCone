import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/subscription.dart';

class SubscriptionCard extends StatefulWidget {
  final Subscription subscription;
  final VoidCallback? onMore;

  const SubscriptionCard({
    super.key,
    required this.subscription,
    this.onMore,
  });

  @override
  State<SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends State<SubscriptionCard> {
  bool _isHovered = false;

  Subscription get subscription => widget.subscription;
  VoidCallback? get onMore => widget.onMore;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _isHovered
              ? CupertinoColors.systemGrey5.resolveFrom(context)
              : CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withValues(alpha: _isHovered ? 0.08 : 0.04),
              blurRadius: _isHovered ? 12 : 8,
              offset: Offset(0, _isHovered ? 4 : 2),
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
                    placeholder: (_, _) => Container(
                      width: 48,
                      height: 48,
                      color: CupertinoColors.systemGrey5
                          .resolveFrom(context),
                      child: const Icon(CupertinoIcons.person_fill,
                          size: 24, color: CupertinoColors.systemGrey),
                    ),
                    errorWidget: (_, _, _) => Container(
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
              minimumSize: const Size.square(32),
              onPressed: onMore,
              child: Icon(
                CupertinoIcons.ellipsis,
                size: 20,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
        ],
      ),
    ),  // closes MouseRegion
    );
  }
}
