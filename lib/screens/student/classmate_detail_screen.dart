import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme.dart';
import '../../models/profile.dart';
import '../../models/learning_entry.dart';
import '../../models/water_record.dart';
import '../../models/student_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/social_provider.dart';
import '../../widgets/avatar_picker.dart';
import '../../widgets/plant_pot.dart';
import '../../widgets/plant_widget.dart';

/// 同学详情页 — 智慧树只读视图 + 浇水 + 留言板
class ClassmateDetailScreen extends ConsumerStatefulWidget {
  final String classmateId;

  const ClassmateDetailScreen({super.key, required this.classmateId});

  @override
  ConsumerState<ClassmateDetailScreen> createState() =>
      _ClassmateDetailScreenState();
}

class _ClassmateDetailScreenState
    extends ConsumerState<ClassmateDetailScreen> {
  Profile? _classmateProfile;
  List<LearningEntry> _entries = [];
  bool _loading = true;
  String? _error;

  bool _hasWatered = false;
  bool _waterLoading = false;
  int _totalWaterCount = 0;

  // 浇水留言列表
  List<WaterRecord> _waterMessages = [];

  // 留言板
  List<StudentMessage> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  bool _sendingMessage = false;

  // 浇水动画
  bool _showWaterDrop = false;
  double _treeScale = 1.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final service = ref.read(supabaseServiceProvider);
      final userId = ref.read(currentUserIdProvider);

      final profile = await service.getStudentProfile(widget.classmateId);
      final entries =
          await service.getStudentLearningEntries(widget.classmateId);
      final totalWater =
          await service.getTotalWaterCount(widget.classmateId);
      final waterMessages =
          await service.getWaterMessagesForStudent(widget.classmateId);

      // 加载留言板
      List<StudentMessage> messages = [];
      try {
        messages = await service.getStudentMessages(widget.classmateId);
      } catch (_) {
        // 留言板加载失败不影响整体页面
      }

      bool watered = false;
      if (userId != null) {
        watered =
            await service.hasWateredToday(userId, widget.classmateId);
      }

      if (mounted) {
        setState(() {
          _classmateProfile = profile;
          _entries = entries;
          _totalWaterCount = totalWater;
          _hasWatered = watered;
          _waterMessages = waterMessages;
          _messages = messages;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载同学数据失败: $e';
          _loading = false;
        });
      }
    }
  }

  /// 弹出浇水对话框
  void _showWaterDialog() {
    if (_hasWatered || _waterLoading) return;

    final nickname = _classmateProfile?.nickname ?? '同学';
    String selectedText = '';
    final textController = TextEditingController();

    const presetMessages = [
      '加油！',
      '好厉害！',
      '一起加油！',
      '真棒！',
      '你好努力！',
      '向你学习！',
      '太酷了！',
      '继续坚持！',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.large),
          ),
          title: Text(
            '\u{1F4A7} 给$nickname浇水',
            style: const TextStyle(fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '选一句鼓励的话：',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: presetMessages.map((msg) {
                    final isSelected = selectedText == msg &&
                        textController.text == msg;
                    return ActionChip(
                      label: Text(
                        msg,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected
                              ? AppColors.white
                              : AppColors.textDark,
                        ),
                      ),
                      backgroundColor: isSelected
                          ? AppColors.primary
                          : AppColors.cardBackground,
                      side: BorderSide.none,
                      onPressed: () {
                        setDialogState(() {
                          selectedText = msg;
                          textController.text = msg;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: textController,
                  decoration: const InputDecoration(
                    hintText: '写一句鼓励的话...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  maxLines: 2,
                  onChanged: (value) {
                    setDialogState(() {
                      // 如果手动修改，清除预设选中
                      if (value != selectedText) {
                        selectedText = '';
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _doWater(null);
              },
              child: const Text('直接浇水'),
            ),
            FilledButton(
              onPressed: () {
                final msg = textController.text.trim();
                Navigator.of(ctx).pop();
                _doWater(msg.isNotEmpty ? msg : null);
              },
              child: const Text('浇水并留言'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doWater(String? message) async {
    if (_hasWatered || _waterLoading) return;

    final userId = ref.read(currentUserIdProvider);
    final myProfile = ref.read(profileProvider).valueOrNull;
    if (userId == null || myProfile?.classroomId == null) return;

    setState(() => _waterLoading = true);

    try {
      final service = ref.read(supabaseServiceProvider);
      await service.waterTree(
        userId,
        widget.classmateId,
        myProfile!.classroomId!,
        message: message,
      );

      // 浇水成功 — 播放动画
      if (mounted) {
        setState(() {
          _hasWatered = true;
          _waterLoading = false;
          _totalWaterCount++;
          _showWaterDrop = true;
        });

        // 如果有留言，刷新浇水留言列表
        if (message != null && message.isNotEmpty) {
          try {
            final service = ref.read(supabaseServiceProvider);
            final waterMessages =
                await service.getWaterMessagesForStudent(widget.classmateId);
            if (mounted) {
              setState(() => _waterMessages = waterMessages);
            }
          } catch (_) {}
        }

        // 水滴下落动画
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          setState(() {
            _showWaterDrop = false;
            _treeScale = 1.05;
          });
        }
        // 树摇晃回复
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          setState(() => _treeScale = 1.0);
        }

        // 刷新social providers
        ref.invalidate(myTodayWatersProvider);
        ref.invalidate(myTotalWaterCountProvider);
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() => _waterLoading = false);
        if (e.code == '23505') {
          // 唯一约束冲突 — 今天已浇过
          setState(() => _hasWatered = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('今天已经浇过了')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('浇水失败: ${e.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _waterLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('浇水失败: $e')),
        );
      }
    }
  }

  /// 发送留言
  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _sendingMessage) return;

    final userId = ref.read(currentUserIdProvider);
    final myProfile = ref.read(profileProvider).valueOrNull;
    if (userId == null || myProfile?.classroomId == null) return;

    setState(() => _sendingMessage = true);

    try {
      final service = ref.read(supabaseServiceProvider);
      final msg = StudentMessage(
        id: '',
        authorId: userId,
        targetStudentId: widget.classmateId,
        classroomId: myProfile!.classroomId!,
        content: content,
      );
      await service.sendMessage(msg);

      // 清空输入框，刷新列表
      _messageController.clear();
      final messages =
          await service.getStudentMessages(widget.classmateId);
      if (mounted) {
        setState(() {
          _messages = messages;
          _sendingMessage = false;
        });
      }
      // 刷新provider
      ref.invalidate(studentMessagesProvider(widget.classmateId));
      ref.invalidate(myMessagesProvider);
    } catch (e) {
      if (mounted) {
        setState(() => _sendingMessage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送留言失败: $e')),
        );
      }
    }
  }

  /// 删除留言
  Future<void> _deleteMessage(String messageId) async {
    try {
      final service = ref.read(supabaseServiceProvider);
      await service.deleteMessage(messageId);
      final messages =
          await service.getStudentMessages(widget.classmateId);
      if (mounted) {
        setState(() => _messages = messages);
      }
      ref.invalidate(studentMessagesProvider(widget.classmateId));
      ref.invalidate(myMessagesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除留言失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _classmateProfile == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Text(
            _error ?? '未找到同学信息',
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      );
    }

    final profile = _classmateProfile!;
    final nickname = profile.nickname;
    final userId = ref.read(currentUserIdProvider);
    final classmates = ref.watch(classmatesProvider).valueOrNull ?? [];

    // 分类学习记录
    final inProgressBooks = _entries
        .where((e) => e.type == 'book' && e.status == 'in_progress')
        .toList();
    final inProgressSkills = _entries
        .where((e) => e.type == 'skill' && e.status == 'in_progress')
        .toList();
    final completed =
        _entries.where((e) => e.status == 'completed').toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('$nickname\u{7684}\u{667A}\u{6167}\u{6811}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 顶部: 智慧树可视化
            _buildTreeVisualization(profile, _entries),
            const SizedBox(height: AppSpacing.md),

            // 浇水统计
            if (_totalWaterCount > 0)
              Padding(
                padding:
                    const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  '\u{1F4A7} 累计收到$_totalWaterCount次浇水',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
              ),

            // 浇水按钮（改为弹出Dialog）
            _buildWaterButton(nickname),
            const SizedBox(height: AppSpacing.lg),

            // 浇水留言展示
            if (_waterMessages.isNotEmpty) ...[
              _buildWaterMessagesSection(classmates),
              const SizedBox(height: AppSpacing.lg),
            ],

            // 在读的书
            if (inProgressBooks.isNotEmpty) ...[
              _buildSectionHeader('\u{1F4D6} 在读的书'),
              ...inProgressBooks
                  .map((book) => _buildBookRow(book)),
              const SizedBox(height: AppSpacing.md),
            ],

            // 在学的技能
            if (inProgressSkills.isNotEmpty) ...[
              _buildSectionHeader('\u{1F3AF} 在学的技能'),
              ...inProgressSkills
                  .map((skill) => _buildSkillRow(skill)),
              const SizedBox(height: AppSpacing.md),
            ],

            // 已完成
            if (completed.isNotEmpty) ...[
              _buildSectionHeader(
                  '\u{1F352} 已完成 (${completed.length})'),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: completed.map((e) {
                  final config =
                      LearningCategories.getCategory(e.category);
                  return Chip(
                    label: Text('${config.emoji} ${e.title}'),
                    labelStyle: const TextStyle(fontSize: 12),
                    backgroundColor:
                        AppColors.moodGreenBg,
                    side: BorderSide.none,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // 留言板
            _buildMessageBoardSection(userId, classmates),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildTreeVisualization(
      Profile profile, List<LearningEntry> entries) {
    // Build learning plants for shelf display
    final plants = entries.take(4).map((entry) {
      final progress = entry.progress;
      int growthCount;
      if (progress >= 90) {
        growthCount = 30;
      } else if (progress >= 60) {
        growthCount = 14;
      } else if (progress >= 40) {
        growthCount = 7;
      } else if (progress >= 20) {
        growthCount = 3;
      } else {
        growthCount = 1;
      }
      final colors = LearningPlantColors.forCategory(entry.category);
      return PlantWidget(
        config: PlantConfig(
          type: PlantType.learning,
          stage: stageFromCount(growthCount),
          primaryColor: colors[0],
          secondaryColor: colors[1],
          learningCategory: entry.category,
        ),
      );
    }).toList();

    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedScale(
          scale: _treeScale,
          duration: const Duration(milliseconds: 300),
          curve: Curves.elasticOut,
          child: Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.large),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.5, 0.51, 1.0],
                colors: [
                  Color(0xFFE8F4FD),
                  Color(0xFFF0F8FF),
                  Color(0xFFFAF8F5),
                  Color(0xFFF5F0E8),
                ],
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.large),
              child: Column(
                children: [
                  // Shelf with plants
                  SizedBox(
                    height: 90,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (int i = 0; i < 4; i++)
                          i < plants.length
                              ? PlantPot(child: plants[i])
                              : const PlantPot(child: null),
                      ],
                    ),
                  ),
                  // Shelf board
                  Container(
                    width: double.infinity,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4A574),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x30000000),
                          blurRadius: 4,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                  // Lottie tree in remaining space
                  Expanded(
                    child: Lottie.asset(
                      'assets/animations/virtues_tree.json',
                      fit: BoxFit.contain,
                      repeat: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Water drop animation
        if (_showWaterDrop)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.bounceOut,
            top: _showWaterDrop ? 80 : 0,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF64B5F6),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.water_drop,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWaterButton(String nickname) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed:
            _hasWatered || _waterLoading ? null : _showWaterDialog,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _hasWatered ? AppColors.divider : AppColors.primary,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xLarge),
          ),
        ),
        child: _waterLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              )
            : Text(
                _hasWatered
                    ? '\u{1F4A7} 今天已浇过水了'
                    : '\u{1F4A7} 给$nickname浇水',
                style: const TextStyle(fontSize: 16),
              ),
      ),
    );
  }

  // ============================================================
  // 浇水留言展示
  // ============================================================

  Widget _buildWaterMessagesSection(List<Profile> classmates) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('\u{1F4A7} 浇水留言'),
        ...(_waterMessages).map((water) {
          final author = classmates
              .where((c) => c.id == water.fromStudentId)
              .firstOrNull;
          final authorName = author?.nickname ?? '同学';
          final authorAvatarKey = author?.avatarKey ?? 'cat';
          final timeStr = _formatTime(water.createdAt);

          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.moodBlueBg,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AvatarCircle(avatarKey: authorAvatarKey, size: 32),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        water.message ?? '',
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
        }),
      ],
    );
  }

  // ============================================================
  // 留言板
  // ============================================================

  Widget _buildMessageBoardSection(
      String? userId, List<Profile> classmates) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('\u{1F4DD} 留言板'),

        // 输入区
        Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: '写一条留言...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                onPressed: _sendingMessage ? null : _sendMessage,
                icon: _sendingMessage
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send, color: AppColors.primary),
              ),
            ],
          ),
        ),

        // 留言列表
        if (_messages.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(
              child: Text(
                '还没有人留言，说点什么吧~',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          )
        else
          ..._messages.map((msg) {
            final author = classmates
                .where((c) => c.id == msg.authorId)
                .firstOrNull;
            final authorName = author?.nickname ?? '同学';
            final authorAvatarKey = author?.avatarKey ?? 'cat';
            final isMyMessage = userId != null && msg.authorId == userId;
            final timeStr = _formatTime(msg.createdAt);

            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.sm),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AvatarCircle(avatarKey: authorAvatarKey, size: 32),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                            if (isMyMessage)
                              GestureDetector(
                                onTap: () => _deleteMessage(msg.id),
                                child: const Padding(
                                  padding: EdgeInsets.only(left: 4),
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
          }),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
      ),
    );
  }

  Widget _buildBookRow(LearningEntry book) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
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
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${book.progress}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkillRow(LearningEntry skill) {
    final config = LearningCategories.getCategory(skill.category);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
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
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化时间为友好显示
  String _formatTime(DateTime? dateTime) {
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
