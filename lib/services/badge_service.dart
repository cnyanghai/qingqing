import 'package:flutter/foundation.dart';
import '../models/badge.dart';
import 'supabase_service.dart';

/// Service for checking and awarding badges after check-in
class BadgeService {
  final SupabaseService _supabaseService;

  BadgeService(this._supabaseService);

  /// Check all badge conditions and award any earned badges.
  /// Returns list of newly earned badge keys.
  ///
  /// [distinctQuadrants] and [notesCount] are optional pre-fetched values.
  /// If provided, the service will use them instead of querying the DB,
  /// avoiding duplicate queries when the caller has already fetched these.
  Future<List<String>> checkAndAwardBadges(
    String studentId, {
    required int currentStreak,
    required int totalCheckins,
    String? note,
    int? distinctQuadrants,
    int? notesCount,
  }) async {
    final newBadges = <String>[];
    try {
      final existingBadges = await _supabaseService.getBadges(studentId);
      final earnedKeys = existingBadges.map((b) => b.badgeKey).toSet();

      // first_checkin: first ever check-in
      if (!earnedKeys.contains('first_checkin') && totalCheckins >= 1) {
        final badge =
            await _supabaseService.awardBadge(studentId, 'first_checkin');
        if (badge != null) newBadges.add('first_checkin');
      }

      // streak_7: 7 consecutive days
      if (!earnedKeys.contains('streak_7') && currentStreak >= 7) {
        final badge =
            await _supabaseService.awardBadge(studentId, 'streak_7');
        if (badge != null) newBadges.add('streak_7');
      }

      // streak_30: 30 consecutive days
      if (!earnedKeys.contains('streak_30') && currentStreak >= 30) {
        final badge =
            await _supabaseService.awardBadge(studentId, 'streak_30');
        if (badge != null) newBadges.add('streak_30');
      }

      // explorer: all 4 quadrants recorded
      if (!earnedKeys.contains('explorer')) {
        final qCount = distinctQuadrants ??
            (await _supabaseService.getDistinctQuadrants(studentId)).length;
        if (qCount >= 4) {
          final badge =
              await _supabaseService.awardBadge(studentId, 'explorer');
          if (badge != null) newBadges.add('explorer');
        }
      }

      // writer: 10 or more notes written
      if (!earnedKeys.contains('writer')) {
        final nCount = notesCount ??
            await _supabaseService.countCheckinNotes(studentId);
        if (nCount >= 10) {
          final badge =
              await _supabaseService.awardBadge(studentId, 'writer');
          if (badge != null) newBadges.add('writer');
        }
      }
    } catch (e) {
      debugPrint('Badge check error: $e');
    }

    return newBadges;
  }

  /// Get badge display info
  BadgeInfo? getBadgeInfo(String badgeKey) {
    return Badge.allBadges[badgeKey];
  }
}
