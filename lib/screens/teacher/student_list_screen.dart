import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/checkin.dart';
import '../../models/profile.dart';
import '../../providers/teacher_provider.dart';
import '../../widgets/avatar_picker.dart';

/// Sort mode for student list
enum _SortMode { latest, name }

/// T3: Student list screen
class StudentListScreen extends ConsumerStatefulWidget {
  const StudentListScreen({super.key});

  @override
  ConsumerState<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends ConsumerState<StudentListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _SortMode _sortMode = _SortMode.latest;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(classStudentsProvider);
    final recentCheckinsAsync = ref.watch(studentRecentCheckinsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
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
                  const Text(
                    '学生名单',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.filter_list,
                        color: AppColors.textSecondary),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('筛选功能即将推出')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Search box
              TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() => _searchQuery = value.trim().toLowerCase());
                },
                decoration: InputDecoration(
                  hintText: '按姓名或昵称搜索...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.large),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Student list content
              Expanded(
                child: studentsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text('加载失败',
                        style: TextStyle(color: AppColors.error)),
                  ),
                  data: (students) {
                    final recentCheckins =
                        recentCheckinsAsync.valueOrNull ?? {};

                    // Filter by search
                    var filtered = students.where((s) {
                      if (_searchQuery.isEmpty) return true;
                      return s.nickname.toLowerCase().contains(_searchQuery);
                    }).toList();

                    // Sort
                    if (_sortMode == _SortMode.latest) {
                      filtered.sort((a, b) {
                        final aCheckins = recentCheckins[a.id] ?? [];
                        final bCheckins = recentCheckins[b.id] ?? [];
                        final aLatest = aCheckins.isNotEmpty
                            ? aCheckins
                                .map((c) => c.checkedAt)
                                .reduce((a, b) => a.isAfter(b) ? a : b)
                            : DateTime(2000);
                        final bLatest = bCheckins.isNotEmpty
                            ? bCheckins
                                .map((c) => c.checkedAt)
                                .reduce((a, b) => a.isAfter(b) ? a : b)
                            : DateTime(2000);
                        return bLatest.compareTo(aLatest);
                      });
                    } else {
                      filtered.sort(
                          (a, b) => a.nickname.compareTo(b.nickname));
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Count and sort toggle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '活跃学生 (${filtered.length})',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _sortMode =
                                      _sortMode == _SortMode.latest
                                          ? _SortMode.name
                                          : _SortMode.latest;
                                });
                              },
                              child: Text(
                                '排序: ${_sortMode == _SortMode.latest ? '最新' : '姓名'}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Student cards
                        Expanded(
                          child: filtered.isEmpty
                              ? const Center(
                                  child: Text(
                                    '暂无学生',
                                    style: TextStyle(
                                        color: AppColors.textSecondary),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: AppSpacing.sm),
                                  itemBuilder: (context, index) {
                                    final student = filtered[index];
                                    final checkins =
                                        recentCheckins[student.id] ?? [];
                                    return _StudentCard(
                                      student: student,
                                      recentCheckins: checkins,
                                      onTap: () {
                                        context.push(
                                            '/teacher/students/${student.id}');
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Individual student card in the list
class _StudentCard extends StatelessWidget {
  final Profile student;
  final List<Checkin> recentCheckins;
  final VoidCallback onTap;

  const _StudentCard({
    required this.student,
    required this.recentCheckins,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusInfo = _getStatusInfo();
    final activityDot = _getActivityDot();
    final last7DaysColors = _getLast7DaysColors();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.large),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar with status dot
            Stack(
              children: [
                AvatarCircle(avatarKey: student.avatarKey, size: 52),
                Positioned(
                  bottom: 2,
                  left: 2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: activityDot,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),

            // Middle: name + 7-day colors
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.nickname,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // 7-day color blocks
                      ...last7DaysColors.map((dayColors) {
                        if (dayColors.length == 1) {
                          // Single color: standard 16x16 block
                          return Container(
                            width: 16,
                            height: 16,
                            margin: const EdgeInsets.only(right: 3),
                            decoration: BoxDecoration(
                              color: dayColors.first,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }
                        // Multiple colors: side-by-side small blocks
                        final displayColors = dayColors.take(3).toList();
                        final blockWidth = 16.0 / displayColors.length;
                        return Container(
                          width: 16,
                          height: 16,
                          margin: const EdgeInsets.only(right: 3),
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Row(
                            children: displayColors.map((color) {
                              return SizedBox(
                                width: blockWidth,
                                height: 16,
                                child: ColoredBox(color: color),
                              );
                            }).toList(),
                          ),
                        );
                      }),
                      const SizedBox(width: 6),
                      const Text(
                        '情绪历史',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Right: status tag + arrow
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusInfo.bgColor,
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: Text(
                    statusInfo.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusInfo.textColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Icon(Icons.chevron_right,
                    size: 20, color: AppColors.textHint),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Get activity dot color:
  /// green = checked today, yellow = checked yesterday, red = 3+ days no checkin
  Color _getActivityDot() {
    if (recentCheckins.isEmpty) return AppColors.moodRed;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    bool checkedToday = false;
    bool checkedYesterday = false;

    for (final c in recentCheckins) {
      final d = DateTime(c.checkedAt.year, c.checkedAt.month, c.checkedAt.day);
      if (d == today) checkedToday = true;
      if (d == today.subtract(const Duration(days: 1))) {
        checkedYesterday = true;
      }
    }

    if (checkedToday) return AppColors.moodGreen;
    if (checkedYesterday) return AppColors.moodYellow;
    return AppColors.moodRed;
  }

  /// Get status: 3 consecutive blue = warning, 2 consecutive blue = attention, else normal
  _StatusInfo _getStatusInfo() {
    final sorted = List<Checkin>.from(recentCheckins)
      ..sort((a, b) => b.checkedAt.compareTo(a.checkedAt));
    // 按日期去重：每天只保留最新一条
    final seen = <String>{};
    final deduped = sorted.where((c) {
      final key = '${c.checkedAt.year}-${c.checkedAt.month}-${c.checkedAt.day}';
      return seen.add(key);
    }).toList();

    int consecutiveBlue = 0;
    for (final c in deduped) {
      if (c.quadrant == 'blue') {
        consecutiveBlue++;
      } else {
        break;
      }
    }

    if (consecutiveBlue >= 3) {
      return _StatusInfo(
        label: '警告',
        bgColor: const Color(0xFFFFE8E8),
        textColor: AppColors.moodRed,
      );
    }
    if (consecutiveBlue >= 2) {
      return _StatusInfo(
        label: '待关注',
        bgColor: const Color(0xFFFFF3CD),
        textColor: const Color(0xFFB8860B),
      );
    }
    return _StatusInfo(
      label: '正常',
      bgColor: const Color(0xFFE8F5E9),
      textColor: AppColors.moodGreen,
    );
  }

  /// Get last 7 days mood color blocks (each day may have multiple colors)
  List<List<Color>> _getLast7DaysColors() {
    final now = DateTime.now();
    final last7DaysColors = <List<Color>>[];

    // Build a date -> list of quadrants map
    final dateMap = <String, List<String>>{};
    for (final c in recentCheckins) {
      final key =
          '${c.checkedAt.year}-${c.checkedAt.month.toString().padLeft(2, '0')}-${c.checkedAt.day.toString().padLeft(2, '0')}';
      dateMap.putIfAbsent(key, () => []).add(c.quadrant);
    }

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final quadrants = dateMap[key];
      if (quadrants != null && quadrants.isNotEmpty) {
        // Take at most 3 colors (newest first)
        last7DaysColors.add(
          quadrants.take(3).map((q) => AppColors.quadrantColor(q)).toList(),
        );
      } else {
        last7DaysColors.add([AppColors.divider]);
      }
    }

    return last7DaysColors;
  }
}

class _StatusInfo {
  final String label;
  final Color bgColor;
  final Color textColor;

  const _StatusInfo({
    required this.label,
    required this.bgColor,
    required this.textColor,
  });
}
