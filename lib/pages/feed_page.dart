import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/monitor_service.dart';
import '../services/storage_service.dart';
import '../services/download_service.dart';
import '../widgets/video_card.dart';

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('视频动态'),
        actions: [
          Consumer<MonitorService>(
            builder: (context, monitor, _) {
              return IconButton(
                icon: monitor.isChecking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed:
                    monitor.isChecking ? null : () => monitor.checkForNewVideos(),
                tooltip: '刷新',
              );
            },
          ),
        ],
      ),
      body: Consumer2<StorageService, MonitorService>(
        builder: (context, storage, monitor, _) {
          final videos = storage.videos;

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
                  if (monitor.isChecking) ...[
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 8),
                    const Text('正在检查新视频...'),
                  ],
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => monitor.checkForNewVideos(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: VideoCard(
                    video: video,
                    onDownload: () {
                      context.read<DownloadService>().addDownload(video);
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
