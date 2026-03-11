/// Badge model
class Badge {
  final String id;
  final String studentId;
  final String badgeKey;
  final DateTime? earnedAt;

  const Badge({
    required this.id,
    required this.studentId,
    required this.badgeKey,
    this.earnedAt,
  });

  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      id: json['id'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      badgeKey: json['badge_key'] as String? ?? '',
      earnedAt: json['earned_at'] != null
          ? DateTime.tryParse(json['earned_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'badge_key': badgeKey,
    };
  }

  /// Badge display info
  static const Map<String, BadgeInfo> allBadges = {
    'first_checkin': BadgeInfo(
      key: 'first_checkin',
      name: '初次记录',
      description: '完成第一次心情记录',
      emoji: '\u{2B50}',
    ),
    'streak_7': BadgeInfo(
      key: 'streak_7',
      name: '火力全开',
      description: '连续记录7天',
      emoji: '\u{1F525}',
    ),
    'streak_30': BadgeInfo(
      key: 'streak_30',
      name: '顶级明星',
      description: '连续记录30天',
      emoji: '\u{1F31F}',
    ),
    'explorer': BadgeInfo(
      key: 'explorer',
      name: '七彩虹',
      description: '记录过4种不同情绪',
      emoji: '\u{1F308}',
    ),
    'writer': BadgeInfo(
      key: 'writer',
      name: '博学者',
      description: '写过10次文字描述',
      emoji: '\u{1F4DD}',
    ),
  };
}

class BadgeInfo {
  final String key;
  final String name;
  final String description;
  final String emoji;

  const BadgeInfo({
    required this.key,
    required this.name,
    required this.description,
    required this.emoji,
  });
}
