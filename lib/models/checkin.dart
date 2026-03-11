/// Check-in record model
class Checkin {
  final String id;
  final String studentId;
  final String classroomId;
  final String quadrant; // 'red', 'yellow', 'green', 'blue'
  final String emotionLabel; // specific emotion word
  final String contextTag; // 'school', 'recess', 'lunch', 'home', 'commute'
  final String? note;
  final DateTime checkedAt;
  final DateTime? createdAt;

  const Checkin({
    required this.id,
    required this.studentId,
    required this.classroomId,
    required this.quadrant,
    required this.emotionLabel,
    required this.contextTag,
    this.note,
    required this.checkedAt,
    this.createdAt,
  });

  factory Checkin.fromJson(Map<String, dynamic> json) {
    return Checkin(
      id: json['id'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      classroomId: json['classroom_id'] as String? ?? '',
      quadrant: json['quadrant'] as String? ?? '',
      emotionLabel: json['emotion_label'] as String? ?? '',
      contextTag: json['context_tag'] as String? ?? '',
      note: json['note'] as String?,
      checkedAt: json['checked_at'] != null
          ? DateTime.tryParse(json['checked_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'classroom_id': classroomId,
      'quadrant': quadrant,
      'emotion_label': emotionLabel,
      'context_tag': contextTag,
      'note': note,
      'checked_at': _formatDate(checkedAt),
    };
  }

  /// Format date as YYYY-MM-DD string
  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
