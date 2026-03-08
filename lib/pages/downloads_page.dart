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
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: Text('下载管理'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _selectedTab,
                onValueChanged: (v) {
                  final index = v ?? 0;
                  setState(() => _selectedTab = index);
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                children: const {
                  0: Text('进行中'),
                  1: Text('已完成'),
                },
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _selectedTab = index);
                },
                children: const [
                  _ActiveDownloads(),
                  _CompletedDownloads(),
                ],
              ),
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground
                    .resolveFrom(context),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.systemGrey.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
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
                  if (task.status == DownloadStatus.queued)
                    Text(
                      '排队中...',
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                      ),
                    )
                  else if (task.phase == DownloadPhase.preparing)
                    Text(
                      '准备中...',
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                      ),
                    )
                  else ...[
                    _buildStreamProgressBar(
                      context,
                      label: '视频',
                      stream: task.videoStream,
                      active: task.phase == DownloadPhase.downloadingVideo,
                      completed: task.phase == DownloadPhase.downloadingAudio ||
                          task.phase == DownloadPhase.merging,
                      paused: task.status == DownloadStatus.paused,
                    ),
                    const SizedBox(height: 8),
                    _buildStreamProgressBar(
                      context,
                      label: '音频',
                      stream: task.audioStream,
                      active: task.phase == DownloadPhase.downloadingAudio,
                      completed: task.phase == DownloadPhase.merging,
                      paused: task.status == DownloadStatus.paused,
                    ),
                    const SizedBox(height: 8),
                    _buildStreamProgressBar(
                      context,
                      label: '合并',
                      stream: task.mergeStream,
                      active: task.phase == DownloadPhase.merging,
                      completed: false,
                      paused: false,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Spacer(),
                      if (task.status == DownloadStatus.downloading &&
                          task.phase != DownloadPhase.merging)
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size.square(28),
                          onPressed: () =>
                              dl.pauseDownload(task.video.bvid),
                          child: Icon(
                            CupertinoIcons.pause_circle,
                            size: 20,
                            color: CupertinoColors.activeOrange
                                .resolveFrom(context),
                          ),
                        )
                      else if (task.status == DownloadStatus.paused)
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size.square(28),
                          onPressed: () =>
                              dl.resumeDownload(task.video.bvid),
                          child: Icon(
                            CupertinoIcons.play_circle,
                            size: 20,
                            color: CupertinoColors.activeGreen
                                .resolveFrom(context),
                          ),
                        ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size.square(28),
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

  Widget _buildStreamProgressBar(
    BuildContext context, {
    required String label,
    required StreamProgress stream,
    required bool active,
    required bool completed,
    required bool paused,
  }) {
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final trackColor = CupertinoColors.systemGrey5.resolveFrom(context);
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final pct = (stream.progress * 100).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? primaryColor : secondaryColor,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$pct%',
              style: TextStyle(
                fontSize: 13,
                color: active ? primaryColor : secondaryColor,
              ),
            ),
            const Spacer(),
            if (stream.totalBytes > 0)
              Text(
                stream.formattedSize,
                style: TextStyle(fontSize: 12, color: secondaryColor),
              ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 5,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: trackColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: stream.progress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: paused
                              ? CupertinoColors.systemGrey3
                                  .resolveFrom(context)
                              : completed
                                  ? CupertinoColors.activeGreen
                                  : primaryColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 3),
        if (completed && stream.completeDuration != null)
          Text(
            '完成 (${stream.completeDuration})',
            style: const TextStyle(
                fontSize: 11, color: CupertinoColors.activeGreen),
          )
        else if (active && stream.speed > 0)
          Row(
            children: [
              Text(
                stream.formattedSpeed,
                style: TextStyle(fontSize: 11, color: secondaryColor),
              ),
              if (stream.formattedEta.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '剩余 ${stream.formattedEta}',
                  style: TextStyle(fontSize: 11, color: secondaryColor),
                ),
              ],
            ],
          )
        else if (paused)
          Text(
            '已暂停',
            style: TextStyle(fontSize: 11, color: secondaryColor),
          ),
      ],
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
          itemCount: completed.length,
          itemBuilder: (context, index) {
            final video = completed[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground
                    .resolveFrom(context),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.systemGrey.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CupertinoListTile(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Icon(CupertinoIcons.checkmark_alt_circle_fill,
                    color: CupertinoTheme.of(context).primaryColor),
                title: Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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
