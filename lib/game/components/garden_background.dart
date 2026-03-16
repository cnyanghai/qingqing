import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 3-layer parallax background for the garden scene.
///
/// - Layer 1 (sky): gradient + drifting clouds
/// - Layer 2 (hills): mid-speed green hills
/// - Layer 3 (grass): fast foreground grass with wavy edge + wind effect
class GardenBackground extends PositionComponent with HasGameReference {
  double _time = 0;

  // Parallax speeds (px/s)
  static const double _hillSpeed = 5.0;
  static const double _cloudSpeed = 8.0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final w = game.size.x;
    final h = game.size.y;

    _drawSky(canvas, w, h);
    _drawClouds(canvas, w, h);
    _drawHills(canvas, w, h);
    _drawGrass(canvas, w, h);
  }

  // ---- Layer 1: Sky gradient ----

  void _drawSky(Canvas canvas, double w, double h) {
    final skyRect = Rect.fromLTWH(0, 0, w, h * 0.65);
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

  // ---- Clouds (independent drift) ----

  void _drawClouds(Canvas canvas, double w, double h) {
    final cloudPaint = Paint()..color = const Color(0xB3FFFFFF);

    final configs = [
      _CloudConfig(yFrac: 0.10, baseFrac: 0.15, scale: 1.0),
      _CloudConfig(yFrac: 0.22, baseFrac: 0.55, scale: 0.8),
      _CloudConfig(yFrac: 0.06, baseFrac: 0.80, scale: 0.65),
    ];

    for (final cfg in configs) {
      final drift = (_time * _cloudSpeed) % (w + 80);
      final baseX = ((cfg.baseFrac * w + drift) % (w + 60)) - 30;
      final baseY = cfg.yFrac * h;
      final s = cfg.scale;

      // 3 overlapping ellipses form one cloud
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

  // ---- Layer 2: Distant hills ----

  void _drawHills(Canvas canvas, double w, double h) {
    final hillOffset = (_time * _hillSpeed) % w;
    final hillTop = h * 0.50;

    // 3 overlapping hills
    final hillColors = [
      const Color(0xFFA5D6A7),
      const Color(0xFF81C784),
      const Color(0xFF66BB6A),
    ];

    final hillConfigs = [
      _HillConfig(cx: 0.20, peakOffset: -18, widthFrac: 0.5),
      _HillConfig(cx: 0.55, peakOffset: -12, widthFrac: 0.45),
      _HillConfig(cx: 0.85, peakOffset: -22, widthFrac: 0.55),
    ];

    for (int i = 0; i < hillConfigs.length; i++) {
      final cfg = hillConfigs[i];
      final paint = Paint()..color = hillColors[i];
      final cx = ((cfg.cx * w + hillOffset) % (w + 100)) - 50;
      final halfW = cfg.widthFrac * w * 0.5;

      final path = Path()
        ..moveTo(cx - halfW, hillTop + 20)
        ..quadraticBezierTo(cx, hillTop + cfg.peakOffset, cx + halfW, hillTop + 20)
        ..lineTo(cx + halfW, h)
        ..lineTo(cx - halfW, h)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  // ---- Layer 3: Grass with wavy edge + wind effect ----

  void _drawGrass(Canvas canvas, double w, double h) {
    final grassTop = h * 0.72;
    final grassRect = Rect.fromLTWH(0, grassTop, w, h - grassTop);

    final grassPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF81C784),
          Color(0xFF4CAF50),
        ],
      ).createShader(grassRect);

    // Wavy top edge with wind phase shift
    final windPhase = _time * 1.2;
    const waveCount = 6;
    final segmentWidth = w / waveCount;

    final path = Path()..moveTo(0, grassTop);
    for (int i = 0; i < waveCount; i++) {
      final x0 = i * segmentWidth;
      final x1 = x0 + segmentWidth;
      final cpx = x0 + segmentWidth / 2;
      // Wind: wave amplitude oscillates over time
      final waveAmp = 5.0 + sin(windPhase + i * 0.8) * 3.0;
      final cpy = grassTop + (i.isEven ? -waveAmp : waveAmp);
      path.quadraticBezierTo(cpx, cpy, x1, grassTop);
    }
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();

    canvas.drawPath(path, grassPaint);
  }
}

// Helper data classes

class _CloudConfig {
  final double yFrac;
  final double baseFrac;
  final double scale;

  _CloudConfig({
    required this.yFrac,
    required this.baseFrac,
    required this.scale,
  });
}

class _HillConfig {
  final double cx;
  final double peakOffset;
  final double widthFrac;

  _HillConfig({
    required this.cx,
    required this.peakOffset,
    required this.widthFrac,
  });
}
