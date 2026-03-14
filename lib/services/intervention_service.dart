import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple intervention record storage with SharedPreferences persistence.
/// In production, this would be backed by a database table.
class InterventionService {
  InterventionService._();

  static const _storageKey = 'intervention_records';

  // Static storage: studentId -> list of records
  static final Map<String, List<InterventionRecord>> _records = {};

  /// Get all intervention records for a student
  static List<InterventionRecord> getRecords(String studentId) {
    return List.unmodifiable(_records[studentId] ?? []);
  }

  /// Add an intervention record for a student
  static Future<void> addRecord(String studentId, String content) async {
    _records.putIfAbsent(studentId, () => []);
    _records[studentId]!.insert(
      0,
      InterventionRecord(
        content: content,
        createdAt: DateTime.now(),
      ),
    );
    await _persist();
  }

  /// Persist all records to SharedPreferences
  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, toJson());
    } catch (e) {
      debugPrint('InterventionService persist error: $e');
    }
  }

  /// Load records from SharedPreferences
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null) {
        fromJson(jsonStr);
      }
    } catch (_) {
      // Silently fail on load errors
    }
  }

  /// Serialize all records to JSON string
  static String toJson() {
    final map = <String, dynamic>{};
    _records.forEach((key, records) {
      map[key] = records.map((r) => r.toJson()).toList();
    });
    return jsonEncode(map);
  }

  /// Load records from JSON string
  static void fromJson(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      _records.clear();
      map.forEach((key, value) {
        _records[key] = (value as List)
            .map((e) =>
                InterventionRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (_) {
      // Silently fail on parse errors
    }
  }
}

/// A single intervention record
class InterventionRecord {
  final String content;
  final DateTime createdAt;

  const InterventionRecord({
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'content': content,
        'created_at': createdAt.toIso8601String(),
      };

  factory InterventionRecord.fromJson(Map<String, dynamic> json) {
    return InterventionRecord(
      content: json['content'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
