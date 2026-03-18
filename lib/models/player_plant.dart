/// 玩家种植的植物实例
class PlayerPlant {
  final String id;
  final String studentId;
  final String plantKey;
  final int shelfIndex;
  final int slotIndex;
  final int level; // 1-5
  final DateTime? createdAt;

  const PlayerPlant({
    required this.id,
    required this.studentId,
    required this.plantKey,
    required this.shelfIndex,
    required this.slotIndex,
    this.level = 1,
    this.createdAt,
  });

  factory PlayerPlant.fromJson(Map<String, dynamic> json) {
    return PlayerPlant(
      id: json['id'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      plantKey: json['plant_key'] as String? ?? '',
      shelfIndex: json['shelf_index'] as int? ?? 0,
      slotIndex: json['slot_index'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'student_id': studentId,
      'plant_key': plantKey,
      'shelf_index': shelfIndex,
      'slot_index': slotIndex,
      'level': level,
    };
  }

  PlayerPlant copyWith({
    String? id,
    String? studentId,
    String? plantKey,
    int? shelfIndex,
    int? slotIndex,
    int? level,
    DateTime? createdAt,
  }) {
    return PlayerPlant(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      plantKey: plantKey ?? this.plantKey,
      shelfIndex: shelfIndex ?? this.shelfIndex,
      slotIndex: slotIndex ?? this.slotIndex,
      level: level ?? this.level,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
