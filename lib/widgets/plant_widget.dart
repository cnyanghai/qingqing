import 'dart:math';
import 'package:flutter/material.dart';

/// Growth stage of a plant (1-5).
enum PlantStage {
  seed,    // stage 1: just recorded
  sprout,  // stage 2: 3 cumulative
  bud,     // stage 3: 7 cumulative
  bloom,   // stage 4: 14 cumulative
  fruit,   // stage 5: 30 cumulative
}

/// Determines the plant stage from a growth count.
PlantStage stageFromCount(int count) {
  if (count >= 30) return PlantStage.fruit;
  if (count >= 14) return PlantStage.bloom;
  if (count >= 7) return PlantStage.bud;
  if (count >= 3) return PlantStage.sprout;
  return PlantStage.seed;
}

/// The type of plant to render.
enum PlantType {
  emotion,  // flower shape (petals)
  learning, // bush / tree shape
}

/// Configuration for a plant's appearance.
class PlantConfig {
  final PlantType type;
  final PlantStage stage;
  final Color primaryColor;
  final Color secondaryColor;
  final String? learningCategory; // 'reading', 'music', 'sports', 'coding', etc.

  const PlantConfig({
    required this.type,
    required this.stage,
    required this.primaryColor,
    required this.secondaryColor,
    this.learningCategory,
  });
}

/// Emotion flower color pairs by quadrant.
class EmotionPlantColors {
  EmotionPlantColors._();

  static const Map<String, List<Color>> colors = {
    'red': [Color(0xFFE57373), Color(0xFFEF9A9A)],
    'yellow': [Color(0xFFFFB74D), Color(0xFFFFE082)],
    'green': [Color(0xFF81C784), Color(0xFFA5D6A7)],
    'blue': [Color(0xFF64B5F6), Color(0xFF90CAF9)],
  };

  static List<Color> forQuadrant(String quadrant) {
    return colors[quadrant] ?? const [Color(0xFF81C784), Color(0xFFA5D6A7)];
  }
}

/// Learning plant color pairs by category.
class LearningPlantColors {
  LearningPlantColors._();

  static List<Color> forCategory(String? category) {
    switch (category) {
      case 'reading':
        return const [Color(0xFF66BB6A), Color(0xFFA5D6A7)]; // green bush + red fruit
      case 'music':
        return const [Color(0xFFAB47BC), Color(0xFFCE93D8)]; // purple
      case 'sports':
        return const [Color(0xFF26A69A), Color(0xFF80CBC4)]; // teal
      case 'coding':
        return const [Color(0xFF00ACC1), Color(0xFF80DEEA)]; // cyan
      default:
        return const [Color(0xFF66BB6A), Color(0xFFA5D6A7)]; // generic green
    }
  }
}

/// A plant rendered via CustomPaint.
///
/// Height varies by stage: seed 6px, sprout 20px, bud 35px, bloom 45px, fruit 50px.
class PlantWidget extends StatelessWidget {
  final PlantConfig config;

  const PlantWidget({super.key, required this.config});

  double get _height {
    switch (config.stage) {
      case PlantStage.seed:
        return 10;
      case PlantStage.sprout:
        return 24;
      case PlantStage.bud:
        return 38;
      case PlantStage.bloom:
        return 48;
      case PlantStage.fruit:
        return 54;
    }
  }

  double get _width {
    switch (config.stage) {
      case PlantStage.seed:
        return 12;
      case PlantStage.sprout:
        return 20;
      case PlantStage.bud:
        return 24;
      case PlantStage.bloom:
        return 36;
      case PlantStage.fruit:
        return 40;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      height: _height,
      child: CustomPaint(
        painter: config.type == PlantType.emotion
            ? _EmotionPlantPainter(
                stage: config.stage,
                primary: config.primaryColor,
                secondary: config.secondaryColor,
              )
            : _LearningPlantPainter(
                stage: config.stage,
                primary: config.primaryColor,
                secondary: config.secondaryColor,
                category: config.learningCategory,
              ),
      ),
    );
  }
}

// ============================================================
// Emotion plant painter (flower shapes with teardrop petals)
// ============================================================

class _EmotionPlantPainter extends CustomPainter {
  final PlantStage stage;
  final Color primary;
  final Color secondary;

