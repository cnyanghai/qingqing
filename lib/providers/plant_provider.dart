import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/player_plant.dart';
import '../models/plant_catalog.dart';
import 'auth_provider.dart';
import 'profile_provider.dart';

/// 我的植物列表
final myPlantsProvider = FutureProvider<List<PlayerPlant>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final service = ref.watch(supabaseServiceProvider);
  try {
    return await service.getMyPlants(userId);
  } catch (e) {
    return [];
  }
});

/// 当前阳光值（从profile读取）
final sunshineProvider = Provider<int>((ref) {
  return ref.watch(profileProvider).valueOrNull?.sunshine ?? 0;
});

/// 玩家等级（基于阳光值）
final playerLevelProvider = Provider<int>((ref) {
  final sunshine = ref.watch(sunshineProvider);
  return LevelCalculator.calculateLevel(sunshine);
});

/// 到下一等级的进度 (0.0 ~ 1.0)
final levelProgressProvider = Provider<double>((ref) {
  final sunshine = ref.watch(sunshineProvider);
  return LevelCalculator.progressToNextLevel(sunshine);
});
