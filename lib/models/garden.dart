import 'package:flutter/material.dart';
import '../config/theme.dart';

/// 情绪象限 → 花朵映射
class FlowerConfig {
  final String emoji;
  final String name;
  final Color color;
  final Color bgColor;

  const FlowerConfig({
    required this.emoji,
    required this.name,
    required this.color,
    required this.bgColor,
  });
}

/// 四种基础花（对应四个情绪象限）
class GardenConfig {
  GardenConfig._();

  static const Map<String, FlowerConfig> flowers = {
    'red': FlowerConfig(
      emoji: '\u{1F339}', // 🌹
      name: '玫瑰',
      color: AppColors.moodRed,
      bgColor: AppColors.moodRedBg,
    ),
    'yellow': FlowerConfig(
      emoji: '\u{1F33B}', // 🌻
      name: '向日葵',
      color: AppColors.moodYellow,
      bgColor: AppColors.moodYellowBg,
    ),
    'green': FlowerConfig(
      emoji: '\u{1F33F}', // 🌿
      name: '薰衣草',
      color: AppColors.moodGreen,
      bgColor: AppColors.moodGreenBg,
    ),
    'blue': FlowerConfig(
      emoji: '\u{1F4A7}', // 💧
      name: '蓝铃花',
      color: AppColors.moodBlue,
      bgColor: AppColors.moodBlueBg,
    ),
  };

  /// 获取花朵配置，若象限无效返回 null
  static FlowerConfig? getFlower(String quadrant) => flowers[quadrant];
}

/// 花园等级
enum GardenLevel {
  empty, // 0次打卡: 空花盆
  seed, // 1次: 种子
  sprout, // 7天连续: 小花苗
  blooming, // 30次累计: 初开花园
  colorful, // 集齐4象限: 缤纷花园
  secret, // 10条备注: 秘密花园
}

/// 花园等级显示信息
extension GardenLevelDisplay on GardenLevel {
  String get displayName {
    switch (this) {
      case GardenLevel.empty:
        return '空花盆';
      case GardenLevel.seed:
        return '种子花园';
      case GardenLevel.sprout:
        return '小花苗';
      case GardenLevel.blooming:
        return '初开花园';
      case GardenLevel.colorful:
        return '缤纷花园';
      case GardenLevel.secret:
        return '秘密花园';
    }
  }

  String get displayEmoji {
    switch (this) {
      case GardenLevel.empty:
        return '\u{1FAB4}'; // 🪴
      case GardenLevel.seed:
        return '\u{1F331}'; // 🌱
      case GardenLevel.sprout:
        return '\u{1F33E}'; // 🌾
      case GardenLevel.blooming:
        return '\u{1F338}'; // 🌸
      case GardenLevel.colorful:
        return '\u{1F308}'; // 🌈
      case GardenLevel.secret:
        return '\u{2728}'; // ✨
    }
  }
}

/// 花园装饰物（成就解锁）
class GardenDecoration {
  final String key;
  final String emoji;
  final String name;
  final String unlockCondition;

  const GardenDecoration({
    required this.key,
    required this.emoji,
    required this.name,
    required this.unlockCondition,
  });
}

/// 所有可解锁装饰
class GardenDecorations {
  GardenDecorations._();

