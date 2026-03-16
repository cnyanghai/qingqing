import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Terms of service screen
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用户协议'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              '用户协议',
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
            _SectionTitle('一、服务说明'),
            SizedBox(height: AppSpacing.sm),
            Text(
              '晴晴是一款面向中小学生的情绪追踪工具，旨在帮助教师了解学生的情绪状态，'
              '促进学生心理健康。学生可以通过晴晴记录每天的心情，教师可以查看班级整体'
              '情绪概况和个别学生的情绪趋势。',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textDark,
                height: 1.8,
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            _SectionTitle('二、使用规则'),
            SizedBox(height: AppSpacing.sm),
            Text(
              '- 请如实记录自己的心情，不要代替他人记录\n'
              '- 不得恶意使用本服务，包括但不限于发布不当内容\n'
              '- 尊重他人隐私，不得窥探或传播他人的情绪记录\n'
              '- 遵守学校的相关管理规定',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textDark,
                height: 1.8,
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            _SectionTitle('三、责任限制'),
            SizedBox(height: AppSpacing.sm),
            Text(
              '- 晴晴是一款辅助工具，仅供参考，不能替代专业心理咨询\n'
              '- 如学生出现严重心理问题，请及时寻求专业心理咨询师的帮助\n'
              '- 我们不对因使用或无法使用本服务所导致的任何间接损失承担责任',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textDark,
                height: 1.8,
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            _SectionTitle('四、账号安全'),
            SizedBox(height: AppSpacing.sm),
            Text(
              '- 用户需妥善保管自己的手机号和密码\n'
              '- 不要将账号信息告知他人\n'
              '- 如发现账号被盗用，请及时联系教师或发送邮件至 cnyanghai@icloud.com',
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
