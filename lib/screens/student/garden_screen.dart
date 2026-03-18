import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/plant_catalog.dart';
import '../../models/player_plant.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/plant_provider.dart';

/// Terrarium 风格植物养成花园
class GardenScreen extends ConsumerStatefulWidget {
  const GardenScreen({super.key});

  @override
  ConsumerState<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends ConsumerState<GardenScreen> {
  // 每株植物今天的点击收益次数（key=plantId）
  final Map<String, int> _tapCounts = {};

  @override
  Widget build(BuildContext context) {
    final plantsAsync = ref.watch(myPlantsProvider);
    final sunshine = ref.watch(sunshineProvider);
    final level = ref.watch(playerLevelProvider);
    final progress = ref.watch(levelProgressProvider);

    return Scaffold(
      body: Column(
        children: [
          // 顶栏
          _TopBar(sunshine: sunshine, level: level, progress: progress),
          // 花园场景
          Expanded(
            child: plantsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(
                child: Text(
                  '\u52A0\u8F7D\u82B1\u56ED\u5931\u8D25',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
              data: (plants) => _GardenScene(
                plants: plants,
                level: level,
                onPlantTap: _handlePlantTap,
                onEmptySlotTap: _handleEmptySlotTap,
              ),
            ),
          ),
          // 底部面板
          _BottomPanel(
            sunshine: sunshine,
            level: level,
            plants: plantsAsync.valueOrNull ?? [],
            onPlant: _handlePlantNew,
            onUpgrade: _handleUpgrade,
          ),
        ],
      ),
    );
  }

  void _handlePlantTap(PlayerPlant plant) {
    final todayCount = _tapCounts[plant.id] ?? 0;
    if (todayCount >= 3) {
      // 达到上限
      _showFloatingText(
        '\u4ECA\u5929\u5DF2\u6536\u83B7', // 今天已收获
        Colors.grey,
      );
      return;
    }
    // 增加阳光+1
    _tapCounts[plant.id] = todayCount + 1;
    final userId = ref.read(currentUserIdProvider);
    final sunshine = ref.read(sunshineProvider);
    if (userId != null) {
      final service = ref.read(supabaseServiceProvider);
      service.updateSunshine(userId, sunshine + 1).then((_) {
        ref.invalidate(profileProvider);
      });
    }
    _showFloatingText('+1\u2600\uFE0F', const Color(0xFFFF9F43)); // +1☀️
  }

  void _showFloatingText(String text, Color color) {
    if (!mounted) return;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _FloatingText(
        text: text,
        color: color,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  void _handleEmptySlotTap(int shelfIndex, int slotIndex) {
    // 弹出品种选择
    _showPlantCatalogSheet(
      targetShelf: shelfIndex,
      targetSlot: slotIndex,
    );
  }

  void _handlePlantNew(PlantSpecies species) {
    final level = ref.read(playerLevelProvider);
    final sunshine = ref.read(sunshineProvider);
    final plants = ref.read(myPlantsProvider).valueOrNull ?? [];

    // 检查是否已种过
    final alreadyPlanted = plants.any((p) => p.plantKey == species.key);
    if (alreadyPlanted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('\u8FD9\u4E2A\u54C1\u79CD\u5DF2\u7ECF\u79CD\u8FC7\u4E86')),
      );
      return;
    }

    if (level < species.unlockLevel) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('\u9700\u8981\u7B49\u7EA7${species.unlockLevel}\u624D\u80FD\u89E3\u9501')),
      );
      return;
    }

