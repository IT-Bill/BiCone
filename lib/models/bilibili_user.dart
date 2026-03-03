class BilibiliUser {
  final int mid;
  final String name;
  final String face;
  final String sign;
  final int level;

  BilibiliUser({
    required this.mid,
    required this.name,
    required this.face,
    this.sign = '',
    this.level = 0,
  });

  factory BilibiliUser.fromJson(Map<String, dynamic> json) {
    return BilibiliUser(
      mid: json['mid'] ?? 0,
      name: json['name'] ?? '',
      face: json['face'] ?? '',
      sign: json['sign'] ?? '',
      level: json['level'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'mid': mid,
        'name': name,
        'face': face,
        'sign': sign,
        'level': level,
      };
}
