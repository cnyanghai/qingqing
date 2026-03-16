import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Wisdom tree with tapered trunk, cloud-shaped canopy, fruits, and
/// optional blue watering glow with breathing effect.
class WisdomTreeComponent extends PositionComponent with HasGameReference {
  final int leafCount;
  final int fruitCount;
  final Map<String, int> categoryMap;
  final int waterCount;

  double _time = 0;

  // Fruit colors per category
  static const _fruitColors = <String, Color>{
    'reading': Color(0xFFE57373),
    'music': Color(0xFFBA68C8),
    'sports': Color(0xFF4FC3F7),
    'coding': Color(0xFF4DB6AC),
    'art': Color(0xFFFFB74D),
    'language': Color(0xFF26A69A),
    'science': Color(0xFF5C6BC0),
    'other': Color(0xFF90A4AE),
  };

  int get _totalEntries => leafCount + fruitCount;

  WisdomTreeComponent({
    required this.leafCount,
    required this.fruitCount,
    required this.categoryMap,
    required this.waterCount,
  });

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final w = game.size.x;
    final h = game.size.y;

    // Position: right-center
    final cx = w * 0.62;
    final bottomY = h * 0.88;

    // Trunk dimensions scale with entries (capped at 60)
    final capped = min(_totalEntries, 60);
    final trunkHeight = 30.0 + capped * 1.2;
    final trunkTopY = bottomY - trunkHeight;
    final trunkBottomWidth = 6.0 + min(capped, 30) * 0.15;
    const trunkTopWidth = 2.0;

    // Canopy dimensions
    final canopyRadius = 18.0 + capped * 0.5;
    final canopyCenterY = trunkTopY - canopyRadius * 0.3;

    // Canopy float
    final canopyFloat = sin(_time * 0.8) * 1.5;

    // ---- Watering glow (behind everything) ----
    if (waterCount > 0) {
      final glowOpacity = 0.2 + sin(_time) * 0.1;
      final glowPaint = Paint()
        ..color = Color.fromRGBO(129, 212, 250, glowOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, canopyCenterY + canopyFloat),
          width: canopyRadius * 2.6,
          height: canopyRadius * 2.0,
        ),
        glowPaint,
      );
    }

    // ---- Trunk (two bezier curves for tapered shape) ----
    _drawTrunk(canvas, cx, bottomY, trunkTopY, trunkBottomWidth, trunkTopWidth);

    // ---- Canopy (cloud shape: 3-4 overlapping ellipses) ----
    _drawCanopy(canvas, cx, canopyCenterY + canopyFloat, canopyRadius);

    // ---- Fruits ----
    _drawFruits(canvas, cx, canopyCenterY + canopyFloat, canopyRadius);
  }

  void _drawTrunk(Canvas canvas, double cx, double bottomY, double topY,
      double bottomHalf, double topHalf) {
    // Left contour
    final trunkPath = Path()
      ..moveTo(cx - bottomHalf, bottomY)
      ..quadraticBezierTo(
        cx - bottomHalf * 0.7 + 1.5,
        (bottomY + topY) / 2,
        cx - topHalf,
        topY,
      )
      // Top edge
      ..lineTo(cx + topHalf, topY)
      // Right contour
      ..quadraticBezierTo(
        cx + bottomHalf * 0.7 - 1.5,
        (bottomY + topY) / 2,
        cx + bottomHalf,
        bottomY,
      )
      ..close();

    final trunkPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx - bottomHalf, bottomY),
        Offset(cx + bottomHalf, bottomY),
        [const Color(0xFF6D4C41), const Color(0xFF8D6E63)],
      );
    canvas.drawPath(trunkPath, trunkPaint);
  }

  void _drawCanopy(Canvas canvas, double cx, double cy, double radius) {
    // Cloud shape: 3-4 overlapping ellipses with gradient
    final canopyPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx, cy),
        radius * 1.2,
        [const Color(0xFF43A047), const Color(0xFF81C784)],
        [0.3, 1.0],
      );

    // Center blob
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: radius * 2.0,
        height: radius * 1.5,
      ),
      canopyPaint,
    );

    // Upper-left blob
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - radius * 0.55, cy - radius * 0.3),
        width: radius * 1.3,
        height: radius * 1.1,
      ),
      canopyPaint,
    );

    // Upper-right blob
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + radius * 0.55, cy - radius * 0.25),
        width: radius * 1.4,
        height: radius * 1.0,
      ),
      canopyPaint,
    );

    // Top blob
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + radius * 0.1, cy - radius * 0.6),
        width: radius * 1.1,
        height: radius * 0.9,
      ),
      canopyPaint,
    );
  }

  void _drawFruits(Canvas canvas, double cx, double cy, double canopyRadius) {
    if (fruitCount == 0) return;

    final categories = categoryMap.keys.toList();
    final cappedFruits = min(fruitCount, 25);

    for (int i = 0; i < cappedFruits; i++) {
      // Distribute fruits within canopy using golden angle
      final angle = i * 2.4 + 0.5;
      final r = canopyRadius * 0.3 + (i % 5) * canopyRadius * 0.12;
      final fx = cx + cos(angle) * r;
      final fy = cy + sin(angle) * r * 0.6;

      // Bounce animation
      final bounce = 1.0 + sin(_time * 2 + i.toDouble()) * 0.05;

      // Pick color from category
      final catIdx = categories.isEmpty ? 0 : i % categories.length;
      final catKey = categories.isNotEmpty ? categories[catIdx] : 'other';
      final fruitColor = _fruitColors[catKey] ?? const Color(0xFF90A4AE);

      final fruitPaint = Paint()..color = fruitColor;
      canvas.drawCircle(Offset(fx, fy), 4.5 * bounce, fruitPaint);

      // Small highlight
      final highlightPaint = Paint()..color = const Color(0x33FFFFFF);
      canvas.drawCircle(Offset(fx - 1.2, fy - 1.2), 1.8, highlightPaint);
    }
  }
}

/// Empty pot with seedling shown when no learning entries exist.
class EmptyPotComponent extends PositionComponent with HasGameReference {
  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final w = game.size.x;
    final h = game.size.y;

    final cx = w * 0.62;
    final bottomY = h * 0.85;

    // Breathing scale for seedling
    final breathScale = 0.95 + sin(_time * 1.5) * 0.05;

    // ---- Pot (trapezoid) ----
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

    // Soil ellipse
    final soilPaint = Paint()..color = const Color(0xFF5D4037);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, bottomY - 30),
        width: 36,
        height: 8,
      ),
      soilPaint,
    );

    // ---- Seedling (with breathing animation) ----
    canvas.save();
    canvas.translate(cx, bottomY - 34);
    canvas.scale(breathScale, breathScale);

    // Stem
    final stemPaint = Paint()
      ..color = const Color(0xFF66BB6A)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, const Offset(0, -21), stemPaint);

    // Left leaf
    final leafPaint = Paint()..color = const Color(0xFF66BB6A);
    canvas.save();
    canvas.translate(-2, -16);
    canvas.rotate(-0.4);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-5, 0), width: 10, height: 5),
      leafPaint,
    );
    canvas.restore();

    // Right leaf
    canvas.save();
    canvas.translate(2, -12);
    canvas.rotate(0.4);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(5, 0), width: 10, height: 5),
      leafPaint,
    );
    canvas.restore();

    canvas.restore(); // end breathing scale
  }
}
