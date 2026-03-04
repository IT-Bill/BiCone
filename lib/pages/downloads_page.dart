import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../models/video_item.dart';
import '../services/download_service.dart';
import '../services/storage_service.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('下载管理'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _selectedTab,
                onValueChanged: (v) =>
                    setState(() => _selectedTab = v ?? 0),
                children: const {
                  0: Text('进行中'),
                  1: Text('已完成'),
                },
              ),
            ),
            Expanded(
              child: _selectedTab == 0
                  ? const _ActiveDownloads()
                  : const _CompletedDownloads(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveDownloads extends StatelessWidget {
  const _ActiveDownloads();

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadService>(
      builder: (context, dl, _) {
        final tasks = dl.activeTasks;

        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.cloud_download,
                    size: 64,
                    color:
                        CupertinoColors.tertiaryLabel.resolveFrom(context)),
                const SizedBox(height: 16),
                Text(
                  '没有正在进行的下载',
                  style: TextStyle(
                    fontSize: 17,
                    color: CupertinoColors.secondaryLabel
                        .resolveFrom(context),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground
                    .resolveFrom(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 4,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemGrey5
                                      .resolveFrom(context),
                                  borderRadius:
                                      BorderRadius.circular(4),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: task.progress.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: CupertinoTheme.of(context)
                                        .primaryColor,
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.status == DownloadStatus.queued
                              ? '排队中...'
                              : '${(task.progress * 100).toStringAsFixed(1)}%  ${task.formattedSize}',
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (task.status == DownloadStatus.downloading &&
                          task.speed > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${task.formattedSpeed}  剩余${task.formattedEta}',
                          style: TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.tertiaryLabel
                                .resolveFrom(context),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minSize: 28,
                        onPressed: () =>
                            dl.cancelDownload(task.video.bvid),
                        child: Icon(
                          CupertinoIcons.xmark_circle,
                          size: 20,
                          color: CupertinoColors.destructiveRed
                              .resolveFrom(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CompletedDownloads extends StatelessWidget {
  const _CompletedDownloads();

  @override
  Widget build(BuildContext context) {
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
                Icon(CupertinoIcons.folder,
                    size: 64,
                    color:
                        CupertinoColors.tertiaryLabel.resolveFrom(context)),
                const SizedBox(height: 16),
                Text(
                  '没有已完成的下载',
                  style: TextStyle(
                    fontSize: 17,
                    color: CupertinoColors.secondaryLabel
                        .resolveFrom(context),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: completed.length,
          itemBuilder: (context, index) {
            final video = completed[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 1),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground
                    .resolveFrom(context),
                borderRadius: index == 0 && completed.length == 1
                    ? BorderRadius.circular(12)
                    : index == 0
                        ? const BorderRadius.vertical(
                            top: Radius.circular(12))
                        : index == completed.length - 1
                            ? const BorderRadius.vertical(
                                bottom: Radius.circular(12))
                            : BorderRadius.zero,
              ),
              child: CupertinoListTile(
                leading: Icon(CupertinoIcons.checkmark_alt_circle_fill,
                    color: CupertinoColors.activeGreen
                        .resolveFrom(context)),
                title: Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15),
                ),
                subtitle: Text(
                  '${video.author}  ${_formatFileSize(video.fileSize)}  ${_formatDownloadedAt(video.downloadedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }

  String _formatDownloadedAt(String? downloadedAt) {
    if (downloadedAt == null || downloadedAt.isEmpty) return '';
    try {
      final date = DateTime.parse(downloadedAt).toUtc().add(const Duration(hours: 8));
      final now = DateTime.now().toUtc().add(const Duration(hours: 8));
      if (date.year == now.year) {
        return '下载于 ${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
      return '下载于 ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
