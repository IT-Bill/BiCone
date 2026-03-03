import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/video_item.dart';

class VideoCard extends StatelessWidget {
  final VideoItem video;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final bool compact;

  const VideoCard({
    super.key,
    required this.video,
    this.onDownload,
    this.onDelete,
    this.onRestore,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return compact ? _buildCompact(context) : _buildFull(context);
  }

  Widget _buildCompact(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
                    child:
                        const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: cs.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image, size: 32),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Title (fixed 2-line height) ──
                  SizedBox(
                    height: (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) * 2.8,
                    child: Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 2),
                  // ── Author ──
                  Text(
                    video.author,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: cs.outline),
                  ),
                  const SizedBox(height: 4),
                  // ── Time & actions ──
                  Row(
                    children: [
                      if (video.pubDate.isNotEmpty)
                        Expanded(
                          child: Text(
                            _formatDate(video.pubDate),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: cs.outline),
                          ),
                        ),
                      if (video.downloadStatus == DownloadStatus.none ||
                          video.downloadStatus == DownloadStatus.failed)
                        InkWell(
                          onTap: onDownload,
                          child: Icon(Icons.download,
                              size: 18, color: cs.primary),
                        ),
                      if (video.downloadStatus == DownloadStatus.downloading ||
                          video.downloadStatus == DownloadStatus.queued)
                        InkWell(
                          onTap: onDownload, // reuse: acts as cancel/reset
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              value: video.downloadStatus == DownloadStatus.downloading
                                  ? video.downloadProgress
                                  : null,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      if (video.downloadStatus == DownloadStatus.completed) ...[
                        Icon(Icons.check_circle, size: 16, color: Colors.green[400]),
                        if (onDelete != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: InkWell(
                              onTap: onDelete,
                              child: Icon(Icons.delete_outline,
                                  size: 18, color: cs.error),
                            ),
                          ),
                      ],
                      if (video.downloadStatus == DownloadStatus.deleted) ...[
                        Icon(Icons.block, size: 16, color: cs.outline),
                        const SizedBox(width: 2),
                        Text('已忽略',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: cs.outline)),
                        if (onRestore != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: InkWell(
                              onTap: onRestore,
                              child: Icon(Icons.restore,
                                  size: 18, color: cs.primary),
                            ),
                          ),
                      ],
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

  Widget _buildFull(BuildContext context) {
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
                    child:
                        const Center(child: CircularProgressIndicator()),
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
                      if (video.downloadStatus == DownloadStatus.completed) ...[
                        const Chip(
                          avatar: Icon(Icons.check_circle,
                              size: 18, color: Colors.green),
                          label: Text('已下载'),
                        ),
                        if (onDelete != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color: cs.error),
                              onPressed: onDelete,
                              tooltip: '删除',
                            ),
                          ),
                      ],
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
      // Convert to UTC+8
      date = date.toUtc().add(const Duration(hours: 8));
      return _relativeTime(date);
    } catch (_) {
      return dateStr.length > 16 ? dateStr.substring(0, 16) : dateStr;
    }
  }

  String _relativeTime(DateTime date) {
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24 && date.day == now.day) {
      return '${diff.inHours}小时前';
    }
    if (date.year == now.year) {
      return '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
