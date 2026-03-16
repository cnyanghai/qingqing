import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/checkin.dart';
import '../../models/learning_entry.dart';
import '../../models/profile.dart';
import '../../models/water_record.dart';
import '../../models/student_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/checkin_provider.dart';
import '../../providers/learning_provider.dart';
import '../../providers/social_provider.dart';
import '../../widgets/avatar_picker.dart';
import '../../widgets/streak_badge.dart';
import '../../widgets/add_learning_dialog.dart';

/// S4: Student home screen
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) return '早上好';
    if (hour >= 12 && hour < 18) return '下午好';
    return '晚上好';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final todayCheckinAsync = ref.watch(todayCheckinProvider);
    final weekCheckinsAsync = ref.watch(weekCheckinsProvider);
    final currentBooks = ref.watch(currentBooksProvider);
    final currentSkills = ref.watch(currentSkillsProvider);
    final allEntries =
        ref.watch(myLearningEntriesProvider).valueOrNull ?? [];
    final todayWatersAsync = ref.watch(myTodayWatersProvider);
    final classmatesAsync = ref.watch(classmatesProvider);
    final myMessagesAsync = ref.watch(myMessagesProvider);
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: profileAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('加载失败: $e',
                style: const TextStyle(color: AppColors.error)),
          ),
          data: (profile) {
            if (profile == null) {
              return const Center(child: Text('未找到用户资料'));
            }

            final greeting = _getGreeting();
            final todayCheckins = todayCheckinAsync.valueOrNull ?? [];
            final weekCheckins = weekCheckinsAsync.valueOrNull ?? [];
            final hasCheckedIn = todayCheckins.isNotEmpty;
            final latestCheckin = todayCheckins.isNotEmpty ? todayCheckins.first : null;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row: avatar + greeting + streak
                  Row(
                    children: [
                      AvatarCircle(
                        avatarKey: profile.avatarKey,
                        size: 48,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$greeting，${profile.nickname}！',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const Text(
                              '又是元气满满的一天',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StreakBadge(streak: profile.streak),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 浇水通知条
                  _buildWaterNotification(
                    todayWatersAsync.valueOrNull ?? [],
                    classmatesAsync.valueOrNull ?? [],
                  ),

                  // 留言通知条
                  _buildMessageNotification(
                    myMessagesAsync.valueOrNull ?? [],
                    classmatesAsync.valueOrNull ?? [],
                  ),

                  // Main check-in card
                  _buildCheckinCard(context, hasCheckedIn, latestCheckin, todayCheckins.length),
                  const SizedBox(height: AppSpacing.lg),

                  // Weekly mood index card
                  _buildWeekCard(context, weekCheckins),
                  const SizedBox(height: AppSpacing.lg),

                  // 最近在读
                  _buildRecentBooksCard(
                    context,
                    currentBooks,
                    ref.watch(classmateLearningProvider).valueOrNull,
                    classmatesAsync.valueOrNull ?? [],
                    userId ?? '',
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 正在学习
                  _buildCurrentSkillsCard(context, currentSkills),
                  const SizedBox(height: AppSpacing.lg),

                  // 智慧树缩略入口
                  _buildWisdomTreeEntry(context, allEntries),
                  const SizedBox(height: AppSpacing.lg),

                  // 班级森林入口
                  _buildClassForestEntry(
                    context,
                    classmatesAsync.valueOrNull ?? [],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCheckinCard(
      BuildContext context, bool hasCheckedIn, Checkin? latestCheckin, int checkinCount) {
    // Button text logic
    String buttonText;
    if (!hasCheckedIn) {
      buttonText = '点击记录';
    } else if (checkinCount == 1) {
      buttonText = '再记一次';
    } else {
      buttonText = '再记一次（今日第$checkinCount次）';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.xLarge),
      ),
      child: Column(
        children: [
          const Text(
            '今天心情怎么样？',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Large circle button — always clickable
          GestureDetector(
            onTap: () => context.go('/checkin'),
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasCheckedIn
                    ? AppColors.quadrantBgColor(
                        latestCheckin?.quadrant ?? 'green')
                    : AppColors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha:0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    hasCheckedIn
                        ? (latestCheckin != null
                            ? _getEmotionEmoji(latestCheckin.emotionLabel)
                            : '\u{1F60A}')
                        : '\u{1F60A}',
                    style: const TextStyle(fontSize: 48),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    buttonText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: hasCheckedIn
                          ? AppColors.quadrantColor(
                              latestCheckin?.quadrant ?? 'green')
                          : AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            hasCheckedIn
                ? '心情变了？随时可以再记一次'
                : '点击太阳记录你的心情瞬间',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekCard(BuildContext context, List<Checkin> weekCheckins) {
    // Build a map of weekday -> list of checkins
    final weekMap = <int, List<Checkin>>{};
    for (final c in weekCheckins) {
      weekMap.putIfAbsent(c.checkedAt.weekday, () => []).add(c);
    }

    final now = DateTime.now();
    final todayWeekday = now.weekday;
    final dayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.xLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '本周心情指数',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              GestureDetector(
                onTap: () => context.go('/calendar'),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '查看详情',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final weekday = index + 1; // 1=Monday
              final dayCheckins = weekMap[weekday] ?? [];
              final isToday = weekday == todayWeekday;
              final isFuture = weekday > todayWeekday;

              return Column(
                children: [
                  // Circle
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dayCheckins.length == 1
                          ? AppColors.quadrantBgColor(dayCheckins.first.quadrant)
                          : (isFuture
                              ? AppColors.cardBackground
                              : (dayCheckins.isEmpty ? null : AppColors.cardBackground)),
                      border: (isToday && dayCheckins.isEmpty)
                          ? Border.all(
                              color: AppColors.primary,
                              width: 1.5,
                              strokeAlign: BorderSide.strokeAlignOutside,
                            )
                          : (dayCheckins.isEmpty && !isFuture
                              ? Border.all(
                                  color: AppColors.divider,
                                  width: 1,
                                )
                              : null),
                    ),
                    child: Center(
                      child: dayCheckins.length == 1
                          ? Text(
                              _getEmotionEmoji(dayCheckins.first.emotionLabel),
                              style: const TextStyle(fontSize: 20),
                            )
                          : dayCheckins.length >= 2
                              ? _buildMultiColorDots(dayCheckins)
                              : (isToday
                                  ? const Icon(
                                      Icons.add,
                                      size: 18,
                                      color: AppColors.primary,
                                    )
                                  : null),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dayLabels[index],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isToday ? FontWeight.w600 : FontWeight.normal,
                      color: isToday
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Build multi-color dots for days with 2+ checkins
  Widget _buildMultiColorDots(List<Checkin> checkins) {
    // Take at most 3 (newest first, already sorted by provider)
    final displayCheckins = checkins.take(3).toList();
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: displayCheckins.map((c) {
        return Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: AppColors.quadrantColor(c.quadrant),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }).toList(),
    );
  }

  // ============================================================
  // Card A — 最近在读
  // ============================================================

  Widget _buildRecentBooksCard(
      BuildContext context,
      List<LearningEntry> books,
      List<LearningEntry>? classLearning,
      List<Profile> classmates,
      String currentUserId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.xLarge),
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
          // 标题行
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '\u{1F4D6} 最近在读',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              GestureDetector(
                onTap: () => _showAddDialog(context, 'book'),
                child: const Icon(
                  Icons.add_circle_outline,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          if (books.isEmpty)
            // 空状态引导
            GestureDetector(
              onTap: () => _showAddDialog(context, 'book'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: const Column(
                  children: [
                    Text(
                      '还没有在读的书，添加一本吧',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Icon(Icons.add, color: AppColors.primary, size: 28),
                  ],
                ),
              ),
            )
          else ...[
            // 显示最近1本书
            _buildBookRow(books.first),
            // 读书圈标识（仅在classLearning已缓存时显示）
            if (classLearning != null)
              _buildReadingCircleHint(
                context,
                books.first,
                classLearning,
                classmates,
                currentUserId,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildBookRow(LearningEntry book) {
    return Column(
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
    );
  }

  // ============================================================
  // Card B — 正在学习
  // ============================================================

  Widget _buildCurrentSkillsCard(
      BuildContext context, List<LearningEntry> skills) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.xLarge),
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
            '\u{1F3AF} 正在学习',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          if (skills.isEmpty)
            // 空状态引导
            GestureDetector(
              onTap: () => _showAddDialog(context, 'skill'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: const Column(
                  children: [
                    Text(
                      '记录你在学习的技能吧',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Icon(Icons.add, color: AppColors.primary, size: 28),
                  ],
                ),
              ),
            )
          else
            // 技能Chip列表
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                ...skills.map((skill) {
                  final config =
                      LearningCategories.getCategory(skill.category);
                  return Chip(
                    label: Text('${config.emoji} ${skill.title}'),
                    labelStyle: const TextStyle(fontSize: 13),
                    backgroundColor: config.color.withValues(alpha: 0.1),
                    side: BorderSide.none,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }),
                // "+" 添加按钮Chip
                ActionChip(
                  label: const Icon(Icons.add, size: 16),
                  onPressed: () => _showAddDialog(context, 'skill'),
                  backgroundColor: AppColors.cardBackground,
                  side: BorderSide.none,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ============================================================
  // Card C — 智慧树缩略入口
  // ============================================================

  Widget _buildWisdomTreeEntry(
      BuildContext context, List<LearningEntry> allEntries) {
    final leaves =
        allEntries.where((e) => e.status == 'in_progress').length;
    final fruits =
        allEntries.where((e) => e.status == 'completed').length;

    return GestureDetector(
      onTap: () => context.go('/garden'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.xLarge),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '\u{1F333} 我的智慧树 \u{00B7} $leaves片叶子 \u{00B7} $fruits个果实',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
            ),
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

  // ============================================================
  // 浇水通知条
  // ============================================================

  Widget _buildWaterNotification(
      List<WaterRecord> todayWaters, List<Profile> classmates) {
    if (todayWaters.isEmpty) return const SizedBox.shrink();

    // 解析浇水人昵称
    final waterFromIds = todayWaters
        .map((w) => w.fromStudentId)
        .toList();
    final names = <String>[];
    for (final fromId in waterFromIds) {
      final match = classmates.where((c) => c.id == fromId).firstOrNull;
      if (match != null && !names.contains(match.nickname)) {
        names.add(match.nickname);
      }
    }

    if (names.isEmpty) return const SizedBox.shrink();

    // 检查最新浇水是否有留言
    final latestWithMessage = todayWaters
        .where((w) => w.message != null && w.message!.isNotEmpty)
        .toList();

    String text;
    if (latestWithMessage.isNotEmpty) {
      final latestWater = latestWithMessage.first;
      final latestAuthor = classmates
          .where((c) => c.id == latestWater.fromStudentId)
          .firstOrNull;
      final authorName = latestAuthor?.nickname ?? '同学';
      text =
          '\u{1F4A7} $authorName给你浇水说：\u{300C}${latestWater.message}\u{300D}';
    } else {
      final firstName = names.first;
      final count = names.length;
      text = count == 1
          ? '\u{1F4A7} 今天$firstName给你的智慧树浇了水！'
          : '\u{1F4A7} 今天$firstName等$count位同学给你的智慧树浇了水！';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.moodBlueBg,
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textDark,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildMessageNotification(
      List<StudentMessage> messages, List<Profile> classmates) {
    if (messages.isEmpty) return const SizedBox.shrink();

    // 筛选今天的留言
    final now = DateTime.now();
    final todayMessages = messages.where((m) {
      if (m.createdAt == null) return false;
      return m.createdAt!.year == now.year &&
          m.createdAt!.month == now.month &&
          m.createdAt!.day == now.day;
    }).toList();

    if (todayMessages.isEmpty) return const SizedBox.shrink();

    final latest = todayMessages.first;
    final author = classmates
        .where((c) => c.id == latest.authorId)
        .firstOrNull;
    final authorName = author?.nickname ?? '同学';
    final text =
        '\u{1F4DD} $authorName给你留言了：\u{300C}${latest.content}\u{300D}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.moodGreenBg,
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textDark,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // ============================================================
  // 班级森林入口
  // ============================================================

  Widget _buildClassForestEntry(
      BuildContext context, List<Profile> classmates) {
    return GestureDetector(
      onTap: () => context.push('/classmates'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.xLarge),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '\u{1F332} 班级森林 \u{00B7} ${classmates.length}位同学',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
            ),
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

  // ============================================================
  // 读书圈标识（首页）
  // ============================================================

  Widget _buildReadingCircleHint(
    BuildContext context,
    LearningEntry book,
    List<LearningEntry> classLearning,
    List<Profile> classmates,
    String currentUserId,
  ) {
    final bookTitleNorm = book.title.trim().toLowerCase();
    // 排除自己的记录
    final readers = classLearning
        .where((e) =>
            e.type == 'book' &&
            e.status == 'in_progress' &&
            e.title.trim().toLowerCase() == bookTitleNorm &&
            e.studentId != currentUserId)
        .toList();

    if (readers.isEmpty) return const SizedBox.shrink();

    // 找到第一个读者的昵称
    final firstReaderId = readers.first.studentId;
    final firstReader =
        classmates.where((c) => c.id == firstReaderId).firstOrNull;
    final name = firstReader?.nickname ?? '同学';
    final count = readers.map((e) => e.studentId).toSet().length;

    return GestureDetector(
      onTap: () => _showReadingCircle(context, book, classLearning,
          classmates, currentUserId),
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Text(
          count == 1
              ? '\u{1F4DA} $name也在读'
              : '\u{1F4DA} $name等$count位同学也在读',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  void _showReadingCircle(
    BuildContext context,
    LearningEntry book,
    List<LearningEntry> classLearning,
    List<Profile> classmates,
    String currentUserId,
  ) {
    // 延迟import避免循环，使用内联实现
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

  void _showAddDialog(BuildContext context, String type) {
    showDialog(
      context: context,
      builder: (ctx) => AddLearningDialog(type: type),
    );
  }

  String _getEmotionEmoji(String label) {
    // Look up emoji by emotion label
    final emotion =
        _emotionEmojiMap[label];
    return emotion ?? '\u{1F60A}';
  }

  static const _emotionEmojiMap = {
    '生气': '\u{1F624}',
    '焦虑': '\u{1F630}',
    '烦躁': '\u{1F620}',
    '压力大': '\u{1F62B}',
    '不耐烦': '\u{1F612}',
    '委屈': '\u{1F616}',
    '开心': '\u{1F604}',
    '兴奋': '\u{1F929}',
    '自豪': '\u{1F60A}',
    '激动': '\u{1F973}',
    '期待': '\u{1F601}',
    '有信心': '\u{1F4AA}',
    '平静': '\u{1F60C}',
    '感激': '\u{1F64F}',
    '满足': '\u{1F60A}',
    '放松': '\u{1F9D8}',
    '温暖': '\u{2600}\u{FE0F}',
    '安全': '\u{1F6E1}\u{FE0F}',
    '难过': '\u{1F622}',
    '失落': '\u{1F614}',
    '孤单': '\u{1F61E}',
    '疲惫': '\u{1F629}',
    '无聊': '\u{1F636}',
    '想家': '\u{1F97A}',
  };
}
