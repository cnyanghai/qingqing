import '../models/checkin.dart';
import '../models/garden.dart';

/// 花园状态计算服务
class GardenService {
  GardenService._();

  /// 计算花园完整状态
  ///
  /// 所有参数由调用方预获取后传入，避免重复查询：
  /// - [totalCheckins] 和 [streak] 来自 profileProvider
  /// - [notesCount] 来自 countCheckinNotes（仅调用1次）
  /// - [distinctQuadrants] 来自 getDistinctQuadrants（仅调用1次）
  /// - [recentCheckins] 用于提取花朵列表
  /// - [distinctContexts] 来自 checkin 的 contextTag 去重计数（可选，用于场景装饰）
  static GardenState calculateState({
    required int totalCheckins,
    required int streak,
    required int notesCount,
    required int distinctQuadrants,
    required List<Checkin> recentCheckins,
    int distinctContexts = 0,
    int maxSameDayQuadrants = 0,
  }) {
    // 1. 提取花朵列表
    final flowers = recentCheckins.map((c) {
      return FlowerEntry(
        quadrant: c.quadrant,
        plantedAt: c.createdAt ?? c.checkedAt,
      );
    }).toList();

    // 2. 计算各象限数量
    final quadrantCounts = <String, int>{};
    for (final f in flowers) {
      quadrantCounts[f.quadrant] = (quadrantCounts[f.quadrant] ?? 0) + 1;
    }

    // 3. 计算花园等级（取最高等级）
    final level = _calculateLevel(
      totalCheckins: totalCheckins,
      streak: streak,
      distinctQuadrants: distinctQuadrants,
      notesCount: notesCount,
    );

    // 4. 计算装饰解锁状态
    final decorations = _calculateDecorations(
      streak: streak,
      totalCheckins: totalCheckins,
      distinctQuadrants: distinctQuadrants,
      notesCount: notesCount,
      distinctContexts: distinctContexts,
      maxSameDayQuadrants: maxSameDayQuadrants,
    );

    return GardenState(
      level: level,
      flowers: flowers,
      decorations: decorations,
      totalFlowers: totalCheckins,
      streak: streak,
      quadrantCounts: quadrantCounts,
    );
  }

  /// 计算花园等级（取最高等级）
  static GardenLevel _calculateLevel({
    required int totalCheckins,
    required int streak,
    required int distinctQuadrants,
    required int notesCount,
  }) {
    if (notesCount >= 10) return GardenLevel.secret;
    if (distinctQuadrants >= 4) return GardenLevel.colorful;
    if (totalCheckins >= 30) return GardenLevel.blooming;
    if (streak >= 7) return GardenLevel.sprout;
    if (totalCheckins >= 1) return GardenLevel.seed;
    return GardenLevel.empty;
  }

  /// 计算装饰解锁状态
  static List<DecorationStatus> _calculateDecorations({
    required int streak,
    required int totalCheckins,
    required int distinctQuadrants,
    required int notesCount,
    required int distinctContexts,
    required int maxSameDayQuadrants,
  }) {
    return GardenDecorations.all.map((decoration) {
      final result = _checkDecoration(
        decoration,
        streak: streak,
        distinctQuadrants: distinctQuadrants,
        notesCount: notesCount,
        distinctContexts: distinctContexts,
        maxSameDayQuadrants: maxSameDayQuadrants,
      );
      return result;
    }).toList();
  }

  /// 检查单个装饰的解锁条件
  static DecorationStatus _checkDecoration(
    GardenDecoration decoration, {
    required int streak,
    required int distinctQuadrants,
    required int notesCount,
    required int distinctContexts,
    required int maxSameDayQuadrants,
  }) {
    switch (decoration.key) {
      // 坚持系列
      case 'butterfly':
        return _streakDecoration(decoration, streak, 3);
      case 'bird':
        return _streakDecoration(decoration, streak, 7);
      case 'fountain':
        return _streakDecoration(decoration, streak, 14);
      case 'rainbow':
        return _streakDecoration(decoration, streak, 30);
      case 'fireworks':
        return _streakDecoration(decoration, streak, 60);

      // 探索系列
      case 'ladybug':
        return _quadrantDecoration(decoration, distinctQuadrants, 2);
      case 'bee':
        return _quadrantDecoration(decoration, distinctQuadrants, 3);
      case 'snail':
        return _quadrantDecoration(decoration, distinctQuadrants, 4);

      // 表达系列
      case 'mushroom':
        return _notesDecoration(decoration, notesCount, 3);
      case 'clover':
        return _notesDecoration(decoration, notesCount, 10);
      case 'cherry':
        return _notesDecoration(decoration, notesCount, 30);

      // 场景系列
      case 'fence':
        final unlocked = distinctContexts >= 5;
        final progress = distinctContexts >= 5
            ? 1.0
            : distinctContexts / 5.0;
        return DecorationStatus(
          decoration: decoration,
          unlocked: unlocked,
          progress: progress,
          progressText: '$distinctContexts/5种场景',
        );

      // 多彩日记
      case 'rainbow_bridge':
        final unlocked = maxSameDayQuadrants >= 3;
        final progress = maxSameDayQuadrants >= 3
            ? 1.0
            : maxSameDayQuadrants / 3.0;
        return DecorationStatus(
          decoration: decoration,
          unlocked: unlocked,
          progress: progress,
          progressText: '$maxSameDayQuadrants/3种情绪',
        );

      default:
        return DecorationStatus(
          decoration: decoration,
          unlocked: false,
        );
    }
  }