    if (sunshine < species.plantCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('\u9633\u5149\u4E0D\u8DB3')),
      );
      return;
    }

    // 弹出选位Dialog
    _showSlotPickerDialog(species);
  }

  void _showSlotPickerDialog(PlantSpecies species) {
    final playerLevel = ref.read(playerLevelProvider);
    final plants = ref.read(myPlantsProvider).valueOrNull ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        title: Text('\u9009\u62E9\u79CD\u690D\u4F4D\u7F6E - ${species.name}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ShelfConfig.shelves
                .where((s) => playerLevel >= s.unlockLevel)
                .map((shelf) {
              return _SlotPickerRow(
                shelf: shelf,
                plants: plants,
                onSlotTap: (shelfIdx, slotIdx) {
                  Navigator.of(ctx).pop();
                  _doPlant(species, shelfIdx, slotIdx);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('\u53D6\u6D88'),
          ),
        ],
      ),
    );
  }

  void _showPlantCatalogSheet({
    required int targetShelf,
    required int targetSlot,
  }) {
    final playerLevel = ref.read(playerLevelProvider);
    final sunshine = ref.read(sunshineProvider);
    final plants = ref.read(myPlantsProvider).valueOrNull ?? [];

    // 找到可种植的品种（未种过 + 已解锁）
    final available = PlantCatalog.species.where((s) {
      final alreadyPlanted = plants.any((p) => p.plantKey == s.key);
      return !alreadyPlanted && playerLevel >= s.unlockLevel;
    }).toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('\u6CA1\u6709\u53EF\u79CD\u690D\u7684\u54C1\u79CD')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '\u9009\u62E9\u690D\u7269\u54C1\u79CD',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...available.map((species) {
              final canAfford = sunshine >= species.plantCost;
              return ListTile(
                leading: Text(species.emoji, style: const TextStyle(fontSize: 28)),
                title: Text(species.name),
                subtitle: Text(species.description),
                trailing: canAfford
                    ? FilledButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _doPlant(species, targetShelf, targetSlot);
                        },
                        child: species.plantCost > 0
                            ? Text('\u2600\uFE0F${species.plantCost}')
                            : const Text('\u514D\u8D39'),
                      )
                    : Text(
                        '\u2600\uFE0F${species.plantCost}',
                        style: const TextStyle(color: AppColors.textHint),
                      ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _doPlant(
      PlantSpecies species, int shelfIndex, int slotIndex) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final sunshine = ref.read(sunshineProvider);
    if (sunshine < species.plantCost) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('\u9633\u5149\u4E0D\u8DB3')),
        );
      }
      return;
    }

    try {
      final service = ref.read(supabaseServiceProvider);
      // 扣除阳光
      if (species.plantCost > 0) {
        await service.updateSunshine(userId, sunshine - species.plantCost);
      }
      // 创建植物
      await service.plantNew(userId, species.key, shelfIndex, slotIndex);
      // 刷新
      ref.invalidate(profileProvider);
      ref.invalidate(myPlantsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('\u79CD\u690D\u5931\u8D25: $e')),
        );
      }
    }
  }

  Future<void> _handleUpgrade(PlayerPlant plant) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final species = PlantCatalog.findByKey(plant.plantKey);
    if (species == null) return;

    if (plant.level >= 5) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('\u5DF2\u8FBE\u6700\u9AD8\u7B49\u7EA7')),
        );
      }
      return;
    }

    final cost = species.upgradeCosts[plant.level]; // cost to go from current to next
    final sunshine = ref.read(sunshineProvider);
    if (sunshine < cost) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('\u9633\u5149\u4E0D\u8DB3')),
        );
      }
      return;
    }

    try {
      final service = ref.read(supabaseServiceProvider);
      await service.updateSunshine(userId, sunshine - cost);
      await service.upgradePlant(plant.id, plant.level + 1);
      ref.invalidate(profileProvider);
      ref.invalidate(myPlantsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('\u5347\u7EA7\u5931\u8D25: $e')),
        );
      }
    }
  }
}

// ============================================================
// 顶栏
// ============================================================

class _TopBar extends StatelessWidget {
  final int sunshine;
  final int level;
  final double progress;

  const _TopBar({
    required this.sunshine,
    required this.level,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 设置图标
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: const Icon(Icons.settings, color: AppColors.textSecondary, size: 24),
          ),
          const Spacer(),
          // 阳光值
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('\u2600\uFE0F', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 4),
              Text(
                _formatNumber(sunshine),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const Spacer(),
          // 等级 + 进度条
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Lv.$level',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                width: 60,
                height: 6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.divider,
                    color: AppColors.primary,
                    minHeight: 6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}k';
    }
    return n.toString();
  }
}

