import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/video_item.dart';

class VideoCard extends StatelessWidget {
  final VideoItem video;
  final VoidCallback? onDownload;

  const VideoCard({
    super.key,
    required this.video,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail ──
            if (video.thumbnail.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: video.thumbnail,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: cs.surfaceContainerHighest,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: cs.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image, size: 48),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title ──
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // ── Author & date ──
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 16, color: cs.outline),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          video.author,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.outline),
                        ),
                      ),
                      if (video.pubDate.isNotEmpty)
                        Text(
                          _formatDate(video.pubDate),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.outline),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── Actions ──
                  Row(
                    children: [
                      _buildStatusChip(context),
                      const Spacer(),
                      if (video.downloadStatus == DownloadStatus.none ||
                          video.downloadStatus == DownloadStatus.failed)
                        FilledButton.icon(
                          onPressed: onDownload,
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('下载'),
                        ),
                      if (video.downloadStatus == DownloadStatus.downloading)
                        Chip(
                          avatar: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              value: video.downloadProgress,
                              strokeWidth: 2,
                            ),
                          ),
                          label: Text(
                              '${(video.downloadProgress * 100).toStringAsFixed(0)}%'),
                        ),
                      if (video.downloadStatus == DownloadStatus.completed)
                        const Chip(
                          avatar: Icon(Icons.check_circle,
                              size: 18, color: Colors.green),
                          label: Text('已下载'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    if (video.downloadStatus == DownloadStatus.queued) {
      return const Chip(
        avatar: Icon(Icons.schedule, size: 16),
        label: Text('排队中'),
        visualDensity: VisualDensity.compact,
      );
    }
    if (video.downloadStatus == DownloadStatus.failed) {
      return Chip(
        avatar: Icon(Icons.error, size: 16,
            color: Theme.of(context).colorScheme.error),
        label: const Text('失败'),
        visualDensity: VisualDensity.compact,
      );
    }
    return const SizedBox.shrink();
  }

  String _formatDate(String dateStr) {
    try {
      // Try ISO 8601 first
      var date = DateTime.tryParse(dateStr);
      // Fallback: RFC 1123 / HTTP date
      date ??= HttpDate.parse(dateStr);
      return _relativeTime(date);
    } catch (_) {
      return dateStr.length > 16 ? dateStr.substring(0, 16) : dateStr;
    }
  }

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${date.month}/${date.day}';
  }
}
