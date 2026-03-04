import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/video_item.dart';
import '../theme.dart';

class VideoCard extends StatelessWidget {
  final VideoItem video;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final VoidCallback? onPlay;
  final bool compact;

  const VideoCard({
    super.key,
    required this.video,
    this.onDownload,
    this.onDelete,
    this.onRestore,
    this.onPlay,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return compact ? _buildCompact(context) : _buildFull(context);
  }

  Widget _buildCompact(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
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
                  color: CupertinoColors.systemGrey5.resolveFrom(context),
                  child: const Center(
                      child: CupertinoActivityIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: CupertinoColors.systemGrey5.resolveFrom(context),
                  child: const Icon(CupertinoIcons.photo,
                      size: 32, color: CupertinoColors.systemGrey),
                ),
              ),
            ),

          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Title (fixed 2-line height) ──
                SizedBox(
                  height: 12 * 2.8,
                  child: Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                // ── Author ──
                Text(
                  video.author,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    color: CupertinoColors.secondaryLabel
                        .resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 4),
                // ── Time & actions ──
                Row(
                  children: [
                    if (video.pubDate.isNotEmpty)
                      Expanded(
                        child: Text(
                          _formatDate(video.pubDate),
                          style: TextStyle(
                            fontSize: 11,
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                          ),
                        ),
                      ),
                    ..._buildCompactActions(context),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCompactActions(BuildContext context) {
    final List<Widget> actions = [];

    if (video.downloadStatus == DownloadStatus.none ||
        video.downloadStatus == DownloadStatus.failed) {
      actions.add(GestureDetector(
        onTap: onDownload,
        child: const Icon(CupertinoIcons.arrow_down_circle,
            size: 20, color: AppTheme.biliPink),
      ));
    }

    if (video.downloadStatus == DownloadStatus.downloading ||
        video.downloadStatus == DownloadStatus.queued) {
      actions.add(GestureDetector(
        onTap: onDownload,
        child: SizedBox(
          width: 16,
          height: 16,
          child: video.downloadStatus == DownloadStatus.downloading
              ? _buildMiniProgress(video.downloadProgress)
              : const CupertinoActivityIndicator(radius: 8),
        ),
      ));
    }

    if (video.downloadStatus == DownloadStatus.completed) {
      if (onPlay != null) {
        actions.add(GestureDetector(
          onTap: onPlay,
          child: const Icon(CupertinoIcons.play_circle,
              size: 18, color: AppTheme.biliPink),
        ));
        actions.add(const SizedBox(width: 4));
      }
      actions.add(const Icon(CupertinoIcons.checkmark_circle_fill,
          size: 16, color: CupertinoColors.activeGreen));
      if (onDelete != null) {
        actions.add(Padding(
          padding: const EdgeInsets.only(left: 4),
          child: GestureDetector(
            onTap: onDelete,
            child: const Icon(CupertinoIcons.trash,
                size: 18, color: CupertinoColors.destructiveRed),
          ),
        ));
      }
    }

    if (video.downloadStatus == DownloadStatus.deleted) {
      actions.add(Icon(CupertinoIcons.slash_circle,
          size: 16,
          color:
              CupertinoColors.secondaryLabel.resolveFrom(context)));
      actions.add(const SizedBox(width: 2));
      actions.add(Text('已忽略',
          style: TextStyle(
            fontSize: 11,
            color: CupertinoColors.secondaryLabel
                .resolveFrom(context),
          )));
      if (onRestore != null) {
        actions.add(Padding(
          padding: const EdgeInsets.only(left: 4),
          child: GestureDetector(
            onTap: onRestore,
            child: const Icon(CupertinoIcons.arrow_counterclockwise,
                size: 18, color: AppTheme.biliPink),
          ),
        ));
      }
    }

    return actions;
  }

  Widget _buildMiniProgress(double progress) {
    return CustomPaint(
      size: const Size(16, 16),
      painter: _CircularProgressPainter(
        progress: progress,
        color: AppTheme.biliPink,
        trackColor: CupertinoColors.systemGrey4,
      ),
    );
  }

  Widget _buildFull(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
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
                  color: CupertinoColors.systemGrey5.resolveFrom(context),
                  child: const Center(
                      child: CupertinoActivityIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: CupertinoColors.systemGrey5.resolveFrom(context),
                  child: const Icon(CupertinoIcons.photo,
                      size: 48, color: CupertinoColors.systemGrey),
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
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // ── Author & date ──
                Row(
                  children: [
                    Icon(CupertinoIcons.person,
                        size: 14,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        video.author,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context),
                        ),
                      ),
                    ),
                    if (video.pubDate.isNotEmpty)
                      Text(
                        _formatDate(video.pubDate),
                        style: TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // ── Actions ──
                Row(
                  children: [
                    _buildStatusTag(context),
                    const Spacer(),
                    ..._buildFullActions(context),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTag(BuildContext context) {
    if (video.downloadStatus == DownloadStatus.queued) {
      return _tag(context, CupertinoIcons.clock, '排队中',
          CupertinoColors.systemGrey);
    }
    if (video.downloadStatus == DownloadStatus.failed) {
      return _tag(context, CupertinoIcons.exclamationmark_circle,
          '失败', CupertinoColors.destructiveRed);
    }
    return const SizedBox.shrink();
  }

  Widget _tag(
      BuildContext context, IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  List<Widget> _buildFullActions(BuildContext context) {
    final List<Widget> actions = [];

    if (video.downloadStatus == DownloadStatus.none ||
        video.downloadStatus == DownloadStatus.failed) {
      actions.add(CupertinoButton(
        padding: EdgeInsets.zero,
        minSize: 32,
        onPressed: onDownload,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.biliPink,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.arrow_down_circle,
                  size: 16, color: CupertinoColors.white),
              SizedBox(width: 4),
              Text('下载',
                  style: TextStyle(
                      fontSize: 13, color: CupertinoColors.white)),
            ],
          ),
        ),
      ));
    }

    if (video.downloadStatus == DownloadStatus.downloading) {
      actions.add(Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey5.resolveFrom(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: _buildMiniProgress(video.downloadProgress),
            ),
            const SizedBox(width: 6),
            Text(
              '${(video.downloadProgress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ));
    }

    if (video.downloadStatus == DownloadStatus.completed) {
      if (onPlay != null) {
        actions.add(CupertinoButton(
          padding: EdgeInsets.zero,
          minSize: 28,
          onPressed: onPlay,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.biliPink.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.play_circle,
                    size: 14, color: AppTheme.biliPink),
                SizedBox(width: 4),
                Text('播放',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.biliPink)),
              ],
            ),
          ),
        ));
        actions.add(const SizedBox(width: 4));
      }
      actions.add(Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: CupertinoColors.activeGreen.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.checkmark_circle_fill,
                size: 14, color: CupertinoColors.activeGreen),
            SizedBox(width: 4),
            Text('已下载',
                style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.activeGreen)),
          ],
        ),
      ));
      if (onDelete != null) {
        actions.add(Padding(
          padding: const EdgeInsets.only(left: 8),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 28,
            onPressed: onDelete,
            child: const Icon(CupertinoIcons.trash,
                size: 20, color: CupertinoColors.destructiveRed),
          ),
        ));
      }
    }

    return actions;
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

/// A tiny circular progress indicator painted with CustomPaint,
/// avoiding the need for Material's CircularProgressIndicator.
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.5;
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      progress * 2 * 3.14159,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter old) =>
      old.progress != progress;
}
