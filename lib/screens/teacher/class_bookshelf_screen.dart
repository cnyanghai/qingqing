import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../models/learning_entry.dart';
import '../../models/profile.dart';
import '../../providers/teacher_provider.dart';

/// 教师端 — 班级书架
class ClassBookshelfScreen extends ConsumerWidget {
  const ClassBookshelfScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(classLearningEntriesProvider);
    final studentsAsync = ref.watch(classStudentsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('班级书架'),
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('加载失败',
              style: TextStyle(color: AppColors.error)),
        ),
        data: (entries) {
          final students = studentsAsync.valueOrNull ?? [];
          final studentMap = <String, Profile>{};
          for (final s in students) {
            studentMap[s.id] = s;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 区域A — 班级阅读统计
                _buildStats(entries),
                const SizedBox(height: AppSpacing.lg),

                // 区域B — 班级书架（按书聚合）
                _buildBookshelf(entries, studentMap),
                const SizedBox(height: AppSpacing.lg),

                // 区域C — 班级技能分布
                _buildSkillDistribution(entries),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // 区域A — 班级阅读统计
  // ============================================================

  Widget _buildStats(List<LearningEntry> entries) {
    final books = entries.where((e) => e.type == 'book').toList();
    final inProgressBooks =
        books.where((e) => e.status == 'in_progress').length;
    final completedBooks =
        books.where((e) => e.status == 'completed').length;

    // 最热门的书
    String hotBook = '-';
    if (books.isNotEmpty) {
      final bookCounts = <String, int>{};
      for (final b in books.where((e) => e.status == 'in_progress')) {
        bookCounts[b.title] = (bookCounts[b.title] ?? 0) + 1;
      }
      if (bookCounts.isNotEmpty) {
        final maxEntry = bookCounts.entries.reduce(
          (a, b) => a.value >= b.value ? a : b,
        );
        hotBook = maxEntry.key;
      }
    }

    return Row(
      children: [
        Expanded(child: _statCard('$inProgressBooks', '在读书籍')),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _statCard('$completedBooks', '已读完')),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _statCard(
            hotBook.length > 4 ? '${hotBook.substring(0, 4)}...' : hotBook,
            '最热门',
          ),
        ),
      ],
    );
  }

  Widget _statCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 区域B — 班级书架（按书聚合）
  // ============================================================

  Widget _buildBookshelf(
      List<LearningEntry> entries, Map<String, Profile> studentMap) {
    final books = entries.where((e) => e.type == 'book').toList();

    // 按title聚合
    final bookGroups = <String, List<LearningEntry>>{};
    for (final b in books) {
      bookGroups.putIfAbsent(b.title, () => []).add(b);
    }

    // 按在读人数降序排列
    final sortedBooks = bookGroups.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '\u{1F4D6} 班级书架',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          if (sortedBooks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Text(
                  '班级还没有学生添加书籍',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...sortedBooks.map((entry) {
              final title = entry.key;
              final readers = entry.value;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${readers.length}人在读',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 头像列表（最多3个 + "+N"）
                    _buildAvatarRow(readers, studentMap),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAvatarRow(
      List<LearningEntry> readers, Map<String, Profile> studentMap) {
    // 去重学生
    final uniqueStudentIds = readers.map((r) => r.studentId).toSet().toList();
    final displayCount = uniqueStudentIds.length > 3 ? 3 : uniqueStudentIds.length;
    final extraCount = uniqueStudentIds.length - displayCount;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...uniqueStudentIds.take(displayCount).map((id) {
          final student = studentMap[id];
          final emoji = student?.avatarEmoji ?? '\u{1F431}';
          return Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cardBackground,
              border: Border.all(color: AppColors.white, width: 1.5),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 14)),
            ),
          );
        }),
        if (extraCount > 0)
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cardBackground,
              border: Border.all(color: AppColors.white, width: 1.5),
            ),
            child: Center(
              child: Text(
                '+$extraCount',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // 区域C — 班级技能分布
  // ============================================================

  Widget _buildSkillDistribution(List<LearningEntry> entries) {
    final skills = entries.where((e) => e.type == 'skill').toList();

    // 按 category 聚合
    final categoryCounts = <String, int>{};
    for (final s in skills) {
      categoryCounts[s.category] = (categoryCounts[s.category] ?? 0) + 1;
    }

    // 按人数降序排列
    final sortedCategories = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxCount = sortedCategories.isNotEmpty
        ? sortedCategories.first.value
        : 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '\u{1F3AF} 技能分布',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          if (sortedCategories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Text(
                  '班级还没有学生添加技能',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...sortedCategories.map((entry) {
              final config = LearningCategories.getCategory(entry.key);
              final count = entry.value;
              final ratio = count / maxCount;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        '${config.emoji} ${config.name}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          backgroundColor: AppColors.divider,
                          color: config.color,
                          minHeight: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '$count人',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
