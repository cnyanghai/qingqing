import 'package:flutter/material.dart';

/// 学习记录模型（书籍或技能）
class LearningEntry {
  final String id;
  final String studentId;
  final String classroomId;
  final String type; // 'book' | 'skill'
  final String title;
  final String category; // 'reading' | 'music' | 'sports' | ...
  final String status; // 'in_progress' | 'completed'
  final int progress; // 0-100
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;

  const LearningEntry({
    required this.id,
    required this.studentId,
    required this.classroomId,
    required this.type,
    required this.title,
    required this.category,
    required this.status,
    this.progress = 0,
    required this.startedAt,
    this.completedAt,
    this.createdAt,
  });

  factory LearningEntry.fromJson(Map<String, dynamic> json) {
    return LearningEntry(
      id: json['id'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      classroomId: json['classroom_id'] as String? ?? '',
      type: json['type'] as String? ?? 'book',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      status: json['status'] as String? ?? 'in_progress',
      progress: json['progress'] as int? ?? 0,
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'classroom_id': classroomId,
      'type': type,
      'title': title,
      'category': category,
      'status': status,
      'progress': progress,
      'started_at': _formatDate(startedAt),
      if (completedAt != null) 'completed_at': _formatDate(completedAt!),
    };
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// 类别配置
class CategoryConfig {
  final String emoji;
  final String name;
  final Color color;

  const CategoryConfig({
    required this.emoji,
    required this.name,
    required this.color,
  });
}

/// 学习类别常量配置
class LearningCategories {
  LearningCategories._();

  static const categories = <String, CategoryConfig>{
    'reading': CategoryConfig(
      emoji: '\u{1F4D6}', // 📖
      name: '阅读',
      color: Color(0xFF8D6E63),
    ),
    'music': CategoryConfig(
      emoji: '\u{1F3B5}', // 🎵
      name: '音乐',
      color: Color(0xFFAB47BC),
    ),
    'sports': CategoryConfig(
      emoji: '\u{26BD}', // ⚽
      name: '运动',
      color: Color(0xFF66BB6A),
    ),
    'coding': CategoryConfig(
      emoji: '\u{1F4BB}', // 💻
      name: '编程',
      color: Color(0xFF42A5F5),
    ),
    'art': CategoryConfig(
      emoji: '\u{1F3A8}', // 🎨
      name: '艺术',
      color: Color(0xFFFF7043),
    ),
    'language': CategoryConfig(
      emoji: '\u{1F30D}', // 🌍
      name: '语言',
      color: Color(0xFF26A69A),
    ),
    'science': CategoryConfig(
      emoji: '\u{1F52C}', // 🔬
      name: '科学',
      color: Color(0xFF5C6BC0),
    ),
    'other': CategoryConfig(
      emoji: '\u{2728}', // ✨
      name: '其他',
      color: Color(0xFFBDBDBD),
    ),
  };

  /// 获取类别配置，若无效返回 other
  static CategoryConfig getCategory(String key) {
    return categories[key] ?? categories['other']!;
  }

  /// 技能可选类别（不含 reading，因为 reading 是书籍专用）
  static const skillCategories = [
    'music',
    'sports',
    'coding',
    'art',
    'language',
    'science',
    'other',
  ];
}
