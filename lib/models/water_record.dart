/// 浇水记录模型
class WaterRecord {
  final String id;
  final String fromStudentId;
  final String toStudentId;
  final String classroomId;
  final DateTime wateredAt;
  final DateTime? createdAt;
  final String? message;

  const WaterRecord({
    required this.id,
    required this.fromStudentId,
    required this.toStudentId,
    required this.classroomId,
    required this.wateredAt,
    this.createdAt,
    this.message,
  });

  factory WaterRecord.fromJson(Map<String, dynamic> json) {
    return WaterRecord(
      id: json['id'] as String? ?? '',
      fromStudentId: json['from_student_id'] as String? ?? '',
      toStudentId: json['to_student_id'] as String? ?? '',
      classroomId: json['classroom_id'] as String? ?? '',
      wateredAt: json['watered_at'] != null
          ? DateTime.tryParse(json['watered_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from_student_id': fromStudentId,
      'to_student_id': toStudentId,
      'classroom_id': classroomId,
      'watered_at': _formatDate(wateredAt),
      if (message != null && message!.isNotEmpty) 'message': message,
    };
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
