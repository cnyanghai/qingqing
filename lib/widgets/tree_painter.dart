import 'dart:math';
import 'package:flutter/material.dart';

/// Data for the wisdom tree visualization
class TreeData {
  final int leafCount; // in-progress learning entries
  final int fruitCount; // completed learning entries
  final Map<String, int> categoryLeaves; // leaves per category
  final int totalWaterCount; // watering count (affects glow)

  const TreeData({
    required this.leafCount,
    required this.fruitCount,
    required this.categoryLeaves,
    required this.totalWaterCount,
  });
}

/// Paints a wisdom tree: trunk, branches, leaves, fruits, and optional glow.
/// Empty state draws a small pot with a seedling.
class TreePainter extends CustomPainter {
  final int leafCount;
  final int fruitCount;
  final Map<String, int> categoryLeaves;
  final double animationValue; // 0.0-1.0 cyclic
  final int totalWaterCount;
  final bool showGlow;

  TreePainter({
    required this.leafCount,
    required this.fruitCount,
    required this.categoryLeaves,
    required this.animationValue,
    required this.totalWaterCount,
    required this.showGlow,
  }) : super(repaint: null);

  // Fruit colors per category
  static const _fruitColors = <String, Color>{
    'reading': Color(0xFFE57373),
    'music': Color(0xFFBA68C8),
    'sports': Color(0xFF4FC3F7),
    'coding': Color(0xFF4DB6AC),
    'art': Color(0xFFFFB74D),
  };
  static const _defaultFruitColor = Color(0xFF90A4AE);

  int get _totalCount => leafCount + fruitCount;

  @override
  void paint(Canvas canvas, Size size) {
    if (_totalCount == 0 && categoryLeaves.isEmpty) {
      _drawEmptyState(canvas, size);
      return;
    }
    _drawTree(canvas, size);
  }

  // ---- Empty state: pot + seedling ----

