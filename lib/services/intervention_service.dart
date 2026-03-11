import 'dart:convert';

/// Simple in-memory intervention record storage (Phase 0 simplification).
/// In production, this would be backed by a database table.
class InterventionService {
  InterventionService._();

  // Static storage: studentId -> list of records
  static final Map<String, List<InterventionRecord>> _records = {};

  /// Get all intervention records for a student
  static List<InterventionRecord> getRecords(String studentId) {
    return List.unmodifiable(_records[studentId] ?? []);
  }

  /// Add an intervention record for a student
  static void addRecord(String studentId, String content) {
    _records.putIfAbsent(studentId, () => []);
    _records[studentId]!.insert(
      0,
      InterventionRecord(
        content: content,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Serialize all records to JSON string (for potential persistence)
  static String toJson() {
    final map = <String, dynamic>{};
    _records.forEach((key, records) {
      map[key] = records.map((r) => r.toJson()).toList();
    });
    return jsonEncode(map);
  }

  /// Load records from JSON string (for potential persistence)
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
