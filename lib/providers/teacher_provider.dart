import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile.dart';
import '../models/classroom.dart';
import '../models/checkin.dart';
import '../models/learning_entry.dart';
import 'auth_provider.dart';

/// Teacher's classroom
final teacherClassroomProvider = FutureProvider<Classroom?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final service = ref.watch(supabaseServiceProvider);
  try {
    return await service.getTeacherClassroom(userId);
  } catch (e) {
    return null;
  }
});

/// All students in the teacher's classroom
final classStudentsProvider = FutureProvider<List<Profile>>((ref) async {
  final classroom = await ref.watch(teacherClassroomProvider.future);
  if (classroom == null) return [];

  final service = ref.watch(supabaseServiceProvider);
  try {
    return await service.getClassStudents(classroom.id);
  } catch (e) {
    return [];
  }
});

/// Today's checkins for the teacher's class
final todayClassCheckinsProvider = FutureProvider<List<Checkin>>((ref) async {
  final classroom = await ref.watch(teacherClassroomProvider.future);
  if (classroom == null) return [];

  final service = ref.watch(supabaseServiceProvider);
  try {
    return await service.getClassCheckinsByDate(classroom.id, DateTime.now());
  } catch (e) {
    return [];
  }
});

/// This week's checkins for the teacher's class (Mon-Sun)
final weekClassCheckinsProvider = FutureProvider<List<Checkin>>((ref) async {
  final classroom = await ref.watch(teacherClassroomProvider.future);
  if (classroom == null) return [];

  final service = ref.watch(supabaseServiceProvider);
  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1));
  final sunday = monday.add(const Duration(days: 6));

  try {
    return await service.getClassCheckinsRange(
      classroom.id,
      startDate: monday,
      endDate: sunday,
    );
  } catch (e) {
    return [];
  }
});

/// Last 7 days of checkins for all students in the class
/// Returns a map: studentId -> list of checkins
final studentRecentCheckinsProvider =
    FutureProvider<Map<String, List<Checkin>>>((ref) async {
  final classroom = await ref.watch(teacherClassroomProvider.future);
  if (classroom == null) return {};

  final service = ref.watch(supabaseServiceProvider);
  final now = DateTime.now();
  final sevenDaysAgo = now.subtract(const Duration(days: 6));

  try {
    final checkins = await service.getClassCheckinsRange(
      classroom.id,
      startDate: sevenDaysAgo,
      endDate: now,
    );

    final map = <String, List<Checkin>>{};
    for (final c in checkins) {
      map.putIfAbsent(c.studentId, () => []).add(c);
    }
    return map;
  } catch (e) {
    return {};
  }
});

/// Checkins for a specific student (parameterized by student ID)
final studentCheckinsProvider =
    FutureProvider.family<List<Checkin>, String>((ref, studentId) async {
  final service = ref.watch(supabaseServiceProvider);
  final now = DateTime.now();
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));

  try {
    return await service.getStudentCheckins(
      studentId,
      startDate: thirtyDaysAgo,
      endDate: now,
    );
  } catch (e) {
    return [];
  }
});

/// Student profile by ID
final studentProfileProvider =
    FutureProvider.family<Profile?, String>((ref, studentId) async {
  final service = ref.watch(supabaseServiceProvider);
  try {
    return await service.getStudentProfile(studentId);
  } catch (e) {
    return null;
  }
});

/// 全班学习记录（教师端专用，与其他teacher providers同文件）
final classLearningEntriesProvider =
    FutureProvider<List<LearningEntry>>((ref) async {
  final classroom = await ref.watch(teacherClassroomProvider.future);
  if (classroom == null) return [];
  final service = ref.watch(supabaseServiceProvider);
  try {
    return await service.getClassLearningEntries(classroom.id);
  } catch (e) {
    return [];
  }
});

/// Student month checkins (for calendar in T4)
final studentMonthCheckinsProvider =
    FutureProvider.family<List<Checkin>, ({String studentId, DateTime month})>(
        (ref, params) async {
  final service = ref.watch(supabaseServiceProvider);
  final start = DateTime(params.month.year, params.month.month, 1);
  final end = DateTime(params.month.year, params.month.month + 1, 0);

  try {
    return await service.getStudentCheckins(
      params.studentId,
      startDate: start,
      endDate: end,
    );
  } catch (e) {
    return [];
  }
});
