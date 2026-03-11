import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/avatar_picker.dart';

/// S3: Setup nickname and avatar after joining class
class SetupProfileScreen extends ConsumerStatefulWidget {
  final String? classroomId;

  const SetupProfileScreen({super.key, this.classroomId});

  @override
  ConsumerState<SetupProfileScreen> createState() =>
      _SetupProfileScreenState();
}

class _SetupProfileScreenState extends ConsumerState<SetupProfileScreen> {
  String? _selectedAvatar;
  final _nicknameController = TextEditingController();
  bool _isLoading = false;

  bool get _canSubmit =>
      _selectedAvatar != null &&
      _nicknameController.text.isNotEmpty &&
      _nicknameController.text.length <= 8 &&
      !_isLoading;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_canSubmit) return;

    setState(() => _isLoading = true);

    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        throw Exception('用户未登录');
      }

      final actions = ref.read(profileActionsProvider);
      await actions.createStudentProfile(
        userId: userId,
        nickname: _nicknameController.text.trim(),
        avatarKey: _selectedAvatar!,
        classroomId: widget.classroomId ?? '',
      );

      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败，请重试')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xl),
              // Title
              const Text(
                '给自己取个名字吧',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                '让我们更好地了解你',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Large avatar preview
              AvatarCircle(
                avatarKey: _selectedAvatar ?? 'cat',
                size: 80,
                showEditIcon: true,
              ),
              const SizedBox(height: AppSpacing.lg),
              // Avatar selection label
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '选择一个你喜欢的形象',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Avatar grid
              AvatarPicker(
                selectedKey: _selectedAvatar,
                onSelect: (key) {
                  setState(() => _selectedAvatar = key);
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              // Nickname input
              TextField(
                controller: _nicknameController,
                maxLength: 8,
                decoration: InputDecoration(
                  hintText: '输入你的昵称',
                  counterText: '${_nicknameController.text.length}/8',
                  suffixText: '${_nicknameController.text.length}/8',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Submit button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _canSubmit ? _handleSubmit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    disabledBackgroundColor: AppColors.accent.withOpacity(0.5),
                  ),
                  child: _isLoading
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
                            Text('开始记录心情'),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 20),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                '随时可以在设置中更改这些信息',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
