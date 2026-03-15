import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/video_item.dart';
import '../models/download_task.dart';
import '../theme.dart';
import 'image_preview.dart';
import 'video_card_utils.dart';

class CompactVideoCard extends StatefulWidget {
  final VideoItem video;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final VoidCallback? onPlay;
  final DownloadTask? downloadTask;

  const CompactVideoCard({
    super.key,
    required this.video,
    this.onDownload,
    this.onDelete,
    this.onRestore,
    this.onPlay,
    this.downloadTask,
  });

  @override
  State<CompactVideoCard> createState() => _CompactVideoCardState();
}

class _CompactVideoCardState extends State<CompactVideoCard> {
  bool _isHovered = false;

  VideoItem get video => widget.video;
  VoidCallback? get onDownload => widget.onDownload;
  VoidCallback? get onDelete => widget.onDelete;
  VoidCallback? get onRestore => widget.onRestore;
  VoidCallback? get onPlay => widget.onPlay;
  DownloadTask? get downloadTask => widget.downloadTask;

  bool get _hasAssetThumbnail => video.thumbnail.startsWith('assets/');

  Widget _buildThumbnail(BuildContext context) {
    if (_hasAssetThumbnail) {
      return Image.asset(
        video.thumbnail,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: CupertinoColors.systemGrey5.resolveFrom(context),
          child: const Icon(
            CupertinoIcons.photo,
            size: 32,
            color: CupertinoColors.systemGrey,
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: video.thumbnail,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: CupertinoColors.systemGrey5.resolveFrom(context),
        child: const Center(child: CupertinoActivityIndicator()),
      ),
      errorWidget: (context, url, error) => Container(
        color: CupertinoColors.systemGrey5.resolveFrom(context),
        child: const Icon(
          CupertinoIcons.photo,
          size: 32,
          color: CupertinoColors.systemGrey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withValues(alpha: _isHovered ? 0.12 : 0.06),
              blurRadius: _isHovered ? 16 : 10,
              offset: Offset(0, _isHovered ? 4 : 2),
            ),
          ],
        ),
        transform: _isHovered ? (Matrix4.identity()..setTranslationRaw(0.0, -2.0, 0.0)) : Matrix4.identity(),
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
                  child: _buildThumbnail(context),
                ),
              ),
            ),

          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Title (fixed 2-line height) ──
                SizedBox(
                  height: 13 * 2 * 1.3,
                  child: Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
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
                          formatVideoDate(video.pubDate),
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
    ),  // closes MouseRegion
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
              ? buildMiniProgress(
                  downloadTask?.phase == DownloadPhase.merging
                      ? downloadTask!.mergeStream.progress
                      : video.downloadProgress,
                )
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

  void _showImagePreview(BuildContext context, String imageUrl) {
    Navigator.of(context, rootNavigator: true).push(
      BlurredImageRoute(
        imageUrl: imageUrl,
        heroTag: 'cover_${video.bvid}',
      ),
    );
  }
}
