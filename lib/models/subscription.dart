class Subscription {
  final int mid;
  final String name;
  final String face;
  final String sign;
  final DateTime addedAt;
  final bool paused;
  final bool downloadPaused;
  final List<String> keywords;

  Subscription({
    required this.mid,
    required this.name,
    required String face,
    this.sign = '',
    this.paused = false,
    this.downloadPaused = false,
    this.keywords = const [],
    DateTime? addedAt,
  })  : face = _normalizeFace(face),
        addedAt = addedAt ?? DateTime.now();

  static String _normalizeFace(String face) {
    final normalized = face.trim();
    if (normalized.startsWith('//')) {
      return 'https:$normalized';
    }
    return normalized;
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      mid: json['mid'] ?? 0,
      name: json['name'] ?? '',
      face: json['face'] ?? '',
      sign: json['sign'] ?? '',
      paused: json['paused'] ?? false,
      downloadPaused: json['downloadPaused'] ?? false,
      keywords: (json['keywords'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      addedAt: json['addedAt'] != null
          ? DateTime.parse(json['addedAt'])
          : DateTime.now(),
    );
  }

  /// Returns true if the given title matches keywords (or if no keywords are set).
  bool matchesTitle(String title) {
    if (keywords.isEmpty) return true;
    final lowerTitle = title.toLowerCase();
    return keywords.any((kw) => lowerTitle.contains(kw.toLowerCase()));
  }

  Map<String, dynamic> toJson() => {
        'mid': mid,
        'name': name,
        'face': face,
        'sign': sign,
        'paused': paused,
        'downloadPaused': downloadPaused,
        'keywords': keywords,
        'addedAt': addedAt.toIso8601String(),
      };
}
