import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/classroom.dart';
import '../services/supabase_service.dart';
import 'auth_provider.dart';
import 'profile_provider.dart';

/// Current user's classroom
final classroomProvider = FutureProvider<Classroom?>((ref) async {
  final profile = await ref.watch(profileProvider.future);
  if (profile?.classroomId == null) return null;

  final service = ref.watch(supabaseServiceProvider);
  try {
    return await service.getClassroom(profile!.classroomId!);
  } catch (e) {
    return null;
  }
});

/// Classroom lookup actions
final classroomActionsProvider = Provider<ClassroomActions>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return ClassroomActions(service);
});

class ClassroomActions {
  final SupabaseService _service;

  ClassroomActions(this._service);

  /// Look up a classroom by join code
  Future<Classroom?> findByCode(String joinCode) async {
    try {
      return await _service.findClassroomByCode(joinCode);
    } catch (e) {
      throw Exception('查询班级失败，请稍后重试');
    }
  }
}
