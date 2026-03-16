import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../models/garden.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/checkin_provider.dart';
import '../../services/garden_service.dart';

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

/// 花园主屏幕
class GardenScreen extends ConsumerWidget {
  const GardenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gardenAsync = ref.watch(gardenStateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: gardenAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('加载花园失败')),
          data: (garden) => _GardenContent(garden: garden),
        ),
      ),
    );
  }
}

class _GardenContent extends StatelessWidget {
  final GardenState garden;

  const _GardenContent({required this.garden});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 区域A: 花园标题
          _buildTitle(context),

          // 区域B: 花园可视化
          _buildGardenVisualization(context),

          // 区域C: 花园统计
          _buildStats(),

          const SizedBox(height: AppSpacing.lg),

          // 区域D: 花园图鉴
          _buildAlmanac(),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Text(
                  '我的花园',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.moodGreenBg,
                    borderRadius: BorderRadius.circular(AppRadius.round),
                  ),
                  child: Text(
                    '${garden.level.displayName} ${garden.level.displayEmoji}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.moodGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: AppColors.textSecondary,
            ),
            onPressed: () {
              // 跳转到个人中心
              // 由于 ProfileScreen 在同一 Shell 中，
              // 使用 DefaultTabController 不合适
              // 这里显示简单提示
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('请切换到"我的"标签页查看个人设置'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGardenVisualization(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final gardenHeight = MediaQuery.of(context).size.height * 0.40;

    return Container(
      width: double.infinity,
      height: gardenHeight,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
            // 空花园引导
            if (garden.level == GardenLevel.empty)
              _buildEmptyGarden()
            else if (garden.level == GardenLevel.seed)
              _buildSeedGarden()
            else
              _buildFlowerGarden(screenWidth, gardenHeight),

            // 装饰物
            ..._buildDecorations(screenWidth, gardenHeight),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyGarden() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '\u{1FAB4}', // 🪴
            style: TextStyle(fontSize: 56),
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            '记录第一个心情，种下第一朵花吧',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textDark,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeedGarden() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '\u{1FAB4}', // 🪴
            style: TextStyle(fontSize: 48),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            '\u{1F331}', // 🌱
            style: TextStyle(fontSize: 32),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            '种子已种下，继续记录让它长大吧',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowerGarden(double width, double height) {
    // 只显示最近50朵花
    final displayFlowers = garden.flowers.length > 50
        ? garden.flowers.sublist(garden.flowers.length - 50)
        : garden.flowers;
    final extraCount =
        garden.flowers.length > 50 ? garden.flowers.length - 50 : 0;

    // 花朵分布区域（留边距）
    final areaWidth = width - AppSpacing.md * 2 - 32;
    final areaHeight = height - 60;

    return Stack(
      children: [
        ...displayFlowers.asMap().entries.map((entry) {
          final index = entry.key;
          final flower = entry.value;
          final config = GardenConfig.getFlower(flower.quadrant);
          if (config == null) return const SizedBox.shrink();

          // 用 index + quadrant hashCode 生成伪随机固定位置
          final seed = index * 31 + flower.quadrant.hashCode;
          final rng = Random(seed);
          final x = 16 + rng.nextDouble() * areaWidth;
          final y = 30 + rng.nextDouble() * areaHeight;
          final fontSize = 28.0 + rng.nextDouble() * 8.0; // 28-36px

          return Positioned(
            left: x,
            top: y,
            child: Text(
              config.emoji,
              style: TextStyle(fontSize: fontSize),
            ),
          );
        }),
        // 额外花朵提示
        if (extraCount > 0)
          Positioned(
            right: 12,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(AppRadius.round),
              ),
              child: Text(
                '还有$extraCount朵花',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildDecorations(double width, double height) {
    final unlocked = garden.unlockedDecorations;
    if (unlocked.isEmpty) return [];

    // 将装饰物分布在花园边缘
    final positions = <Offset>[
      Offset(8, 8), // 左上
      Offset(width - 80, 8), // 右上
      Offset(8, height - 48), // 左下
      Offset(width - 80, height - 48), // 右下
      Offset(width / 2 - 16, 8), // 顶部中间
      Offset(8, height / 2 - 16), // 左中
      Offset(width - 80, height / 2 - 16), // 右中
    ];

    return unlocked.asMap().entries.map((entry) {
      final idx = entry.key;
      final status = entry.value;
      final pos =
          idx < positions.length ? positions[idx] : positions[idx % positions.length];

      return Positioned(
        left: pos.dx,
        top: pos.dy,
        child: Text(
          status.decoration.emoji,
          style: const TextStyle(fontSize: 24),
        ),
      );
    }).toList();
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
