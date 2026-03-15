import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/video_item.dart';
import '../services/monitor_service.dart';
import '../services/storage_service.dart';
import '../services/download_service.dart';
import '../services/error_report_utils.dart';
import '../widgets/video_grid.dart';
import '../widgets/search_filter_panel.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  bool _showDeleted = true;
  bool _showInvalidated = true;
  int _selectedUpMid = 0; // 0 = all

  // Search & filter state
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;

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
    _searchController.dispose();
    // Safe removal: only remove if widget is still in tree
    try {
      context.read<DownloadService>().removeListener(_onDownloadChanged);
    } catch (_) {}
    super.dispose();
  }

  void _onDownloadChanged() {
    if (!mounted) return;
    final dl = context.read<DownloadService>();
    if (dl.lastError != null) {
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
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('关闭'),
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
                onPressed: () {
                  Navigator.pop(ctx);
                  reportErrorToSentry(context, error);
                },
                child: const Text('反馈'),
              ),
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('关闭'),
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

    // iOS: auto-set to app's Documents directory
    if (Platform.isIOS) {
      final docs = await getApplicationDocumentsDirectory();
      final dlDir = Directory('${docs.path}/Downloads');
      if (!await dlDir.exists()) await dlDir.create(recursive: true);
      storage.setDownloadPath(dlDir.path);
      return true;
    }

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

        // Hide undownloaded videos if the setting is enabled
        if (storage.hideUndownloaded) {
          allVideos = allVideos
              .where((v) =>
                  v.downloadStatus == DownloadStatus.completed)
              .toList();
        }

        // Build unique UP主 list from subscriptions (show all, even without videos)
        final upMap = <int, String>{};
        for (final s in storage.subscriptions) {
          if (!s.paused) {
            upMap[s.mid] = s.name;
          }
        }
        // Also include UPs from videos that may not be in subscriptions anymore
        for (final v in storage.videos) {
          if (v.authorMid != 0 && !upMap.containsKey(v.authorMid)) {
            upMap[v.authorMid] = v.author;
          }
        }
        final upList = upMap.entries.toList();

        // Filter by selected UP主
        var filteredVideos = _selectedUpMid == 0
            ? allVideos
            : allVideos.where((v) => v.authorMid == _selectedUpMid).toList();

        // Apply search & date filters
        if (_searchText.isNotEmpty) {
          final q = _searchText.toLowerCase();
          filteredVideos = filteredVideos.where((v) {
            return v.title.toLowerCase().contains(q) ||
                v.author.toLowerCase().contains(q);
          }).toList();
        }
        if (_dateFrom != null) {
          filteredVideos = filteredVideos.where((v) {
            final d = _parsePubDate(v.pubDate);
            return d != null && !d.isBefore(_dateFrom!);
          }).toList();
        }
        if (_dateTo != null) {
          final toEnd = DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59);
          filteredVideos = filteredVideos.where((v) {
            final d = _parsePubDate(v.pubDate);
            return d != null && !d.isAfter(toEnd);
          }).toList();
        }

        // Sort by publish date descending (newest first)
        filteredVideos.sort((a, b) => _comparePubDate(b.pubDate, a.pubDate));

        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            transitionBetweenRoutes: false,
            padding: const EdgeInsetsDirectional.only(start: 20, end: 20),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () => setState(() => _showSearch = !_showSearch),
                  child: Icon(
                    _showSearch ? CupertinoIcons.search_circle_fill : CupertinoIcons.search,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Consumer<MonitorService>(
                  builder: (context, monitor, _) {
                    return CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
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
                // Search & filter panel
                if (_showSearch)
                  SearchFilterPanel(
                    searchController: _searchController,
                    searchText: _searchText,
                    dateFrom: _dateFrom,
                    dateTo: _dateTo,
                    selectedUpMid: _selectedUpMid,
                    upList: upList,
                    storage: storage,
                    onSearchChanged: (v) => setState(() => _searchText = v),
                    onSearchCleared: () {
                      _searchController.clear();
                      setState(() => _searchText = '');
                    },
                    onDateFromChanged: (d) => setState(() => _dateFrom = d),
                    onDateToChanged: (d) => setState(() => _dateTo = d),
                    onFilterApplied: (f) => setState(() {
                      _searchController.text = f.keyword;
                      _searchText = f.keyword;
                      _selectedUpMid = f.authorMid;
                      _dateFrom = f.dateFrom;
                      _dateTo = f.dateTo;
                    }),
                  ),
                // UP主 filter (scrollable chip bar)
                if (upList.isNotEmpty)
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      itemCount: upList.length + 1,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final isAll = index == 0;
                        final mid = isAll ? 0 : upList[index - 1].key;
                        final label = isAll ? '全部' : upList[index - 1].value;
                        final selected = _selectedUpMid == mid;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedUpMid = mid),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: selected
                                  ? CupertinoTheme.of(context).primaryColor
                                  : CupertinoColors.systemGrey5.resolveFrom(context),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                color: selected
                                    ? CupertinoColors.white
                                    : CupertinoColors.label.resolveFrom(context),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                // Video grid
                Expanded(
                  child: _selectedUpMid != 0 && filteredVideos.isEmpty && _searchText.isEmpty && _dateFrom == null && _dateTo == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.play_rectangle,
                                  size: 64, color: CupertinoColors.tertiaryLabel.resolveFrom(context)),
                              const SizedBox(height: 16),
                              Text(
                                '暂未获取到视频',
                                style: TextStyle(
                                  fontSize: 17,
                                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '未发布视频或近期图文动态较多',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                                ),
                              ),
                            ],
                          ),
                        )
                      : VideoGrid(
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
          CupertinoActionSheetAction(
            onPressed: () {
              final storage = context.read<StorageService>();
              storage.setHideUndownloaded(!storage.hideUndownloaded);
              Navigator.pop(ctx);
            },
            child: Text(
              context.read<StorageService>().hideUndownloaded
                  ? '显示未下载视频'
                  : '隐藏未下载视频',
            ),
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
