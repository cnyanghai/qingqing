import 'supabase_service.dart';

/// Service for calculating and updating streaks
class StreakService {
  final SupabaseService _supabaseService;

  StreakService(this._supabaseService);

  /// Calculate and update streak after a new check-in
  Future<int> updateStreak(String studentId) async {
    try {
      final streak = await _supabaseService.calculateStreak(studentId);

      // Get current longest streak
      final profile = await _supabaseService.getProfile(studentId);
      final currentLongest = profile?.longestStreak ?? 0;
      final newLongest = streak > currentLongest ? streak : currentLongest;

      // Get current total
      final currentTotal = profile?.totalCheckins ?? 0;

      // Update profile
      await _supabaseService.updateProfile(studentId, {
        'streak': streak,
        'longest_streak': newLongest,
        'total_checkins': currentTotal + 1,
      });

      return streak;
    } catch (e) {
      // Return 0 if calculation fails — not critical
      return 0;
    }
  }
}
