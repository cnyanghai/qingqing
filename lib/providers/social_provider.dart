import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile.dart';
import '../models/learning_entry.dart';
import '../models/water_record.dart';
import '../models/student_message.dart';
import 'auth_provider.dart';
import 'profile_provider.dart';

/// 我的同班同学
final classmatesProvider = FutureProvider<List<Profile>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  final profile = await ref.watch(profileProvider.future);
  if (userId == null || profile == null || profile.classroomId == null) {
    return [];
  }
  final service = ref.watch(supabaseServiceProvider);
  return await service.getClassmates(profile.classroomId!, userId);
});

/// 全班学习记录（学生视角） — 复用 getClassLearningEntries
final classmateLearningProvider =
    FutureProvider<List<LearningEntry>>((ref) async {
  final profile = await ref.watch(profileProvider.future);
  if (profile == null || profile.classroomId == null) return [];
  final service = ref.watch(supabaseServiceProvider);
  return await service.getClassLearningEntries(profile.classroomId!);
});

/// 今天我收到的浇水记录
final myTodayWatersProvider = FutureProvider<List<WaterRecord>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  final service = ref.watch(supabaseServiceProvider);
  return await service.getMyTodayWaters(userId);
});

/// 我的总浇水次数
final myTotalWaterCountProvider = FutureProvider<int>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return 0;
  final service = ref.watch(supabaseServiceProvider);
  return await service.getTotalWaterCount(userId);
});

/// 某同学收到的留言
final studentMessagesProvider =
    FutureProvider.family<List<StudentMessage>, String>(
        (ref, targetStudentId) async {
  final service = ref.watch(supabaseServiceProvider);
  return await service.getStudentMessages(targetStudentId);
});

/// 我收到的留言
final myMessagesProvider = FutureProvider<List<StudentMessage>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  final service = ref.watch(supabaseServiceProvider);
  return await service.getStudentMessages(userId);
});