  void _drawEmptyState(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final bottomY = size.height * 0.85;

    // Pot (trapezoid)
    final potPaint = Paint()..color = const Color(0xFF8D6E63);
    final potPath = Path()
      ..moveTo(cx - 20, bottomY - 30)
      ..lineTo(cx + 20, bottomY - 30)
      ..lineTo(cx + 15, bottomY)
      ..lineTo(cx - 15, bottomY)
      ..close();
    canvas.drawPath(potPath, potPaint);

    // Pot rim
    final rimPaint = Paint()..color = const Color(0xFF6D4C41);
    canvas.drawRect(
      Rect.fromLTWH(cx - 22, bottomY - 34, 44, 6),
      rimPaint,
    );

    // Soil (dark brown ellipse)
    final soilPaint = Paint()..color = const Color(0xFF5D4037);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, bottomY - 30),
        width: 36,
        height: 8,
      ),
      soilPaint,
    );

    // Seedling stem
    final stemPaint = Paint()
      ..color = const Color(0xFF66BB6A)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(cx, bottomY - 34),
      Offset(cx, bottomY - 55),
      stemPaint,
    );

    // Two small leaves
    final leafPaint = Paint()..color = const Color(0xFF66BB6A);
    // Left leaf
    canvas.save();
    canvas.translate(cx - 2, bottomY - 50);
    canvas.rotate(-0.4);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-5, 0), width: 10, height: 5),
      leafPaint,
    );
    canvas.restore();

    // Right leaf
    canvas.save();
    canvas.translate(cx + 2, bottomY - 46);
    canvas.rotate(0.4);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(5, 0), width: 10, height: 5),
      leafPaint,
    );
    canvas.restore();
  }

  // ---- Tree rendering ----

  void _drawTree(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final bottomY = size.height * 0.90;

    // Trunk dimensions scale with record count (capped at 50)
    final capped = min(_totalCount, 50);
    final trunkWidth = 3.0 + capped * 0.1;
    final trunkHeight = 40.0 + capped * 1.5; // max 115px

    final trunkTopY = bottomY - trunkHeight;

    // ---- Glow (watering effect) ----
    if (showGlow && totalWaterCount > 0) {
      final glowPaint = Paint()
        ..color = const Color(0xFF81D4FA)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawLine(
        Offset(cx, trunkTopY + 5),
        Offset(cx, bottomY),
        glowPaint..strokeWidth = trunkWidth + 8,
      );
    }

    // ---- Trunk (slightly curved bezier) ----
    final trunkPaint = Paint()
      ..color = const Color(0xFF795548)
      ..strokeWidth = trunkWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final trunkPath = Path()
      ..moveTo(cx, bottomY)
      ..quadraticBezierTo(
        cx + 3, // slight curve
        (bottomY + trunkTopY) / 2,
        cx,
        trunkTopY,
      );
    canvas.drawPath(trunkPath, trunkPaint);

    // ---- Branches ----
    final categories = categoryLeaves.keys.toList();
    final branchCount = min(categories.length, 4).clamp(2, 4);
    final branchSpacing = trunkHeight / (branchCount + 1);

    int leafDrawn = 0;
    int fruitDrawn = 0;

    for (int b = 0; b < branchCount; b++) {
      final isLeft = b.isEven;
      final branchBaseY = trunkTopY + branchSpacing * (b + 0.5);

      // Branch (thin bezier)
      final direction = isLeft ? -1.0 : 1.0;
      final branchLength = 25.0 + (b % 2) * 10.0;
      final branchEndX = cx + direction * branchLength;
      final branchEndY = branchBaseY - 10;

      final branchPaint = Paint()
        ..color = const Color(0xFF795548)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final branchPath = Path()
        ..moveTo(cx, branchBaseY)
        ..quadraticBezierTo(
          cx + direction * branchLength * 0.5,
          branchBaseY - 5,
          branchEndX,
          branchEndY,
        );
      canvas.drawPath(branchPath, branchPaint);

      // Determine how many leaves/fruits on this branch
      final catKey = b < categories.length ? categories[b] : null;
      final catCount = catKey != null ? (categoryLeaves[catKey] ?? 0) : 0;

      // Draw leaves and fruits along this branch
      for (int i = 0; i < min(catCount, 5); i++) {
        final t = 0.5 + i * 0.12; // spread along branch
        final itemX = cx + direction * branchLength * t;
        final itemY = branchBaseY - 5 * t + (i.isEven ? -3 : 3);

        if (fruitDrawn < fruitCount && i < (catCount ~/ 2 + 1)) {
          // Draw fruit
          final fruitColor =
              _fruitColors[catKey] ?? _defaultFruitColor;
          _drawFruit(canvas, Offset(itemX, itemY - 4), fruitColor);
          fruitDrawn++;
        } else if (leafDrawn < leafCount) {
          // Draw leaf with tremor animation
          final tremor =
              sin(animationValue * 2 * pi + leafDrawn * 1.0) * 1.0;
          _drawLeaf(canvas, Offset(itemX + tremor, itemY - 2));
          leafDrawn++;
        }
      }
    }

    // Draw remaining leaves at tree crown
    final crownCenterY = trunkTopY + 5;
    while (leafDrawn < leafCount && leafDrawn < 50) {
      final angle = leafDrawn * 2.4; // golden angle spread
      final r = 8.0 + (leafDrawn % 5) * 4.0;
      final lx = cx + cos(angle) * r;
      final ly = crownCenterY + sin(angle) * r * 0.6;
      final tremor =
          sin(animationValue * 2 * pi + leafDrawn * 1.0) * 1.0;
      _drawLeaf(canvas, Offset(lx + tremor, ly));
      leafDrawn++;
    }

    // Draw remaining fruits at tree crown
    while (fruitDrawn < fruitCount && fruitDrawn < 50) {
      final angle = fruitDrawn * 2.4 + 1.2;
      final r = 10.0 + (fruitDrawn % 4) * 5.0;
      final fx = cx + cos(angle) * r;
      final fy = crownCenterY + sin(angle) * r * 0.6;
      // Pick color from available categories
      final catIdx = fruitDrawn % (categories.isEmpty ? 1 : categories.length);
      final catKey = categories.isNotEmpty ? categories[catIdx] : null;
      final fruitColor = _fruitColors[catKey] ?? _defaultFruitColor;
      _drawFruit(canvas, Offset(fx, fy), fruitColor);
      fruitDrawn++;
    }
  }

  void _drawLeaf(Canvas canvas, Offset center) {
    final leafPaint = Paint()..color = const Color(0xFF66BB6A);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 8, height: 5),
      leafPaint,
    );
  }

  void _drawFruit(Canvas canvas, Offset center, Color color) {
    final fruitPaint = Paint()..color = color;
    canvas.drawCircle(center, 5, fruitPaint);

    // Small highlight
    final highlightPaint = Paint()..color = const Color(0x33FFFFFF);
    canvas.drawCircle(Offset(center.dx - 1.5, center.dy - 1.5), 2, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant TreePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.leafCount != leafCount ||
        oldDelegate.fruitCount != fruitCount ||
        oldDelegate.totalWaterCount != totalWaterCount ||
        oldDelegate.showGlow != showGlow;
  }
}
