import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/avatar_picker.dart';

/// S3: Setup account and profile after joining class
class SetupProfileScreen extends ConsumerStatefulWidget {
  final String? classroomId;

  const SetupProfileScreen({super.key, this.classroomId});

  @override
  ConsumerState<SetupProfileScreen> createState() =>
      _SetupProfileScreenState();
}

class _SetupProfileScreenState extends ConsumerState<SetupProfileScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  String? _selectedAvatar;
  bool _isLoading = false;

  /// Validate Chinese mobile number: exactly 11 digits, starts with 1
  bool get _isValidPhone {
    final phone = _phoneController.text.trim();
    return RegExp(r'^1\d{10}$').hasMatch(phone);
  }

  bool get _canSubmit =>
      _isValidPhone &&
      _passwordController.text.length >= 6 &&
      _selectedAvatar != null &&
      _nicknameController.text.isNotEmpty &&
      _nicknameController.text.length <= 8 &&
      !_isLoading;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_canSubmit) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(supabaseServiceProvider);

      // 1. Create auth user (phone stored as email)
      // If user already exists (previous failed attempt), try signing in instead
      final email = '${_phoneController.text.trim()}@qingqing.local';
      String? userId;
      try {
        final authResponse = await service.signUpWithEmail(
          email,
          _passwordController.text,
        );
        userId = authResponse.user?.id;
      } catch (e) {
        if (e.toString().contains('user_already_exists') ||
            e.toString().contains('already registered')) {
          // User exists from a previous failed attempt, try login
          final loginResponse = await service.signInWithEmail(
            email,
            _passwordController.text,
          );
          userId = loginResponse.user?.id;
        } else {
          rethrow;
        }
      }
      if (userId == null) {
        throw Exception('注册失败，未获取到用户信息');
      }

      // 2. Create student profile
      final actions = ref.read(profileActionsProvider);
      await actions.createStudentProfile(
        userId: userId,
        nickname: _nicknameController.text.trim(),
        avatarKey: _selectedAvatar!,
        classroomId: widget.classroomId ?? '',
      );

      // 3. Navigate to home
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('注册失败: $e')),
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
                '创建你的账号',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                '填写信息后即可开始记录心情',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Phone number
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '手机号',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: '请输入手机号',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
              // Password
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '密码',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: '请输入密码（至少6位）',
                ),
                onChanged: (_) => setState(() {}),
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
                  counterText: '',
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
                '随时可以在设置中更改昵称和头像',
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
