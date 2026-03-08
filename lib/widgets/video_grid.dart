import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
import '../models/video_item.dart';
import '../services/monitor_service.dart';
import '../services/storage_service.dart';
import '../services/download_service.dart';
import '../services/rss_service.dart';
import '../widgets/video_card.dart';

class VideoGrid extends StatelessWidget {
  final List<VideoItem> videos;
  final bool showDeleted;
  final Future<bool> Function() onBeforeDownload;
  const VideoGrid({super.key, required this.videos, this.showDeleted = false, required this.onBeforeDownload});

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.play_rectangle,
                size: 64, color: CupertinoColors.tertiaryLabel.resolveFrom(context)),
            const SizedBox(height: 16),
            Text(
              '暂无视频',
              style: TextStyle(
                fontSize: 17,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '添加订阅后，新视频将自动出现在这里',
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width < 500 ? 2 : width < 800 ? 3 : width < 1100 ? 4 : 5;
        final isDesktop = width >= 720;
        final padding = isDesktop
            ? const EdgeInsets.fromLTRB(16, 16, 16, 24)
            : const EdgeInsets.fromLTRB(12, 12, 12, 120);

        Widget scrollView = CustomScrollView(
          slivers: [
            if (!isDesktop)
              CupertinoSliverRefreshControl(
                onRefresh: () => context.read<MonitorService>().checkForNewVideos(),
              ),
            SliverPadding(
              padding: padding,
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
              (context, index) {
                final video = videos[index];
                final dl = context.read<DownloadService>();
                final task = dl.tasks
                    .cast<DownloadTask?>()
                    .firstWhere((t) => t!.video.bvid == video.bvid,
                        orElse: () => null);
                return VideoCard(
                  video: video,
                  compact: true,
                  downloadTask: task,
                  onDownload: () async {
                    if (video.downloadStatus == DownloadStatus.downloading) {
                      // Don't allow pause during merge phase
                      if (task?.phase == DownloadPhase.merging) return;
                      await dl.pauseDownload(video.bvid);
                      return;
                    }
                    if (video.downloadStatus == DownloadStatus.queued) {
                      await dl.cancelDownload(video.bvid);
                      return;
                    }
                    if (video.downloadStatus == DownloadStatus.paused) {
                      await dl.resumeDownload(video.bvid);
                      return;
                    }
                    if (!await onBeforeDownload()) return;
                    dl.addDownload(video);
                  },
                  onPlay: video.downloadStatus == DownloadStatus.completed &&
                          video.localPath != null
                      ? () => OpenFilex.open(video.localPath!)
                      : null,
                  onDelete: video.downloadStatus == DownloadStatus.completed
                      ? () => _confirmDelete(context, video)
                      : video.downloadStatus == DownloadStatus.invalidated
                          ? () {
                              context
                                  .read<StorageService>()
                                  .deleteVideo(video.bvid);
                            }
                          : (video.downloadStatus == DownloadStatus.paused ||
                                  video.downloadStatus == DownloadStatus.failed)
                              ? () async {
                                  final dl = context.read<DownloadService>();
                                  await dl.cancelDownload(video.bvid);
                                }
                              : null,
                  onRestore: video.downloadStatus == DownloadStatus.deleted
                      ? () {
                          context
                              .read<StorageService>()
                              .restoreVideo(video.bvid);
                        }
                      : video.downloadStatus == DownloadStatus.invalidated
                          ? () async {
                              // Retry: restore to none, then download
                              final storage = context.read<StorageService>();
                              await storage.restoreVideo(video.bvid);
                              if (!context.mounted) return;
                              final dl = context.read<DownloadService>();
                              final restored = storage.videos.cast<VideoItem?>().firstWhere(
                                    (v) => v!.bvid == video.bvid,
                                    orElse: () => null,
                                  );
                              if (restored != null) {
                                if (!await onBeforeDownload()) return;
                                dl.addDownload(restored);
                              }
                            }
                          : null,
                );
              },
              childCount: videos.length,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: isDesktop ? 12 : 8,
              mainAxisSpacing: isDesktop ? 12 : 8,
              childAspectRatio: _calculateAspectRatio(width, crossAxisCount, isDesktop ? 12 : 8, isDesktop ? 16 : 8),
            ),
          ),
        ),
      ],
    );

        return scrollView;
      },
    );
  }

  double _calculateAspectRatio(double totalWidth, int crossAxisCount, double crossAxisSpacing, double horizontalPadding) {
    final availableWidth = totalWidth - horizontalPadding * 2 - crossAxisSpacing * (crossAxisCount - 1);
    final columnWidth = availableWidth / crossAxisCount;
    final thumbnailHeight = columnWidth / (16 / 9);
    // padding(8+8) + title 2 lines(13*1.3*2=33.8) + gap(4) + author(15) + gap(4) + actions(20) + buffer
    const textAreaHeight = 96.0;
    final cellHeight = thumbnailHeight + textAreaHeight;
    return columnWidth / cellHeight;
  }

  void _confirmDelete(BuildContext context, VideoItem video) async {
    // Show a loading indicator while checking validity
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const CupertinoAlertDialog(
        content: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoActivityIndicator(),
              SizedBox(height: 12),
              Text('正在检查视频状态...'),
            ],
          ),
        ),
      ),
    );

    // Check video validity via RSSHub
    final storage = context.read<StorageService>();
    final rssService = RssService(rssHubUrl: storage.rssHubUrl, rssMode: storage.rssMode);
    final exists = await rssService.checkVideoExists(video.authorMid, video.bvid);

    if (!context.mounted) return;
    Navigator.pop(context); // dismiss loading

    if (exists == false) {
      // Video is invalid — warn user
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('视频可能已失效'),
          content: Text(
            '「${video.title}」\n\n未在源站中找到，可能已失效，删除后可能无法再次下载。\n如视频仍有效，删除后可重新下载。\n确定要删除吗？',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.pop(ctx);
                if (context.mounted) {
                  final dl = context.read<DownloadService>();
                  final st = context.read<StorageService>();
                  await dl.deleteVideoFiles(video);
                  st.deleteVideo(video.bvid);
                }
              },
              child: const Text('删除'),
            ),
          ],
        ),
      );
    } else {
      // Video is still valid (or check inconclusive) — normal delete flow
      final statusNote = exists == true ? '\n\n视频状态：正常' : '';
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('删除视频'),
          content: Text('确定要删除「${video.title}」吗？\n文件将被删除，且不会被自动重新下载。$statusNote'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.pop(ctx);
                if (context.mounted) {
                  final dl = context.read<DownloadService>();
                  final st = context.read<StorageService>();
                  await dl.deleteVideoFiles(video);
                  st.deleteVideo(video.bvid);
                }
              },
              child: const Text('删除'),
            ),
          ],
        ),
      );
    }
  }
}
