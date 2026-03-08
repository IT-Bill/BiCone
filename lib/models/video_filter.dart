class VideoFilter {
  final String name;
  final String keyword; // matches title, author, or bvid
  final int authorMid; // 0 = any
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const VideoFilter({
    required this.name,
    this.keyword = '',
    this.authorMid = 0,
    this.dateFrom,
    this.dateTo,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'keyword': keyword,
        'authorMid': authorMid,
        if (dateFrom != null) 'dateFrom': dateFrom!.toIso8601String(),
        if (dateTo != null) 'dateTo': dateTo!.toIso8601String(),
      };

  factory VideoFilter.fromJson(Map<String, dynamic> json) => VideoFilter(
        name: json['name'] ?? '',
        keyword: json['keyword'] ?? '',
        authorMid: json['authorMid'] ?? 0,
        dateFrom:
            json['dateFrom'] != null ? DateTime.tryParse(json['dateFrom']) : null,
        dateTo:
            json['dateTo'] != null ? DateTime.tryParse(json['dateTo']) : null,
      );

  bool get isEmpty =>
      keyword.isEmpty && authorMid == 0 && dateFrom == null && dateTo == null;
}
