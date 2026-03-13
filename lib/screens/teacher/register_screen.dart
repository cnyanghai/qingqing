import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/profile.dart';

/// T1: Teacher registration / class creation screen
/// Phone number is stored as {phone}@qingqing.local in Supabase email field
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _schoolController = TextEditingController();
  final _classNumberController = TextEditingController();

  int? _selectedGrade;
  bool _isLoading = false;

  /// Validate Chinese mobile number: exactly 11 digits, starts with 1
  bool get _isValidPhone {
    final phone = _phoneController.text.trim();
    return RegExp(r'^1\d{10}$').hasMatch(phone);
  }

  bool get _canSubmit =>
      _isValidPhone &&
      _passwordController.text.length >= 6 &&
      _nameController.text.isNotEmpty &&
      _schoolController.text.isNotEmpty &&
      _selectedGrade != null &&
      _classNumberController.text.isNotEmpty &&
      !_isLoading;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _schoolController.dispose();
    _classNumberController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_canSubmit) return;
    setState(() => _isLoading = true);

    try {
      final service = ref.read(supabaseServiceProvider);

      // 1. Create auth user (phone stored as email)
      // If user already exists (previous failed attempt), try signing in
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

      // 2. Find or create school
      final schoolId =
          await service.findOrCreateSchool(_schoolController.text.trim());

      // 3. Generate unique 6-digit join code
      final joinCode = await service.generateUniqueJoinCode();

      // 4. Calculate enrollment year from selected grade
      // e.g. grade 3 in 2026 => enrolled in 2024
      final enrollmentYear = DateTime.now().year - _selectedGrade! + 1;

      // 5. Create classroom
      await service.createClassroom(
        schoolId: schoolId,
        teacherId: userId,
        enrollmentYear: enrollmentYear,
        classNumber: int.tryParse(_classNumberController.text.trim()) ?? 1,
        joinCode: joinCode,
      );

      // 6. Create teacher profile
      final profile = Profile(
        id: userId,
        role: 'teacher',
        nickname: _nameController.text.trim(),
        avatarKey: 'cat',
        classroomId: null,
      );
      await service.upsertProfile(profile);

      // 7. Navigate to T5 (class code screen) with the join code
      if (mounted) {
        context.go('/teacher/class-code', extra: joinCode);
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('创建班级'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '教师注册',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                '创建班级后，学生可以通过班级码加入',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Phone
              const Text('手机号',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  )),
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
              const Text('密码',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  )),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: '请输入密码（至少6位）',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
              // Name
              const Text('姓名',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  )),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: '请输入您的姓名',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
              // School
              const Text('学校',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  )),
              const SizedBox(height: 8),
              TextField(
                controller: _schoolController,
                decoration: const InputDecoration(
                  hintText: '输入学校名称',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
              // Grade selection
              const Text('年级',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  )),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(6, (index) {
                  final grade = index + 1;
                  final isSelected = _selectedGrade == grade;
                  final gradeNames = [
                    '一年级',
                    '二年级',
                    '三年级',
                    '四年级',
                    '五年级',
                    '六年级'
                  ];
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedGrade = grade),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.white,
                        borderRadius:
                            BorderRadius.circular(AppRadius.round),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.divider,
                        ),
                      ),
                      child: Text(
                        gradeNames[index],
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected
                              ? AppColors.white
                              : AppColors.textDark,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.md),
              // Class number
              const Text('班级号',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  )),
              const SizedBox(height: 8),
              TextField(
                controller: _classNumberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '例如: 2',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Submit
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _canSubmit ? _handleRegister : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor:
                        AppColors.primary.withOpacity(0.5),
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
                      : const Text('创建班级'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
