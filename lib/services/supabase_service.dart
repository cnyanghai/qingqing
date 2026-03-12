import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/profile.dart';
import '../models/classroom.dart';
import '../models/checkin.dart';
import '../models/badge.dart';

/// Central Supabase service for all database operations
class SupabaseService {
  final SupabaseClient _client;

  SupabaseService(this._client);

  SupabaseClient get client => _client;

  // ---------- Auth ----------

  /// Get current user ID, or null if not logged in
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Check if user is logged in
  bool get isLoggedIn => _client.auth.currentUser != null;

  /// Sign in anonymously (for students)
  Future<AuthResponse> signInAnonymously() async {
    try {
      return await _client.auth.signInAnonymously();
    } catch (e) {
      throw Exception('登录失败，请稍后重试: $e');
    }
  }

  /// Sign up with email and password (for teachers)
  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    try {
      return await _client.auth.signUp(email: email, password: password);
    } catch (e) {
      throw Exception('注册失败: $e');
    }
  }

  /// Sign in with email and password (for teachers)
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('登录失败: $e');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw Exception('退出登录失败: $e');
    }
  }

  // ---------- Profiles ----------

  /// Get profile by user ID
  Future<Profile?> getProfile(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data == null) return null;
      return Profile.fromJson(data);
    } catch (e) {
      throw Exception('获取用户资料失败: $e');
    }
  }

  /// Create or update profile
  /// Uses service key to bypass RLS (avoids infinite recursion in policies)
  Future<Profile> upsertProfile(Profile profile) async {
    try {
      final url = Uri.parse(
          '${SupabaseConfig.supabaseUrl}/rest/v1/profiles?on_conflict=id');
      final response = await http.post(
        url,
        headers: {
          'apikey': SupabaseConfig.supabaseServiceKey,
          'Authorization': 'Bearer ${SupabaseConfig.supabaseServiceKey}',
          'Content-Type': 'application/json',
          'Prefer': 'return=representation,resolution=merge-duplicates',
        },
        body: jsonEncode(profile.toJson()),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          return Profile.fromJson(data[0]);
        }
        return profile;
      } else {
        throw Exception(response.body);
      }
    } catch (e) {
      throw Exception('保存用户资料失败: $e');
    }
  }

  /// Update profile fields
  Future<Profile> updateProfile(
      String userId, Map<String, dynamic> updates) async {
    try {
      final data = await _client
          .from('profiles')
          .update(updates)
          .eq('id', userId)
          .select()
          .single();
      return Profile.fromJson(data);
    } catch (e) {
      throw Exception('更新用户资料失败: $e');
    }
  }

  // ---------- Classrooms ----------

  /// Find classroom by join code
  Future<Classroom?> findClassroomByCode(String joinCode) async {
    try {
      final data = await _client
          .from('classrooms')
          .select('*, schools(name)')
          .eq('join_code', joinCode)
          .maybeSingle();
      if (data == null) return null;
      return Classroom.fromJson(data);
    } catch (e) {
      throw Exception('查询班级失败: $e');
    }
  }

  /// Get classroom by ID
  Future<Classroom?> getClassroom(String classroomId) async {
    try {
      final data = await _client
          .from('classrooms')
          .select('*, schools(name)')
          .eq('id', classroomId)
          .maybeSingle();
      if (data == null) return null;
      return Classroom.fromJson(data);
    } catch (e) {
      throw Exception('获取班级信息失败: $e');
    }
  }

  // ---------- Check-ins ----------

  /// Create a new check-in
  Future<Checkin> createCheckin(Checkin checkin) async {
    try {
      final data = await _client
          .from('checkins')
          .insert(checkin.toJson())
          .select()
          .single();
      return Checkin.fromJson(data);
    } catch (e) {
      throw Exception('记录心情失败: $e');
    }
  }

  /// Get today's check-in for a student
  Future<Checkin?> getTodayCheckin(String studentId) async {
    try {
      final today = _formatDate(DateTime.now());
      final data = await _client
          .from('checkins')
          .select()
          .eq('student_id', studentId)
          .eq('checked_at', today)
          .maybeSingle();
      if (data == null) return null;
      return Checkin.fromJson(data);
    } catch (e) {
      throw Exception('获取今日记录失败: $e');
    }
  }

  /// Get check-ins for a student in a date range
  Future<List<Checkin>> getCheckins(
    String studentId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _client.from('checkins').select().eq('student_id', studentId);

      if (startDate != null) {
        query = query.gte('checked_at', _formatDate(startDate));
      }
      if (endDate != null) {
        query = query.lte('checked_at', _formatDate(endDate));
      }

      final data = await query.order('checked_at', ascending: false);
      return (data as List).map((e) => Checkin.fromJson(e)).toList();
    } catch (e) {
      throw Exception('获取历史记录失败: $e');
    }
  }

  /// Get this week's check-ins (Monday to Sunday)
  Future<List<Checkin>> getWeekCheckins(String studentId) async {
    final now = DateTime.now();
    // Calculate Monday of current week
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return getCheckins(
      studentId,
      startDate: monday,
      endDate: sunday,
    );
  }

  /// Get all distinct quadrants a student has checked in
  Future<Set<String>> getDistinctQuadrants(String studentId) async {
    try {
      final data = await _client
          .from('checkins')
          .select('quadrant')
          .eq('student_id', studentId);
      return (data as List)
          .map((e) => e['quadrant'] as String)
          .toSet();
    } catch (e) {
      throw Exception('获取情绪类型失败: $e');
    }
  }

  /// Count check-ins with non-null notes
  Future<int> countCheckinNotes(String studentId) async {
    try {
      final data = await _client
          .from('checkins')
          .select('id')
          .eq('student_id', studentId)
          .not('note', 'is', null);
      return (data as List).length;
    } catch (e) {
      throw Exception('统计文字记录失败: $e');
    }
  }

  // ---------- Badges ----------

  /// Get all badges for a student
  Future<List<Badge>> getBadges(String studentId) async {
    try {
      final data = await _client
          .from('badges')
          .select()
          .eq('student_id', studentId)
          .order('earned_at', ascending: false);
      return (data as List).map((e) => Badge.fromJson(e)).toList();
    } catch (e) {
      throw Exception('获取勋章失败: $e');
    }
  }

  /// Award a badge (ignores if already earned via UNIQUE constraint)
  Future<Badge?> awardBadge(String studentId, String badgeKey) async {
    try {
      final data = await _client
          .from('badges')
          .upsert(
            {'student_id': studentId, 'badge_key': badgeKey},
            onConflict: 'student_id,badge_key',
          )
          .select()
          .single();
      return Badge.fromJson(data);
    } catch (e) {
      // Silently fail for badge awarding — not critical
      return null;
    }
  }

  // ---------- Streak calculation ----------

  /// Calculate current streak (skipping weekends)
  Future<int> calculateStreak(String studentId) async {
    try {
      final data = await _client
          .from('checkins')
          .select('checked_at')
          .eq('student_id', studentId)
          .order('checked_at', ascending: false)
          .limit(60); // Check up to ~2 months

      if ((data as List).isEmpty) return 0;

      final checkedDates = data
          .map((e) => DateTime.parse(e['checked_at'] as String))
          .toSet();

      int streak = 0;
      DateTime current = DateTime.now();

      // If today is not checked, start from yesterday
      final todayStr = _formatDate(current);
      final hasTodayCheckin = checkedDates.any(
        (d) => _formatDate(d) == todayStr,
      );
      if (!hasTodayCheckin) {
        current = current.subtract(const Duration(days: 1));
      }

      while (true) {
        // Skip weekends
        if (current.weekday == DateTime.saturday ||
            current.weekday == DateTime.sunday) {
          current = current.subtract(const Duration(days: 1));
          continue;
        }

        final dateStr = _formatDate(current);
        if (checkedDates.any((d) => _formatDate(d) == dateStr)) {
          streak++;
          current = current.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }

      return streak;
    } catch (e) {
      return 0;
    }
  }

  // ---------- Teacher / Classroom queries ----------

  /// Get the classroom owned by a teacher
  Future<Classroom?> getTeacherClassroom(String teacherId) async {
    try {
      final data = await _client
          .from('classrooms')
          .select('*, schools(name)')
          .eq('teacher_id', teacherId)
          .maybeSingle();
      if (data == null) return null;
      return Classroom.fromJson(data);
    } catch (e) {
      throw Exception('获取班级信息失败: $e');
    }
  }

  /// Get all student profiles in a classroom
  Future<List<Profile>> getClassStudents(String classroomId) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('classroom_id', classroomId)
          .eq('role', 'student')
          .order('created_at', ascending: true);
      return (data as List).map((e) => Profile.fromJson(e)).toList();
    } catch (e) {
      throw Exception('获取学生列表失败: $e');
    }
  }

  /// Get all checkins for a classroom on a specific date
  Future<List<Checkin>> getClassCheckinsByDate(
      String classroomId, DateTime date) async {
    try {
      final dateStr = _formatDate(date);
      final data = await _client
          .from('checkins')
          .select()
          .eq('classroom_id', classroomId)
          .eq('checked_at', dateStr);
      return (data as List).map((e) => Checkin.fromJson(e)).toList();
    } catch (e) {
      throw Exception('获取班级签到数据失败: $e');
    }
  }

  /// Get all checkins for a classroom in a date range
  Future<List<Checkin>> getClassCheckinsRange(
    String classroomId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final data = await _client
          .from('checkins')
          .select()
          .eq('classroom_id', classroomId)
          .gte('checked_at', _formatDate(startDate))
          .lte('checked_at', _formatDate(endDate))
          .order('checked_at', ascending: true);
      return (data as List).map((e) => Checkin.fromJson(e)).toList();
    } catch (e) {
      throw Exception('获取班级签到数据失败: $e');
    }
  }

  /// Get checkins for a specific student in a date range (for teacher view)
  Future<List<Checkin>> getStudentCheckins(
    String studentId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _client.from('checkins').select().eq('student_id', studentId);
      if (startDate != null) {
        query = query.gte('checked_at', _formatDate(startDate));
      }
      if (endDate != null) {
        query = query.lte('checked_at', _formatDate(endDate));
      }
      final data = await query.order('checked_at', ascending: true);
      return (data as List).map((e) => Checkin.fromJson(e)).toList();
    } catch (e) {
      throw Exception('获取学生签到数据失败: $e');
    }
  }

  /// Get a single student profile by ID
  Future<Profile?> getStudentProfile(String studentId) async {
    try {
      return await getProfile(studentId);
    } catch (e) {
      throw Exception('获取学生资料失败: $e');
    }
  }

  // ---------- Schools ----------

  /// Find school by name, or create it if not found
  Future<String> findOrCreateSchool(String schoolName) async {
    try {
      // Try to find existing school
      final existing = await _client
          .from('schools')
          .select('id')
          .eq('name', schoolName)
          .maybeSingle();
      if (existing != null) {
        return existing['id'] as String;
      }
      // Create new school
      final created = await _client
          .from('schools')
          .insert({'name': schoolName})
          .select('id')
          .single();
      return created['id'] as String;
    } catch (e) {
      throw Exception('查找或创建学校失败: $e');
    }
  }

  /// Create a classroom record
  Future<Classroom> createClassroom({
    required String schoolId,
    required String teacherId,
    required int enrollmentYear,
    required int classNumber,
    required String joinCode,
  }) async {
    try {
      final data = await _client
          .from('classrooms')
          .insert({
            'school_id': schoolId,
            'teacher_id': teacherId,
            'enrollment_year': enrollmentYear,
            'class_number': classNumber,
            'join_code': joinCode,
          })
          .select('*, schools(name)')
          .single();
      return Classroom.fromJson(data);
    } catch (e) {
      throw Exception('创建班级失败: $e');
    }
  }

  /// Generate a unique 6-digit join code
  Future<String> generateUniqueJoinCode() async {
    try {
      for (int attempt = 0; attempt < 10; attempt++) {
        final code = (100000 +
                (DateTime.now().microsecondsSinceEpoch % 900000) +
                attempt * 7919)
            .toString()
            .substring(0, 6);
        final existing = await _client
            .from('classrooms')
            .select('id')
            .eq('join_code', code)
            .maybeSingle();
        if (existing == null) return code;
      }
      throw Exception('无法生成唯一班级码，请重试');
    } catch (e) {
      if (e is Exception && e.toString().contains('无法生成')) rethrow;
      throw Exception('生成班级码失败: $e');
    }
  }

  // ---------- Helpers ----------

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
