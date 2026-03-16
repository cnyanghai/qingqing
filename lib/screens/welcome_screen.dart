import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';

/// S1: Welcome/Login page
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);

    // 已登录用户：加载profile后手动跳转
    if (userId != null) {
      final profileAsync = ref.watch(profileProvider);

      if (profileAsync.isLoading) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      final profile = profileAsync.valueOrNull;
      if (profile != null) {
        // 使用 addPostFrameCallback 避免在 build 中直接导航
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            if (profile.role == 'teacher') {
              context.go('/teacher/home');
            } else {
              context.go('/home');
            }
          }
        });
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      // profileAsync.hasError: 降级显示WelcomeScreen让用户重新操作
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE8F0FE), // light blue top
              AppColors.background, // warm white bottom
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // Sun icon in orange rounded square
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(AppRadius.xLarge),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '\u{2600}\u{FE0F}',
                      style: TextStyle(fontSize: 48),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Title
                const Text(
                  '晴晴',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Subtitle
                const Text(
                  '记录你的每一天心情',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(flex: 2),
                // Student button (primary orange)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => context.go('/join'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.xLarge),
                      ),
                    ),
                    child: const Text(
                      '我是学生 \u2014 加入班级',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Teacher button (outlined)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => context.go('/teacher/register'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textDark,
                      side: const BorderSide(
                        color: AppColors.textDark,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.xLarge),
                      ),
                    ),
                    child: const Text(
                      '我是老师 \u2014 创建班级',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Login link for existing accounts
                GestureDetector(
                  onTap: () => context.go('/login'),
                  child: const Text(
                    '已有账号？点击登录',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                // PWA install hint
                const Text(
                  '\u{1F4F1} 长按分享按钮，选择"添加到主屏幕"获得更好体验',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                // Bottom tagline
                const Text(
                  '让每一天都有好心情',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
