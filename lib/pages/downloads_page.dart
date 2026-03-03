import 'dart:io';
import 'package:flutter/material.dart';import 'package:flutter/services.dart';import 'package:provider/provider.dart';
import '../models/video_item.dart';
import '../services/download_service.dart';
import '../services/storage_service.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('下载管理'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '进行中', icon: Icon(Icons.downloading)),
              Tab(text: '已完成', icon: Icon(Icons.download_done)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_ActiveDownloads(), _CompletedDownloads()],
        ),
      ),
    );
  }
}

// ─── Active downloads tab ───────────────────────────────

class _ActiveDownloads extends StatelessWidget {
  const _ActiveDownloads();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Consumer<DownloadService>(
      builder: (context, dl, _) {
        final tasks = dl.activeTasks;

        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_download_outlined,
                    size: 80, color: cs.outlineVariant),
                const SizedBox(height: 16),
                Text(
                  '没有正在进行的下载',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: task.progress,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          task.status == DownloadStatus.queued
                              ? '排队中...'
                              : '${(task.progress * 100).toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.cancel_outlined),
                          onPressed: () => dl.cancelDownload(task.video.bvid),
                          tooltip: '取消',
                          iconSize: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Completed downloads tab ────────────────────────────

class _CompletedDownloads extends StatelessWidget {
  const _CompletedDownloads();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Consumer<StorageService>(
      builder: (context, storage, _) {
        final completed = storage.videos
            .where((v) => v.downloadStatus == DownloadStatus.completed)
            .toList();

        if (completed.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 80, color: cs.outlineVariant),
                const SizedBox(height: 16),
                Text(
                  '没有已完成的下载',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: completed.length,
          itemBuilder: (context, index) {
            final video = completed[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading:
                    Icon(Icons.check_circle, color: Colors.green[400]),
                title: Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(video.author),
                trailing: video.localPath != null
                    ? IconButton(
                        icon: const Icon(Icons.folder_open),
                        onPressed: () {
                          final file = File(video.localPath!);
                          if (!file.existsSync()) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('文件不存在')),
                            );
                          } else {
                            // Show file path and allow copying
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('文件位置'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SelectableText(
                                      video.localPath!,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(text: video.localPath!),
                                      );
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('路径已复制到剪贴板'),
                                        ),
                                      );
                                    },
                                    child: const Text('复制路径'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      // Copy the directory path
                                      final dir = file.parent.path;
                                      Clipboard.setData(
                                        ClipboardData(text: dir),
                                      );
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('文件夹路径已复制: $dir'),
                                        ),
                                      );
                                    },
                                    child: const Text('复制目录'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('关闭'),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                        tooltip: '打开文件夹',
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}
