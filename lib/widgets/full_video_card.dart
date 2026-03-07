import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show LinearProgressIndicator, AlwaysStoppedAnimation;
import 'package:cached_network_image/cached_network_image.dart';
import '../models/video_item.dart';
import '../models/download_task.dart';
import '../theme.dart';
import 'image_preview.dart';
import 'video_card_utils.dart';

class FullVideoCard extends StatelessWidget {
  final VideoItem video;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final VoidCallback? onPlay;
  final DownloadTask? downloadTask;

  const FullVideoCard({
    super.key,
    required this.video,
    this.onDownload,
    this.onDelete,
    this.onRestore,
    this.onPlay,
    this.downloadTask,
  });

  @override
  Widget build(BuildContext context) {
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
                        formatVideoDate(video.pubDate),
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

  void _showImagePreview(BuildContext context, String imageUrl) {
    Navigator.of(context, rootNavigator: true).push(
      BlurredImageRoute(
        imageUrl: imageUrl,
        heroTag: 'cover_${video.bvid}',
      ),
    );
  }
}
