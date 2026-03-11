import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/badge.dart' as app_badge;
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/classroom_provider.dart';
import '../../widgets/avatar_picker.dart';
import '../../widgets/stat_circle.dart';

/// S7: Student profile/settings screen
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final classroomAsync = ref.watch(classroomProvider);
    final badgesAsync = ref.watch(badgesProvider);

    return Scaffold(
      body: profileAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('加载失败',
              style: const TextStyle(color: AppColors.error)),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('未找到用户资料'));
          }

          final classroom = classroomAsync.valueOrNull;
          final badges = badgesAsync.valueOrNull ?? [];
          final earnedBadgeKeys =
              badges.map((b) => b.badgeKey).toSet();

          return SingleChildScrollView(
            child: Column(
              children: [
                // Top blue gradient header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(
                    top: 48,
                    bottom: AppSpacing.xl,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF5BA0D9),
                        Color(0xFF4A90D9),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      // App bar row
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back,
                                  color: AppColors.white),
                              onPressed: () =>
                                  context.go('/home'),
                            ),
                            const Expanded(
                              child: Text(
                                '个人资料',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                  Icons.settings_outlined,
                                  color: AppColors.white),
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // Avatar
                      AvatarCircle(
                        avatarKey: profile.avatarKey,
                        size: 80,
                        showEditIcon: true,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // Name
                      Text(
                        profile.nickname,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Class info
                      Text(
                        classroom != null
                            ? classroom.shortDisplay
                            : '',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                // Stats row
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                      horizontal: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius:
                          BorderRadius.circular(AppRadius.large),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceEvenly,
                      children: [
                        StatCircle(
                          label: '总天数',
                          value: '${profile.totalCheckins}',
                        ),
                        StatCircle(
                          label: '连续天数',
                          value: '${profile.streak}',
                          color: AppColors.moodRed,
                        ),
                        StatCircle(
                          label: '勋章数',
                          value: '${badges.length}',
                          color: AppColors.moodGreen,
                        ),
                      ],
                    ),
                  ),
                ),
                // Badges section
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '已获勋章',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text(
                              '查看全部',
                              style: TextStyle(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Horizontal badge list
                      SizedBox(
                        height: 100,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: app_badge.Badge.allBadges.entries
                              .map((entry) {
                            final info = entry.value;
                            final isEarned = earnedBadgeKeys
                                .contains(entry.key);
                            return _buildBadgeItem(
                                info, isEarned);
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Settings list
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '设置',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _settingsTile(
                        icon: Icons.person_outline,
                        title: '账号详情',
                        subtitle: '管理您的个人信息',
                        onTap: () {},
                      ),
                      _settingsTile(
                        icon: Icons.notifications_outlined,
                        title: '消息通知',
                        subtitle: '课程提醒与学习通知',
                        onTap: null, // Phase 0: disabled
                        enabled: false,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // Logout
                      InkWell(
                        onTap: () => _handleLogout(context, ref),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.md),
                          child: Row(
                            children: [
                              Icon(Icons.logout,
                                  color: AppColors.error,
                                  size: 20),
                              SizedBox(width: AppSpacing.md),
                              Text(
                                '退出登录',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBadgeItem(app_badge.BadgeInfo info, bool isEarned) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: AppSpacing.md),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isEarned
                  ? AppColors.accent.withOpacity(0.15)
                  : AppColors.cardBackground,
              border: Border.all(
                color: isEarned ? AppColors.accent : AppColors.divider,
                width: 2,
              ),
            ),
            child: Center(
              child: isEarned
                  ? Text(info.emoji, style: const TextStyle(fontSize: 24))
                  : const Icon(
                      Icons.lock_outline,
                      color: AppColors.textHint,
                      size: 20,
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            info.name,
            style: TextStyle(
              fontSize: 11,
              color: isEarned
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

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Icon(
              icon,
              color: enabled ? AppColors.textDark : AppColors.textHint,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: enabled
                          ? AppColors.textDark
                          : AppColors.textHint,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: enabled ? AppColors.textHint : AppColors.divider,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final service = ref.read(supabaseServiceProvider);
        await service.signOut();
        if (context.mounted) {
          context.go('/');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('退出失败，请重试')),
          );
        }
      }
    }
  }
}
