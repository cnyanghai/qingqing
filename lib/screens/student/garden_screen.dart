import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../config/theme.dart';
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
import '../../widgets/learning_label.dart';
import '../../widgets/plant_pot.dart';
import '../../widgets/plant_widget.dart';
import '../../widgets/sunshine_particle.dart';

/// Garden state Provider (unchanged)
final gardenStateProvider = FutureProvider<GardenState>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return GardenState.empty;

  final profile = await ref.watch(profileProvider.future);
  if (profile == null) return GardenState.empty;

  final service = ref.watch(supabaseServiceProvider);

  try {
    final notesCount = await service.countCheckinNotes(userId);
    final distinctQuadrants = await service.getDistinctQuadrants(userId);

    final semesterCheckins =
        await ref.watch(semesterCheckinsProvider.future);

    final distinctContexts =
        semesterCheckins.map((c) => c.contextTag).toSet().length;

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

// ============================================================
// Main Garden Screen with Garden + Bookshelf tabs
// ============================================================

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
    final profile = ref.watch(profileProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: gardenAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('\u52A0\u8F7D\u82B1\u56ED\u5931\u8D25')),
          data: (garden) {
            // Build unified plant list
            final plants = _buildPlantList(garden, allEntries);
            final sunshine = GardenService.calculateSunshine(
              totalCheckins: profile?.totalCheckins ?? 0,
              currentStreak: profile?.streak ?? 0,
              totalLearningEntries: allEntries.length,
              totalWaterReceived: totalWaterCount,
            );
            final gardenLevelName =
                GardenService.gardenLevelName(sunshine);

            return Column(
              children: [
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
                      Tab(text: '\u{1F338} \u82B1\u56ED'),
                      Tab(text: '\u{1F4DA} \u4E66\u67B6'),
                    ],
                  ),
                ),
                // TabBarView fills remaining space
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Garden Tab: full terrarium scene
                      _GardenTabContent(
                        garden: garden,
                        plants: plants,
                        sunshine: sunshine,
                        gardenLevelName: gardenLevelName,
                        totalWaterCount: totalWaterCount,
                        allEntries: allEntries,
                        messages: myMessages,
                        classmates: classmates,
                        userId: userId,
                        onDeleteMessage: _deleteMyMessage,
                      ),
                      // Bookshelf Tab (unchanged)
                      _BookshelfTabContent(entries: allEntries),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Build the unified plant list from emotion checkins + learning entries.
  List<PlantData> _buildPlantList(
      GardenState garden, List<LearningEntry> entries) {
    final plants = <PlantData>[];

    // Emotion plants: one per quadrant that has checkins
    for (final entry in garden.quadrantCounts.entries) {
      final quadrant = entry.key;
      final count = entry.value;
      if (count <= 0) continue;

      // Use the quadrant's Chinese name as the label
      final quadrantNames = {
        'red': '\u6709\u70B9\u70E6',
        'yellow': '\u5F88\u5F00\u5FC3',
        'green': '\u5F88\u5E73\u9759',
        'blue': '\u4E0D\u592A\u597D',
      };

      plants.add(PlantData(
        type: 'emotion',
        quadrant: quadrant,
        emotionLabel: quadrantNames[quadrant],
        growthCount: count,
      ));

      // If many checkins in one quadrant, add extra flowers
      if (count >= 8) {
        plants.add(PlantData(
          type: 'emotion',
          quadrant: quadrant,
          emotionLabel: quadrantNames[quadrant],
          growthCount: (count / 2).floor(),
        ));
      }
    }

    // Learning plants: one per in-progress or completed entry
    for (final entry in entries) {
      // Growth count based on progress for learning entries
      final growthCount = _learningGrowthCount(entry.progress);
      plants.add(PlantData(
        type: 'learning',
        category: entry.category,
        title: entry.title,
        growthCount: growthCount,
        progress: entry.progress,
        isCompleted: entry.status == 'completed',
      ));
    }

    return plants;
  }

  /// Map learning progress (0-100) to growth count thresholds.
  int _learningGrowthCount(int progress) {
    if (progress >= 90) return 30; // fruit
    if (progress >= 60) return 14; // bloom
    if (progress >= 40) return 7; // bud
    if (progress >= 20) return 3; // sprout
    return 1; // seed
  }

  Future<void> _deleteMyMessage(String messageId) async {
    try {
      final service = ref.read(supabaseServiceProvider);
      await service.deleteMessage(messageId);
      ref.invalidate(myMessagesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('\u5220\u9664\u7559\u8A00\u5931\u8D25: $e')),
        );
      }
    }
  }
}

