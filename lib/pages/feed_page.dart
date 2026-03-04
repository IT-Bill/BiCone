import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../models/video_item.dart';
import '../services/monitor_service.dart';
import '../services/storage_service.dart';
import '../services/download_service.dart';
import '../widgets/video_card.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  bool _showDeleted = false;
  int _selectedUpMid = 0; // 0 = all

  @override
  Widget build(BuildContext context) {
    return Consumer3<StorageService, MonitorService, DownloadService>(
      builder: (context, storage, monitor, download, _) {
        final allVideos = _showDeleted
            ? storage.videos.toList()
            : storage.videos
                .where((v) => v.downloadStatus != DownloadStatus.deleted)
                .toList();

        // Build unique UP主 list
        final upMap = <int, String>{};
        for (final v in storage.videos) {
          if (v.authorMid != 0 && !upMap.containsKey(v.authorMid)) {
            upMap[v.authorMid] = v.author;
          }
        }
        final upList = upMap.entries.toList();

        // Filter by selected UP主
        final filteredVideos = _selectedUpMid == 0
            ? allVideos
            : allVideos.where((v) => v.authorMid == _selectedUpMid).toList();

        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('视频动态'),
                if (monitor.lastCheck != null)
                  Text(
                    '上次检查 ${monitor.lastCheck!.hour.toString().padLeft(2, '0')}:'
                    '${monitor.lastCheck!.minute.toString().padLeft(2, '0')}:'
                    '${monitor.lastCheck!.second.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.normal,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _showOptions(context),
                  child: const Icon(CupertinoIcons.ellipsis_circle, size: 22),
                ),
                Consumer<MonitorService>(
                  builder: (context, monitor, _) {
                    return CupertinoButton(
                      padding: const EdgeInsets.only(left: 8),
                      onPressed: monitor.isChecking
                          ? null
                          : () => monitor.checkForNewVideos(),
                      child: monitor.isChecking
                          ? const CupertinoActivityIndicator()
                          : const Icon(CupertinoIcons.refresh, size: 22),
                    );
                  },
                ),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // UP主 filter (scrollable segmented control)
                if (upList.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: SizedBox(
                      width: double.infinity,
                      child: CupertinoSlidingSegmentedControl<int>(
                        groupValue: _selectedUpMid,
                        onValueChanged: (v) =>
                            setState(() => _selectedUpMid = v ?? 0),
                        children: {
                          0: const Text('全部', style: TextStyle(fontSize: 13)),
                          ...{
                            for (final e in upList)
                              e.key: Text(
                                e.value,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                          },
                        },
                      ),
                    ),
                  ),
                // Video grid
                Expanded(
                  child: _VideoGrid(
                    videos: filteredVideos,
                    showDeleted: _showDeleted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOptions(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _showDeleted = !_showDeleted);
              Navigator.pop(ctx);
            },
            child: Text(_showDeleted ? '隐藏已忽略视频' : '显示已忽略视频'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }
}

class _VideoGrid extends StatelessWidget {
  final List<VideoItem> videos;
  final bool showDeleted;
  const _VideoGrid({required this.videos, this.showDeleted = false});

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

    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () => context.read<MonitorService>().checkForNewVideos(),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final video = videos[index];
                return VideoCard(
                  video: video,
                  compact: true,
                  onDownload: () async {
                    final dl = context.read<DownloadService>();
                    if (video.downloadStatus == DownloadStatus.downloading ||
                        video.downloadStatus == DownloadStatus.queued) {
                      await dl.cancelDownload(video.bvid);
                      return;
                    }
                    dl.addDownload(video);
                  },
                  onDelete: video.downloadStatus == DownloadStatus.completed
                      ? () => _confirmDelete(context, video)
                      : null,
                  onRestore: video.downloadStatus == DownloadStatus.deleted
                      ? () {
                          context
                              .read<StorageService>()
                              .restoreVideo(video.bvid);
                        }
                      : null,
                );
              },
              childCount: videos.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.96,
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, VideoItem video) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('删除视频'),
        content: Text('确定要删除「${video.title}」吗？\n文件将被删除，且不会被自动重新下载。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              if (video.localPath != null) {
                try {
                  final file = File(video.localPath!);
                  if (await file.exists()) {
                    await file.delete();
                  }
                } catch (e) {
                  debugPrint('Error deleting file: $e');
                }
              }
              if (context.mounted) {
                context.read<StorageService>().deleteVideo(video.bvid);
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
