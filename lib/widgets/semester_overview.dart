import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart';
import '../models/checkin.dart';
import '../providers/checkin_provider.dart';

/// 学期概览视图：20周 x 5天（工作日）小方块矩阵
class SemesterOverview extends ConsumerWidget {
  const SemesterOverview({super.key});

  /// 计算当前学期起始日期
  static DateTime _semesterStart() {
    final now = DateTime.now();
    final currentYear = now.year;
    final fallStart = DateTime(currentYear, 9, 1);
    final springStart = DateTime(currentYear, 3, 1);
    final lastFallStart = DateTime(currentYear - 1, 9, 1);

    if (!fallStart.isAfter(now)) {
      return fallStart;
    } else if (!springStart.isAfter(now)) {
      return springStart;
    } else {
      return lastFallStart;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkinsAsync = ref.watch(semesterCheckinsProvider);

    return checkinsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(
        child: Text('加载失败', style: TextStyle(color: AppColors.error)),
      ),
      data: (checkins) => _buildMatrix(checkins),
    );
  }

  Widget _buildMatrix(List<Checkin> checkins) {
    final semesterStart = _semesterStart();

    // Build a date -> quadrant map (keep latest per day)
    final dateQuadrants = <String, String>{};
    for (final c in checkins) {
      final key = _formatDate(c.checkedAt);
      dateQuadrants.putIfAbsent(key, () => c.quadrant); // 保留最新一条（列表倒序，第一个即最新）
    }

    // Find the Monday of the week containing semesterStart
    // weekday: 1=Mon, 7=Sun
    final firstMonday = semesterStart.subtract(
      Duration(days: semesterStart.weekday - 1),
    );

    const weekdays = ['一', '二', '三', '四', '五'];
    const cellSize = 18.0;
    const cellSpacing = 3.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: weekday labels
          Row(
            children: [
              // Space for week labels
              SizedBox(
                width: 48,
                child: Container(),
              ),
              ...weekdays.map((day) => SizedBox(
                    width: cellSize + cellSpacing,
                    child: Center(
                      child: Text(
                        day,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )),
            ],
          ),
          const SizedBox(height: 4),
          // 20 weeks of data
          ...List.generate(20, (weekIndex) {
            final weekMonday = firstMonday.add(Duration(days: weekIndex * 7));

            return Padding(
              padding: const EdgeInsets.only(bottom: cellSpacing),
              child: Row(
                children: [
                  // Week label
                  SizedBox(
                    width: 48,
                    child: Text(
                      '第${weekIndex + 1}周',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                  // 5 weekday cells (Mon-Fri)
                  ...List.generate(5, (dayIndex) {
                    final date = weekMonday.add(Duration(days: dayIndex));
                    final key = _formatDate(date);
                    final quadrant = dateQuadrants[key];

                    Color cellColor;
                    if (quadrant != null) {
                      cellColor = AppColors.quadrantColor(quadrant);
                    } else {
                      cellColor = const Color(0xFFE8E8E8);
                    }

                    return Container(
                      width: cellSize,
                      height: cellSize,
                      margin: const EdgeInsets.only(right: cellSpacing),
                      decoration: BoxDecoration(
                        color: cellColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
          // Legend
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 48),
              _legendItem(AppColors.moodYellow, '开心'),
              const SizedBox(width: 8),
              _legendItem(AppColors.moodGreen, '平静'),
              const SizedBox(width: 8),
              _legendItem(AppColors.moodBlue, '不太好'),
              const SizedBox(width: 8),
              _legendItem(AppColors.moodRed, '有点烦'),
              const SizedBox(width: 8),
              _legendItem(const Color(0xFFE8E8E8), '无记录'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
