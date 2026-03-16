import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/profile.dart';
import '../../models/learning_entry.dart';
import '../../providers/auth_provider.dart';
import '../../providers/social_provider.dart';
import '../../widgets/avatar_picker.dart';

/// 班级森林 — 同学列表页面
class ClassmatesScreen extends ConsumerWidget {
  const ClassmatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classmatesAsync = ref.watch(classmatesProvider);
    final classLearningAsync = ref.watch(classmateLearningProvider);
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('班级森林'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: classmatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('加载失败: $e',
              style: const TextStyle(color: AppColors.error)),
        ),
        data: (classmates) {
          final allLearning = classLearningAsync.valueOrNull ?? [];

          // 统计
          final allBooks = allLearning
              .where((e) => e.type == 'book')
              .map((e) => e.title.trim().toLowerCase())
              .toSet()
              .length;
          final allSkills = allLearning
              .where((e) => e.type == 'skill')
              .length;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // 顶部统计
              _buildClassStats(allBooks, allSkills, classmates.length),
              const SizedBox(height: AppSpacing.md),

              // 同学列表
              ...classmates.map((classmate) => _ClassmateListTile(
                    classmate: classmate,
                    allLearning: allLearning,
                    currentUserId: userId ?? '',
                  )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildClassStats(int bookCount, int skillCount, int classmateCount) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        '\u{1F333} 全班共读$bookCount本书 \u{00B7} 学习$skillCount项技能 \u{00B7} $classmateCount位同学',
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textDark,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// 同学列表行
class _ClassmateListTile extends ConsumerStatefulWidget {
  final Profile classmate;
  final List<LearningEntry> allLearning;
  final String currentUserId;

  const _ClassmateListTile({
    required this.classmate,
    required this.allLearning,
    required this.currentUserId,
  });

  @override
  ConsumerState<_ClassmateListTile> createState() =>
      _ClassmateListTileState();
}

class _ClassmateListTileState extends ConsumerState<_ClassmateListTile> {
  bool _hasWatered = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkWaterStatus();
  }

  Future<void> _checkWaterStatus() async {
    try {
      final service = ref.read(supabaseServiceProvider);
      final watered = await service.hasWateredToday(
          widget.currentUserId, widget.classmate.id);
      if (mounted) {
        setState(() {
          _hasWatered = watered;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final classmate = widget.classmate;
    final entries = widget.allLearning
        .where((e) => e.studentId == classmate.id)
        .toList();
    final leaves = entries.where((e) => e.status == 'in_progress').length;
    final fruits = entries.where((e) => e.status == 'completed').length;
    final totalEntries = entries.length;

    // 智慧树等级
    String treeLabel;
    if (totalEntries == 0) {
      treeLabel = '\u{1F331}种子';
    } else if (totalEntries <= 3) {
      treeLabel = '\u{1F331}小树苗';
    } else if (totalEntries <= 8) {
      treeLabel = '\u{1F332}小树';
    } else {
      treeLabel = '\u{1F333}大树';
    }

    return GestureDetector(
      onTap: () => context.push('/classmates/${classmate.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            AvatarCircle(
              avatarKey: classmate.avatarKey,
              size: 44,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        classmate.nickname,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.moodGreenBg,
                          borderRadius:
                              BorderRadius.circular(AppRadius.small),
                        ),
                        child: Text(
                          treeLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.moodGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\u{1F33F}$leaves片叶子 \u{00B7} \u{1F352}$fruits个果实',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // 浇水状态
            if (_loading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                _hasWatered ? '\u{1F4A7} 已浇' : '\u{1F6BF} 去浇水',
                style: TextStyle(
                  fontSize: 12,
                  color: _hasWatered
                      ? AppColors.textHint
                      : AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}
