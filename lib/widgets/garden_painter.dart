import 'dart:math';
import 'package:flutter/material.dart';

/// Data for a single flower in the garden scene
class FlowerData {
  final String quadrant; // determines color
  final int index; // determines position and size (pseudo-random seed)

  const FlowerData({
    required this.quadrant,
    required this.index,
  });
}

/// Paints the garden background scene: sky, clouds, sun, grass, and flowers.
/// All rendering uses Canvas API only (no emoji).
class GardenPainter extends CustomPainter {
  final List<FlowerData> flowers;
  final double animationValue; // 0.0-1.0 cyclic
  final Size canvasSize;

  GardenPainter({
    required this.flowers,
    required this.animationValue,
    required this.canvasSize,
  }) : super(repaint: null);

  // Flower petal color mapping per quadrant
  static const _petalColors = <String, Color>{
    'red': Color(0xFFEF5350),
    'yellow': Color(0xFFFFB74D),
    'green': Color(0xFF81C784),
    'blue': Color(0xFF64B5F6),
  };

  @override
  void paint(Canvas canvas, Size size) {
    _drawSky(canvas, size);
    _drawClouds(canvas, size);
    _drawSun(canvas, size);
    _drawGrass(canvas, size);
    _drawFlowers(canvas, size);
  }

  // ---- Sky ----

  void _drawSky(Canvas canvas, Size size) {
    final skyRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.60);
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFE3F2FD), // light blue
          Color(0xFFF3E5F5), // pale purple
        ],
      ).createShader(skyRect);
    canvas.drawRect(skyRect, skyPaint);
  }

  // ---- Clouds ----

  void _drawClouds(Canvas canvas, Size size) {
    final cloudPaint = Paint()..color = const Color(0xB3FFFFFF); // alpha ~0.7

    // 3 clouds at different vertical positions
    const cloudConfigs = [
      (yFrac: 0.10, baseFrac: 0.15, scale: 1.0),
      (yFrac: 0.22, baseFrac: 0.55, scale: 0.8),
      (yFrac: 0.06, baseFrac: 0.80, scale: 0.65),
    ];

    for (final cfg in cloudConfigs) {
      final drift = (animationValue * 20.0) % size.width;
      final baseX =
          ((cfg.baseFrac * size.width + drift) % (size.width + 60)) - 30;
      final baseY = cfg.yFrac * size.height;
      final s = cfg.scale;

      // 3 overlapping ellipses
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(baseX, baseY),
          width: 40 * s,
          height: 18 * s,
        ),
        cloudPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(baseX + 16 * s, baseY - 4 * s),
          width: 30 * s,
          height: 16 * s,
        ),
        cloudPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(baseX - 14 * s, baseY - 2 * s),
          width: 28 * s,
          height: 14 * s,
        ),
        cloudPaint,
      );
    }
  }

  // ---- Sun ----

  void _drawSun(Canvas canvas, Size size) {
    final cx = size.width - 30;
    const cy = 28.0;
    const radius = 14.0;

    // Sun body
    final sunPaint = Paint()..color = const Color(0xFFFFCA28);
    canvas.drawCircle(Offset(cx, cy), radius, sunPaint);

    // 8 rays, slowly rotating
    final rayPaint = Paint()
      ..color = const Color(0xFFFFCA28)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final rotationOffset = animationValue * 2 * pi;
    for (int i = 0; i < 8; i++) {
      final angle = (i * pi / 4) + rotationOffset * 0.1;
      final innerR = radius + 3;
      final outerR = radius + 9;
      canvas.drawLine(
        Offset(cx + cos(angle) * innerR, cy + sin(angle) * innerR),
        Offset(cx + cos(angle) * outerR, cy + sin(angle) * outerR),
        rayPaint,
      );
    }
  }

  // ---- Grass ----

  void _drawGrass(Canvas canvas, Size size) {
    final grassTop = size.height * 0.75;
    final grassRect = Rect.fromLTWH(0, grassTop, size.width, size.height * 0.25);

    // Gradient fill
    final grassPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF81C784),
          Color(0xFF4CAF50),
        ],
      ).createShader(grassRect);

    // Wavy top edge
    final path = Path()..moveTo(0, grassTop);
    final waveCount = 5;
    final segmentWidth = size.width / waveCount;
    for (int i = 0; i < waveCount; i++) {
      final x0 = i * segmentWidth;
      final x1 = x0 + segmentWidth;
      final cpx = x0 + segmentWidth / 2;
      final cpy = grassTop + (i.isEven ? -6 : 6);
      path.quadraticBezierTo(cpx, cpy, x1, grassTop);
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, grassPaint);
  }

  // ---- Flowers ----

  void _drawFlowers(Canvas canvas, Size size) {
    // Cap at 50
    final displayFlowers =
        flowers.length > 50 ? flowers.sublist(flowers.length - 50) : flowers;

    final grassLineY = size.height * 0.75;

    for (int i = 0; i < displayFlowers.length; i++) {
      final flower = displayFlowers[i];

      // Pseudo-random position based on index (golden angle distribution)
      final xRaw = (i * 137.5) % size.width;
      final x = xRaw.clamp(10.0, size.width - 10.0);

      // Y position: near grass line with index-based offset
      final yHash = ((flower.index * 7 + 13) % 20) - 10; // -10 to +10
      final y = grassLineY + yHash.toDouble();

      // Size: 14-20px
      final flowerSize = 14.0 + ((flower.index * 3 + 5) % 7);

      // Sway angle (micro animation)
      final swayAngle =
          sin(animationValue * 2 * pi + i * 0.7) * 0.05;

      final color =
          _petalColors[flower.quadrant] ?? const Color(0xFF90A4AE);

      _drawFlower(canvas, Offset(x, y), color, flowerSize, swayAngle);
    }
  }

  void _drawFlower(Canvas canvas, Offset center, Color petalColor,
      double size, double swayAngle) {
    final petalPaint = Paint()..color = petalColor;
    final centerPaint = Paint()..color = const Color(0xFFFFEB3B); // yellow pistil

    // Stem (draw first so it appears behind the flower head)
    final stemPaint = Paint()
      ..color = const Color(0xFF388E3C)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
        center, Offset(center.dx, center.dy + size * 1.5), stemPaint);

    // Rotate canvas for sway
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(swayAngle);

    // 5 petals arranged in a circle
    final petalRadius = size * 0.35;
    final petalDistance = size * 0.3;
    for (int i = 0; i < 5; i++) {
      final angle = (i * 2 * pi / 5) - pi / 2;
      final px = cos(angle) * petalDistance;
      final py = sin(angle) * petalDistance;
      canvas.drawCircle(Offset(px, py), petalRadius, petalPaint);
    }

    // Pistil (center yellow circle)
    canvas.drawCircle(Offset.zero, size * 0.2, centerPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GardenPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.flowers.length != flowers.length ||
        oldDelegate.canvasSize != canvasSize;
  }
}
