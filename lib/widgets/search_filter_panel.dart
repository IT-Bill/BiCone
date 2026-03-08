import 'package:flutter/cupertino.dart';
import '../models/video_filter.dart';
import '../services/storage_service.dart';

class SearchFilterPanel extends StatelessWidget {
  final TextEditingController searchController;
  final String searchText;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final int selectedUpMid;
  final List<MapEntry<int, String>> upList;
  final StorageService storage;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final ValueChanged<DateTime?> onDateFromChanged;
  final ValueChanged<DateTime?> onDateToChanged;
  final ValueChanged<VideoFilter> onFilterApplied;

  const SearchFilterPanel({
    super.key,
    required this.searchController,
    required this.searchText,
    required this.dateFrom,
    required this.dateTo,
    required this.selectedUpMid,
    required this.upList,
    required this.storage,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onDateFromChanged,
    required this.onDateToChanged,
    required this.onFilterApplied,
  });

  @override
  Widget build(BuildContext context) {
    final savedFilters = storage.savedFilters;
    final hasActiveFilter =
        searchText.isNotEmpty || dateFrom != null || dateTo != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search text field
          CupertinoSearchTextField(
            controller: searchController,
            placeholder: '搜索标题、UP主',
            onChanged: onSearchChanged,
            onSuffixTap: onSearchCleared,
          ),
          const SizedBox(height: 8),
          // Date range row
          _buildDateRangeRow(context),
          const SizedBox(height: 8),
          // Save filter / saved filters row
          _buildSavedFiltersRow(context, savedFilters, hasActiveFilter),
        ],
      ),
    );
  }

  Widget _buildDateRangeRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _pickDate(context, isFrom: true),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6.resolveFrom(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                dateFrom != null
                    ? '${dateFrom!.year}-${dateFrom!.month.toString().padLeft(2, '0')}-${dateFrom!.day.toString().padLeft(2, '0')}'
                    : '起始日期',
                style: TextStyle(
                  fontSize: 13,
                  color: dateFrom != null
                      ? CupertinoColors.label.resolveFrom(context)
                      : CupertinoColors.placeholderText
                          .resolveFrom(context),
                ),
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('—', style: TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => _pickDate(context, isFrom: false),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6.resolveFrom(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                dateTo != null
                    ? '${dateTo!.year}-${dateTo!.month.toString().padLeft(2, '0')}-${dateTo!.day.toString().padLeft(2, '0')}'
                    : '结束日期',
                style: TextStyle(
                  fontSize: 13,
                  color: dateTo != null
                      ? CupertinoColors.label.resolveFrom(context)
                      : CupertinoColors.placeholderText
                          .resolveFrom(context),
                ),
              ),
            ),
          ),
        ),
        if (dateFrom != null || dateTo != null)
          CupertinoButton(
            padding: const EdgeInsets.only(left: 8),
            minimumSize: Size.zero,
            onPressed: () {
              onDateFromChanged(null);
              onDateToChanged(null);
            },
            child:
                const Icon(CupertinoIcons.xmark_circle_fill, size: 18),
          ),
      ],
    );
  }

  Widget _buildSavedFiltersRow(
      BuildContext context, List<VideoFilter> savedFilters, bool hasActiveFilter) {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          if (hasActiveFilter)
            GestureDetector(
              onTap: () => _saveCurrentFilter(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: CupertinoTheme.of(context).primaryColor),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.bookmark,
                        size: 14,
                        color: CupertinoTheme.of(context).primaryColor),
                    const SizedBox(width: 4),
                    Text('保存筛选',
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                CupertinoTheme.of(context).primaryColor)),
                  ],
                ),
              ),
            ),
          if (hasActiveFilter && savedFilters.isNotEmpty)
            const SizedBox(width: 8),
          if (savedFilters.isNotEmpty)
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: savedFilters.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final f = savedFilters[index];
                  return GestureDetector(
                    onTap: () => onFilterApplied(f),
                    onLongPress: () =>
                        _confirmDeleteFilter(context, index, f.name),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey5
                            .resolveFrom(context),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.bookmark_fill,
                              size: 12,
                              color: CupertinoColors.secondaryLabel
                                  .resolveFrom(context)),
                          const SizedBox(width: 4),
                          Text(f.name,
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _pickDate(BuildContext context, {required bool isFrom}) {
    DateTime initial =
        isFrom ? (dateFrom ?? DateTime.now()) : (dateTo ?? DateTime.now());

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 260,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('取消'),
                  onPressed: () => Navigator.pop(ctx),
                ),
                CupertinoButton(
                  child: const Text('确定'),
                  onPressed: () {
                    if (isFrom) {
                      onDateFromChanged(initial);
                    } else {
                      onDateToChanged(initial);
                    }
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initial,
                maximumDate: DateTime.now(),
                onDateTimeChanged: (d) => initial = d,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveCurrentFilter(BuildContext context) {
    final nameController = TextEditingController();
    final parts = <String>[];
    if (searchText.isNotEmpty) parts.add(searchText);
    if (selectedUpMid != 0) {
      final upName = upList
          .where((e) => e.key == selectedUpMid)
          .map((e) => e.value)
          .firstOrNull;
      if (upName != null) parts.add(upName);
    }
    if (dateFrom != null || dateTo != null) parts.add('时间范围');
    nameController.text = parts.join(' + ');

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('保存筛选条件'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: nameController,
            placeholder: '筛选名称',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              storage.addSavedFilter(VideoFilter(
                name: name,
                keyword: searchText,
                authorMid: selectedUpMid,
                dateFrom: dateFrom,
                dateTo: dateTo,
              ));
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFilter(
      BuildContext context, int index, String name) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('删除筛选条件'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('确定删除「$name」？'),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              storage.removeSavedFilter(index);
              Navigator.pop(ctx);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
