class Subscription {
  final int mid;
  final String name;
  final String face;
  final String sign;
  final DateTime addedAt;

  Subscription({
    required this.mid,
    required this.name,
    required this.face,
    this.sign = '',
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      mid: json['mid'] ?? 0,
      name: json['name'] ?? '',
      face: json['face'] ?? '',
      sign: json['sign'] ?? '',
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
        'addedAt': addedAt.toIso8601String(),
      };
}
