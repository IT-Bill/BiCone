class Subscription {
  final int mid;
  final String name;
  final String face;
  final String sign;
  final DateTime addedAt;
  final bool paused;
  final bool downloadPaused;

  Subscription({
    required this.mid,
    required this.name,
    required this.face,
    this.sign = '',
    this.paused = false,
    this.downloadPaused = false,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      mid: json['mid'] ?? 0,
      name: json['name'] ?? '',
      face: json['face'] ?? '',
      sign: json['sign'] ?? '',
      paused: json['paused'] ?? false,
      downloadPaused: json['downloadPaused'] ?? false,
      addedAt: json['addedAt'] != null
          ? DateTime.parse(json['addedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'mid': mid,
        'name': name,
        'face': face,
        'sign': sign,
        'paused': paused,
        'downloadPaused': downloadPaused,
        'addedAt': addedAt.toIso8601String(),
      };
}
