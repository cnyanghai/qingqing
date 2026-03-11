import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/checkin.dart';
import '../models/emotion.dart';

/// GitHub-style mood calendar grid showing daily mood colors
class MoodCalendar extends StatelessWidget {
  final DateTime month;
  final List<Checkin> checkins;
  final ValueChanged<Checkin>? onDayTap;

  const MoodCalendar({
    super.key,
    required this.month,
    required this.checkins,
    this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    // Build a map of date -> checkin for quick lookup
    final checkinMap = <String, Checkin>{};
    for (final c in checkins) {
      final key = _dateKey(c.checkedAt);
      checkinMap[key] = c;
    }

    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final startWeekday = firstDay.weekday % 7; // 0=Sunday

    final dayLabels = ['日', '一', '二', '三', '四', '五', '六'];

    return Column(
      children: [
        // Day of week header
        Row(
          children: dayLabels
              .map((d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Calendar grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: startWeekday + lastDay.day,
          itemBuilder: (context, index) {
            if (index < startWeekday) {
              return const SizedBox.shrink();
            }

            final day = index - startWeekday + 1;
            final date = DateTime(month.year, month.month, day);
            final key = _dateKey(date);
            final checkin = checkinMap[key];
            final isToday = _isToday(date);
            final isFuture = date.isAfter(DateTime.now());

            Color tileColor;
            if (checkin != null) {
              tileColor = AppColors.quadrantColor(checkin.quadrant);
            } else if (isFuture) {
              tileColor = AppColors.cardBackground;
            } else {
              tileColor = const Color(0xFFE0E0E0);
            }

            return GestureDetector(
              onTap: checkin != null ? () => onDayTap?.call(checkin) : null,
              child: Container(
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(6),
                  border: isToday
                      ? Border.all(color: AppColors.primary, width: 2)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: checkin != null
                          ? AppColors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

/// Detail popup for a specific day's check-in
class CheckinDetailPopup extends StatelessWidget {
  final Checkin checkin;

  const CheckinDetailPopup({super.key, required this.checkin});

  @override
  Widget build(BuildContext context) {
    final emotion = EmotionData.findEmotionByLabel(checkin.emotionLabel);
    final contextLabel = EmotionData.contextLabel(checkin.contextTag);
    final quadrantColor = AppColors.quadrantColor(checkin.quadrant);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: quadrantColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${checkin.checkedAt.month}月${checkin.checkedAt.day}日',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${emotion?.emoji ?? ""} ${checkin.emotionLabel}',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            '场景: $contextLabel',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          if (checkin.note != null && checkin.note!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              checkin.note!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
