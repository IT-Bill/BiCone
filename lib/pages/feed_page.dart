import 'dart:io';
import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Consumer3<StorageService, MonitorService, DownloadService>(
      builder: (context, storage, monitor, download, _) {
        // Filter videos based on showDeleted toggle
        final allVideos = _showDeleted
            ? storage.videos.toList()
            : storage.videos
                .where((v) => v.downloadStatus != DownloadStatus.deleted)
                .toList();

        // Build unique UP主 list from ALL non-deleted videos (for tabs)
        final upMap = <int, String>{};
        for (final v in storage.videos) {
          if (v.authorMid != 0 && !upMap.containsKey(v.authorMid)) {
            upMap[v.authorMid] = v.author;
          }
        }
        final upList = upMap.entries.toList();

        return DefaultTabController(
          length: 1 + upList.length,
          child: Scaffold(
            appBar: AppBar(
              centerTitle: true,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('视频动态'),
                  if (monitor.lastCheck != null)
                    Text(
                      '上次检查 ${monitor.lastCheck!.hour.toString().padLeft(2, '0')}:'
                      '${monitor.lastCheck!.minute.toString().padLeft(2, '0')}:'
                      '${monitor.lastCheck!.second.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'toggle_deleted') {
                      setState(() => _showDeleted = !_showDeleted);
                    }
                  },
                  itemBuilder: (ctx) => [
                    CheckedPopupMenuItem<String>(
                      value: 'toggle_deleted',
                      checked: _showDeleted,
                      child: const Text('显示已忽略视频'),
                    ),
                  ],
                ),
                Consumer<MonitorService>(
                  builder: (context, monitor, _) {
                    return IconButton(
                      icon: monitor.isChecking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      onPressed: monitor.isChecking
                          ? null
                          : () => monitor.checkForNewVideos(),
                      tooltip: '刷新',
                    );
                  },
                ),
              ],
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  const Tab(text: '全部'),
                  ...upList.map((e) => Tab(text: e.value)),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _VideoGrid(
                  videos: allVideos,
                  showDeleted: _showDeleted,
                ),
                ...upList.map((e) => _VideoGrid(
                      videos: allVideos
                          .where((v) => v.authorMid == e.key)
                          .toList(),
                      showDeleted: _showDeleted,
                    )),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VideoGrid extends StatelessWidget {
  final List<VideoItem> videos;
  final bool showDeleted;
  const _VideoGrid({required this.videos, this.showDeleted = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined,
                size: 80, color: cs.outlineVariant),
            const SizedBox(height: 16),
            Text(
              '暂无视频',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              '添加订阅后，新视频将自动出现在这里',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.outline),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<MonitorService>().checkForNewVideos(),
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.96,
        ),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final video = videos[index];
          return VideoCard(
            video: video,
            compact: true,
            onDownload: () async {
              final dl = context.read<DownloadService>();
              // If stuck in downloading/queued but no active task, reset first
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
                    context.read<StorageService>().restoreVideo(video.bvid);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已恢复，可重新下载')),
                    );
                  }
                : null,
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, VideoItem video) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除视频'),
        content: Text('确定要删除「${video.title}」吗？\n文件将被删除，且不会被自动重新下载。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Delete the actual file
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
              // Mark as deleted in storage
              if (context.mounted) {
                context.read<StorageService>().deleteVideo(video.bvid);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
