/// 同学留言模型
class StudentMessage {
  final String id;
  final String authorId;
  final String targetStudentId;
  final String classroomId;
  final String content;
  final DateTime? createdAt;

  const StudentMessage({
    required this.id,
    required this.authorId,
    required this.targetStudentId,
    required this.classroomId,
    required this.content,
    this.createdAt,
  });

  factory StudentMessage.fromJson(Map<String, dynamic> json) {
    return StudentMessage(
      id: json['id'] as String? ?? '',
      authorId: json['author_id'] as String? ?? '',
      targetStudentId: json['target_student_id'] as String? ?? '',
      classroomId: json['classroom_id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'author_id': authorId,
      'target_student_id': targetStudentId,
      'classroom_id': classroomId,
      'content': content,
    };
  }
}
