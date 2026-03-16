import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../models/garden.dart';
import '../../models/learning_entry.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/checkin_provider.dart';
import '../../providers/learning_provider.dart';
import '../../services/garden_service.dart';
import '../../widgets/add_learning_dialog.dart';

/// 花园状态 Provider
final gardenStateProvider = FutureProvider<GardenState>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return GardenState.empty;

  final profile = await ref.watch(profileProvider.future);
  if (profile == null) return GardenState.empty;

  final service = ref.watch(supabaseServiceProvider);

  try {
    // 获取数据（各只查一次）
    final notesCount = await service.countCheckinNotes(userId);
    final distinctQuadrants = await service.getDistinctQuadrants(userId);

    // 获取学期内的打卡记录用于花朵列表
    final semesterCheckins =
        await ref.watch(semesterCheckinsProvider.future);

    // 计算不同场景数量
    final distinctContexts =
        semesterCheckins.map((c) => c.contextTag).toSet().length;

    // 计算同一天最多不同情绪象限数
    final dayQuadrants = <String, Set<String>>{};
    for (final c in semesterCheckins) {
      final dayKey =
          '${c.checkedAt.year}-${c.checkedAt.month}-${c.checkedAt.day}';
      dayQuadrants.putIfAbsent(dayKey, () => {}).add(c.quadrant);
    }
    int maxSameDayQuadrants = 0;
    for (final qs in dayQuadrants.values) {
      if (qs.length > maxSameDayQuadrants) {
        maxSameDayQuadrants = qs.length;
      }
    }

    return GardenService.calculateState(
      totalCheckins: profile.totalCheckins,
      streak: profile.streak,
      notesCount: notesCount,
      distinctQuadrants: distinctQuadrants.length,
      recentCheckins: semesterCheckins,
      distinctContexts: distinctContexts,
      maxSameDayQuadrants: maxSameDayQuadrants,
    );
  } catch (_) {
    return GardenState.empty;
  }
});

/// 花园主屏幕（成长乐园）— 内含花园/书架两个子Tab
class GardenScreen extends ConsumerStatefulWidget {
  const GardenScreen({super.key});

