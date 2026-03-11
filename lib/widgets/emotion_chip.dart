import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/emotion.dart';

/// Emotion selection chip for step 2 (specific emotion within a quadrant)
class EmotionChip extends StatelessWidget {
  final EmotionItem emotion;
  final String quadrantKey;
  final bool isSelected;
  final VoidCallback onTap;

  const EmotionChip({
    super.key,
    required this.emotion,
    required this.quadrantKey,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.quadrantBgColor(quadrantKey);
    final borderColor = AppColors.quadrantColor(quadrantKey);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: isSelected
              ? Border.all(color: borderColor, width: 2)
              : Border.all(color: borderColor.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            Text(
              emotion.emoji,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    emotion.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    emotion.labelEn,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
