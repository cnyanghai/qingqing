import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/checkin.dart';
import '../../models/classroom.dart';
import '../../models/emotion.dart';
import '../../models/profile.dart';
import '../../providers/teacher_provider.dart';
import '../../services/intervention_service.dart';
import '../../widgets/avatar_picker.dart';
import '../../widgets/mood_calendar.dart';

/// T4: Student detail screen (teacher view)
class StudentDetailScreen extends ConsumerStatefulWidget {
  final String studentId;

  const StudentDetailScreen({super.key, required this.studentId});

  @override
  ConsumerState<StudentDetailScreen> createState() =>
      _StudentDetailScreenState();
}

class _StudentDetailScreenState extends ConsumerState<StudentDetailScreen> {
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<InterventionRecord> _interventions = [];

  @override
  void initState() {
    super.initState();
    _interventions = InterventionService.getRecords(widget.studentId);
  }

  void _refreshInterventions() {
    setState(() {
      _interventions = InterventionService.getRecords(widget.studentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(studentProfileProvider(widget.studentId));
    final checkinsAsync = ref.watch(studentCheckinsProvider(widget.studentId));
    final monthCheckinsAsync = ref.watch(studentMonthCheckinsProvider(
      (studentId: widget.studentId, month: _calendarMonth),
    ));
    final classroomAsync = ref.watch(teacherClassroomProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('学生详情'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('加载失败',
                style: TextStyle(color: AppColors.error)),
          ),
          data: (profile) {
            if (profile == null) {
              return const Center(child: Text('未找到学生资料'));
            }

            final checkins30d = checkinsAsync.valueOrNull ?? [];
            final monthCheckins = monthCheckinsAsync.valueOrNull ?? [];
            final classroom = classroomAsync.valueOrNull;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Student info header
                  _buildStudentHeader(profile, classroom),
                  const SizedBox(height: AppSpacing.lg),

                  // 30-day trend line chart
                  _buildSectionTitle('30天情绪趋势'),
                  const SizedBox(height: AppSpacing.md),
                  _buildLineChart(checkins30d),
                  const SizedBox(height: AppSpacing.lg),

                  // Monthly mood calendar
                  _buildSectionTitle('月度情绪日历'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildMonthSelector(),
                  const SizedBox(height: AppSpacing.md),
                  _buildCalendar(monthCheckins),
                  const SizedBox(height: AppSpacing.lg),

                  // Intervention records
                  _buildSectionTitle('关注记录'),
                  const SizedBox(height: AppSpacing.md),
                  _buildAddInterventionButton(),
                  const SizedBox(height: AppSpacing.md),
                  _buildInterventionList(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStudentHeader(Profile profile, Classroom? classroom) {
    final classInfo = classroom != null ? classroom.displayName : '';

    return Row(
      children: [
        AvatarCircle(avatarKey: profile.avatarKey, size: 56),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile.nickname,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            if (classInfo.isNotEmpty)
              Text(
                classInfo,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textDark,
      ),
    );
  }

  Widget _buildLineChart(List<Checkin> checkins) {
    // Map quadrant to Y value: red=1, blue=2, green=3, yellow=4
    int quadrantToY(String q) {
      switch (q) {
        case 'red':
          return 1;
        case 'blue':
          return 2;
        case 'green':
          return 3;
        case 'yellow':
          return 4;
        default:
          return 2;
      }
    }

    Color quadrantDotColor(String q) {
      return AppColors.quadrantColor(q);
    }

    // Build spots from checkins
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    // Create a date -> checkin map
    final dateCheckins = <String, Checkin>{};
    for (final c in checkins) {
      final key =
          '${c.checkedAt.year}-${c.checkedAt.month.toString().padLeft(2, '0')}-${c.checkedAt.day.toString().padLeft(2, '0')}';
      dateCheckins[key] = c;
    }

    // Build spots for each day that has data
    final spots = <FlSpot>[];
    final spotColors = <int, Color>{};

    for (int i = 0; i <= 30; i++) {
      final date = thirtyDaysAgo.add(Duration(days: i));
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final checkin = dateCheckins[key];
      if (checkin != null) {
        spots.add(FlSpot(i.toDouble(), quadrantToY(checkin.quadrant).toDouble()));
        spotColors[spots.length - 1] = quadrantDotColor(checkin.quadrant);
      }
    }

    if (spots.isEmpty) {
      return Container(
        width: double.infinity,
        height: 200,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        child: const Center(
          child: Text(
            '暂无数据',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: 240,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          minY: 0.5,
          maxY: 4.5,
          minX: 0,
          maxX: 30,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.2,
              color: AppColors.primary.withValues(alpha:0.3),
              barWidth: 2,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final color = spotColors[index] ?? AppColors.primary;
                  return FlDotCirclePainter(
                    radius: 5,
                    color: color,
                    strokeWidth: 2,
                    strokeColor: AppColors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(show: false),
            ),
          ],
          titlesData: FlTitlesData(
            show: true,
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  String label;
                  Color color;
                  switch (value.toInt()) {
                    case 1:
                      label = '有点烦';
                      color = AppColors.moodRed;
                    case 2:
                      label = '不太好';
                      color = AppColors.moodBlue;
                    case 3:
                      label = '平静';
                      color = AppColors.moodGreen;
                    case 4:
                      label = '开心';
                      color = AppColors.moodYellow;
                    default:
                      return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 7,
                getTitlesWidget: (value, meta) {
                  final dayIndex = value.toInt();
                  if (dayIndex < 0 || dayIndex > 30) {
                    return const SizedBox.shrink();
                  }
                  final date = thirtyDaysAgo.add(Duration(days: dayIndex));
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${date.month}/${date.day}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.divider.withValues(alpha:0.5),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    final monthStr = DateFormat('yyyy年M月').format(_calendarMonth);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
          onPressed: () {
            setState(() {
              _calendarMonth = DateTime(
                _calendarMonth.year,
                _calendarMonth.month - 1,
              );
            });
          },
        ),
        Text(
          monthStr,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          onPressed: () {
            final next = DateTime(
              _calendarMonth.year,
              _calendarMonth.month + 1,
            );
            if (!next.isAfter(DateTime.now())) {
              setState(() => _calendarMonth = next);
            }
          },
        ),
      ],
    );
  }

  Widget _buildCalendar(List<Checkin> monthCheckins) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: MoodCalendar(
        month: _calendarMonth,
        checkins: monthCheckins,
        onDayTap: (checkins) {
          _showCheckinDetail(checkins);
        },
      ),
    );
  }

  void _showCheckinDetail(List<Checkin> checkins) {
    if (checkins.isEmpty) return;

    final firstCheckin = checkins.first;
    final dateTitle = '${firstCheckin.checkedAt.month}月${firstCheckin.checkedAt.day}日';
    final countSuffix = checkins.length > 1 ? ' \u00b7 ${checkins.length}条记录' : '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.quadrantColor(firstCheckin.quadrant),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$dateTitle$countSuffix',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: checkins.asMap().entries.map((entry) {
              final index = entry.key;
              final checkin = entry.value;
              final emojis = EmotionData.getEmojis(checkin.emotionLabel);
              final displayText = EmotionData.getDisplayText(checkin.emotionLabel);
              final contextLabel = EmotionData.contextLabel(checkin.contextTag);

              // Extract time from created_at
              final timeStr = checkin.createdAt != null
                  ? '${checkin.createdAt!.hour.toString().padLeft(2, '0')}:${checkin.createdAt!.minute.toString().padLeft(2, '0')}'
                  : '';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (index > 0)
                    const Divider(height: 16, color: AppColors.divider),
                  if (timeStr.isNotEmpty)
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint,
                      ),
                    ),
                  if (timeStr.isNotEmpty)
                    const SizedBox(height: 4),
                  Text(
                    '$emojis $displayText',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '场景: $contextLabel',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                  if (checkin.note != null && checkin.note!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '学生留言:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            checkin.note!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildAddInterventionButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _showAddInterventionDialog,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('添加关注记录'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.large),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  void _showAddInterventionDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        title: const Text('添加关注记录'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 200,
          decoration: InputDecoration(
            hintText: '记录与学生的沟通情况...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                await InterventionService.addRecord(widget.studentId, text);
                _refreshInterventions();
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('记录已保存')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Widget _buildInterventionList() {
    if (_interventions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        child: const Center(
          child: Text(
            '暂无关注记录',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Column(
      children: _interventions.map((record) {
        final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(record.createdAt);

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha:0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                record.content,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
