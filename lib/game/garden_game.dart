import 'package:flame/game.dart';
import 'components/garden_background.dart';
import 'components/flower_component.dart';
import 'components/tree_component.dart';
import 'components/ambient_particles.dart';

/// Data for a single flower in the Flame garden scene.
class GardenFlowerData {
  final String quadrant;
  final int index;

  const GardenFlowerData({
    required this.quadrant,
    required this.index,
  });
}

/// Main Flame game for the garden scene.
///
/// Replaces the old CustomPainter-based rendering with a Flame game loop
/// featuring parallax background, animated flowers, wisdom tree, and
/// ambient particle effects.
class GardenGame extends FlameGame {
  final List<GardenFlowerData> flowers;
  final int treeLeafCount;
  final int treeFruitCount;
  final Map<String, int> treeCategoryMap;
  final int waterCount;
  final bool hasEntries;

  GardenGame({
    required this.flowers,
    required this.treeLeafCount,
    required this.treeFruitCount,
    required this.treeCategoryMap,
    required this.waterCount,
    required this.hasEntries,
  });

  @override
  Future<void> onLoad() async {
    await add(GardenBackground());

    // Flowers (max 50)
    final displayFlowers = flowers.length > 50
        ? flowers.sublist(flowers.length - 50)
        : flowers;
    for (int i = 0; i < displayFlowers.length; i++) {
      await add(FlowerComponent(
        quadrant: displayFlowers[i].quadrant,
        index: i,
        totalFlowers: displayFlowers.length,
      ));
    }

    // Wisdom tree or empty pot
    if (hasEntries) {
      await add(WisdomTreeComponent(
        leafCount: treeLeafCount,
        fruitCount: treeFruitCount,
        categoryMap: treeCategoryMap,
        waterCount: waterCount,
      ));
    } else {
      await add(EmptyPotComponent());
    }

    // Ambient particles (butterflies, light dots, petal drift)
    await add(AmbientParticles());
  }
}
