import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../game/garden_game.dart';
import '../../models/garden.dart';
import '../../models/learning_entry.dart';
import '../../models/profile.dart';
import '../../models/student_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/checkin_provider.dart';
import '../../providers/learning_provider.dart';
import '../../providers/social_provider.dart';
import '../../services/garden_service.dart';
import '../../widgets/add_learning_dialog.dart';
import '../../widgets/avatar_picker.dart';

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
    final totalWaterCount =
        ref.watch(myTotalWaterCountProvider).valueOrNull ?? 0;
    final myMessages =
        ref.watch(myMessagesProvider).valueOrNull ?? [];
    final classmates =
        ref.watch(classmatesProvider).valueOrNull ?? [];
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: gardenAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('加载花园失败')),
          data: (garden) => Column(
            children: [
              // 固定高度200px的顶部场景区（含留言图标）
              SizedBox(
                height: 200,
                child: Stack(
                  children: [
                    _buildUnifiedScene(
                        context, garden, allEntries, totalWaterCount),
                    // 留言图标 + badge
                    Positioned(
                      top: AppSpacing.sm + 4,
                      right: AppSpacing.sm + 4,
                      child: _buildMessageBadge(
                        context,
                        myMessages,
                        classmates,
                        userId,
                      ),
                    ),
                  ],
                ),
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

  /// Group learning entries by category for tree visualization
  Map<String, int> _groupByCategory(List<LearningEntry> entries) {
    final result = <String, int>{};
    for (final e in entries) {
      result[e.category] = (result[e.category] ?? 0) + 1;
    }
    return result;
  }

  /// Unified top scene: Flame game with parallax background, flowers,
  /// wisdom tree, and ambient particles.
  Widget _buildUnifiedScene(BuildContext context, GardenState garden,
      List<LearningEntry> entries, int totalWaterCount) {
    final flowerDataList = garden.flowers
        .take(50)
        .toList()
        .asMap()
        .entries
        .map((e) => GardenFlowerData(
              quadrant: e.value.quadrant,
              index: e.key,
            ))
        .toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(AppSpacing.sm),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: Stack(
          children: [
            // Flame game scene
            GameWidget(
              game: GardenGame(
                flowers: flowerDataList,
                treeLeafCount:
                    entries.where((e) => e.status == 'in_progress').length,
                treeFruitCount:
                    entries.where((e) => e.status == 'completed').length,
                treeCategoryMap: _groupByCategory(entries),
                waterCount: totalWaterCount,
                hasEntries: entries.isNotEmpty,
              ),
            ),
            // Overlaid UI: guide text when no learning entries
            if (entries.isEmpty)
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
                      '\u{1F331} \u{6DFB}\u{52A0}\u{7B2C}\u{4E00}\u{672C}\u{4E66}\u{FF0C}\u{79CD}\u{4E0B}\u{667A}\u{6167}\u{6811}',
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

  /// 留言图标 + 未读数 badge
  Widget _buildMessageBadge(
    BuildContext context,
    List<StudentMessage> messages,
    List<Profile> classmates,
    String? userId,
  ) {
    final messageCount = messages.length;

    return GestureDetector(
      onTap: () => _showMessageSheet(context, messages, classmates, userId),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.85),
          shape: BoxShape.circle,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.mail_outline,
              size: 22,
              color: AppColors.primary,
            ),
            if (messageCount > 0)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    messageCount > 99 ? '99+' : '$messageCount',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 显示留言列表 BottomSheet
  void _showMessageSheet(
    BuildContext context,
    List<StudentMessage> messages,
    List<Profile> classmates,
    String? userId,
  ) {
    // 最多展示最近10条
    final displayMessages =
        messages.length > 10 ? messages.sublist(0, 10) : messages;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (_, scrollController) => SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Text(
                      '\u{1F4DD} 留言 \u{00B7} ${messages.length}条',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: const Icon(
                        Icons.close,
                        color: AppColors.textHint,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: displayMessages.isEmpty
                    ? const Center(
                        child: Text(
                          '还没有收到留言',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: displayMessages.length,
                        itemBuilder: (_, index) {
                          final msg = displayMessages[index];
                          final author = classmates
                              .where((c) => c.id == msg.authorId)
                              .firstOrNull;
                          final authorName =
                              author?.nickname ?? '同学';
                          final authorAvatarKey =
                              author?.avatarKey ?? 'cat';
                          final timeStr =
                              _formatMessageTime(msg.createdAt);

                          // 目标学生是自己的，可以删除
                          final canDelete = userId != null &&
                              msg.targetStudentId == userId;

                          return Container(
                            margin: const EdgeInsets.only(
                                bottom: AppSpacing.sm),
                            padding:
                                const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(
                                  AppRadius.medium),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withValues(alpha: 0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                AvatarCircle(
                                  avatarKey: authorAvatarKey,
                                  size: 32,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            authorName,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight:
                                                  FontWeight.w600,
                                              color:
                                                  AppColors.textDark,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            timeStr,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color:
                                                  AppColors.textHint,
                                            ),
                                          ),
                                          if (canDelete)
                                            GestureDetector(
                                              onTap: () async {
                                                Navigator.of(ctx)
                                                    .pop();
                                                await _deleteMyMessage(
                                                    msg.id);
                                              },
                                              child: const Padding(
                                                padding:
                                                    EdgeInsets.only(
                                                        left: 4),
                                                child: Icon(
                                                  Icons.close,
                                                  size: 16,
                                                  color: AppColors
                                                      .textHint,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        msg.content,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 删除收到的留言
  Future<void> _deleteMyMessage(String messageId) async {
    try {
      final service = ref.read(supabaseServiceProvider);
      await service.deleteMessage(messageId);
      ref.invalidate(myMessagesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除留言失败: $e')),
        );
      }
    }
  }

  /// 格式化留言时间
  String _formatMessageTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';

    return '${dateTime.month}/${dateTime.day}';
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

    // 读书圈数据（在书架Tab打开时加载）
    final classLearningAsync = ref.watch(classmateLearningProvider);
    final classLearning = classLearningAsync.valueOrNull;
    final classmatesAsync = ref.watch(classmatesProvider);
    final classmates = classmatesAsync.valueOrNull ?? [];
    final currentUserId =
        ref.watch(currentUserIdProvider) ?? '';

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
              ...inProgressBooks.map((book) => _buildBookItem(
                    book,
                    classLearning,
                    classmates,
                    currentUserId,
                  )),

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

  Widget _buildBookItem(
    LearningEntry book,
    List<LearningEntry>? classLearning,
    List<Profile> classmates,
    String currentUserId,
  ) {
    // 读书圈计数（排除自己）
    int readingCircleCount = 0;
    if (classLearning != null) {
      final bookTitleNorm = book.title.trim().toLowerCase();
      readingCircleCount = classLearning
          .where((e) =>
              e.type == 'book' &&
              e.status == 'in_progress' &&
              e.title.trim().toLowerCase() == bookTitleNorm &&
              e.studentId != currentUserId)
          .map((e) => e.studentId)
          .toSet()
          .length;
    }

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
          // 读书圈标签
          if (readingCircleCount > 0)
            GestureDetector(
              onTap: () => _showReadingCircleDialog(
                  book, classLearning!, classmates, currentUserId),
              child: Container(
                margin: const EdgeInsets.only(left: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.moodBlueBg,
                  borderRadius:
                      BorderRadius.circular(AppRadius.small),
                ),
                child: Text(
                  '\u{1F465}$readingCircleCount人在读',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                  ),
                ),
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

  void _showReadingCircleDialog(
    LearningEntry book,
    List<LearningEntry> classLearning,
    List<Profile> classmates,
    String currentUserId,
  ) {
    final bookTitleNorm = book.title.trim().toLowerCase();
    final readers = classLearning
        .where((e) =>
            e.type == 'book' &&
            e.status == 'in_progress' &&
            e.title.trim().toLowerCase() == bookTitleNorm &&
            e.studentId != currentUserId)
        .toList();

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
