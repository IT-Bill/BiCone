import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/subscription.dart';

class SubscriptionCard extends StatelessWidget {
  final Subscription subscription;
  final VoidCallback? onDelete;

  const SubscriptionCard({
    super.key,
    required this.subscription,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 28,
          backgroundImage: subscription.face.isNotEmpty
              ? CachedNetworkImageProvider(subscription.face)
              : null,
          child: subscription.face.isEmpty
              ? const Icon(Icons.person, size: 28)
              : null,
        ),
        title: Text(
          subscription.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('UID: ${subscription.mid}'),
            if (subscription.sign.isNotEmpty)
              Text(
                subscription.sign,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline,
              color: Theme.of(context).colorScheme.error),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
