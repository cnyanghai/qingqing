import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/emotion.dart';
import '../../models/badge.dart' as app_badge;
import '../../models/garden.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/checkin_provider.dart';
import '../../widgets/mood_grid.dart';
import '../../widgets/emotion_chip.dart';
import '../../widgets/context_card.dart';
import '../../widgets/streak_badge.dart';

/// S5 Check-in flow: 4 steps via PageView
/// Step 1: Select quadrant (S5)
/// Step 2: Select specific emotion (S5b)
/// Step 3: Select context + optional note (S5c)
/// Step 4: Success page (S5d)
class CheckinFlowScreen extends ConsumerStatefulWidget {
  const CheckinFlowScreen({super.key});

  @override
  ConsumerState<CheckinFlowScreen> createState() => _CheckinFlowScreenState();
}

class _CheckinFlowScreenState extends ConsumerState<CheckinFlowScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Step 1 state
  String? _selectedQuadrant;

  // Step 2 state
  final Set<String> _selectedEmotions = {};

  // Step 3 state
  String? _selectedContext;
  final _noteController = TextEditingController();

  // Step 4 state (results)
  int _resultStreak = 0;
  List<String> _resultNewBadges = [];
  int _resultTotalFlowers = 0;
  List<String> _resultNewDecorations = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pageController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/home');
    }
  }

  Future<void> _submitCheckin() async {
    if (_selectedQuadrant == null ||
        _selectedEmotions.isEmpty ||
        _selectedContext == null) return;

    setState(() => _isSubmitting = true);

    try {
      final userId = ref.read(currentUserIdProvider);
      final profile = await ref.read(profileProvider.future);
      if (userId == null || profile == null) {
        throw Exception('用户未登录');
      }

      final actions = ref.read(checkinActionsProvider);
      final result = await actions.submitCheckin(
        studentId: userId,
        classroomId: profile.classroomId ?? '',
        quadrant: _selectedQuadrant!,
        emotionLabel: _selectedEmotions.join(','),
        contextTag: _selectedContext!,
        note: _noteController.text.isNotEmpty
            ? _noteController.text.trim()
            : null,
      );

      setState(() {
        _resultStreak = result.streak;
        _resultNewBadges = result.newBadges;
        _resultTotalFlowers = result.totalFlowers;
        _resultNewDecorations = result.newDecorations;
        _isSubmitting = false;
      });

      _nextPage(); // Go to success page
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('记录失败，请稍后重试')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildStep1(),
            _buildStep2(),
            _buildStep3(),
            _buildStep4(),
          ],
        ),
      ),
    );
  }

  // ============ Step 1: Select Quadrant ============
  Widget _buildStep1() {
    final profileAsync = ref.watch(profileProvider);
    final nickname = profileAsync.valueOrNull?.nickname ?? '';

    return Column(
      children: [
        // App bar
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.go('/home'),
              ),
              const Expanded(
                child: Text(
                  '记录心情',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 48), // Balance the close button
            ],
          ),
        ),
        // Progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '1/3',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Text(
                    '进行中',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 1 / 3,
                  backgroundColor: AppColors.divider,
                  color: AppColors.moodGreen,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '嗨，$nickname',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  '你现在感觉怎么样？',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                // 2x2 mood grid
                MoodGrid(
                  selectedQuadrant: _selectedQuadrant,
                  onSelect: (key) {
                    setState(() {
                      _selectedQuadrant = key;
                      _selectedEmotions.clear(); // Reset emotions on quadrant change
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        // Bottom: continue button
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _selectedQuadrant != null ? _nextPage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha:0.5),
              ),
              child: const Text('继续'),
            ),
          ),
        ),
      ],
    );
  }

  // ============ Step 2: Select Specific Emotion ============
  Widget _buildStep2() {
    final quadrant = EmotionData.findQuadrant(_selectedQuadrant ?? '');
    final emotions = quadrant?.emotions ?? [];

    return Column(
      children: [
        // App bar
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _previousPage,
              ),
              const Expanded(
                child: Text(
                  '更具体一点？',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        // Progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '2/3',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Text(
                    '进行中',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 2 / 3,
                  backgroundColor: AppColors.divider,
                  color: AppColors.moodGreen,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.md),
                const Text(
                  '你现在感觉如何？',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  '选择最贴切的一个或多个词汇',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Emotion chips grid (2 columns)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: emotions.length,
                  itemBuilder: (context, index) {
                    final emotion = emotions[index];
                    return EmotionChip(
                      emotion: emotion,
                      quadrantKey: _selectedQuadrant!,
                      isSelected: _selectedEmotions.contains(emotion.label),
                      onTap: () {
                        setState(() {
                          if (_selectedEmotions.contains(emotion.label)) {
                            _selectedEmotions.remove(emotion.label);
                          } else {
                            _selectedEmotions.add(emotion.label);
                          }
                        });
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        // Bottom button
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _selectedEmotions.isNotEmpty ? _nextPage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha:0.5),
              ),
              child: const Text('下一步'),
            ),
          ),
        ),
      ],
    );
  }

  // ============ Step 3: Select Context + Note ============
  Widget _buildStep3() {
    final contextOptions = EmotionData.contextOptions;

    return Column(
      children: [
        // App bar
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _previousPage,
              ),
              const Expanded(
                child: Text(
                  '心情记录',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        // Progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '3/3',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Text(
                    '进行中',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 1.0,
                  backgroundColor: AppColors.divider,
                  color: AppColors.moodGreen,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.md),
                const Center(
                  child: Text(
                    '这个心情是在哪里的？',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Center(
                  child: Text(
                    '选择一个最符合当下的场景',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Context cards: 2-2-1 layout
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    childAspectRatio: 1.3,
                  ),
                  itemCount: contextOptions.length,
                  itemBuilder: (context, index) {
                    final option = contextOptions[index];
                    return ContextCard(
                      option: option,
                      isSelected: _selectedContext == option.key,
                      onTap: () {
                        setState(
                            () => _selectedContext = option.key);
                      },
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                // Note input
                const Text(
                  '想说点什么吗？',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _noteController,
                  maxLength: 50,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: '写下此刻的想法...',
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                // Character count
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_noteController.text.length}/50',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Bottom button
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed:
                  _selectedContext != null && !_isSubmitting
                      ? _submitCheckin
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                disabledBackgroundColor:
                    AppColors.accent.withValues(alpha:0.5),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: AppColors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('完成'),
                        SizedBox(width: 4),
                        Icon(Icons.check, size: 20),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // ============ Step 4: Success ============
  Widget _buildStep4() {
    final flowerConfig = GardenConfig.getFlower(_selectedQuadrant ?? '');
    final flowerEmoji = flowerConfig?.emoji ?? '\u{1F33B}';
    final flowerName = flowerConfig?.name ?? '花';
    final emotionEmojis = _selectedEmotions
        .map((l) => EmotionData.findEmotionByLabel(l)?.emoji ?? '')
        .where((e) => e.isNotEmpty)
        .join('');
    final emotionText = _selectedEmotions.join('\u3001');

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE3ECF5), // light blue
            AppColors.background,
          ],
        ),
      ),
      child: Column(
        children: [
          // App bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => context.go('/home'),
                ),
                const Expanded(
                  child: Text(
                    '记录成功',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          const Spacer(flex: 1),
          // Flower planting animation
          _FlowerPlantAnimation(
            flowerEmoji: flowerEmoji,
            quadrantColor: flowerConfig?.color ?? AppColors.moodGreen,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '你种下了一朵$flowerName! $flowerEmoji',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          if (emotionText.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$emotionEmojis $emotionText',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            '你的花园里现在有$_resultTotalFlowers朵花了',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Streak badge
          StreakBadge(streak: _resultStreak, large: true),
          const SizedBox(height: AppSpacing.md),
          // New badges
          if (_resultNewBadges.isNotEmpty)
            ..._resultNewBadges.map((badgeKey) {
              final info = app_badge.Badge.allBadges[badgeKey];
              if (info == null) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius:
                      BorderRadius.circular(AppRadius.large),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF0F4F8),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          '\u{1F3C6}',
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            '新徽章: ${info.name}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            info.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          // New decorations
          if (_resultNewDecorations.isNotEmpty)
            _NewDecorationsBanner(
              decorationKeys: _resultNewDecorations,
            ),
          const Spacer(flex: 2),
          // Return home button
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => context.go('/home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('返回首页'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 种花动画: 种子 → 花朵，带光晕扩散
class _FlowerPlantAnimation extends StatefulWidget {
  final String flowerEmoji;
  final Color quadrantColor;

  const _FlowerPlantAnimation({
    required this.flowerEmoji,
    required this.quadrantColor,
  });

  @override
  State<_FlowerPlantAnimation> createState() =>
      _FlowerPlantAnimationState();
}

class _FlowerPlantAnimationState extends State<_FlowerPlantAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _showFlower = false;
  double _haloSize = 0;
  double _haloOpacity = 0.4;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    // Start animation sequence
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _showFlower = true);
        _controller.forward();
        // Start halo expansion
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            setState(() {
              _haloSize = 120;
              _haloOpacity = 0;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo effect
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            width: _haloSize,
            height: _haloSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.quadrantColor.withValues(alpha: _haloOpacity),
            ),
          ),
          // Seed → Flower transition
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: _showFlower
                ? ScaleTransition(
                    key: const ValueKey('flower'),
                    scale: _scaleAnimation,
                    child: Text(
                      widget.flowerEmoji,
                      style: const TextStyle(fontSize: 72),
                    ),
                  )
                : const Text(
                    '\u{1F331}', // seed emoji
                    key: ValueKey('seed'),
                    style: TextStyle(fontSize: 56),
                  ),
          ),
        ],
      ),
    );
  }
}

/// 新装饰解锁提示（带滑入动画）
class _NewDecorationsBanner extends StatefulWidget {
  final List<String> decorationKeys;

  const _NewDecorationsBanner({required this.decorationKeys});

  @override
  State<_NewDecorationsBanner> createState() =>
      _NewDecorationsBannerState();
}

class _NewDecorationsBannerState extends State<_NewDecorationsBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    // Delay 0.5s after flower animation
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Column(
        children: widget.decorationKeys.map((key) {
          final decoration = GardenDecorations.findByKey(key);
          if (decoration == null) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.moodYellowBg,
              borderRadius: BorderRadius.circular(AppRadius.large),
              border: Border.all(
                color: AppColors.moodYellow,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '\u{1F389}', // party emoji
                  style: TextStyle(fontSize: 20),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '获得新装饰: ${decoration.emoji} ${decoration.name}!',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
