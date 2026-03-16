import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart';
import '../models/learning_entry.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/learning_provider.dart';

/// 添加书籍或技能的通用Dialog
class AddLearningDialog extends ConsumerStatefulWidget {
  /// 'book' 或 'skill'
  final String type;

  const AddLearningDialog({super.key, required this.type});

  @override
  ConsumerState<AddLearningDialog> createState() => _AddLearningDialogState();
}

class _AddLearningDialogState extends ConsumerState<AddLearningDialog> {
  final _titleController = TextEditingController();
  String _selectedCategory = 'other';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.type == 'book') {
      _selectedCategory = 'reading';
    } else {
      _selectedCategory = 'music';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final userId = ref.read(currentUserIdProvider);
    final profile = ref.read(profileProvider).valueOrNull;
    if (userId == null || profile == null || profile.classroomId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('用户信息异常，请重试')),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final entry = LearningEntry(
        id: '',
        studentId: userId,
        classroomId: profile.classroomId!,
        type: widget.type,
        title: title,
        category: _selectedCategory,
        status: 'in_progress',
        progress: 0,
        startedAt: DateTime.now(),
      );

      final service = ref.read(supabaseServiceProvider);
      await service.createLearningEntry(entry);
      ref.invalidate(myLearningEntriesProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBook = widget.type == 'book';

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      title: Text(isBook ? '添加书籍' : '添加技能'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 名称输入框
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: isBook ? '书名' : '技能名（如"钢琴"）',
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),

            // 技能类别选择
            if (!isBook) ...[
              const SizedBox(height: AppSpacing.md),
              const Text(
                '选择类别',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: LearningCategories.skillCategories.map((key) {
                  final config = LearningCategories.getCategory(key);
                  final isSelected = _selectedCategory == key;
                  return ChoiceChip(
                    label: Text('${config.emoji} ${config.name}'),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = key);
                      }
                    },
                    selectedColor: config.color.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      color: isSelected ? config.color : AppColors.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
            ],

            // 书籍类别固定显示
            if (isBook) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Text(
                    '类别：',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${LearningCategories.getCategory('reading').emoji} 阅读',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('确认'),
        ),
      ],
    );
  }
}
