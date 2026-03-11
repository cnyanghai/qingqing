/// Classroom model
class Classroom {
  final String id;
  final String? schoolId;
  final String? teacherId;
  final int enrollmentYear;
  final int classNumber;
  final String joinCode;
  final String? schoolName;
  final DateTime? createdAt;

  const Classroom({
    required this.id,
    required this.enrollmentYear,
    required this.classNumber,
    required this.joinCode,
    this.schoolId,
    this.teacherId,
    this.schoolName,
    this.createdAt,
  });

  factory Classroom.fromJson(Map<String, dynamic> json) {
    // Handle nested school name from join query
    String? schoolName;
    if (json['schools'] != null && json['schools'] is Map) {
      schoolName = (json['schools'] as Map<String, dynamic>)['name'] as String?;
    } else {
      schoolName = json['school_name'] as String?;
    }

    return Classroom(
      id: json['id'] as String? ?? '',
      schoolId: json['school_id'] as String?,
      teacherId: json['teacher_id'] as String?,
      enrollmentYear: json['enrollment_year'] as int? ?? DateTime.now().year,
      classNumber: json['class_number'] as int? ?? 1,
      joinCode: json['join_code'] as String? ?? '',
      schoolName: schoolName,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'school_id': schoolId,
      'teacher_id': teacherId,
      'enrollment_year': enrollmentYear,
      'class_number': classNumber,
      'join_code': joinCode,
    };
  }

  /// Computed grade number: current year - enrollment year + 1
  int get gradeNumber {
    return DateTime.now().year - enrollmentYear + 1;
  }

  /// Display name: e.g. "三年级2班"
  String get displayName {
    final gradeNames = ['一', '二', '三', '四', '五', '六', '七', '八', '九'];
    final grade = gradeNumber;
    final gradeName =
        grade > 0 && grade <= gradeNames.length ? gradeNames[grade - 1] : '$grade';
    return '$gradeName年级$classNumber班';
  }

  /// Short display: e.g. "3年级 · 2班"
  String get shortDisplay {
    return '$gradeNumber年级 \u00B7 $classNumber班';
  }
}
