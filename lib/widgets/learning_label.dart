import 'package:flutter/material.dart';
import '../models/learning_entry.dart';

/// 学习标签 Widget -- 匹配 Lottie 插画风格
///
/// 小标签显示类别 emoji + 书名/技能名，浮在智慧树树冠区域。
class LearningLabel extends StatelessWidget {
  final String title;
  final String category;
  final bool isCompleted;

  const LearningLabel({
    super.key,
    required this.title,
    required this.category,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final config = LearningCategories.getCategory(category);

    return Opacity(
      opacity: 0.9,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 80),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isCompleted
              ? const Color(0xFFFFF8E1)
              : const Color(0xFFF5F0E8).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF3F3C56).withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCompleted)
              const Padding(
                padding: EdgeInsets.only(right: 2),
                child: Icon(
                  Icons.check_circle,
                  size: 10,
                  color: Color(0xFF8D6E63),
                ),
              ),
            Text(
              config.emoji,
              style: const TextStyle(fontSize: 9),
            ),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF2E2E33),
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
