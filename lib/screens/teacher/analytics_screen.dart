import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../models/checkin.dart';
import '../../models/profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/teacher_provider.dart';
import '../../widgets/avatar_picker.dart';

/// Last week's checkins provider for the teacher's class (previous Mon-Sun)
final _lastWeekCheckinsProvider = FutureProvider<List<Checkin>>((ref) async {
  final classroom = await ref.watch(teacherClassroomProvider.future);
  if (classroom == null) return [];

  final service = ref.watch(supabaseServiceProvider);
  final now = DateTime.now();
  final thisMonday = now.subtract(Duration(days: now.weekday - 1));
  final lastMonday = thisMonday.subtract(const Duration(days: 7));
  final lastSunday = thisMonday.subtract(const Duration(days: 1));

  try {
    return await service.getClassCheckinsRange(
      classroom.id,
      startDate: lastMonday,
      endDate: lastSunday,
    );
  } catch (e) {
    return [];
  }
});

/// Teacher analytics screen — displays weekly checkin trends, mood distribution,
/// students needing attention, and participation leaderboard.
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  bool _showAllRanking = false;

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(classStudentsProvider);
    final weekCheckinsAsync = ref.watch(weekClassCheckinsProvider);
    final lastWeekCheckinsAsync = ref.watch(_lastWeekCheckinsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: studentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('加载失败',
                style: TextStyle(color: AppColors.error)),
          ),
          data: (students) {
            final weekCheckins = weekCheckinsAsync.valueOrNull ?? [];
            final lastWeekCheckins = lastWeekCheckinsAsync.valueOrNull ?? [];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page title
                  const Text(
                    '班级分析',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Module A: Weekly checkin rate trend
                  _buildCheckinRateTrend(students, weekCheckins),
                  const SizedBox(height: AppSpacing.lg),

                  // Module B: Mood distribution comparison
                  _buildMoodComparison(weekCheckins, lastWeekCheckins),
                  const SizedBox(height: AppSpacing.lg),

                  // Module C: Students needing attention
                  _buildAttentionList(students, weekCheckins),
                  const SizedBox(height: AppSpacing.lg),

                  // Module D: Participation leaderboard
                  _buildLeaderboard(students, weekCheckins),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // Module A — Weekly checkin rate trend (line chart)
  // ============================================================

  Widget _buildCheckinRateTrend(
      List<Profile> students, List<Checkin> weekCheckins) {
    final totalStudents = students.length;
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));

    // Calculate daily checkin rate for Mon-Sun
    final dailyRates = <double>[];
    for (int i = 0; i < 7; i++) {
      final day = DateTime(monday.year, monday.month, monday.day + i);
      // Only count up to today
      if (day.isAfter(DateTime(now.year, now.month, now.day))) {
        dailyRates.add(-1); // -1 means future day, no data
        continue;
      }
      if (totalStudents == 0) {
        dailyRates.add(0);
        continue;
      }
      final dayStr = _formatDate(day);
      final checkedStudents = weekCheckins
          .where((c) => _formatDate(c.checkedAt) == dayStr)
          .map((c) => c.studentId)
          .toSet()
          .length;
      dailyRates.add(checkedStudents / totalStudents * 100);
    }

    // Calculate weekly average (only for days with data)
    final validRates = dailyRates.where((r) => r >= 0).toList();
    final avgRate = validRates.isEmpty
        ? 0.0
        : validRates.reduce((a, b) => a + b) / validRates.length;

    final dayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + average
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '本周打卡率',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.moodGreenBg,
                  borderRadius: BorderRadius.circular(AppRadius.round),
                ),
                child: Text(
                  '平均 ${avgRate.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.moodGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Line chart
          if (totalStudents == 0)
            const SizedBox(
              height: 180,
              child: Center(
                child: Text(
                  '暂无学生数据',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 100,
                  minX: 0,
                  maxX: 6,
                  lineBarsData: [
                    LineChartBarData(
                      spots: _buildLineSpots(dailyRates),
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: AppColors.primary,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: AppColors.primary,
                            strokeWidth: 2,
                            strokeColor: AppColors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    show: true,
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: 25,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              '${value.toInt()}%',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < dayLabels.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                dayLabels[idx],
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 25,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppColors.divider.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<FlSpot> _buildLineSpots(List<double> dailyRates) {
    final spots = <FlSpot>[];
    for (int i = 0; i < dailyRates.length; i++) {
      if (dailyRates[i] >= 0) {
        spots.add(FlSpot(i.toDouble(), dailyRates[i]));
      }
    }
    return spots;
  }

  // ============================================================
  // Module B — Mood distribution comparison (this week vs last week)
  // ============================================================

  Widget _buildMoodComparison(
      List<Checkin> weekCheckins, List<Checkin> lastWeekCheckins) {
    final thisWeekDist = _computeMoodDistribution(weekCheckins);
    final lastWeekDist = _computeMoodDistribution(lastWeekCheckins);

    // Compute blue change
    final thisBlue = thisWeekDist['blue'] ?? 0;
    final lastBlue = lastWeekDist['blue'] ?? 0;
    final blueDiff = thisBlue - lastBlue;

    String summaryText;
    if (weekCheckins.isEmpty && lastWeekCheckins.isEmpty) {
      summaryText = '暂无数据';
    } else if (weekCheckins.isEmpty) {
      summaryText = '本周暂无打卡数据';
    } else if (lastWeekCheckins.isEmpty) {
      summaryText = '本周蓝色情绪占比${thisBlue.toStringAsFixed(0)}%（上周无数据）';
    } else if (blueDiff > 0) {
      summaryText =
          '本周蓝色情绪占比${thisBlue.toStringAsFixed(0)}%，较上周增加${blueDiff.abs().toStringAsFixed(0)}%';
    } else if (blueDiff < 0) {
      summaryText =
          '本周蓝色情绪占比${thisBlue.toStringAsFixed(0)}%，较上周减少${blueDiff.abs().toStringAsFixed(0)}%';
    } else {
      summaryText =
          '本周蓝色情绪占比${thisBlue.toStringAsFixed(0)}%，与上周持平';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '情绪变化趋势',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Two mini pie charts
          Row(
            children: [
              Expanded(
                child: _buildMiniPieChart('上周', lastWeekDist),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildMiniPieChart('本周', thisWeekDist),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Legend
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              _moodLegendDot(AppColors.moodRed, '烦躁'),
              _moodLegendDot(AppColors.moodYellow, '开心'),
              _moodLegendDot(AppColors.moodGreen, '平静'),
              _moodLegendDot(AppColors.moodBlue, '低落'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Summary text
          Text(
            summaryText,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _moodLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildMiniPieChart(String label, Map<String, double> distribution) {
    final hasData = distribution.values.any((v) => v > 0);

    final sections = <PieChartSectionData>[];
    if (hasData) {
      final quadrants = [
        ('red', AppColors.moodRed),
        ('yellow', AppColors.moodYellow),
        ('green', AppColors.moodGreen),
        ('blue', AppColors.moodBlue),
      ];
      for (final (key, color) in quadrants) {
        final pct = distribution[key] ?? 0;
        if (pct > 0) {
          sections.add(PieChartSectionData(
            color: color,
            value: pct,
            title: '',
            radius: 20,
          ));
        }
      }
    }

    if (sections.isEmpty) {
      sections.add(PieChartSectionData(
        color: AppColors.divider,
        value: 1,
        title: '',
        radius: 20,
      ));
    }

    return Column(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 28,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  /// Returns a map: quadrant -> percentage (0-100)
  Map<String, double> _computeMoodDistribution(List<Checkin> checkins) {
    final counts = <String, int>{
      'red': 0,
      'yellow': 0,
      'green': 0,
      'blue': 0,
    };
    for (final c in checkins) {
      counts[c.quadrant] = (counts[c.quadrant] ?? 0) + 1;
    }
    final total = checkins.length;
    if (total == 0) {
      return {'red': 0, 'yellow': 0, 'green': 0, 'blue': 0};
    }
    return {
      'red': counts['red']! / total * 100,
      'yellow': counts['yellow']! / total * 100,
      'green': counts['green']! / total * 100,
      'blue': counts['blue']! / total * 100,
    };
  }

  // ============================================================
  // Module C — Students needing attention
  // ============================================================

  Widget _buildAttentionList(
      List<Profile> students, List<Checkin> weekCheckins) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Group checkins by student
    final studentCheckins = <String, List<Checkin>>{};
    for (final c in weekCheckins) {
      studentCheckins.putIfAbsent(c.studentId, () => []).add(c);
    }

    // Identify students needing attention
    final attentionItems = <_AttentionItem>[];

    for (final student in students) {
      final checkins = studentCheckins[student.id] ?? [];
      final reasons = <String>[];

      // Rule 1: Consecutive 3 days no checkin (natural calendar days, no skipping weekends)
      final checkedDates = checkins
          .map((c) =>
              DateTime(c.checkedAt.year, c.checkedAt.month, c.checkedAt.day))
          .toSet();

      bool has3DayGap = true;
      for (int i = 0; i < 3; i++) {
        final day = today.subtract(Duration(days: i));
        if (checkedDates.contains(day)) {
          has3DayGap = false;
          break;
        }
      }
      if (has3DayGap) {
        reasons.add('3天未打卡');
      }

      // Rule 2: Blue > 50% in last 7 days
      if (checkins.isNotEmpty) {
        final blueCount =
            checkins.where((c) => c.quadrant == 'blue').length;
        if (blueCount / checkins.length > 0.5) {
          reasons.add('情绪低落');
        }
      }

      // Rule 3: Red > 40% in last 7 days
      if (checkins.isNotEmpty) {
        final redCount =
            checkins.where((c) => c.quadrant == 'red').length;
        if (redCount / checkins.length > 0.4) {
          reasons.add('频繁烦躁');
        }
      }

      if (reasons.isNotEmpty) {
        attentionItems.add(_AttentionItem(
          student: student,
          reasons: reasons,
        ));
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '需要关注',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          if (attentionItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Text(
                  '本周班级状态良好 \u{1F389}',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...attentionItems.map((item) => _buildAttentionRow(item)),
        ],
      ),
    );
  }

  Widget _buildAttentionRow(_AttentionItem item) {
    return InkWell(
      onTap: () {
        context.push('/teacher/students/${item.student.id}');
      },
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            AvatarCircle(avatarKey: item.student.avatarKey, size: 40),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.student.nickname,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: item.reasons.map((reason) {
                      Color bgColor;
                      Color textColor;
                      if (reason == '3天未打卡') {
                        bgColor = AppColors.moodYellowBg;
                        textColor = const Color(0xFFB8860B);
                      } else if (reason == '情绪低落') {
                        bgColor = AppColors.moodBlueBg;
                        textColor = AppColors.moodBlue;
                      } else {
                        bgColor = AppColors.moodRedBg;
                        textColor = AppColors.moodRed;
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius:
                              BorderRadius.circular(AppRadius.small),
                        ),
                        child: Text(
                          reason,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 20, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Module D — Participation leaderboard
  // ============================================================

  Widget _buildLeaderboard(
      List<Profile> students, List<Checkin> weekCheckins) {
    // Group checkins by student
    final studentCheckins = <String, List<Checkin>>{};
    for (final c in weekCheckins) {
      studentCheckins.putIfAbsent(c.studentId, () => []).add(c);
    }

    // Build ranking data
    final rankings = <_RankingItem>[];
    for (final student in students) {
      final checkins = studentCheckins[student.id] ?? [];
      final checkinCount = checkins.length;
      final checkedDays = checkins
          .map((c) =>
              DateTime(c.checkedAt.year, c.checkedAt.month, c.checkedAt.day))
          .toSet();

      // Calculate consecutive days (ending at today, counting backward)
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      int consecutive = 0;
      DateTime checkDay = today;
      while (checkedDays.contains(checkDay)) {
        consecutive++;
        checkDay = checkDay.subtract(const Duration(days: 1));
      }

      rankings.add(_RankingItem(
        student: student,
        checkinCount: checkinCount,
        consecutiveDays: consecutive,
      ));
    }

    // Sort by checkin count descending
    rankings.sort((a, b) => b.checkinCount.compareTo(a.checkinCount));

    final displayCount = _showAllRanking ? rankings.length : 10;
    final displayList = rankings.take(displayCount).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '打卡排行榜',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          if (rankings.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Text(
                  '暂无打卡数据',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else ...[
            ...displayList.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildRankingRow(index + 1, item);
            }),

            // Show expand/collapse button if more than 10
            if (rankings.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showAllRanking = !_showAllRanking;
                      });
                    },
                    child: Text(
                      _showAllRanking ? '收起' : '展开全部',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildRankingRow(int rank, _RankingItem item) {
    // Medal icons for top 3
    String? medalEmoji;
    if (rank == 1) medalEmoji = '\u{1F947}';
    if (rank == 2) medalEmoji = '\u{1F948}';
    if (rank == 3) medalEmoji = '\u{1F949}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Rank number / medal
          SizedBox(
            width: 28,
            child: medalEmoji != null
                ? Text(medalEmoji, style: const TextStyle(fontSize: 18))
                : Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AvatarCircle(avatarKey: item.student.avatarKey, size: 36),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              item.student.nickname,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Checkin count
          Text(
            '${item.checkinCount}次',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Consecutive days
          if (item.consecutiveDays > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.moodGreenBg,
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Text(
                '连续${item.consecutiveDays}天',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.moodGreen,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // Helpers
  // ============================================================

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

// ============================================================
// Data classes
// ============================================================

class _AttentionItem {
  final Profile student;
  final List<String> reasons;

  const _AttentionItem({required this.student, required this.reasons});
}

class _RankingItem {
  final Profile student;
  final int checkinCount;
  final int consecutiveDays;

  const _RankingItem({
    required this.student,
    required this.checkinCount,
    required this.consecutiveDays,
  });
}
