import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../models/classroom.dart';
import '../providers/auth_provider.dart';
import '../providers/classroom_provider.dart';
import '../widgets/pin_input.dart';

/// S2: Join classroom by entering a 6-digit code
class JoinClassScreen extends ConsumerStatefulWidget {
  const JoinClassScreen({super.key});

  @override
  ConsumerState<JoinClassScreen> createState() => _JoinClassScreenState();
}

class _JoinClassScreenState extends ConsumerState<JoinClassScreen> {
  String _code = '';
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isCodeComplete => _code.length == 6;

  Future<void> _handleJoin() async {
    if (!_isCodeComplete) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final actions = ref.read(classroomActionsProvider);
      final classroom = await actions.findByCode(_code);

      if (classroom == null) {
        setState(() {
          _errorMessage = '班级码无效，请核对后重试';
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;

      // Show confirmation dialog
      final confirmed = await _showConfirmDialog(classroom);
      if (confirmed != true) {
        setState(() => _isLoading = false);
        return;
      }

      // Create anonymous auth user
      final service = ref.read(supabaseServiceProvider);
      await service.signInAnonymously();

      if (!mounted) return;

      // Navigate to profile setup with classroom ID
      context.go('/setup-profile', extra: classroom.id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '查询失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<bool?> _showConfirmDialog(Classroom classroom) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        title: const Text('确认加入'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '学校: ${(classroom.schoolName != null && classroom.schoolName!.isNotEmpty) ? classroom.schoolName! : '未知学校'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '班级: ${classroom.displayName}',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('确认加入'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('加入班级'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              const Spacer(flex: 1),
              // Person+ icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add_outlined,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Title
              const Text(
                '输入班级码',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                '班级码找你的老师要哦',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Pin input
              PinInput(
                onCompleted: (value) {
                  setState(() => _code = value);
                },
                onChanged: (value) {
                  setState(() {
                    _code = value;
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.md),
              // Error message
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 14,
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              // Tip card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4F8),
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '温馨提示：请输入老师提供的6位数字代码。如果您还没有代码，请联系您的班主任。',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              // Join button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isCodeComplete && !_isLoading
                      ? _handleJoin
                      : null,
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
                      : const Text('加入'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
