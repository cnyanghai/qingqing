import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Privacy policy screen
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('隐私政策'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              '隐私政策',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              '最后更新：2026年3月',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textHint,
              ),
            ),
            SizedBox(height: AppSpacing.xl),
            _SectionTitle('一、信息收集范围'),
            SizedBox(height: AppSpacing.sm),
            Text(
              '我们收集以下信息用于提供服务：\n'
              '- 手机号（学生通常使用家长副号）\n'
              '- 昵称\n'
              '- 头像选择\n'
              '- 情绪记录（包括情绪象限、具体情绪、场景、备注）\n'
              '- 学校和班级信息',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textDark,
                height: 1.8,
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            _SectionTitle('二、信息用途'),
            SizedBox(height: AppSpacing.sm),
            Text(
              '收集的信息仅用于以下目的：\n'
              '- 教师查看班级学生的情绪状态\n'
              '- 帮助教师了解学生心理健康状况\n'
              '- 不用于任何商业目的',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textDark,
                height: 1.8,
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            _SectionTitle('三、信息存储'),
            SizedBox(height: AppSpacing.sm),
            Text(
              '- 数据使用 Supabase 云服务存储\n'
              '- 所有数据传输采用 HTTPS 加密\n'
              '- 我们会采取合理的技术措施保护您的信息安全',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textDark,
                height: 1.8,
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            _SectionTitle('四、信息可见性'),
            SizedBox(height: AppSpacing.sm),
            Text(
              '- 学生的情绪记录仅班级教师和本人可见\n'
              '- 不对外公开任何学生信息\n'
              '- 其他学生无法查看彼此的情绪记录',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textDark,
                height: 1.8,
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            _SectionTitle('五、信息删除'),
            SizedBox(height: AppSpacing.sm),
            Text(
              '用户可随时申请删除所有个人记录：\n'
              '- 联系班级教师提出删除请求\n'
              '- 或发送邮件至以下地址申请删除',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textDark,
                height: 1.8,
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            _SectionTitle('六、联系方式'),
            SizedBox(height: AppSpacing.sm),
            Text(
              '如有任何隐私相关问题，请联系：\ncnyanghai@icloud.com',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textDark,
                height: 1.8,
              ),
            ),
            SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      ),
    );
  }
}
