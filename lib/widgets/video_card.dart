import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show LinearProgressIndicator, AlwaysStoppedAnimation;
import 'package:cached_network_image/cached_network_image.dart';
import '../models/video_item.dart';
import '../services/download_service.dart';
import '../theme.dart';

class VideoCard extends StatelessWidget {
  final VideoItem video;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final VoidCallback? onPlay;
  final bool compact;
  final DownloadTask? downloadTask;

  const VideoCard({
    super.key,
    required this.video,
    this.onDownload,
    this.onDelete,
    this.onRestore,
    this.onPlay,
    this.compact = false,
    this.downloadTask,
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
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
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
            GestureDetector(
              onTap: () => _showImagePreview(context, video.thumbnail),
              child: Hero(
                tag: 'cover_${video.bvid}',
                child: AspectRatio(
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
                  height: 12 * 2 * 1.4,
                  child: Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
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
        video.downloadStatus == DownloadStatus.queued ||
        video.downloadStatus == DownloadStatus.paused) {
      // Phase label for downloading state
      if (video.downloadStatus == DownloadStatus.downloading && downloadTask != null) {
        String phaseLabel;
        switch (downloadTask!.phase) {
          case DownloadPhase.downloadingVideo:
            phaseLabel = '视频下载';
            break;
          case DownloadPhase.downloadingAudio:
            phaseLabel = '音频下载';
            break;
          case DownloadPhase.merging:
            phaseLabel = '合并中';
            break;
          default:
            phaseLabel = '准备中';
        }
        actions.add(Text(
          phaseLabel,
          style: TextStyle(
            fontSize: 10,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ));
        actions.add(const SizedBox(width: 4));
      }
      actions.add(GestureDetector(
        onTap: onDownload,
        child: SizedBox(
          width: 20,
          height: 20,
          child: video.downloadStatus == DownloadStatus.downloading
              ? _buildMiniProgress(video.downloadProgress)
              : video.downloadStatus == DownloadStatus.paused
                  ? const Icon(CupertinoIcons.pause_circle,
                      size: 20, color: CupertinoColors.systemOrange)
                  : const CupertinoActivityIndicator(radius: 10),
        ),
      ));
    }

    if (video.downloadStatus == DownloadStatus.completed) {
      if (onPlay != null) {
        actions.add(GestureDetector(
          onTap: onPlay,
          child: const Icon(CupertinoIcons.play_circle,
              size: 20, color: AppTheme.biliPink),
        ));
        actions.add(const SizedBox(width: 4));
      }
      actions.add(const Icon(CupertinoIcons.checkmark_circle_fill,
          size: 20, color: CupertinoColors.activeGreen));
      if (onDelete != null) {
        actions.add(Padding(
          padding: const EdgeInsets.only(left: 4),
          child: GestureDetector(
            onTap: onDelete,
            child: const Icon(CupertinoIcons.trash,
                size: 20, color: CupertinoColors.destructiveRed),
          ),
        ));
      }
    }

    if (video.downloadStatus == DownloadStatus.deleted) {
      actions.add(Icon(CupertinoIcons.slash_circle,
          size: 20,
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
                size: 20, color: AppTheme.biliPink),
          ),
        ));
      }
    }

    if (video.downloadStatus == DownloadStatus.invalidated) {
      actions.add(Icon(CupertinoIcons.exclamationmark_triangle,
          size: 20,
          color: CupertinoColors.systemOrange.resolveFrom(context)));
      actions.add(const SizedBox(width: 2));
      actions.add(Text('已失效',
          style: TextStyle(
            fontSize: 11,
            color: CupertinoColors.systemOrange.resolveFrom(context),
          )));
      if (onRestore != null) {
        actions.add(Padding(
          padding: const EdgeInsets.only(left: 4),
          child: GestureDetector(
            onTap: onRestore,
            child: const Icon(CupertinoIcons.arrow_counterclockwise,
                size: 20, color: AppTheme.biliPink),
          ),
        ));
      }
    }

    return actions;
  }

  Widget _buildMiniProgress(double progress) {
    return CustomPaint(
      size: const Size(20, 20),
      painter: _CircularProgressPainter(
        progress: progress,
        color: AppTheme.biliPink,
        trackColor: CupertinoColors.systemGrey4,
      ),
    );
  }

  Widget _buildDownloadProgress(BuildContext context) {
    final task = downloadTask!;
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final trackColor = CupertinoColors.systemGrey5.resolveFrom(context);

    if (task.phase == DownloadPhase.merging) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            const CupertinoActivityIndicator(radius: 8),
            const SizedBox(width: 8),
            Text('合并中...', style: TextStyle(fontSize: 12, color: secondaryColor)),
          ],
        ),
      );
    }

    if (task.phase == DownloadPhase.preparing) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            const CupertinoActivityIndicator(radius: 8),
            const SizedBox(width: 8),
            Text('准备中...', style: TextStyle(fontSize: 12, color: secondaryColor)),
          ],
        ),
      );
    }

    Widget buildStreamBar({
      required String label,
      required StreamProgress stream,
      required bool active,
      required bool completed,
    }) {
      final pct = (stream.progress * 100).toStringAsFixed(0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label + percentage + size
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active ? AppTheme.biliPink : secondaryColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$pct%',
                style: TextStyle(
                  fontSize: 11,
                  color: active ? AppTheme.biliPink : secondaryColor,
                ),
              ),
              const Spacer(),
              if (stream.totalBytes > 0)
                Text(
                  stream.formattedSize,
                  style: TextStyle(fontSize: 10, color: secondaryColor),
                ),
            ],
          ),
          const SizedBox(height: 3),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: stream.progress,
                backgroundColor: trackColor,
                valueColor: AlwaysStoppedAnimation<Color>(
                  completed
                      ? CupertinoColors.activeGreen
                      : active
                          ? AppTheme.biliPink
                          : CupertinoColors.systemGrey3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Speed + ETA or completion duration
          if (completed && stream.completeDuration != null)
            Text(
              '完成 (${stream.completeDuration})',
              style: TextStyle(fontSize: 10, color: CupertinoColors.activeGreen),
            )
          else if (active && stream.speed > 0)
            Row(
              children: [
                Text(
                  stream.formattedSpeed,
                  style: TextStyle(fontSize: 10, color: secondaryColor),
                ),
                if (stream.formattedEta.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '剩余 ${stream.formattedEta}',
                    style: TextStyle(fontSize: 10, color: secondaryColor),
                  ),
                ],
              ],
            ),
        ],
      );
    }

    final videoCompleted = task.phase == DownloadPhase.downloadingAudio ||
        task.phase == DownloadPhase.merging;
    final videoActive = task.phase == DownloadPhase.downloadingVideo;
    final audioActive = task.phase == DownloadPhase.downloadingAudio;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          buildStreamBar(
            label: '视频',
            stream: task.videoStream,
            active: videoActive,
            completed: videoCompleted,
          ),
          const SizedBox(height: 6),
          buildStreamBar(
            label: '音频',
            stream: task.audioStream,
            active: audioActive,
            completed: false,
          ),
        ],
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
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
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
            GestureDetector(
              onTap: () => _showImagePreview(context, video.thumbnail),
              child: Hero(
                tag: 'cover_${video.bvid}',
                child: AspectRatio(
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

                // ── Download progress ──
                if (downloadTask != null &&
                    video.downloadStatus == DownloadStatus.downloading)
                  _buildDownloadProgress(context),
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
    if (video.downloadStatus == DownloadStatus.invalidated) {
      return _tag(context, CupertinoIcons.exclamationmark_triangle,
          '已失效', CupertinoColors.systemOrange);
    }
    if (video.downloadStatus == DownloadStatus.paused) {
      return _tag(context, CupertinoIcons.pause_circle,
          '已暂停', CupertinoColors.systemOrange);
    }
    return const SizedBox.shrink();
  }

  Widget _tag(
      BuildContext context, IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
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
        minimumSize: const Size.square(32),
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

    if (video.downloadStatus == DownloadStatus.paused) {
      actions.add(Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: CupertinoColors.systemOrange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.pause_circle,
                size: 14, color: CupertinoColors.systemOrange),
            const SizedBox(width: 4),
            Text(
              '已暂停 ${(video.downloadProgress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12, color: CupertinoColors.systemOrange),
            ),
          ],
        ),
      ));
    }

    if (video.downloadStatus == DownloadStatus.downloading) {
      actions.add(CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size.square(32),
        onPressed: onDownload,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey5.resolveFrom(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.pause_circle,
                  size: 14, color: CupertinoColors.systemGrey),
              const SizedBox(width: 4),
              Text(
                '${(video.downloadProgress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ));
    }

    if (video.downloadStatus == DownloadStatus.completed) {
      if (onPlay != null) {
        actions.add(CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(28),
          onPressed: onPlay,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.biliPink.withValues(alpha: 0.12),
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
          color: CupertinoColors.activeGreen.withValues(alpha: 0.12),
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
            minimumSize: const Size.square(28),
            onPressed: onDelete,
            child: const Icon(CupertinoIcons.trash,
                size: 20, color: CupertinoColors.destructiveRed),
          ),
        ));
      }
    }

    if (video.downloadStatus == DownloadStatus.invalidated) {
      // Show "已失效" tag with retry and delete actions
      actions.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: CupertinoColors.systemOrange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.exclamationmark_triangle,
                size: 14, color: CupertinoColors.systemOrange.resolveFrom(context)),
            const SizedBox(width: 4),
            Text('已失效',
                style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemOrange.resolveFrom(context))),
          ],
        ),
      ));
      if (onRestore != null) {
        actions.add(Padding(
          padding: const EdgeInsets.only(left: 8),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(28),
            onPressed: onRestore,
            child: const Icon(CupertinoIcons.arrow_counterclockwise,
                size: 20, color: AppTheme.biliPink),
          ),
        ));
      }
    }

    return actions;
  }

  void _showImagePreview(BuildContext context, String imageUrl) {
    Navigator.of(context, rootNavigator: true).push(
      _BlurredImageRoute(
        imageUrl: imageUrl,
        heroTag: 'cover_${video.bvid}',
      ),
    );
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

class _ImagePreviewPage extends StatefulWidget {
  final String imageUrl;
  final String heroTag;
  const _ImagePreviewPage({required this.imageUrl, required this.heroTag});

  @override
  State<_ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<_ImagePreviewPage> {
  final TransformationController _transformController = TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Only dismiss if not zoomed in
        if (_transformController.value.isIdentity()) {
          Navigator.pop(context);
        } else {
          // Reset zoom
          _transformController.value = Matrix4.identity();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox.expand(
        child: InteractiveViewer(
          transformationController: _transformController,
          minScale: 1.0,
          maxScale: 4.0,
          child: Center(
            child: Hero(
              tag: widget.heroTag,
              child: CachedNetworkImage(
                imageUrl: widget.imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const CupertinoActivityIndicator(
                  color: CupertinoColors.white,
                ),
                errorWidget: (context, url, error) => const Icon(
                  CupertinoIcons.photo,
                  size: 64,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BlurredImageRoute extends PageRoute<void> {
  final String imageUrl;
  final String heroTag;

  _BlurredImageRoute({required this.imageUrl, required this.heroTag});

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => null;

  @override
  Color get barrierColor => CupertinoColors.black.withValues(alpha: 0.001);

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 250);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          color: CupertinoColors.black.withValues(alpha: animation.value),
          child: child,
        );
      },
      child: child,
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _ImagePreviewPage(imageUrl: imageUrl, heroTag: heroTag);
  }
}