  const _EmotionPlantPainter({
    required this.stage,
    required this.primary,
    required this.secondary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (stage) {
      case PlantStage.seed:
        _paintSeed(canvas, size);
      case PlantStage.sprout:
        _paintSprout(canvas, size);
      case PlantStage.bud:
        _paintBud(canvas, size);
      case PlantStage.bloom:
        _paintBloom(canvas, size);
      case PlantStage.fruit:
        _paintFruit(canvas, size);
    }
  }

  void _paintSeed(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height - 3;
    final paint = Paint()..color = const Color(0xFF2E7D32);
    canvas.drawCircle(Offset(cx, cy), 3, paint);
  }

  void _paintSprout(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final bottom = size.height;

    // Stem
    _drawStem(canvas, cx, bottom - 2, bottom - 18, 1.2);

    // Two small leaves
    _drawLeaf(canvas, cx, bottom - 14, -0.4, 5, 3);
    _drawLeaf(canvas, cx, bottom - 12, 0.4, 5, 3);
  }

  void _paintBud(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final bottom = size.height;

    // Stem
    _drawStem(canvas, cx, bottom - 2, bottom - 30, 1.4);

    // Leaves on stem
    _drawLeaf(canvas, cx, bottom - 18, -0.5, 6, 3.5);
    _drawLeaf(canvas, cx, bottom - 14, 0.5, 5, 3);

    // Bud (ellipse, darker shade of primary)
    final budPaint = Paint()..color = Color.lerp(primary, const Color(0xFF333333), 0.25)!;
    canvas.save();
    canvas.translate(cx, bottom - 32);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 7, height: 10), budPaint);
    canvas.restore();
  }

  void _paintBloom(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final bottom = size.height;

    // Stem
    _drawStem(canvas, cx, bottom - 2, bottom - 35, 1.5);

    // Leaves
    _drawLeaf(canvas, cx, bottom - 22, -0.5, 7, 4);
    _drawLeaf(canvas, cx, bottom - 16, 0.5, 6, 3.5);
    _drawLeaf(canvas, cx, bottom - 10, -0.3, 5, 3);

    // Flower head at top
    _drawFlowerHead(canvas, cx, bottom - 38, 6.0);
  }

  void _paintFruit(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final bottom = size.height;

    // Stem
    _drawStem(canvas, cx, bottom - 2, bottom - 38, 1.6);

    // Leaves
    _drawLeaf(canvas, cx, bottom - 24, -0.5, 7, 4);
    _drawLeaf(canvas, cx, bottom - 18, 0.5, 6, 3.5);
    _drawLeaf(canvas, cx, bottom - 12, -0.3, 5, 3);

    // Flower head
    _drawFlowerHead(canvas, cx, bottom - 42, 6.5);

    // Small fruit beside the flower
    final fruitPaint = Paint()..color = _fruitColor;
    canvas.drawCircle(Offset(cx + 9, bottom - 34), 4, fruitPaint);
    // Fruit highlight
    final highlightPaint = Paint()..color = const Color(0x40FFFFFF);
    canvas.drawCircle(Offset(cx + 8, bottom - 35.5), 1.5, highlightPaint);
  }

  Color get _fruitColor {
    // Choose fruit color based on primary
    if (primary.r > 0.78) return const Color(0xFFE53935); // red fruit
    if (primary.g > 0.78) return const Color(0xFF43A047); // green fruit
    if (primary.b > 0.78) return const Color(0xFF1E88E5); // blue fruit
    return const Color(0xFFFF8F00); // orange/yellow fruit
  }

  void _drawStem(Canvas canvas, double cx, double bottom, double top, double width) {
    final stemPaint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, bottom), Offset(cx, top), stemPaint);
  }

  void _drawLeaf(Canvas canvas, double stemX, double stemY, double angle, double length, double width) {
    canvas.save();
    canvas.translate(stemX, stemY);
    canvas.rotate(angle);

    final leafPath = Path();
    leafPath.moveTo(0, 0);
    leafPath.quadraticBezierTo(length * 0.5, -width, length, 0);
    leafPath.quadraticBezierTo(length * 0.5, width, 0, 0);

    final leafPaint = Paint()..color = const Color(0xFF66BB6A);
    canvas.drawPath(leafPath, leafPaint);
    canvas.restore();
  }

  /// Draws a flower head with teardrop petals using Bezier curves + gradient.
  void _drawFlowerHead(Canvas canvas, double cx, double cy, double petalLength) {
    const petalCount = 5;

    for (int i = 0; i < petalCount; i++) {
      final angle = (i * 2 * pi / petalCount) - pi / 2;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);

      // Teardrop petal path (Bezier curves)
      final petalPath = Path();
      petalPath.moveTo(0, 0);
      petalPath.cubicTo(
        petalLength * 0.4, -petalLength * 0.35,
        petalLength * 0.9, -petalLength * 0.15,
        petalLength, 0,
      );
      petalPath.cubicTo(
        petalLength * 0.9, petalLength * 0.15,
        petalLength * 0.4, petalLength * 0.35,
        0, 0,
      );

      // Gradient fill from center (primary) to edge (secondary)
      final petalPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, 0),
          radius: 1.2,
          colors: [primary, secondary],
        ).createShader(Rect.fromCenter(
          center: Offset(petalLength / 2, 0),
          width: petalLength * 2,
          height: petalLength,
        ));
      canvas.drawPath(petalPath, petalPaint);

      canvas.restore();
    }

    // Yellow pistil center
    final pistilPaint = Paint()..color = const Color(0xFFFFD54F);
    canvas.drawCircle(Offset(cx, cy), petalLength * 0.3, pistilPaint);
    // Pistil detail dots
    final dotPaint = Paint()..color = const Color(0xFFFFA000);
    canvas.drawCircle(Offset(cx - 1, cy - 1), 0.8, dotPaint);
    canvas.drawCircle(Offset(cx + 1, cy), 0.8, dotPaint);
    canvas.drawCircle(Offset(cx, cy + 1), 0.8, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _EmotionPlantPainter oldDelegate) {
    return oldDelegate.stage != stage ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary;
  }
}

