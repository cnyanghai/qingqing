// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/checkin.dart';
import '../../models/classroom.dart';
import '../../models/profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/teacher_provider.dart';
import '../../widgets/avatar_picker.dart';

/// T2: Teacher dashboard screen
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isExporting = false;

  Future<void> _handleExport(String classroomId, String range) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final service = ref.read(supabaseServiceProvider);

      // Calculate date range
      final now = DateTime.now();
      DateTime startDate;
      if (range == 'week') {
        startDate = now.subtract(Duration(days: now.weekday - 1));
      } else {
        startDate = DateTime(now.year, now.month, 1);
      }

      // Fetch data
      final checkins = await service.getClassCheckinsRange(
        classroomId,
        startDate: startDate,
        endDate: now,
      );

      if (checkins.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('该时间段暂无记录')),
          );
        }
        return;
      }

      // Build student nickname map
      final students = await service.getClassStudents(classroomId);
      final nicknameMap = <String, String>{};
      for (final s in students) {
        nicknameMap[s.id] = s.nickname;
      }

      // Build CSV with BOM for Excel compatibility
      final buffer = StringBuffer('\uFEFF');
      buffer.writeln('学生昵称,日期,时间,情绪象限,具体情绪,场景,备注');

      for (final c in checkins) {
        final nickname = _escapeCsv(nicknameMap[c.studentId] ?? '未知');
        final date = DateFormat('yyyy-MM-dd').format(c.checkedAt);
        final time = c.createdAt != null
            ? DateFormat('HH:mm').format(c.createdAt!)
            : '-';
        final quadrant = _escapeCsv(c.quadrant);
        final emotion = _escapeCsv(c.emotionLabel);
        final context = _escapeCsv(c.contextTag);
        final note = _escapeCsv(c.note ?? '');
        buffer.writeln('$nickname,$date,$time,$quadrant,$emotion,$context,$note');
      }

      // Trigger browser download
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final rangeLabel = range == 'week' ? '周报' : '月报';
      final fileName = '晴晴_班级${rangeLabel}_$dateStr.csv';

      final bytes = utf8.encode(buffer.toString());
      final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导出成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  /// Escape CSV field: wrap in quotes if it contains comma, quote, or newline
  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  void _showExportOptions(String classroomId) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('导出本周数据'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleExport(classroomId, 'week');
                },
              ),
              ListTile(
                leading: const Icon(Icons.date_range),
                title: const Text('导出本月数据'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleExport(classroomId, 'month');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final classroomAsync = ref.watch(teacherClassroomProvider);
    final studentsAsync = ref.watch(classStudentsProvider);
    final todayCheckinsAsync = ref.watch(todayClassCheckinsProvider);
    final weekCheckinsAsync = ref.watch(weekClassCheckinsProvider);
    final recentCheckinsAsync = ref.watch(studentRecentCheckinsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('加载失败', style: TextStyle(color: AppColors.error)),
          ),
          data: (profile) {
            if (profile == null) {
              return const Center(child: Text('未找到教师资料'));
            }

            final classroom = classroomAsync.valueOrNull;
            final students = studentsAsync.valueOrNull ?? [];
            final todayCheckins = todayCheckinsAsync.valueOrNull ?? [];
            final weekCheckins = weekCheckinsAsync.valueOrNull ?? [];
            final recentCheckins = recentCheckinsAsync.valueOrNull ?? {};

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: teacher info + export button
                  _buildHeader(profile, classroom),
                  const SizedBox(height: AppSpacing.lg),

                  // "Today overview" section header
                  _buildOverviewHeader(),
                  const SizedBox(height: AppSpacing.md),

                  // Pie chart card or empty state
                  if (todayCheckins.isEmpty)
                    _buildEmptyState()
                  else ...[
                    _buildPieChartCard(todayCheckins),
                    const SizedBox(height: AppSpacing.md),

                    // Alert card
                    _buildAlertCard(
                      context,
                      students: students,
                      todayCheckins: todayCheckins,
                      recentCheckins: recentCheckins,
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  // Weekly trend
                  const Text(
                    '本周情绪趋势',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildWeeklyTrend(weekCheckins),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(Profile profile, Classroom? classroom) {
    final classDisplay = classroom != null
        ? '${classroom.displayName} 班主任'
        : '班主任';

    return Row(
      children: [
        AvatarCircle(avatarKey: profile.avatarKey, size: 52),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${profile.nickname}老师',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                classDisplay,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        // Export button
        if (classroom != null)
          _isExporting
              ? const SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.file_download,
                      color: AppColors.textSecondary),
                  tooltip: '导出数据',
                  onPressed: () => _showExportOptions(classroom.id),
                )
        else
          const SizedBox(width: 48), // 保持布局平衡
      ],
    );
  }

  Widget _buildOverviewHeader() {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy年M月d日').format(now);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          '今日概览',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.moodBlueBg,
            borderRadius: BorderRadius.circular(AppRadius.round),
          ),
          child: Text(
            dateStr,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: Column(
        children: [
          const Icon(Icons.sentiment_satisfied_alt,
              size: 48, color: AppColors.textHint),
          const SizedBox(height: AppSpacing.md),
          const Text(
            '今天还没有同学记录心情哦',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartCard(List<Checkin> todayCheckins) {
    // Count by quadrant
    final counts = <String, int>{
      'yellow': 0,
      'green': 0,
      'red': 0,
      'blue': 0,
    };
    for (final c in todayCheckins) {
      counts[c.quadrant] = (counts[c.quadrant] ?? 0) + 1;
    }

    final total = todayCheckins.length;
    final studentCount = todayCheckins.map((c) => c.studentId).toSet().length;

    // Calculate percentages
    String pct(int count) {
      if (total == 0) return '0%';
      return '${(count / total * 100).round()}%';
    }

    final sections = <PieChartSectionData>[];
    final legendItems = <_LegendItem>[];

    final quadrantInfo = [
      ('yellow', '高能量·舒服', AppColors.moodYellow, counts['yellow'] ?? 0),
      ('green', '低能量·舒服', AppColors.moodGreen, counts['green'] ?? 0),
      ('red', '高能量·不舒服', AppColors.moodRed, counts['red'] ?? 0),
      ('blue', '低能量·不舒服', AppColors.moodBlue, counts['blue'] ?? 0),
    ];

    for (final info in quadrantInfo) {
      final count = info.$4;
      if (count > 0) {
        sections.add(PieChartSectionData(
          color: info.$3,
          value: count.toDouble(),
          title: '',
          radius: 28,
        ));
      }
      legendItems.add(_LegendItem(
        color: info.$3,
        label: info.$2,
        percentage: pct(count),
      ));
    }

    // If no sections, add a placeholder grey
    if (sections.isEmpty) {
      sections.add(PieChartSectionData(
        color: AppColors.divider,
        value: 1,
        title: '',
        radius: 28,
      ));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Pie chart with center label
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 42,
                    sectionsSpace: 2,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$studentCount',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const Text(
                      '人打卡',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '共$total条记录',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          // Legend and title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '班级情绪分布',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  children: legendItems
                      .map((item) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: item.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${item.label}(${item.percentage})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(
    BuildContext context, {
    required List<Profile> students,
    required List<Checkin> todayCheckins,
    required Map<String, List<Checkin>> recentCheckins,
  }) {
    // Alert rule 1: students with 3 consecutive blue days
    final alertStudents = <Profile>[];
    for (final student in students) {
      final checkins = recentCheckins[student.id] ?? [];
      if (_hasConsecutiveBlueDays(checkins, 3)) {
        alertStudents.add(student);
      }
    }

    // Alert rule 2: class alert if red+blue > 40% today
    final total = todayCheckins.length;
    bool classAlert = false;
    if (total > 0) {
      final redBlue = todayCheckins
          .where((c) => c.quadrant == 'red' || c.quadrant == 'blue')
          .length;
      classAlert = (redBlue / total) > 0.4;
    }

    if (alertStudents.isEmpty && !classAlert) {
      return const SizedBox.shrink();
    }

    // Build alert message
    final isUrgent = alertStudents.length >= 3 || classAlert;
    final borderColor = isUrgent ? AppColors.moodRed : AppColors.moodYellow;

    String alertMessage;
    if (alertStudents.isNotEmpty) {
      const displayCount = 2;
      final names = alertStudents.take(displayCount).map((s) => s.nickname).join('\u3001');
      final remaining = alertStudents.length - displayCount;
      final remainingSuffix = remaining > 0 ? '等$remaining位同学' : '';
      alertMessage = '$names$remainingSuffix今日情绪波动较大，建议午间进行心理疏导。';
    } else {
      alertMessage = '今日红色和蓝色情绪占比超过40%，建议关注班级整体情绪状态。';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.moodYellowBg,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border(
          left: BorderSide(color: borderColor, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '\u26A0\uFE0F 需要关注',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (isUrgent)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.moodRed,
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: const Text(
                    '紧急',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            alertMessage,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          GestureDetector(
            onTap: () => context.go('/teacher/students'),
            child: const Text(
              '立即处理 >',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasConsecutiveBlueDays(List<Checkin> checkins, int requiredDays) {
    if (checkins.length < requiredDays) return false;

    // Sort by date descending
    final sorted = List<Checkin>.from(checkins)
      ..sort((a, b) {
        final d = b.checkedAt.compareTo(a.checkedAt);
        return d != 0
            ? d
            : (b.createdAt ?? DateTime(0))
                .compareTo(a.createdAt ?? DateTime(0));
      });

    // 按日期去重：每个学生每天只保留第一条（列表已按created_at倒序，第一条即最新）
    final seen = <String>{};
    final deduped = <Checkin>[];
    for (final c in sorted) {
      final key = '${c.studentId}_${c.checkedAt.year}-${c.checkedAt.month}-${c.checkedAt.day}';
      if (seen.add(key)) deduped.add(c);
    }

    int consecutive = 0;
    DateTime? previousDate;

    for (final checkin in deduped) {
      if (checkin.quadrant == 'blue') {
        if (previousDate == null) {
          consecutive = 1;
        } else {
          final diff = previousDate.difference(checkin.checkedAt).inDays;
          if (diff <= 1) {
            consecutive++;
          } else {
            consecutive = 1;
          }
        }
        if (consecutive >= requiredDays) return true;
        previousDate = checkin.checkedAt;
      } else {
        consecutive = 0;
        previousDate = null;
      }
    }
    return false;
  }

  Widget _buildWeeklyTrend(List<Checkin> weekCheckins) {
    // Group checkins by weekday
    final weekdayData = <int, List<Checkin>>{};
    for (int i = 1; i <= 7; i++) {
      weekdayData[i] = [];
    }
    for (final c in weekCheckins) {
      final wd = c.checkedAt.weekday;
      weekdayData[wd]?.add(c);
    }

    final dayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend
          Row(
            children: [
              _legendDot(AppColors.moodBlue, '低'),
              const SizedBox(width: AppSpacing.sm),
              _legendDot(AppColors.primary, '高'),
              const Spacer(),
              const Text(
                '正面情绪指数',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Bar chart
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 1.0,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
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
                      reservedSize: 28,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                barGroups: List.generate(7, (i) {
                  final wd = i + 1;
                  final dayCheckins = weekdayData[wd] ?? [];
                  if (dayCheckins.isEmpty) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: 0.05,
                          color: AppColors.divider,
                          width: 28,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6)),
                        ),
                      ],
                    );
                  }

                  final positiveCount = dayCheckins
                      .where((c) =>
                          c.quadrant == 'yellow' || c.quadrant == 'green')
                      .length;
                  final negativeCount = dayCheckins
                      .where((c) =>
                          c.quadrant == 'red' || c.quadrant == 'blue')
                      .length;
                  final total = dayCheckins.length;
                  final positiveRatio = positiveCount / total;
                  final negativeRatio = negativeCount / total;

                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: max(0.05, positiveRatio + negativeRatio),
                        width: 28,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                        rodStackItems: [
                          BarChartRodStackItem(
                              0, negativeRatio, AppColors.moodBlue),
                          BarChartRodStackItem(negativeRatio,
                              negativeRatio + positiveRatio, AppColors.primary),
                        ],
                        color: Colors.transparent,
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
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
}

class _LegendItem {
  final Color color;
  final String label;
  final String percentage;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.percentage,
  });
}