// ============================================================
// 花园场景
// ============================================================

class _GardenScene extends StatelessWidget {
  final List<PlayerPlant> plants;
  final int level;
  final void Function(PlayerPlant) onPlantTap;
  final void Function(int shelfIndex, int slotIndex) onEmptySlotTap;

  const _GardenScene({
    required this.plants,
    required this.level,
    required this.onPlantTap,
    required this.onEmptySlotTap,
  });

  @override
  Widget build(BuildContext context) {
    // 架子从上到下排列: 高等级(index 3)在上, 初始(index 0)在下
    final shelvesReversed = ShelfConfig.shelves.reversed.toList();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFB3E5FC), // 天蓝
            Color(0xFF81D4FA), // 深天蓝
          ],
        ),
      ),
      child: Stack(
        children: [
          // 云朵装饰
          const Positioned(top: 20, left: 30, child: _Cloud(width: 80)),
          const Positioned(top: 50, right: 20, child: _Cloud(width: 60)),
          const Positioned(top: 100, left: 120, child: _Cloud(width: 50)),
          // 架子列表
          SingleChildScrollView(
            padding: const EdgeInsets.only(top: 20, bottom: 20),
            child: Column(
              children: [
                for (final shelf in shelvesReversed) ...[
                  const SizedBox(height: 16),
                  _ShelfWidget(
                    shelfIndex: shelf.index,
                    slots: shelf.slots,
                    plants: plants
                        .where((p) => p.shelfIndex == shelf.index)
                        .toList(),
                    isLocked: level < shelf.unlockLevel,
                    unlockLevel: shelf.unlockLevel,
                    onPlantTap: onPlantTap,
                    onEmptySlotTap: onEmptySlotTap,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 云朵
// ============================================================

class _Cloud extends StatelessWidget {
  final double width;

  const _Cloud({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * 0.4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(width * 0.2),
      ),
    );
  }
}

// ============================================================
// 架子 Widget
// ============================================================

class _ShelfWidget extends StatelessWidget {
  final int shelfIndex;
  final int slots;
  final List<PlayerPlant> plants;
  final bool isLocked;
  final int unlockLevel;
  final void Function(PlayerPlant) onPlantTap;
  final void Function(int, int) onEmptySlotTap;

  const _ShelfWidget({
    required this.shelfIndex,
    required this.slots,
    required this.plants,
    required this.isLocked,
    required this.unlockLevel,
    required this.onPlantTap,
    required this.onEmptySlotTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLocked) {
      return _buildLockedShelf();
    }
    return _buildUnlockedShelf();
  }

  Widget _buildLockedShelf() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: 110,
            decoration: BoxDecoration(
              color: const Color(0xFF90CAF9).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
          ),
          // 木质架子横板
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _WoodPlank(),
          ),
          // 锁定遮罩
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF64B5F6).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '\uD83D\uDD12', // 🔒
                    style: TextStyle(fontSize: 28),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\u7B49\u7EA7$unlockLevel\u89E3\u9501', // 等级X解锁
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnlockedShelf() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 植物行
          SizedBox(
            height: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < slots; i++)
                  _buildSlot(i),
              ],
            ),
          ),
          // 木质架子横板
          _WoodPlank(),
        ],
      ),
    );
  }

  Widget _buildSlot(int slotIndex) {
    final plant = plants.where((p) => p.slotIndex == slotIndex).firstOrNull;
    if (plant != null) {
      return _PlantSlot(plant: plant, onTap: () => onPlantTap(plant));
    }
    return _EmptySlot(onTap: () => onEmptySlotTap(shelfIndex, slotIndex));
  }
}

// ============================================================
// 木质架子横板
// ============================================================

class _WoodPlank extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 0),
      decoration: const BoxDecoration(
        color: Color(0xFF8D6E63),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF6D4C41),
            offset: Offset(0, 2),
            blurRadius: 0,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 植物位
// ============================================================