// ============================================================
// Learning plant painter (bush / tree shapes, not flowers)
// ============================================================

class _LearningPlantPainter extends CustomPainter {
  final PlantStage stage;
  final Color primary;
  final Color secondary;
  final String? category;

  const _LearningPlantPainter({
    required this.stage,
    required this.primary,
    required this.secondary,
    this.category,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (stage) {
      case PlantStage.seed:
        _paintSeed(canvas, size);
      case PlantStage.sprout:
        _paintSprout(canvas, size);
      case PlantStage.bud:
        _paintBush(canvas, size, small: true);
      case PlantStage.bloom:
        _paintBush(canvas, size, small: false);
      case PlantStage.fruit:
        _paintBushWithFruit(canvas, size);
    }
  }

  void _paintSeed(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height - 3;
    final paint = Paint()..color = primary;
    canvas.drawCircle(Offset(cx, cy), 3, paint);
  }

  void _paintSprout(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final bottom = size.height;

    // Thin trunk
    final trunkPaint = Paint()
      ..color = const Color(0xFF795548)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, bottom - 2), Offset(cx, bottom - 16), trunkPaint);

    // Two small leaves
    _drawBushLeaf(canvas, cx - 3, bottom - 16, 5, 4, primary);
    _drawBushLeaf(canvas, cx + 3, bottom - 14, 5, 4, secondary);
  }

  void _paintBush(Canvas canvas, Size size, {required bool small}) {
    final cx = size.width / 2;
    final bottom = size.height;
    final bushRadius = small ? 8.0 : 11.0;
    final trunkHeight = small ? 20.0 : 26.0;

    // Trunk
    final trunkPaint = Paint()
      ..color = const Color(0xFF795548)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx, bottom - 2),
      Offset(cx, bottom - trunkHeight),
      trunkPaint,
    );

    // Bush canopy (layered circles)
    final bushPaint = Paint()..color = primary;
    final bushLight = Paint()..color = secondary;

    final centerY = bottom - trunkHeight - bushRadius * 0.5;
    canvas.drawCircle(Offset(cx - bushRadius * 0.3, centerY + 2), bushRadius * 0.7, bushPaint);
    canvas.drawCircle(Offset(cx + bushRadius * 0.3, centerY + 2), bushRadius * 0.7, bushPaint);
    canvas.drawCircle(Offset(cx, centerY - 2), bushRadius * 0.8, bushLight);

    // Category-specific detail
    if (category == 'music' && !small) {
      // Music note shape in center
      final notePaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(cx, centerY), 2, notePaint);
      canvas.drawLine(Offset(cx + 2, centerY), Offset(cx + 2, centerY - 5), notePaint);
    }
  }

  void _paintBushWithFruit(Canvas canvas, Size size) {
    // Draw full bush first
    _paintBush(canvas, size, small: false);

    final cx = size.width / 2;
    final bottom = size.height;

    // Small colored fruits
    final fruitColor = _fruitColorForCategory();
    final fruitPaint = Paint()..color = fruitColor;
    canvas.drawCircle(Offset(cx - 7, bottom - 34), 3, fruitPaint);
    canvas.drawCircle(Offset(cx + 6, bottom - 32), 2.5, fruitPaint);
    canvas.drawCircle(Offset(cx + 2, bottom - 38), 2.5, fruitPaint);

    // Fruit highlights
    final hl = Paint()..color = const Color(0x40FFFFFF);
    canvas.drawCircle(Offset(cx - 7.5, bottom - 35), 1, hl);
    canvas.drawCircle(Offset(cx + 5.5, bottom - 33), 0.8, hl);
  }

  Color _fruitColorForCategory() {
    switch (category) {
      case 'reading':
        return const Color(0xFFE53935); // red book fruit
      case 'music':
        return const Color(0xFFAB47BC); // purple
      case 'sports':
        return const Color(0xFFFF8F00); // orange
      case 'coding':
        return const Color(0xFF00ACC1); // cyan
      default:
        return const Color(0xFFFF8F00); // orange
    }
  }

  void _drawBushLeaf(Canvas canvas, double x, double y, double w, double h, Color color) {
    final paint = Paint()..color = color;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y), width: w, height: h),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _LearningPlantPainter oldDelegate) {
    return oldDelegate.stage != stage ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.category != category;
  }
}