// ============================================================
// Garden Tab: Full Terrarium Scene
// ============================================================

class _GardenTabContent extends StatefulWidget {
  final GardenState garden;
  final List<PlantData> plants;
  final int sunshine;
  final String gardenLevelName;
  final int totalWaterCount;
  final List<LearningEntry> allEntries;
  final List<StudentMessage> messages;
  final List<Profile> classmates;
  final String? userId;
  final Future<void> Function(String) onDeleteMessage;

  const _GardenTabContent({
    required this.garden,
    required this.plants,
    required this.sunshine,
    required this.gardenLevelName,
    required this.totalWaterCount,
    required this.allEntries,
    required this.messages,
    required this.classmates,
    required this.userId,
    required this.onDeleteMessage,
  });

  @override
  State<_GardenTabContent> createState() => _GardenTabContentState();
}

class _GardenTabContentState extends State<_GardenTabContent> {
  // Track which plant was tapped for bounce animation
  int? _tappedPlantIndex;
  OverlayEntry? _infoBubble;

  @override
  void dispose() {
    _infoBubble?.remove();
    super.dispose();
  }

  /// Number of shelves based on total checkins.
  int get _shelfCount {
    final total = widget.garden.totalFlowers;
    if (total >= 50) return 3;
    if (total >= 20) return 2;
    return 1;
  }

