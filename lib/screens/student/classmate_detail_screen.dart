import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme.dart';
import '../../models/profile.dart';
import '../../models/learning_entry.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/social_provider.dart';

/// 同学详情页 — 智慧树只读视图 + 浇水
class ClassmateDetailScreen extends ConsumerStatefulWidget {
  final String classmateId;

  const ClassmateDetailScreen({super.key, required this.classmateId});

  @override
  ConsumerState<ClassmateDetailScreen> createState() =>
      _ClassmateDetailScreenState();
}

class _ClassmateDetailScreenState
    extends ConsumerState<ClassmateDetailScreen> {
  Profile? _classmateProfile;
  List<LearningEntry> _entries = [];
  bool _loading = true;
  String? _error;

  bool _hasWatered = false;
  bool _waterLoading = false;
  int _totalWaterCount = 0;

  // 浇水动画
  bool _showWaterDrop = false;
  double _treeScale = 1.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final service = ref.read(supabaseServiceProvider);
      final userId = ref.read(currentUserIdProvider);

      final profile = await service.getStudentProfile(widget.classmateId);
      final entries =
          await service.getStudentLearningEntries(widget.classmateId);
      final totalWater =
          await service.getTotalWaterCount(widget.classmateId);

      bool watered = false;
      if (userId != null) {
        watered =
            await service.hasWateredToday(userId, widget.classmateId);
      }

      if (mounted) {
        setState(() {
          _classmateProfile = profile;
          _entries = entries;
          _totalWaterCount = totalWater;
          _hasWatered = watered;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载同学数据失败: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _doWater() async {
    if (_hasWatered || _waterLoading) return;

    final userId = ref.read(currentUserIdProvider);
    final myProfile = ref.read(profileProvider).valueOrNull;
    if (userId == null || myProfile?.classroomId == null) return;

    setState(() => _waterLoading = true);

    try {
      final service = ref.read(supabaseServiceProvider);
      await service.waterTree(
          userId, widget.classmateId, myProfile!.classroomId!);

      // 浇水成功 — 播放动画
      if (mounted) {
        setState(() {
          _hasWatered = true;
          _waterLoading = false;
          _totalWaterCount++;
          _showWaterDrop = true;
        });

        // 水滴下落动画
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          setState(() {
            _showWaterDrop = false;
            _treeScale = 1.05;
          });
        }
        // 树摇晃回复
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          setState(() => _treeScale = 1.0);
        }

        // 刷新social providers
        ref.invalidate(myTodayWatersProvider);
        ref.invalidate(myTotalWaterCountProvider);
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() => _waterLoading = false);
        if (e.code == '23505') {
          // 唯一约束冲突 — 今天已浇过
          setState(() => _hasWatered = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('今天已经浇过了')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('浇水失败: ${e.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _waterLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('浇水失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _classmateProfile == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Text(
            _error ?? '未找到同学信息',
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      );
    }

    final profile = _classmateProfile!;
    final nickname = profile.nickname;

    // 分类学习记录
    final inProgressBooks = _entries
        .where((e) => e.type == 'book' && e.status == 'in_progress')
        .toList();
    final inProgressSkills = _entries
        .where((e) => e.type == 'skill' && e.status == 'in_progress')
        .toList();
    final completed =
        _entries.where((e) => e.status == 'completed').toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('$nickname\u{7684}\u{667A}\u{6167}\u{6811}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 顶部: 智慧树可视化
            _buildTreeVisualization(profile, _entries),
            const SizedBox(height: AppSpacing.md),

            // 浇水统计
            if (_totalWaterCount > 0)
              Padding(
                padding:
                    const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  '\u{1F4A7} 累计收到$_totalWaterCount次浇水',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
              ),

            // 浇水按钮
            _buildWaterButton(nickname),
            const SizedBox(height: AppSpacing.lg),

            // 在读的书
            if (inProgressBooks.isNotEmpty) ...[
              _buildSectionHeader('\u{1F4D6} 在读的书'),
              ...inProgressBooks
                  .map((book) => _buildBookRow(book)),
              const SizedBox(height: AppSpacing.md),
            ],

            // 在学的技能
            if (inProgressSkills.isNotEmpty) ...[
              _buildSectionHeader('\u{1F3AF} 在学的技能'),
              ...inProgressSkills
                  .map((skill) => _buildSkillRow(skill)),
              const SizedBox(height: AppSpacing.md),
            ],

            // 已完成
            if (completed.isNotEmpty) ...[
              _buildSectionHeader(
                  '\u{1F352} 已完成 (${completed.length})'),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: completed.map((e) {
                  final config =
                      LearningCategories.getCategory(e.category);
                  return Chip(
                    label: Text('${config.emoji} ${e.title}'),
                    labelStyle: const TextStyle(fontSize: 12),
                    backgroundColor:
                        AppColors.moodGreenBg,
                    side: BorderSide.none,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildTreeVisualization(
      Profile profile, List<LearningEntry> entries) {
    final screenWidth = MediaQuery.of(context).size.width;
    final treeHeight = min(160.0, 40.0 + entries.length * 6.0);

    // 浇水发光效果
    final hasGlow = _totalWaterCount > 0;

    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedScale(
          scale: _treeScale,
          duration: const Duration(milliseconds: 300),
          curve: Curves.elasticOut,
          child: Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.large),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFB3E5FC),
                  Color(0xFFC8E6C9),
                  Color(0xFF81C784),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: entries.isNotEmpty
                ? _buildTree(entries, screenWidth, treeHeight, hasGlow)
                : const Center(
                    child: Text(
                      '\u{1F331} 还没有学习记录',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
          ),
        ),
        // 水滴动画
        if (_showWaterDrop)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.bounceOut,
            top: _showWaterDrop ? 80 : 0,
            child: const Text(
              '\u{1F4A7}',
              style: TextStyle(fontSize: 32),
            ),
          ),
      ],
    );
  }

  Widget _buildTree(List<LearningEntry> entries, double screenWidth,
      double treeHeight, bool hasGlow) {
    final centerX = screenWidth / 2 - AppSpacing.md;

    final categoryCounts = <String, List<LearningEntry>>{};
    for (final e in entries) {
      categoryCounts.putIfAbsent(e.category, () => []).add(e);
    }
    final categories = categoryCounts.keys.toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: Stack(
        children: [
          // 树干
          Positioned(
            left: centerX - 4,
            bottom: 10,
            child: Container(
              width: 8,
              height: treeHeight,
              decoration: BoxDecoration(
                color: const Color(0xFF8D6E63),
                borderRadius: BorderRadius.circular(4),
                boxShadow: hasGlow
                    ? [
                        BoxShadow(
                          color: Colors.lightBlueAccent
                              .withValues(alpha: 0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
          // 枝干+叶子/果实
          ...categories.asMap().entries.expand((catEntry) {
            final catIndex = catEntry.key;
            final catKey = catEntry.value;
            final catEntries = categoryCounts[catKey]!;
            final branchY = treeHeight -
                20 -
                catIndex *
                    (treeHeight / (categories.length + 1));
            final isLeft = catIndex.isEven;

            final branchWidgets = <Widget>[
              Positioned(
                left: isLeft
                    ? centerX - 34
                    : centerX + 4,
                bottom: branchY + 10,
                child: Container(
                  width: 34,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8D6E63),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            ];

            for (int i = 0; i < catEntries.length && i < 3; i++) {
              final e = catEntries[i];
              final isCompleted = e.status == 'completed';
              final config =
                  LearningCategories.getCategory(e.category);
              final offsetX = isLeft
                  ? centerX - 44 - i * 16.0
                  : centerX + 38 + i * 16.0;

              branchWidgets.add(
                Positioned(
                  left: offsetX,
                  bottom: branchY + 8,
                  child: Text(
                    isCompleted ? config.emoji : '\u{1F33F}',
                    style: TextStyle(
                        fontSize: isCompleted ? 16 : 14),
                  ),
                ),
              );
            }

            return branchWidgets;
          }),
        ],
      ),
    );
  }

  Widget _buildWaterButton(String nickname) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _hasWatered || _waterLoading ? null : _doWater,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _hasWatered ? AppColors.divider : AppColors.primary,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xLarge),
          ),
        ),
        child: _waterLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              )
            : Text(
                _hasWatered
                    ? '\u{1F4A7} 今天已浇过水了'
                    : '\u{1F4A7} 给$nickname浇水',
                style: const TextStyle(fontSize: 16),
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
      ),
    );
  }

  Widget _buildBookRow(LearningEntry book) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            book.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: book.progress / 100.0,
                    backgroundColor: AppColors.divider,
                    color: AppColors.primary,
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${book.progress}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkillRow(LearningEntry skill) {
    final config = LearningCategories.getCategory(skill.category);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        children: [
          Text(config.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              skill.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