  static DecorationStatus _streakDecoration(
    GardenDecoration decoration,
    int streak,
    int required,
  ) {
    final unlocked = streak >= required;
    final progress = unlocked ? 1.0 : streak / required.toDouble();
    return DecorationStatus(
      decoration: decoration,
      unlocked: unlocked,
      progress: progress,
      progressText: '$streak/$required天',
    );
  }

  static DecorationStatus _quadrantDecoration(
    GardenDecoration decoration,
    int distinctQuadrants,
    int required,
  ) {
    final unlocked = distinctQuadrants >= required;
    final progress = unlocked
        ? 1.0
        : distinctQuadrants / required.toDouble();
    return DecorationStatus(
      decoration: decoration,
      unlocked: unlocked,
      progress: progress,
      progressText: '$distinctQuadrants/$required种象限',
    );
  }

  static DecorationStatus _notesDecoration(
    GardenDecoration decoration,
    int notesCount,
    int required,
  ) {
    final unlocked = notesCount >= required;
    final progress = unlocked ? 1.0 : notesCount / required.toDouble();
    return DecorationStatus(
      decoration: decoration,
      unlocked: unlocked,
      progress: progress,
      progressText: '$notesCount/$required条',
    );
  }

  /// Calculate sunshine value (pure front-end, no DB).
  ///
  /// Formula: checkins*10 + learningEntries*5 + waterReceived*3 + streak*2
  static int calculateSunshine({
    required int totalCheckins,
    required int currentStreak,
    required int totalLearningEntries,
    required int totalWaterReceived,
  }) {
    return totalCheckins * 10 +
        totalLearningEntries * 5 +
        totalWaterReceived * 3 +
        currentStreak * 2;
  }

  /// Garden level name based on sunshine value.
  static String gardenLevelName(int sunshine) {
    if (sunshine >= 5000) return '\u{1F333} \u79D8\u5BC6\u82B1\u56ED';
    if (sunshine >= 2000) return '\u{1F33A} \u7F24\u7EB7\u82B1\u56ED';
    if (sunshine >= 500) return '\u{1F338} \u82B1\u5F00\u82B1\u56ED';
    if (sunshine >= 100) return '\u{1F33F} \u5C0F\u82B1\u56ED';
    return '\u{1F331} \u79CD\u5B50\u82B1\u56ED';
  }

  /// 计算新解锁的装饰 key 列表
  ///
  /// 比较打卡前后的解锁状态，返回本次新解锁的装饰 key
  static List<String> calculateNewDecorations({
    required int streakBefore,
    required int streakAfter,
    required int distinctQuadrantsBefore,
    required int distinctQuadrantsAfter,
    required int notesCountBefore,
    required int notesCountAfter,
    required int distinctContextsBefore,
    required int distinctContextsAfter,
    required int maxSameDayQuadrantsBefore,
    required int maxSameDayQuadrantsAfter,
  }) {
    final before = _calculateDecorations(
      streak: streakBefore,
      totalCheckins: 0, // 不影响装饰计算
      distinctQuadrants: distinctQuadrantsBefore,
      notesCount: notesCountBefore,
      distinctContexts: distinctContextsBefore,
      maxSameDayQuadrants: maxSameDayQuadrantsBefore,
    );

    final after = _calculateDecorations(
      streak: streakAfter,
      totalCheckins: 0,
      distinctQuadrants: distinctQuadrantsAfter,
      notesCount: notesCountAfter,
      distinctContexts: distinctContextsAfter,
      maxSameDayQuadrants: maxSameDayQuadrantsAfter,
    );

    final newKeys = <String>[];
    for (int i = 0; i < after.length; i++) {
      if (after[i].unlocked && !before[i].unlocked) {
        newKeys.add(after[i].decoration.key);
      }
    }
    return newKeys;
  }
}
