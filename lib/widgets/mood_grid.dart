import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/emotion.dart';

/// 2x2 mood quadrant selection grid (S5 step 1)
class MoodGrid extends StatelessWidget {
  final String? selectedQuadrant;
  final ValueChanged<String> onSelect;

  const MoodGrid({
    super.key,
    this.selectedQuadrant,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // Layout order from spec/screenshot:
    // top-left: red (有点烦), top-right: yellow (很开心)
    // bottom-left: blue (不太好), bottom-right: green (很平静)
    final gridItems = [
      _GridItem(quadrant: EmotionData.quadrants[0]), // red
      _GridItem(quadrant: EmotionData.quadrants[1]), // yellow
      _GridItem(quadrant: EmotionData.quadrants[3]), // blue (bottom-left)
      _GridItem(quadrant: EmotionData.quadrants[2]), // green (bottom-right)
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.0,
      children: gridItems.map((item) {
        final isSelected = selectedQuadrant == item.quadrant.key;
        return _MoodQuadrantCard(
          quadrant: item.quadrant,
          isSelected: isSelected,
          onTap: () => onSelect(item.quadrant.key),
        );
      }).toList(),
    );
  }
}

class _GridItem {
  final EmotionQuadrant quadrant;
  const _GridItem({required this.quadrant});
}

class _MoodQuadrantCard extends StatelessWidget {
  final EmotionQuadrant quadrant;
  final bool isSelected;
  final VoidCallback onTap;

  const _MoodQuadrantCard({
    required this.quadrant,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.quadrantBgColor(quadrant.key);
    final textColor = AppColors.quadrantColor(quadrant.key);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.xLarge),
          border: isSelected
              ? Border.all(color: textColor, width: 2.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              quadrant.emoji,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              quadrant.label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
