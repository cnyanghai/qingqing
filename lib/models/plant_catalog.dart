/// 植物品种定义
class PlantSpecies {
  final String key;
  final String name;
  final String description;
  final int unlockLevel;
  final int plantCost;
  final List<int> upgradeCosts; // 每级升级花费 [lv1->2, lv2->3, lv3->4, lv4->5]
  final int productionPerSec;
  final String assetPath;
  final String emoji; // placeholder用

  const PlantSpecies({
    required this.key,
    required this.name,
    required this.description,
    required this.unlockLevel,
    required this.plantCost,
    required this.upgradeCosts,
    required this.productionPerSec,
    required this.assetPath,
    required this.emoji,
  });

  /// 获取指定等级的图片路径
  String stageImagePath(int level) => '$assetPath/stage$level.jpg';
}

/// 全部植物品种
class PlantCatalog {
  PlantCatalog._();

  static const List<PlantSpecies> species = [
    PlantSpecies(
      key: 'violet',
      name: '\u7D2B\u7F57\u5170', // 紫罗兰
      description: '\u4F18\u96C5\u7684\u7D2B\u8272\u82B1\u6735\uFF0C\u662F\u82B1\u56ED\u91CC\u6700\u53D7\u6B22\u8FCE\u7684\u690D\u7269',
      unlockLevel: 1,
      plantCost: 0,
      upgradeCosts: [0, 25, 60, 150, 400],
      productionPerSec: 1,
      assetPath: 'assets/plants/violet',
      emoji: '\uD83C\uDF3A', // 🌺
    ),
    PlantSpecies(
      key: 'aloe',
      name: '\u82A6\u835F', // 芦荟
      description: '\u751F\u547D\u529B\u987D\u5F3A\u7684\u7EFF\u8272\u690D\u7269',
      unlockLevel: 3,
      plantCost: 200,
      upgradeCosts: [0, 40, 100, 250, 600],
      productionPerSec: 2,
      assetPath: 'assets/plants/aloe',
      emoji: '\uD83C\uDF3F', // 🌿
    ),
    PlantSpecies(
      key: 'cactus',
      name: '\u4ED9\u4EBA\u638C', // 仙人掌
      description: '\u6C99\u6F20\u4E2D\u7684\u52C7\u58EB',
      unlockLevel: 5,
      plantCost: 500,
      upgradeCosts: [0, 60, 150, 400, 1000],
      productionPerSec: 3,
      assetPath: 'assets/plants/cactus',
      emoji: '\uD83C\uDF35', // 🌵
    ),
    PlantSpecies(
      key: 'sunflower',
      name: '\u5411\u65E5\u8475', // 向日葵
      description: '\u6C38\u8FDC\u8FFD\u968F\u9633\u5149\u7684\u4E50\u89C2\u82B1\u6735',
      unlockLevel: 8,
      plantCost: 1000,
      upgradeCosts: [0, 100, 250, 600, 1500],
      productionPerSec: 5,
      assetPath: 'assets/plants/sunflower',
      emoji: '\uD83C\uDF3B', // 🌻
    ),
    PlantSpecies(
      key: 'rose',
      name: '\u73AB\u7470', // 玫瑰
      description: '\u82B1\u4E2D\u4E4B\u738B\uFF0C\u9700\u8981\u6082\u5FC3\u7167\u6599',
      unlockLevel: 12,
      plantCost: 2000,
      upgradeCosts: [0, 200, 500, 1200, 3000],
      productionPerSec: 8,
      assetPath: 'assets/plants/rose',
      emoji: '\uD83C\uDF39', // 🌹
    ),
  ];

  /// 按key查找品种，找不到返回null
  static PlantSpecies? findByKey(String key) {
    try {
      return species.firstWhere((s) => s.key == key);
    } catch (_) {
      return null;
    }
  }
}

/// 架子层级配置
class ShelfLevel {
  final int index;
  final int slots;
  final int unlockLevel;

  const ShelfLevel({
    required this.index,
    required this.slots,
    required this.unlockLevel,
  });
}

/// 架子配置
class ShelfConfig {
  ShelfConfig._();

  static const List<ShelfLevel> shelves = [
    ShelfLevel(index: 0, slots: 3, unlockLevel: 1),
    ShelfLevel(index: 1, slots: 3, unlockLevel: 5),
    ShelfLevel(index: 2, slots: 4, unlockLevel: 12),
    ShelfLevel(index: 3, slots: 4, unlockLevel: 20),
  ];
}

/// 等级计算工具
class LevelCalculator {
  LevelCalculator._();

  /// 等级经验表: Lv1=0, Lv2=50, Lv3=120, Lv4=200, Lv5=300, ...
  /// 公式: sqrt(totalSunshineEarned / 25) + 1, 上限30
  static int calculateLevel(int totalSunshineEarned) {
    if (totalSunshineEarned <= 0) return 1;
    final level = ((_sqrt(totalSunshineEarned / 25.0)) + 1).floor();
    return level.clamp(1, 30);
  }

  /// 当前等级到下一等级的进度 (0.0 ~ 1.0)
  static double progressToNextLevel(int totalSunshineEarned) {
    final currentLevel = calculateLevel(totalSunshineEarned);
    if (currentLevel >= 30) return 1.0;

    final currentLevelThreshold = _thresholdForLevel(currentLevel);
    final nextLevelThreshold = _thresholdForLevel(currentLevel + 1);
    final range = nextLevelThreshold - currentLevelThreshold;
    if (range <= 0) return 1.0;

    final progress = (totalSunshineEarned - currentLevelThreshold) / range;
    return progress.clamp(0.0, 1.0);
  }

  /// 给定等级所需的总阳光
  static int _thresholdForLevel(int level) {
    // 逆运算: level = sqrt(sunshine/25) + 1
    // => sunshine = 25 * (level - 1)^2
    final l = level - 1;
    return (25 * l * l).toInt();
  }

  static double _sqrt(double x) {
    if (x <= 0) return 0;
    // Newton's method for sqrt
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
}
