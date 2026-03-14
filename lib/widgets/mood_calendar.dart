import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/checkin.dart';

/// GitHub-style mood calendar grid showing daily mood colors
class MoodCalendar extends StatelessWidget {
  final DateTime month;
  final List<Checkin> checkins;
  final ValueChanged<List<Checkin>>? onDayTap;

  const MoodCalendar({
    super.key,
    required this.month,
    required this.checkins,
    this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    // Build a map of date -> list of checkins for quick lookup
    final checkinMap = <String, List<Checkin>>{};
    for (final c in checkins) {
      final key = _dateKey(c.checkedAt);
      checkinMap.putIfAbsent(key, () => []).add(c);
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
            final dayCheckins = checkinMap[key] ?? [];
            final isToday = _isToday(date);
            final isFuture = date.isAfter(DateTime.now());

            if (dayCheckins.isEmpty) {
              // No records: grey or future
              return Container(
                decoration: BoxDecoration(
                  color: isFuture ? AppColors.cardBackground : const Color(0xFFE0E0E0),
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
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }

            if (dayCheckins.length == 1) {
              // Single record: full color fill (keep existing behavior)
              return GestureDetector(
                onTap: () => onDayTap?.call(dayCheckins),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.quadrantColor(dayCheckins.first.quadrant),
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
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              );
            }

            // Multiple records: color splits (2-3 colors, 4+ takes newest 3)
            final displayCheckins = dayCheckins.take(3).toList();
            return GestureDetector(
              onTap: () => onDayTap?.call(dayCheckins),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: isToday
                      ? Border.all(color: AppColors.primary, width: 2)
                      : null,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Row(
                      children: displayCheckins.map((c) {
                        return Expanded(
                          child: Container(
                            color: AppColors.quadrantColor(c.quadrant),
                          ),
                        );
                      }).toList(),
                    ),
                    Center(
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ],
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
