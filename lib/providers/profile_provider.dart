import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile.dart';
import '../models/badge.dart';
import '../services/supabase_service.dart';
import 'auth_provider.dart';

/// Current user profile — refreshes when auth changes
final profileProvider = FutureProvider<Profile?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final service = ref.watch(supabaseServiceProvider);
  try {
    return await service.getProfile(userId);
  } catch (e) {
    return null;
  }
});

/// Badges for current user
final badgesProvider = FutureProvider<List<Badge>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final service = ref.watch(supabaseServiceProvider);
  try {
    return await service.getBadges(userId);
  } catch (e) {
    return [];
  }
});

/// Notifier for profile actions (setup, update)
final profileActionsProvider =
    Provider<ProfileActions>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return ProfileActions(service, ref);
});

class ProfileActions {
  final SupabaseService _service;
  final Ref _ref;

  ProfileActions(this._service, this._ref);

  /// Create initial student profile after joining a class
  Future<Profile> createStudentProfile({
    required String userId,
    required String nickname,
    required String avatarKey,
    required String classroomId,
  }) async {
    try {
      final profile = Profile(
        id: userId,
        role: 'student',
        nickname: nickname,
        avatarKey: avatarKey,
        classroomId: classroomId,
      );
      final result = await _service.upsertProfile(profile);
      _ref.invalidate(profileProvider);
      return result;
    } catch (e) {
      throw Exception('创建资料失败: $e');
    }
  }

  /// Update profile (avatar, nickname)
  Future<Profile> updateProfile(
      String userId, Map<String, dynamic> updates) async {
    try {
      final result = await _service.updateProfile(userId, updates);
      _ref.invalidate(profileProvider);
      return result;
    } catch (e) {
      throw Exception('更新资料失败: $e');
    }
  }
}