class _PlantSlot extends StatefulWidget {
  final PlayerPlant plant;
  final VoidCallback onTap;

  const _PlantSlot({required this.plant, required this.onTap});

  @override
  State<_PlantSlot> createState() => _PlantSlotState();
}

class _PlantSlotState extends State<_PlantSlot>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.12),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.12, end: 1.0),
        weight: 60,
      ),
    ]).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.easeOutBack,
    ));
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final species = PlantCatalog.findByKey(widget.plant.plantKey);

    return GestureDetector(
      onTap: () {
        widget.onTap();
        _bounceController.forward(from: 0);
      },
      child: AnimatedBuilder(
        animation: _bounceAnimation,
        builder: (ctx, child) {
          return Transform.scale(
            scale: _bounceAnimation.value,
            child: child,
          );
        },
        child: SizedBox(
          width: 80,
          height: 90,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 植物图片
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: species != null
                    ? Image.asset(
                        species.stageImagePath(widget.plant.level),
                        width: 70,
                        height: 70,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            _PlaceholderPlant(
                              level: widget.plant.level,
                              emoji: species.emoji,
                            ),
                      )
                    : _PlaceholderPlant(
                        level: widget.plant.level,
                        emoji: '\uD83C\uDF31',
                      ),
              ),
              const SizedBox(height: 2),
              // 等级文字
              Text(
                'Lv.${widget.plant.level}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Placeholder 植物（没有图片时）
// ============================================================

class _PlaceholderPlant extends StatelessWidget {
  final int level;
  final String emoji;

  const _PlaceholderPlant({required this.level, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFF81C784).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 2),
          Text(
            'Lv.$level',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 空位
// ============================================================

class _EmptySlot extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptySlot({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.arrow_downward, color: Colors.white60, size: 20),
            SizedBox(height: 4),
            Icon(Icons.local_florist_outlined, color: Colors.white60, size: 16),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 飘动文字（+1☀️）
// ============================================================

class _FloatingText extends StatefulWidget {
  final String text;
  final Color color;
  final VoidCallback onDone;

  const _FloatingText({
    required this.text,
    required this.color,
    required this.onDone,
  });

  @override
  State<_FloatingText> createState() => _FloatingTextState();
}

class _FloatingTextState extends State<_FloatingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnim;
  late Animation<double> _offsetAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _opacityAnim = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _offsetAnim = Tween(begin: 0.0, end: -60.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned(
      left: size.width / 2 - 30,
      top: size.height / 2,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (ctx, child) {
          return Transform.translate(
            offset: Offset(0, _offsetAnim.value),
            child: Opacity(
              opacity: _opacityAnim.value,
              child: child,
            ),
          );
        },
        child: Text(
          widget.text,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: widget.color,
            shadows: const [
              Shadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(1, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 位置选择行（种植时用）
// ============================================================

class _SlotPickerRow extends StatelessWidget {
  final ShelfLevel shelf;
  final List<PlayerPlant> plants;
  final void Function(int shelfIndex, int slotIndex) onSlotTap;

  const _SlotPickerRow({
    required this.shelf,
    required this.plants,
    required this.onSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Text(
            '\u7B2C${shelf.index + 1}\u5C42\u67B6\u5B50', // 第N层架子
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Row(
          children: [
            for (int i = 0; i < shelf.slots; i++)
              Builder(builder: (ctx) {
                final occupied = plants.any(
                    (p) => p.shelfIndex == shelf.index && p.slotIndex == i);
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: GestureDetector(
                    onTap: occupied
                        ? null
                        : () => onSlotTap(shelf.index, i),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: occupied
                            ? AppColors.divider
                            : const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: occupied
                              ? AppColors.textHint
                              : AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: occupied
                            ? const Icon(Icons.local_florist,
                                color: AppColors.textHint, size: 20)
                            : const Icon(Icons.add,
                                color: AppColors.primary, size: 20),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

// ============================================================
// 底部面板
// ============================================================

class _BottomPanel extends StatelessWidget {
  final int sunshine;
  final int level;
  final List<PlayerPlant> plants;
  final void Function(PlantSpecies) onPlant;
  final Future<void> Function(PlayerPlant) onUpgrade;

  const _BottomPanel({
    required this.sunshine,
    required this.level,
    required this.plants,
    required this.onPlant,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.large),
        ),
      ),
      child: Column(
        children: [
          // Tab头
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: const Row(
              children: [
                Text(
                  '\uD83C\uDF31 \u690D\u7269\u56FE\u9274', // 🌱 植物图鉴
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                Spacer(),
                Text(
                  '\uD83C\uDF08 \u4E3B\u9898(\u9884\u7559)', // 🌈 主题(预留)
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 植物列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              itemCount: PlantCatalog.species.length,
              itemBuilder: (ctx, index) {
                final species = PlantCatalog.species[index];
                return _PlantCatalogRow(
                  species: species,
                  playerLevel: level,
                  sunshine: sunshine,
                  existingPlant: plants
                      .where((p) => p.plantKey == species.key)
                      .firstOrNull,
                  onPlant: () => onPlant(species),
                  onUpgrade: onUpgrade,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 植物图鉴行
// ============================================================

class _PlantCatalogRow extends StatelessWidget {
  final PlantSpecies species;
  final int playerLevel;
  final int sunshine;
  final PlayerPlant? existingPlant;
  final VoidCallback onPlant;
  final Future<void> Function(PlayerPlant) onUpgrade;

  const _PlantCatalogRow({
    required this.species,
    required this.playerLevel,
    required this.sunshine,
    required this.existingPlant,
    required this.onPlant,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final isUnlocked = playerLevel >= species.unlockLevel;

    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
      child: Row(
        children: [
          // 缩略图
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 50,
              height: 50,
              child: _buildThumbnail(),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // 名称+状态
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  species.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isUnlocked
                        ? AppColors.textDark
                        : AppColors.textHint,
                  ),
                ),
                Text(
                  _statusText(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // 操作按钮
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    if (species.key == 'violet') {
      final level = existingPlant?.level ?? 1;
      return Image.asset(
        species.stageImagePath(level),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _emojiThumbnail(),
      );
    }
    return _emojiThumbnail();
  }

  Widget _emojiThumbnail() {
    return Container(
      color: const Color(0xFFE8F5E9),
      child: Center(
        child: Text(species.emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }

  String _statusText() {
    if (existingPlant != null) {
      return 'Level ${existingPlant!.level}  \u2600\uFE0F${species.productionPerSec}/s';
    }
    if (playerLevel >= species.unlockLevel) {
      return '\u79CD\u5B50'; // 种子
    }
    return '\u672A\u89E3\u9501'; // 未解锁
  }

  Widget _buildActionButton() {
    if (existingPlant != null) {
      // 已种植
      if (existingPlant!.level >= 5) {
        return _grayButton('\u6EE1\u7EA7'); // 满级
      }
      final cost = species.upgradeCosts[existingPlant!.level];
      final canAfford = sunshine >= cost;
      return _actionButton(
        label: '\u5347\u7EA7', // 升级
        cost: cost,
        color: canAfford ? AppColors.success : AppColors.divider,
        textColor: canAfford ? Colors.white : AppColors.textHint,
        onTap: canAfford ? () => onUpgrade(existingPlant!) : null,
      );
    }

    if (playerLevel < species.unlockLevel) {
      return _grayButton('Lv.${species.unlockLevel} \uD83D\uDD12');
    }

    final canAfford = sunshine >= species.plantCost;
    return _actionButton(
      label: '\u79CD\u690D', // 种植
      cost: species.plantCost,
      color: canAfford ? AppColors.primary : AppColors.divider,
      textColor: canAfford ? Colors.white : AppColors.textHint,
      onTap: canAfford ? onPlant : null,
    );
  }

  Widget _grayButton(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textHint,
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required int cost,
    required Color color,
    required Color textColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            if (cost > 0)
              Text(
                '\u2600\uFE0F$cost',
                style: TextStyle(fontSize: 10, color: textColor),
              ),
          ],
        ),
      ),
    );
  }
}