  /// Slots per shelf.
  int get _slotsPerShelf => 4;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Garden scene (scrollable, fills most space)
        Expanded(
          child: SingleChildScrollView(
            child: _buildGardenScene(context),
          ),
        ),
        // Bottom sunshine info bar
        _buildSunshineBar(context),
      ],
    );
  }

  Widget _buildGardenScene(BuildContext context) {
    final shelves = _shelfCount;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.55, 0.56, 1.0],
          colors: [
            Color(0xFFE8F4FD), // light blue sky top
            Color(0xFFF0F8FF), // lighter sky bottom
            Color(0xFFFAF8F5), // beige wall top
            Color(0xFFF5F0E8), // warmer beige wall bottom
          ],
        ),
      ),
      child: Column(
        children: [
          // Title bar
          _buildTitleBar(context),
          const SizedBox(height: 8),
          // Shelves (top to bottom: shelf 3 if exists, shelf 2 if exists, shelf 1)
          for (int shelfIdx = shelves - 1; shelfIdx >= 0; shelfIdx--)
            _buildShelf(context, shelfIdx),
          // Wisdom tree area (bottom grass)
          _buildWisdomTreeArea(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTitleBar(BuildContext context) {
    final messageCount = widget.messages.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          // Garden level name
          Text(
            widget.gardenLevelName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const Spacer(),
          // Water count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(AppRadius.round),
            ),
            child: Text(
              '\u{1F4A7} ${widget.totalWaterCount}',
              style: const TextStyle(fontSize: 12, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 8),
          // Message icon + badge
          GestureDetector(
            onTap: () => _showMessageSheet(context),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.mail_outline, size: 20, color: AppColors.primary),
                  if (messageCount > 0)
                    Positioned(
                      top: -5,
                      right: -5,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                        child: Text(
                          messageCount > 99 ? '99+' : '$messageCount',
                          style: const TextStyle(
                            fontSize: 8,
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
          ),
        ],
      ),
    );
  }

  Widget _buildShelf(BuildContext context, int shelfIndex) {
    // Calculate which plants go on this shelf
    final startIdx = shelfIndex * _slotsPerShelf;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Plant area on the shelf
        SizedBox(
          height: 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(_slotsPerShelf, (slotIdx) {
              final plantIdx = startIdx + slotIdx;
              if (plantIdx < widget.plants.length) {
                return _buildPlantSlot(context, plantIdx);
              }
              return PlantPot(
                child: null,
                onEmptyTap: () {
                  // Could navigate to checkin or add learning
                },
              );
            }),
          ),
        ),
        // Wooden shelf board
        _buildShelfBoard(),
      ],
    );
  }

  Widget _buildPlantSlot(BuildContext context, int plantIdx) {
    final plant = widget.plants[plantIdx];
    final stage = stageFromCount(plant.growthCount);
    final isTapped = _tappedPlantIndex == plantIdx;

    // Build the plant widget
    Widget plantWidget;
    if (plant.type == 'emotion') {
      final colors = EmotionPlantColors.forQuadrant(plant.quadrant ?? 'green');
      plantWidget = PlantWidget(
        config: PlantConfig(
          type: PlantType.emotion,
          stage: stage,
          primaryColor: colors[0],
          secondaryColor: colors[1],
        ),
      );
    } else {
      final colors = LearningPlantColors.forCategory(plant.category);
      plantWidget = PlantWidget(
        config: PlantConfig(
          type: PlantType.learning,
          stage: stage,
          primaryColor: colors[0],
          secondaryColor: colors[1],
          learningCategory: plant.category,
        ),
      );
    }

    // Wrap with particles for bud+ stages
    Widget plantWithParticles;
    if (stage == PlantStage.bloom || stage == PlantStage.fruit) {
      plantWithParticles = Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: plantWidget,
          ),
          Positioned(
            top: 0,
            child: SunshineParticleEmitter(
              intervalSeconds: stage == PlantStage.fruit ? 2.0 : 3.0,
              emitWidth: 16,
            ),
          ),
        ],
      );
    } else if (stage == PlantStage.bud) {
      plantWithParticles = Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: plantWidget,
          ),
          Positioned(
            top: 0,
            child: SunshineParticleEmitter(
              intervalSeconds: 6.0,
              emitWidth: 12,
            ),
          ),
        ],
      );
    } else {
      plantWithParticles = plantWidget;
    }

    return GestureDetector(
      onTap: () => _onPlantTap(context, plantIdx, plant),
      child: AnimatedScale(
        scale: isTapped ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.elasticOut,
        child: PlantPot(
          child: plantWithParticles,
        ),
      ),
    );
  }

  void _onPlantTap(BuildContext context, int plantIdx, PlantData plant) {
    setState(() => _tappedPlantIndex = plantIdx);

    // Reset bounce after animation completes
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() {
          if (_tappedPlantIndex == plantIdx) {
            _tappedPlantIndex = null;
          }
        });
      }
    });

    // Show info bubble
    _showInfoBubble(context, plant);
  }

  void _showInfoBubble(BuildContext context, PlantData plant) {
    // Remove existing bubble
    _infoBubble?.remove();
    _infoBubble = null;

    final stage = stageFromCount(plant.growthCount);
    final stageNames = {
      PlantStage.seed: '\u79CD\u5B50',
      PlantStage.sprout: '\u53D1\u82BD',
      PlantStage.bud: '\u82B1\u82DE',
      PlantStage.bloom: '\u76DB\u5F00',
      PlantStage.fruit: '\u7ED3\u679C',
    };

    String line1;
    String line2;

    if (plant.type == 'emotion') {
      final quadrantEmojis = {
        'red': '\u{1F624}',
        'yellow': '\u{1F604}',
        'green': '\u{1F60C}',
        'blue': '\u{1F622}',
      };
      line1 =
          '${quadrantEmojis[plant.quadrant] ?? ''} ${plant.emotionLabel ?? ''}';
      line2 =
          '\u7B2C${plant.growthCount}\u6B21 \u00B7 ${stageNames[stage] ?? ''}';
    } else {
      line1 = '\u{1F4D6} ${plant.title ?? ''}';
      line2 = '\u8FDB\u5EA6 ${plant.progress}%';
    }

    final overlay = Overlay.of(context);
    _infoBubble = OverlayEntry(
      builder: (ctx) => _InfoBubbleOverlay(
        line1: line1,
        line2: line2,
        onDismiss: () {
          _infoBubble?.remove();
          _infoBubble = null;
        },
      ),
    );
    overlay.insert(_infoBubble!);

    // Auto-dismiss after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      _infoBubble?.remove();
      _infoBubble = null;
    });
  }

  /// Wooden shelf board with shadow.
  Widget _buildShelfBoard() {
    return Container(
      width: double.infinity,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFD4A574), // warm wood color
        borderRadius: BorderRadius.circular(2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30000000),
            blurRadius: 4,
            offset: Offset(0, 3),
          ),
        ],
      ),
    );
  }

  /// Wisdom tree at the bottom (Lottie + grass).
  Widget _buildWisdomTreeArea() {
    // Collect learning labels for the tree canopy
    final displayEntries = widget.allEntries.take(8).toList();

    return Container(
      width: double.infinity,
      height: 180,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF5F0E8), // match wall
            Color(0xFFD5E8C0), // grass transition
            Color(0xFF8BC34A), // grass green
          ],
          stops: [0.0, 0.7, 1.0],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Lottie wisdom tree
          Positioned(
            bottom: 0,
            child: SizedBox(
              height: 160,
              width: 200,
              child: Lottie.asset(
                'assets/animations/virtues_tree.json',
                fit: BoxFit.contain,
                repeat: true,
              ),
            ),
          ),
          // Learning labels float in the tree canopy
          ..._buildTreeLabels(displayEntries),
        ],
      ),
    );
  }

  List<Widget> _buildTreeLabels(List<LearningEntry> entries) {
    if (entries.isEmpty) return [];

    final labels = <Widget>[];
    final screenWidth = MediaQuery.of(context).size.width;

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final isCompleted = entry.status == 'completed';

      final xRatio = 0.1 + (i * 0.618033988 % 0.8);
      final yRatio = 0.05 + (i * 0.381966 % 0.4);

      labels.add(Positioned(
        left: xRatio * screenWidth * 0.8,
        top: yRatio * 100,
        child: LearningLabel(
          title: entry.title,
          category: entry.category,
          isCompleted: isCompleted,
        ),
      ));
    }
    return labels;
  }

  /// Bottom info bar with sunshine value + plant stats.
  Widget _buildSunshineBar(BuildContext context) {
    // Count plants by stage
    int seedCount = 0, sproutCount = 0, budCount = 0, bloomCount = 0,
        fruitCount = 0;
    for (final p in widget.plants) {
      final stage = stageFromCount(p.growthCount);
      switch (stage) {
        case PlantStage.seed:
          seedCount++;
        case PlantStage.sprout:
          sproutCount++;
        case PlantStage.bud:
          budCount++;
        case PlantStage.bloom:
          bloomCount++;
        case PlantStage.fruit:
          fruitCount++;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Sunshine value
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('\u{2600}\u{FE0F}',
                  style: TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Text(
                '${widget.sunshine}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF8F00),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 18, color: AppColors.divider),
          const SizedBox(width: 12),
          // Plant stats
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (seedCount > 0)
                    _statChip('\u{1F331}', seedCount),
                  if (sproutCount > 0)
                    _statChip('\u{1F33F}', sproutCount),
                  if (budCount > 0)
                    _statChip('\u{1F33E}', budCount),
                  if (bloomCount > 0)
                    _statChip('\u{1F338}', bloomCount),
                  if (fruitCount > 0)
                    _statChip('\u{1F34E}', fruitCount),
                  if (widget.plants.isEmpty)
                    const Text(
                      '\u8FD8\u6CA1\u6709\u690D\u7269',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
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

  Widget _statChip(String emoji, int count) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(
        '$emoji\u00D7$count',
        style: const TextStyle(fontSize: 13, color: AppColors.textDark),
      ),
    );
  }

  // ============================================================
  // Message Sheet (preserved from original)
  // ============================================================

  void _showMessageSheet(BuildContext context) {
    final messages = widget.messages;
    final classmates = widget.classmates;
    final userId = widget.userId;

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
                      '\u{1F4DD} \u7559\u8A00 \u00B7 ${messages.length}\u6761',
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
                          '\u8FD8\u6CA1\u6709\u6536\u5230\u7559\u8A00',
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
                          final authorName = author?.nickname ?? '\u540C\u5B66';
                          final authorAvatarKey = author?.avatarKey ?? 'cat';
                          final timeStr = _formatMessageTime(msg.createdAt);
                          final canDelete = userId != null &&
                              msg.targetStudentId == userId;

                          return Container(
                            margin:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.medium),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textDark,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            timeStr,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textHint,
                                            ),
                                          ),
                                          if (canDelete)
                                            GestureDetector(
                                              onTap: () async {
                                                Navigator.of(ctx).pop();
                                                await widget
                                                    .onDeleteMessage(msg.id);
                                              },
                                              child: const Padding(
                                                padding:
                                                    EdgeInsets.only(left: 4),
                                                child: Icon(
                                                  Icons.close,
                                                  size: 16,
                                                  color: AppColors.textHint,
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

  String _formatMessageTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return '\u521A\u521A';
    if (diff.inMinutes < 60) return '${diff.inMinutes}\u5206\u949F\u524D';
    if (diff.inHours < 24) return '${diff.inHours}\u5C0F\u65F6\u524D';
    if (diff.inDays < 7) return '${diff.inDays}\u5929\u524D';

    return '${dateTime.month}/${dateTime.day}';
  }
}

// ============================================================
// Info Bubble Overlay (shows on plant tap)
// ============================================================

class _InfoBubbleOverlay extends StatefulWidget {
  final String line1;
  final String line2;
  final VoidCallback onDismiss;

  const _InfoBubbleOverlay({
    required this.line1,
    required this.line2,
    required this.onDismiss,
  });

  @override
  State<_InfoBubbleOverlay> createState() => _InfoBubbleOverlayState();
}

class _InfoBubbleOverlayState extends State<_InfoBubbleOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    // Start fade out before dismiss
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) {
        _fadeController.reverse().then((_) {
          widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.3,
      left: 0,
      right: 0,
      child: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppRadius.medium),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.line1,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.line2,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Bookshelf Tab (preserved from original, unchanged)
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

    final classLearningAsync = ref.watch(classmateLearningProvider);
    final classLearning = classLearningAsync.valueOrNull;
    final classmatesAsync = ref.watch(classmatesProvider);
    final classmates = classmatesAsync.valueOrNull ?? [];
    final currentUserId = ref.watch(currentUserIdProvider) ?? '';

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _buildSectionHeader(
              '\u{1F4D6} \u5728\u8BFB',
              count: inProgressBooks.length,
            ),
            if (inProgressBooks.isEmpty)
              _buildEmptyHint('\u8FD8\u6CA1\u6709\u5728\u8BFB\u7684\u4E66')
            else
              ...inProgressBooks.map((book) => _buildBookItem(
                    book,
                    classLearning,
                    classmates,
                    currentUserId,
                  )),

            const SizedBox(height: AppSpacing.lg),

            _buildCollapsibleHeader(
              '\u{1F4D5} \u5DF2\u8BFB\u5B8C',
              count: completedBooks.length,
              isExpanded: _showCompletedBooks,
              onTap: () =>
                  setState(() => _showCompletedBooks = !_showCompletedBooks),
            ),
            if (_showCompletedBooks)
              ...completedBooks.map((book) => _buildCompletedBookItem(book)),

            const SizedBox(height: AppSpacing.lg),

            _buildSectionHeader(
              '\u{1F3AF} \u6280\u80FD',
              count: inProgressSkills.length,
            ),
            if (inProgressSkills.isEmpty)
              _buildEmptyHint('\u8FD8\u6CA1\u6709\u5728\u5B66\u7684\u6280\u80FD')
            else
              ...inProgressSkills.map((skill) => _buildSkillItem(skill)),

            const SizedBox(height: AppSpacing.lg),

            _buildCollapsibleHeader(
              '\u{1F3C6} \u5DF2\u638C\u63E1',
              count: completedSkills.length,
              isExpanded: _showMasteredSkills,
              onTap: () =>
                  setState(() => _showMasteredSkills = !_showMasteredSkills),
            ),
            if (_showMasteredSkills)
              ...completedSkills.map((skill) => _buildCompletedSkillItem(skill)),

            const SizedBox(height: 80),
          ],
        ),

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

  Widget _buildBookItem(
    LearningEntry book,
    List<LearningEntry>? classLearning,
    List<Profile> classmates,
    String currentUserId,
  ) {
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
          if (readingCircleCount > 0)
            GestureDetector(
              onTap: () => _showReadingCircleDialog(
                  book, classLearning!, classmates, currentUserId),
              child: Container(
                margin: const EdgeInsets.only(left: AppSpacing.sm),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.moodBlueBg,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Text(
                  '\u{1F465}$readingCircleCount\u4EBA\u5728\u8BFB',
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
              '\u5DF2\u8BFB\u5B8C',
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
              '\u5DF2\u638C\u63E1',
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

  Widget _buildPopupMenu(LearningEntry entry, {required bool isBook}) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AppColors.textHint, size: 20),
      onSelected: (value) =>
          _handleMenuAction(value, entry, isBook: isBook),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'update_progress',
          child: Text('\u66F4\u65B0\u8FDB\u5EA6'),
        ),
        PopupMenuItem(
          value: 'complete',
          child: Text(isBook
              ? '\u6807\u8BB0\u5B8C\u6210'
              : '\u6807\u8BB0\u638C\u63E1'),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Text('\u5220\u9664',
              style: TextStyle(color: AppColors.error)),
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
                SnackBar(content: Text('\u66F4\u65B0\u5931\u8D25: $e')),
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
                      ? '\u{1F389} \u606D\u559C\u8BFB\u5B8C\u300A${entry.title}\u300B!'
                      : '\u{1F389} \u606D\u559C\u638C\u63E1\u300C${entry.title}\u300D!',
                ),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('\u64CD\u4F5C\u5931\u8D25: $e')),
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
                SnackBar(content: Text('\u5220\u9664\u5931\u8D25: $e')),
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
          title: const Text('\u66F4\u65B0\u8FDB\u5EA6'),
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
              child: const Text('\u53D6\u6D88'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(sliderValue.toInt()),
              child: const Text('\u786E\u8BA4'),
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
        title: const Text('\u786E\u8BA4\u5220\u9664'),
        content: Text('\u786E\u5B9A\u8981\u5220\u9664\u300C$title\u300D\u5417\uFF1F'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('\u53D6\u6D88'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('\u5220\u9664'),
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
                '\u{1F4DA} \u6B63\u5728\u8BFB\u300A${book.title}\u300B\u7684\u540C\u5B66',
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
                '\u4E00\u8D77\u8BFB\u4E66\uFF0C\u4E00\u8D77\u6210\u957F \u{1F4D6}',
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
                title: const Text('\u6DFB\u52A0\u4E66\u7C4D'),
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
                title: const Text('\u6DFB\u52A0\u6280\u80FD'),
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
