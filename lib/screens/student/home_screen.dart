import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/checkin.dart';
import '../../providers/profile_provider.dart';
import '../../providers/checkin_provider.dart';
import '../../widgets/avatar_picker.dart';
import '../../widgets/streak_badge.dart';

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
            final todayCheckin = todayCheckinAsync.valueOrNull;
            final weekCheckins = weekCheckinsAsync.valueOrNull ?? [];
            final hasCheckedIn = todayCheckin != null;

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

                  // Main check-in card
                  _buildCheckinCard(context, hasCheckedIn, todayCheckin),
                  const SizedBox(height: AppSpacing.lg),

                  // Weekly mood index card
                  _buildWeekCard(context, weekCheckins),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCheckinCard(
      BuildContext context, bool hasCheckedIn, Checkin? todayCheckin) {
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
          // Large circle button
          GestureDetector(
            onTap: hasCheckedIn ? null : () => context.go('/checkin'),
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasCheckedIn
                    ? AppColors.quadrantBgColor(
                        todayCheckin?.quadrant ?? 'green')
                    : AppColors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
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
                        ? (todayCheckin != null
                            ? _getEmotionEmoji(todayCheckin.emotionLabel)
                            : '\u{1F60A}')
                        : '\u{1F60A}',
                    style: const TextStyle(fontSize: 48),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasCheckedIn ? '已记录 \u2713' : '点击记录',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: hasCheckedIn
                          ? AppColors.quadrantColor(
                              todayCheckin?.quadrant ?? 'green')
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
                ? '今天的心情已经记录好啦'
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
    // Build a map of weekday -> checkin
    final weekMap = <int, Checkin>{};
    for (final c in weekCheckins) {
      weekMap[c.checkedAt.weekday] = c;
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
            color: Colors.black.withOpacity(0.04),
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
                child: const Text(
                  '查看详情',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final weekday = index + 1; // 1=Monday
              final checkin = weekMap[weekday];
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
                      color: checkin != null
                          ? AppColors.quadrantBgColor(checkin.quadrant)
                          : (isFuture
                              ? AppColors.cardBackground
                              : null),
                      border: (isToday && checkin == null)
                          ? Border.all(
                              color: AppColors.primary,
                              width: 1.5,
                              strokeAlign: BorderSide.strokeAlignOutside,
                            )
                          : (checkin == null && !isFuture
                              ? Border.all(
                                  color: AppColors.divider,
                                  width: 1,
                                )
                              : null),
                    ),
                    child: Center(
                      child: checkin != null
                          ? Text(
                              _getEmotionEmoji(checkin.emotionLabel),
                              style: const TextStyle(fontSize: 20),
                            )
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
