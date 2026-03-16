import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../models/checkin.dart';
import '../../models/emotion.dart';
import '../../providers/checkin_provider.dart';
import '../../widgets/mood_calendar.dart';
import '../../widgets/semester_overview.dart';

/// S6: Emotion calendar screen
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  void _previousMonth() {
    setState(() {
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final checkinsAsync = ref.watch(monthCheckinsProvider(_currentMonth));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '情绪追踪器',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48), // 保持布局平衡
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              // Month navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _previousMonth,
                  ),
                  Text(
                    '${_currentMonth.year}年${_currentMonth.month}月',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _nextMonth,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Calendar
              Container(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Legend row
                    Row(
                      children: [
                        const Text(
                          '每日进度',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        const Spacer(),
                        _legendDot(AppColors.moodRed, '高能量·不舒服'),
                        _legendDot(AppColors.moodYellow, '高能量·舒服'),
                        _legendDot(AppColors.moodGreen, '低能量·舒服'),
                        _legendDot(AppColors.moodBlue, '低能量·不舒服'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    checkinsAsync.when(
                      loading: () => const Center(
                          child: CircularProgressIndicator()),
                      error: (e, _) => Text('加载失败',
                          style: TextStyle(color: AppColors.error)),
                      data: (checkins) => MoodCalendar(
                        month: _currentMonth,
                        checkins: checkins,
                        onDayTap: (checkins) {
                          _showCheckinDetail(checkins);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Selected day detail is shown via bottom sheet (see onDayTap)
              const SizedBox(height: AppSpacing.md),
              // Semester overview entry
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showSemesterOverview(context),
                  child: const Text(
                    '查看学期概览 \u2192',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Monthly distribution
              checkinsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (checkins) =>
                    _buildDistribution(checkins),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Encouragement card
              _buildEncouragement(),
            ],
          ),
        ),
      ),
    );
  }

  void _showCheckinDetail(List<Checkin> checkins) {
    if (checkins.isEmpty) return;

    final firstCheckin = checkins.first;
    // Weekday names
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final weekday = weekdays[firstCheckin.checkedAt.weekday - 1];

    // Title: date + record count (don't show "1条记录" for single record)
    final dateTitle = '${firstCheckin.checkedAt.year}年${firstCheckin.checkedAt.month}月${firstCheckin.checkedAt.day}日 $weekday';
    final countSuffix = checkins.length > 1 ? ' \u00b7 ${checkins.length}条记录' : '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xLarge)),
      ),
      backgroundColor: AppColors.white,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: date + close button
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.quadrantColor(firstCheckin.quadrant),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '$dateTitle$countSuffix',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Record list (sorted by created_at descending, newest first)
              ...checkins.asMap().entries.map((entry) {
                final index = entry.key;
                final checkin = entry.value;
                final emojis = EmotionData.getEmojis(checkin.emotionLabel);
                final displayText = EmotionData.getDisplayText(checkin.emotionLabel);
                final contextOption = EmotionData.contextOptions
                    .where((c) => c.key == checkin.contextTag)
                    .toList();
                final contextLabel = contextOption.isNotEmpty
                    ? contextOption.first.label
                    : checkin.contextTag;
                final contextIcon = contextOption.isNotEmpty
                    ? contextOption.first.icon
                    : '';
                final quadrantColor = AppColors.quadrantColor(checkin.quadrant);

                // Extract time from created_at
                final timeStr = checkin.createdAt != null
                    ? '${checkin.createdAt!.hour.toString().padLeft(2, '0')}:${checkin.createdAt!.minute.toString().padLeft(2, '0')}'
                    : '';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (index > 0)
                      const Divider(height: 1, color: AppColors.divider),
                    if (index > 0)
                      const SizedBox(height: AppSpacing.md),
                    // Time label (if available)
                    if (timeStr.isNotEmpty)
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                    if (timeStr.isNotEmpty)
                      const SizedBox(height: AppSpacing.xs),
                    // Emotion row: color dot + emoji + label
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
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            '$emojis $displayText',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // Context tag
                    Row(
                      children: [
                        if (contextIcon.isNotEmpty)
                          Text(contextIcon, style: const TextStyle(fontSize: 14)),
                        if (contextIcon.isNotEmpty)
                          const SizedBox(width: AppSpacing.xs),
                        Text(
                          '场景: $contextLabel',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    // Note (if any)
                    if (checkin.note != null && checkin.note!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                        child: Text(
                          checkin.note!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showSemesterOverview(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xLarge)),
      ),
      backgroundColor: AppColors.white,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '学期概览',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textSecondary),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Semester overview matrix
                  const Expanded(
                    child: SingleChildScrollView(
                      child: SemesterOverview(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _legendDot(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
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
          if (label.isNotEmpty) ...[
            const SizedBox(width: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.textHint),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDistribution(List<Checkin> checkins) {
    if (checkins.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        child: const Center(
          child: Text(
            '本月还没有记录',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    // Count per quadrant
    final counts = <String, int>{};
    for (final c in checkins) {
      counts[c.quadrant] = (counts[c.quadrant] ?? 0) + 1;
    }
    final total = checkins.length;

    // Sorted by count descending
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final quadrantLabels = {
      'green': '很平静',
      'blue': '不太好',
      'yellow': '很开心',
      'red': '有点烦',
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '每月情绪分布',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...entries.map((entry) {
            final percent = (entry.value / total * 100).round();
            final color = AppColors.quadrantColor(entry.key);
            final label = quadrantLabels[entry.key] ?? entry.key;

            return Padding(
              padding:
                  const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: entry.value / total,
                      backgroundColor: AppColors.divider,
                      color: color,
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEncouragement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '今日关注',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_outline,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '自我关怀提醒',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '记录心情是了解自己的第一步，坚持下去，你会发现更好的自己。',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