  static const List<GardenDecoration> all = [
    // 坚持系列
    GardenDecoration(
      key: 'butterfly',
      emoji: '\u{1F98B}', // 🦋
      name: '蝴蝶',
      unlockCondition: '连续打卡3天',
    ),
    GardenDecoration(
      key: 'bird',
      emoji: '\u{1F426}', // 🐦
      name: '小鸟',
      unlockCondition: '连续打卡7天',
    ),
    GardenDecoration(
      key: 'fountain',
      emoji: '\u{26F2}', // ⛲
      name: '喷泉',
      unlockCondition: '连续打卡14天',
    ),
    GardenDecoration(
      key: 'rainbow',
      emoji: '\u{1F308}', // 🌈
      name: '彩虹',
      unlockCondition: '连续打卡30天',
    ),
    GardenDecoration(
      key: 'fireworks',
      emoji: '\u{1F386}', // 🎆
      name: '烟花',
      unlockCondition: '连续打卡60天',
    ),
    // 探索系列
    GardenDecoration(
      key: 'ladybug',
      emoji: '\u{1F41E}', // 🐞
      name: '瓢虫',
      unlockCondition: '体验2种情绪象限',
    ),
    GardenDecoration(
      key: 'bee',
      emoji: '\u{1F41D}', // 🐝
      name: '蜜蜂',
      unlockCondition: '体验3种情绪象限',
    ),
    GardenDecoration(
      key: 'snail',
      emoji: '\u{1F40C}', // 🐌
      name: '蜗牛',
      unlockCondition: '体验全部4种情绪象限',
    ),
    // 表达系列
    GardenDecoration(
      key: 'mushroom',
      emoji: '\u{1F344}', // 🍄
      name: '蘑菇',
      unlockCondition: '写3条备注',
    ),
    GardenDecoration(
      key: 'clover',
      emoji: '\u{1F340}', // 🍀
      name: '四叶草',
      unlockCondition: '写10条备注',
    ),
    GardenDecoration(
      key: 'cherry',
      emoji: '\u{1F338}', // 🌸
      name: '樱花树',
      unlockCondition: '写30条备注',
    ),
    // 场景系列
    GardenDecoration(
      key: 'fence',
      emoji: '\u{1F3E1}', // 🏡
      name: '小栅栏',
      unlockCondition: '在全部5种场景打过卡',
    ),
    // 多彩日记
    GardenDecoration(
      key: 'rainbow_bridge',
      emoji: '\u{1F309}', // 🌉
      name: '彩虹桥',
      unlockCondition: '同一天记录3种不同情绪',
    ),
  ];

  /// 按 key 索引
  static GardenDecoration? findByKey(String key) {
    try {
      return all.firstWhere((d) => d.key == key);
    } catch (_) {
      return null;
    }
  }
}

/// 花朵条目（花园中的一朵花）
class FlowerEntry {
  final String quadrant;
  final DateTime plantedAt;

  const FlowerEntry({
    required this.quadrant,
    required this.plantedAt,
  });
}

/// 装饰解锁状态
class DecorationStatus {
  final GardenDecoration decoration;
  final bool unlocked;
  final double progress; // 0.0 ~ 1.0
  final String progressText; // 如 "3/7天"

  const DecorationStatus({
    required this.decoration,
    required this.unlocked,
    this.progress = 0.0,
    this.progressText = '',
  });
}

/// 花园完整状态
class GardenState {
  final GardenLevel level;
  final List<FlowerEntry> flowers;
  final List<DecorationStatus> decorations;
  final int totalFlowers;
  final int streak;
  final Map<String, int> quadrantCounts;

  const GardenState({
    required this.level,
    required this.flowers,
    required this.decorations,
    required this.totalFlowers,
    this.streak = 0,
    required this.quadrantCounts,
  });

  /// 已解锁的装饰
  List<DecorationStatus> get unlockedDecorations =>
      decorations.where((d) => d.unlocked).toList();

  /// 未解锁的装饰
  List<DecorationStatus> get lockedDecorations =>
      decorations.where((d) => !d.unlocked).toList();

  /// 空花园状态
  static const GardenState empty = GardenState(
    level: GardenLevel.empty,
    flowers: [],
    decorations: [],
    totalFlowers: 0,
    streak: 0,
    quadrantCounts: {},
  );
}

/// Unified plant data for the terrarium garden display.
///
/// Combines both emotion check-in flowers and learning-entry plants
/// into a single model for shelf layout.
class PlantData {
  /// 'emotion' or 'learning'
  final String type;

  /// Emotion quadrant ('red', 'yellow', 'green', 'blue'). Only for emotion type.
  final String? quadrant;

  /// Learning category ('reading', 'music', 'sports', 'coding', etc.). Only for learning type.
  final String? category;

  /// Book/skill title. Only for learning type.
  final String? title;

  /// Emotion label text (e.g. "happy"). Only for emotion type.
  final String? emotionLabel;

  /// Cumulative count that determines growth stage.
  final int growthCount;

  /// Progress 0-100. Only meaningful for learning type.
  final int progress;

  /// Whether the learning entry is completed.
  final bool isCompleted;

  const PlantData({
    required this.type,
    this.quadrant,
    this.category,
    this.title,
    this.emotionLabel,
    required this.growthCount,
    this.progress = 0,
    this.isCompleted = false,
  });
}
