import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/checkin.dart';
import '../../models/garden.dart';
import '../../models/profile.dart';
import '../../providers/teacher_provider.dart';
import '../../widgets/avatar_picker.dart';

/// 教师端班级花园概览
class ClassGardenScreen extends ConsumerWidget {
  const ClassGardenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(classStudentsProvider);
    final recentCheckinsAsync = ref.watch(studentRecentCheckinsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('班级花园'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: studentsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('加载失败')),
        data: (students) {
          if (students.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '\u{1F33B}', // sunflower
                    style: TextStyle(fontSize: 56),
                  ),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    '班级还没有学生',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          final recentCheckins =
              recentCheckinsAsync.valueOrNull ?? {};

          // Sort by totalCheckins descending (most active first)
          final sorted = List<Profile>.from(students)
            ..sort((a, b) =>
                b.totalCheckins.compareTo(a.totalCheckins));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary bar
                _buildSummary(sorted),
                const SizedBox(height: AppSpacing.lg),
                // Student garden cards
                ...sorted.map((student) => _StudentGardenCard(
                      student: student,
                      checkins: recentCheckins[student.id] ?? [],
                    )),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummary(List<Profile> students) {
    final totalFlowers = students.fold<int>(
      0,
      (sum, s) => sum + s.totalCheckins,
    );
    final activeCount =
        students.where((s) => s.totalCheckins > 0).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFC8E6C9), Color(0xFFE8F5E9)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _summaryItem('\u{1F33A}', '$totalFlowers', '总花朵'),
          _summaryItem('\u{1F468}\u{200D}\u{1F393}', '$activeCount', '活跃学生'),
          _summaryItem(
            '\u{1F331}',
            '${students.length}',
            '总人数',
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String emoji, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// 单个学生的花园卡片
class _StudentGardenCard extends StatelessWidget {
  final Profile student;
  final List<Checkin> checkins;

  const _StudentGardenCard({
    required this.student,
    required this.checkins,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate garden level from profile data (pure frontend)
    final level = _calculateLevel(student);

    // Count quadrants from recent checkins
    final quadrantCounts = <String, int>{};
    for (final c in checkins) {
      quadrantCounts[c.quadrant] =
          (quadrantCounts[c.quadrant] ?? 0) + 1;
    }

    // Latest 3 flowers
    final latest3 = checkins.take(3).toList();

    return GestureDetector(
      onTap: () => context.push('/teacher/students/${student.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.large),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            AvatarCircle(avatarKey: student.avatarKey, size: 44),
            const SizedBox(width: AppSpacing.md),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        student.nickname,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${level.displayName} ${level.displayEmoji}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Flower counts per quadrant
                  _buildFlowerRow(quadrantCounts),
                ],
              ),
            ),
            // Latest 3 flower dots
            Row(
              mainAxisSize: MainAxisSize.min,
              children: latest3.map((c) {
                final config = GardenConfig.getFlower(c.quadrant);
                return Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    config?.emoji ?? '',
                    style: const TextStyle(fontSize: 16),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textHint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowerRow(Map<String, int> counts) {
    final total = student.totalCheckins;
    if (total == 0) {
      return const Text(
        '还未种花',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textHint,
        ),
      );
    }

    final parts = <Widget>[];
    for (final q in ['red', 'yellow', 'green', 'blue']) {
      final count = counts[q] ?? 0;
      if (count > 0) {
        final config = GardenConfig.getFlower(q);
        if (config != null) {
          parts.add(
            Text(
              '${config.emoji}\u{00D7}$count',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          );
          parts.add(const SizedBox(width: 6));
        }
      }
    }

    parts.add(
      Text(
        '共$total朵',
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textHint,
        ),
      ),
    );

    return Row(children: parts);
  }

  GardenLevel _calculateLevel(Profile profile) {
    // Simplified: we don't have notesCount or distinctQuadrants here
    // (those would require additional queries, which is forbidden).
    // Use totalCheckins and streak only.
    if (profile.totalCheckins == 0) return GardenLevel.empty;
    if (profile.totalCheckins >= 30) return GardenLevel.blooming;
    if (profile.streak >= 7) return GardenLevel.sprout;
    return GardenLevel.seed;
  }
}
