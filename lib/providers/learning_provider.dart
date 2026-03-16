import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/learning_entry.dart';
import 'auth_provider.dart';

/// 当前学生的学习记录
final myLearningEntriesProvider =
    FutureProvider<List<LearningEntry>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  final service = ref.watch(supabaseServiceProvider);
  return await service.getMyLearningEntries(userId);
});

/// 当前在读的书（status = in_progress, type = book）
final currentBooksProvider = Provider<List<LearningEntry>>((ref) {
  final entries = ref.watch(myLearningEntriesProvider).valueOrNull ?? [];
  return entries
      .where((e) => e.type == 'book' && e.status == 'in_progress')
      .toList();
});

/// 当前在学的技能（status = in_progress, type = skill）
final currentSkillsProvider = Provider<List<LearningEntry>>((ref) {
  final entries = ref.watch(myLearningEntriesProvider).valueOrNull ?? [];
  return entries
      .where((e) => e.type == 'skill' && e.status == 'in_progress')
      .toList();
});
