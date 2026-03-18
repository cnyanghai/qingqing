/// User profile model (student or teacher)
class Profile {
  final String id;
  final String role; // 'student' or 'teacher'
  final String nickname;
  final String avatarKey;
  final String? classroomId;
  final int streak;
  final int longestStreak;
  final int totalCheckins;
  final int points;
  final int sunshine;
  final DateTime? createdAt;

  const Profile({
    required this.id,
    required this.role,
    required this.nickname,
    this.avatarKey = 'cat',
    this.classroomId,
    this.streak = 0,
    this.longestStreak = 0,
    this.totalCheckins = 0,
    this.points = 0,
    this.sunshine = 0,
    this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String? ?? '',
      role: json['role'] as String? ?? 'student',
      nickname: json['nickname'] as String? ?? '',
      avatarKey: json['avatar_key'] as String? ?? 'cat',
      classroomId: json['classroom_id'] as String?,
      streak: json['streak'] as int? ?? 0,
      longestStreak: json['longest_streak'] as int? ?? 0,
      totalCheckins: json['total_checkins'] as int? ?? 0,
      points: json['points'] as int? ?? 0,
      sunshine: json['sunshine'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'nickname': nickname,
      'avatar_key': avatarKey,
      'classroom_id': classroomId,
      'streak': streak,
      'longest_streak': longestStreak,
      'total_checkins': totalCheckins,
      'points': points,
      'sunshine': sunshine,
    };
  }

  Profile copyWith({
    String? id,
    String? role,
    String? nickname,
    String? avatarKey,
    String? classroomId,
    int? streak,
    int? longestStreak,
    int? totalCheckins,
    int? points,
    int? sunshine,
    DateTime? createdAt,
  }) {
    return Profile(
      id: id ?? this.id,
      role: role ?? this.role,
      nickname: nickname ?? this.nickname,
      avatarKey: avatarKey ?? this.avatarKey,
      classroomId: classroomId ?? this.classroomId,
      streak: streak ?? this.streak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalCheckins: totalCheckins ?? this.totalCheckins,
      points: points ?? this.points,
      sunshine: sunshine ?? this.sunshine,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Avatar emoji for display (placeholder, using emoji as avatar)
  String get avatarEmoji {
    return avatarOptions[avatarKey] ?? '\u{1F431}';
  }

  /// All available avatar options
  static const Map<String, String> avatarOptions = {
    'cat': '\u{1F431}',
    'dog': '\u{1F436}',
    'girl': '\u{1F467}',
    'rabbit': '\u{1F430}',
    'bear': '\u{1F43B}',
    'fox': '\u{1F98A}',
    'panda': '\u{1F43C}',
    'koala': '\u{1F428}',
  };

  /// Avatar labels in Chinese
  static const Map<String, String> avatarLabels = {
    'cat': '猫咪',
    'dog': '小狗',
    'girl': '女孩',
    'rabbit': '兔子',
    'bear': '小熊',
    'fox': '狐狸',
    'panda': '熊猫',
    'koala': '考拉',
  };
}
