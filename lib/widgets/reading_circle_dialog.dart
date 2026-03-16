import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../models/learning_entry.dart';
import '../models/profile.dart';
import 'avatar_picker.dart';

/// 读书圈弹窗 — 展示共读同一本书的同学及各自进度
class ReadingCircleDialog {
  ReadingCircleDialog._();

  /// 展示读书圈 BottomSheet
  /// [book] 当前书籍
  /// [classLearning] 全班学习记录
  /// [classmates] 同学列表
  /// [currentUserId] 当前用户ID（排除自己）
  static void show({
    required BuildContext context,
    required LearningEntry book,
    required List<LearningEntry> classLearning,
    required List<Profile> classmates,
    required String currentUserId,
  }) {
    final bookTitleNorm = book.title.trim().toLowerCase();
    final readers = classLearning
        .where((e) =>
            e.type == 'book' &&
            e.status == 'in_progress' &&
            e.title.trim().toLowerCase() == bookTitleNorm &&
            e.studentId != currentUserId)
        .toList();

    if (readers.isEmpty) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '\u{1F4DA} 正在读《${book.title}》的同学',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ...readers.map((entry) {
                final classmate = classmates
                    .where((c) => c.id == entry.studentId)
                    .firstOrNull;
                if (classmate == null) return const SizedBox.shrink();
                return ListTile(
                  leading: AvatarCircle(
                    avatarKey: classmate.avatarKey,
                    size: 36,
                  ),
                  title: Text(classmate.nickname),
                  trailing: SizedBox(
                    width: 100,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: entry.progress / 100.0,
                              backgroundColor: AppColors.divider,
                              color: AppColors.primary,
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${entry.progress}%',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.push('/classmates/${classmate.id}');
                  },
                );
              }),
              const SizedBox(height: AppSpacing.md),
              const Text(
                '一起读书，一起成长 \u{1F4D6}',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 计算某本书的共读人数（排除自己）
  static int getReadingCircleCount({
    required LearningEntry book,
    required List<LearningEntry> classLearning,
    required String currentUserId,
  }) {
    final bookTitleNorm = book.title.trim().toLowerCase();
    return classLearning
        .where((e) =>
            e.type == 'book' &&
            e.status == 'in_progress' &&
            e.title.trim().toLowerCase() == bookTitleNorm &&
            e.studentId != currentUserId)
        .map((e) => e.studentId)
        .toSet()
        .length;
  }
}
