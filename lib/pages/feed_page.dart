import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import '../models/video_item.dart';
import '../services/monitor_service.dart';
import '../services/storage_service.dart';
import '../services/download_service.dart';
import '../services/rss_service.dart';
import '../widgets/video_card.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  bool _showDeleted = true;
  bool _showInvalidated = false;
  int _selectedUpMid = 0; // 0 = all

  @override
  void initState() {
    super.initState();
    // Listen for download errors
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dl = context.read<DownloadService>();
      dl.addListener(_onDownloadChanged);
    });
  }

  @override
  void dispose() {
    // Safe removal: only remove if widget is still in tree
    try {
      context.read<DownloadService>().removeListener(_onDownloadChanged);
    } catch (_) {}
    super.dispose();
  }

  void _onDownloadChanged() {
    final dl = context.read<DownloadService>();
    if (dl.lastError != null && mounted) {
      final error = dl.lastError!;
      final errorBvid = dl.lastErrorBvid;
      dl.clearLastError();

      if (errorBvid != null) {
        // Video info / CID / download URL failure → offer retry or mark invalid
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('下载失败'),
            content: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () {
                  Navigator.pop(ctx);
                  // Retry download
                  final storage = context.read<StorageService>();
                  final video = storage.videos.cast<VideoItem?>().firstWhere(
                        (v) => v!.bvid == errorBvid,
                        orElse: () => null,
                      );
                  if (video != null) {
                    dl.addDownload(video);
                  }
                },
                child: const Text('重试'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  context.read<StorageService>().invalidateVideo(errorBvid);
                },
                child: const Text('标记为失效'),
              ),
            ],
          ),
        );
      } else {
        // Other errors (permission, path, etc.)
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('下载失败'),
            content: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<bool> _ensureDownloadPath() async {
    final storage = context.read<StorageService>();
    if (storage.downloadPath.isNotEmpty) return true;

    // First time: must set download path before downloading
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('设置下载路径'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            '首次下载需要设置保存路径。\n推荐在 Download 目录下创建新文件夹。',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('选择文件夹'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final dir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择下载路径',
      );
      if (dir != null) {
        storage.setDownloadPath(dir);
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<StorageService, MonitorService, DownloadService>(
      builder: (context, storage, monitor, download, _) {
        var allVideos = _showDeleted
            ? storage.videos.toList()
            : storage.videos
                .where((v) => v.downloadStatus != DownloadStatus.deleted)
                .toList();

        // Hide invalidated videos unless toggled on
        if (!_showInvalidated) {
          allVideos = allVideos
              .where((v) => v.downloadStatus != DownloadStatus.invalidated)
              .toList();
        }

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

        // Sort by publish date descending (newest first)
        filteredVideos.sort((a, b) => _comparePubDate(b.pubDate, a.pubDate));

        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            padding: const EdgeInsetsDirectional.only(start: 20, end: 20),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 0,
              onPressed: () => _showOptions(context),
              child: const Icon(CupertinoIcons.ellipsis_circle, size: 22),
            ),
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
            trailing: Consumer<MonitorService>(
              builder: (context, monitor, _) {
                return CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: monitor.isChecking
                      ? null
                      : () => monitor.checkForNewVideos(),
                  child: monitor.isChecking
                      ? const CupertinoActivityIndicator()
                      : const Icon(CupertinoIcons.refresh, size: 22),
                );
              },
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
                    onBeforeDownload: _ensureDownloadPath,
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
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _showInvalidated = !_showInvalidated);
              Navigator.pop(ctx);
            },
            child: Text(_showInvalidated ? '隐藏已失效视频' : '显示已失效视频'),
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

  int _comparePubDate(String a, String b) {
    final da = _parsePubDate(a);
    final db = _parsePubDate(b);
    if (da == null && db == null) return 0;
    if (da == null) return -1;
    if (db == null) return 1;
    return da.compareTo(db);
  }

  DateTime? _parsePubDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      return DateTime.tryParse(dateStr) ?? HttpDate.parse(dateStr);
    } catch (_) {
      return null;
    }
  }
}

class _VideoGrid extends StatelessWidget {
  final List<VideoItem> videos;
  final bool showDeleted;
  final Future<bool> Function() onBeforeDownload;
  const _VideoGrid({required this.videos, this.showDeleted = false, required this.onBeforeDownload});

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
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.98,
            ),
          ),
        ),
      ],
    );
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
    final rssService = RssService(rssHubUrl: storage.rssHubUrl);
    final exists = await rssService.checkVideoExists(video.authorMid, video.bvid);

    if (!context.mounted) return;
    Navigator.pop(context); // dismiss loading

    if (exists == false) {
      // Video is invalid — warn user
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('视频已失效'),
          content: Text(
            '「${video.title}」在源站已失效，删除后可能无法再次下载。\n确定要删除吗？',
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
}