  @override
  ConsumerState<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends ConsumerState<GardenScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gardenAsync = ref.watch(gardenStateProvider);
    final allEntries =
        ref.watch(myLearningEntriesProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: gardenAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('加载花园失败')),
          data: (garden) => Column(
            children: [
              // 固定高度200px的顶部场景区
              SizedBox(
                height: 200,
                child: _buildUnifiedScene(context, garden, allEntries),
              ),
              // TabBar
              Container(
                color: AppColors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 2.5,
                  tabs: const [
                    Tab(text: '\u{1F338} 花园'),
                    Tab(text: '\u{1F4DA} 书架'),
                  ],
                ),
              ),
              // TabBarView占满剩余空间
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // 花园子Tab
                    _GardenTabContent(garden: garden),
                    // 书架子Tab
                    _BookshelfTabContent(entries: allEntries),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 统一顶部场景：花朵 + 智慧树
  Widget _buildUnifiedScene(
      BuildContext context, GardenState garden, List<LearningEntry> entries) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.large),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFB3E5FC), // 天空蓝
            Color(0xFFC8E6C9), // 浅绿
            Color(0xFF81C784), // 深绿草地
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: Stack(
          children: [
            // 左侧：花朵（缩小版，最近20朵）
            ..._buildMiniFlowers(garden, screenWidth),
            // 右侧/中央：智慧树可视化
            if (entries.isNotEmpty)
              _buildWisdomTree(entries, screenWidth)
            else
              // 如果没有学习记录：底部引导文字
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(AppRadius.round),
                    ),
                    child: const Text(
                      '添加第一本书，种下智慧树',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 缩小版花朵（最近20朵，分布在左半侧）
  List<Widget> _buildMiniFlowers(GardenState garden, double screenWidth) {
    if (garden.flowers.isEmpty) return [];

    final displayFlowers = garden.flowers.length > 20
        ? garden.flowers.sublist(garden.flowers.length - 20)
        : garden.flowers;

    final areaWidth = screenWidth * 0.45;
    const areaHeight = 160.0;

    return displayFlowers.asMap().entries.map((entry) {
      final index = entry.key;
      final flower = entry.value;
      final config = GardenConfig.getFlower(flower.quadrant);
      if (config == null) return const SizedBox.shrink();

      final seed = index * 31 + flower.quadrant.hashCode;
      final rng = Random(seed);
      final x = 8 + rng.nextDouble() * (areaWidth - 24);
      final y = 16 + rng.nextDouble() * areaHeight;
      final fontSize = 18.0 + rng.nextDouble() * 6.0;

      return Positioned(
        left: x,
        top: y,
        child: Text(
          config.emoji,
          style: TextStyle(fontSize: fontSize),
        ),
      );
    }).toList();
  }

  /// 智慧树可视化（Stack+Positioned+emoji）
  Widget _buildWisdomTree(List<LearningEntry> entries, double screenWidth) {
    final treeHeight = min(150.0, 30.0 + entries.length * 5.0);
    final treeX = screenWidth * 0.6;

    // 按类别分组
    final categoryCounts = <String, List<LearningEntry>>{};
    for (final e in entries) {
      categoryCounts.putIfAbsent(e.category, () => []).add(e);
    }
    final categories = categoryCounts.keys.toList();

    return Positioned(
      left: treeX,
      bottom: 10,
      child: SizedBox(
        width: screenWidth * 0.35,
        height: treeHeight + 20,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 树干
            Positioned(
              left: screenWidth * 0.35 / 2 - 3,
              bottom: 0,
              child: Container(
                width: 6,
                height: treeHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFF8D6E63),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            // 枝干 + 叶子/果实
            ...categories.asMap().entries.expand((catEntry) {
              final catIndex = catEntry.key;
              final catKey = catEntry.value;
              final catEntries = categoryCounts[catKey]!;
              final branchY =
                  treeHeight - 20 - catIndex * (treeHeight / (categories.length + 1));
              final isLeft = catIndex.isEven;

              final branchWidgets = <Widget>[
                // 枝干
                Positioned(
                  left: isLeft
                      ? screenWidth * 0.35 / 2 - 30
                      : screenWidth * 0.35 / 2 + 3,
                  bottom: branchY,
                  child: Container(
                    width: 30,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8D6E63),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
              ];

              // 叶子和果实
              for (int i = 0; i < catEntries.length && i < 3; i++) {
                final e = catEntries[i];
                final isCompleted = e.status == 'completed';
                final config = LearningCategories.getCategory(e.category);
                final offsetX = isLeft
                    ? screenWidth * 0.35 / 2 - 40 - i * 14.0
                    : screenWidth * 0.35 / 2 + 34 + i * 14.0;

                branchWidgets.add(
                  Positioned(
                    left: offsetX,
                    bottom: branchY - 2,
                    child: Text(
                      isCompleted ? config.emoji : '\u{1F33F}', // 果实用类别emoji，叶子用🌿
                      style: TextStyle(fontSize: isCompleted ? 14 : 12),
                    ),
                  ),
                );
              }

              return branchWidgets;
            }),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 花园子Tab（原有内容：统计 + 图鉴）
// ============================================================

class _GardenTabContent extends StatelessWidget {
  final GardenState garden;

  const _GardenTabContent({required this.garden});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 花园统计
          _buildStats(),
          const SizedBox(height: AppSpacing.lg),
          // 花园图鉴
          _buildAlmanac(),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildStats() {
    // 找出最多的花种
    String mostFlower = '-';
    if (garden.quadrantCounts.isNotEmpty) {
      final maxEntry = garden.quadrantCounts.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      final config = GardenConfig.getFlower(maxEntry.key);
      if (config != null) {
        mostFlower = '${config.name}${config.emoji}';
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _statItem('${garden.totalFlowers}', '总花朵'),
            _statItem(mostFlower, '最多花种'),
            _statItem('${garden.streak}', '连续天数'),
            _statItem(garden.level.displayEmoji, '花园等级'),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
    );
  }

  Widget _buildAlmanac() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '花园图鉴',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.75,
            ),
            itemCount: garden.decorations.length,
            itemBuilder: (context, index) {
              final status = garden.decorations[index];
              return _buildDecorationItem(context, status);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDecorationItem(BuildContext context, DecorationStatus status) {
    return GestureDetector(
      onTap: () => _showDecorationDetail(context, status),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: status.unlocked
                  ? AppColors.moodGreenBg
                  : AppColors.cardBackground,
              border: Border.all(
                color: status.unlocked
                    ? AppColors.moodGreen
                    : AppColors.divider,
                width: 2,
              ),
            ),
            child: Center(
              child: status.unlocked
                  ? Text(
                      status.decoration.emoji,
                      style: const TextStyle(fontSize: 24),
                    )
                  : const Icon(
                      Icons.lock_outline,
                      color: AppColors.textHint,
                      size: 20,
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status.decoration.name,
            style: TextStyle(
              fontSize: 11,
              color: status.unlocked
                  ? AppColors.textDark
                  : AppColors.textHint,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showDecorationDetail(BuildContext context, DecorationStatus status) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        title: Row(
          children: [
            Text(
              status.decoration.emoji,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(status.decoration.name),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              status.unlocked ? '已解锁' : '未解锁',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: status.unlocked
                    ? AppColors.moodGreen
                    : AppColors.textHint,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '解锁条件: ${status.decoration.unlockCondition}',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            if (!status.unlocked && status.progressText.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '当前进度: ${status.progressText}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: status.progress.clamp(0.0, 1.0),
                  backgroundColor: AppColors.divider,
                  color: AppColors.moodGreen,
                  minHeight: 6,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 书架子Tab（书籍列表 + 技能列表）
// ============================================================

class _BookshelfTabContent extends ConsumerStatefulWidget {
  final List<LearningEntry> entries;

  const _BookshelfTabContent({required this.entries});

  @override
  ConsumerState<_BookshelfTabContent> createState() =>
      _BookshelfTabContentState();
}

class _BookshelfTabContentState extends ConsumerState<_BookshelfTabContent> {
  bool _showCompletedBooks = false;
  bool _showMasteredSkills = false;

  @override
  Widget build(BuildContext context) {
    final inProgressBooks = widget.entries
        .where((e) => e.type == 'book' && e.status == 'in_progress')
        .toList();
    final completedBooks = widget.entries
        .where((e) => e.type == 'book' && e.status == 'completed')
        .toList();
    final inProgressSkills = widget.entries
        .where((e) => e.type == 'skill' && e.status == 'in_progress')
        .toList();
    final completedSkills = widget.entries
        .where((e) => e.type == 'skill' && e.status == 'completed')
        .toList();

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // 区域A — 在读书籍
            _buildSectionHeader(
              '\u{1F4D6} 在读',
              count: inProgressBooks.length,
            ),
            if (inProgressBooks.isEmpty)
              _buildEmptyHint('还没有在读的书')
            else
              ...inProgressBooks.map((book) => _buildBookItem(book)),

            const SizedBox(height: AppSpacing.lg),

            // 区域B — 已读完书籍（可折叠）
            _buildCollapsibleHeader(
              '\u{1F4D5} 已读完',
              count: completedBooks.length,
              isExpanded: _showCompletedBooks,
              onTap: () =>
                  setState(() => _showCompletedBooks = !_showCompletedBooks),
            ),
            if (_showCompletedBooks)
              ...completedBooks.map((book) => _buildCompletedBookItem(book)),

            const SizedBox(height: AppSpacing.lg),

            // 区域C — 正在学习的技能
            _buildSectionHeader(
              '\u{1F3AF} 技能',
              count: inProgressSkills.length,
            ),
            if (inProgressSkills.isEmpty)
              _buildEmptyHint('还没有在学的技能')
            else
              ...inProgressSkills.map((skill) => _buildSkillItem(skill)),

            const SizedBox(height: AppSpacing.lg),

            // 区域D — 已掌握的技能（可折叠）
            _buildCollapsibleHeader(
              '\u{1F3C6} 已掌握',
              count: completedSkills.length,
              isExpanded: _showMasteredSkills,
              onTap: () =>
                  setState(() => _showMasteredSkills = !_showMasteredSkills),
            ),
            if (_showMasteredSkills)
              ...completedSkills.map((skill) => _buildCompletedSkillItem(skill)),

            // 底部留空给FAB
            const SizedBox(height: 80),
          ],
        ),

        // FAB 添加按钮
        Positioned(
          right: AppSpacing.md,
          bottom: AppSpacing.md,
          child: FloatingActionButton(
            onPressed: () => _showAddOptions(context),
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add, color: AppColors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, {required int count}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        '$title ($count)',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
    );
  }

  Widget _buildCollapsibleHeader(
    String title, {
    required int count,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          children: [
            Text(
              '$title ($count)',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 书籍条目
  // ============================================================

  Widget _buildBookItem(LearningEntry book) {
    return Container(
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
          Expanded(
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
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${book.progress}%',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildPopupMenu(book, isBook: true),
        ],
      ),
    );
  }

  Widget _buildCompletedBookItem(LearningEntry book) {
    final completedDate = book.completedAt != null
        ? '${book.completedAt!.month}/${book.completedAt!.day}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              book.title,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.moodGreenBg,
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: const Text(
              '已读完',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.moodGreen,
              ),
            ),
          ),
          if (completedDate.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              completedDate,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // 技能条目
  // ============================================================

  Widget _buildSkillItem(LearningEntry skill) {
    final config = LearningCategories.getCategory(skill.category);

    return Container(
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
          Text(config.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skill.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: skill.progress / 100.0,
                          backgroundColor: AppColors.divider,
                          color: config.color,
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${skill.progress}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: config.color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildPopupMenu(skill, isBook: false),
        ],
      ),
    );
  }

  Widget _buildCompletedSkillItem(LearningEntry skill) {
    final config = LearningCategories.getCategory(skill.category);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
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
                fontSize: 14,
                color: AppColors.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.moodGreenBg,
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: const Text(
              '已掌握',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.moodGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 操作菜单
  // ============================================================

  Widget _buildPopupMenu(LearningEntry entry, {required bool isBook}) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AppColors.textHint, size: 20),
      onSelected: (value) => _handleMenuAction(value, entry, isBook: isBook),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'update_progress',
          child: Text('更新进度'),
        ),
        PopupMenuItem(
          value: 'complete',
          child: Text(isBook ? '标记完成' : '标记掌握'),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Text('删除', style: TextStyle(color: AppColors.error)),
        ),
      ],
    );
  }

  Future<void> _handleMenuAction(String action, LearningEntry entry,
      {required bool isBook}) async {
    final service = ref.read(supabaseServiceProvider);

    switch (action) {
      case 'update_progress':
        final newProgress = await _showProgressDialog(entry.progress);
        if (newProgress != null && mounted) {
          try {
            await service.updateLearningEntry(
              entry.id,
              {'progress': newProgress},
            );
            ref.invalidate(myLearningEntriesProvider);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('更新失败: $e')),
              );
            }
          }
        }
        break;

      case 'complete':
        try {
          final now = DateTime.now();
          final dateStr =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          await service.updateLearningEntry(entry.id, {
            'status': 'completed',
            'progress': 100,
            'completed_at': dateStr,
          });
          ref.invalidate(myLearningEntriesProvider);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isBook
                      ? '\u{1F389} 恭喜读完《${entry.title}》!'
                      : '\u{1F389} 恭喜掌握「${entry.title}」!',
                ),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('操作失败: $e')),
            );
          }
        }
        break;

      case 'delete':
        final confirmed = await _showDeleteConfirmation(entry.title);
        if (confirmed == true && mounted) {
          try {
            await service.deleteLearningEntry(entry.id);
            ref.invalidate(myLearningEntriesProvider);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('删除失败: $e')),
              );
            }
          }
        }
        break;
    }
  }

  Future<int?> _showProgressDialog(int currentProgress) {
    double sliderValue = currentProgress.toDouble();
    return showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.large),
          ),
          title: const Text('更新进度'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${sliderValue.toInt()}%',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Slider(
                value: sliderValue,
                min: 0,
                max: 100,
                divisions: 20,
                label: '${sliderValue.toInt()}%',
                onChanged: (v) => setDialogState(() => sliderValue = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(sliderValue.toInt()),
              child: const Text('确认'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(String title) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        title: const Text('确认删除'),
        content: Text('确定要删除「$title」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
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
              ListTile(
                leading: const Text('\u{1F4D6}',
                    style: TextStyle(fontSize: 24)),
                title: const Text('添加书籍'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showDialog(
                    context: context,
                    builder: (_) => const AddLearningDialog(type: 'book'),
                  );
                },
              ),
              ListTile(
                leading: const Text('\u{1F3AF}',
                    style: TextStyle(fontSize: 24)),
                title: const Text('添加技能'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showDialog(
                    context: context,
                    builder: (_) => const AddLearningDialog(type: 'skill'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
