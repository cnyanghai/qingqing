import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Ambient environmental effects: butterflies, floating light dots.
class AmbientParticles extends PositionComponent with HasGameReference {
  double _time = 0;
  final _rng = Random();

  // Butterflies
  late List<_Butterfly> _butterflies;

  // Floating light dots
  late List<_LightDot> _lightDots;

  @override
  Future<void> onLoad() async {
    _butterflies = List.generate(2, (_) => _Butterfly(_rng));
    _lightDots = List.generate(4, (_) => _LightDot(_rng));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    final w = game.size.x;
    final h = game.size.y;
    final grassY = h * 0.72;

    for (final b in _butterflies) {
      b.update(dt, w, h, grassY, _rng);
    }
    for (final d in _lightDots) {
      d.update(dt, w, grassY, _rng);
    }
  }

  @override
  void render(Canvas canvas) {
    for (final b in _butterflies) {
      b.render(canvas, _time);
    }
    for (final d in _lightDots) {
      d.render(canvas);
    }
  }
}

/// A simplified butterfly with flapping triangle wings.
class _Butterfly {
  double x;
  double y;
  double targetX;
  double targetY;
  double speed;
  Color color;
  double pathTimer;
  static const double pathInterval = 10.0;

  _Butterfly(Random rng)
      : x = rng.nextDouble() * 200 + 50,
        y = rng.nextDouble() * 60 + 20,
        targetX = rng.nextDouble() * 200 + 50,
        targetY = rng.nextDouble() * 60 + 20,
        speed = 12 + rng.nextDouble() * 8,
        color = [const Color(0xFFCE93D8), const Color(0xFFFFF176)][rng.nextInt(2)],
        pathTimer = 0;

  void update(double dt, double w, double h, double grassY, Random rng) {
    pathTimer += dt;
    if (pathTimer >= pathInterval) {
      pathTimer = 0;
      targetX = rng.nextDouble() * (w - 40) + 20;
      targetY = rng.nextDouble() * (grassY * 0.5) + 10;
    }

    // Lerp toward target
    final dx = targetX - x;
    final dy = targetY - y;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist > 1) {
      x += (dx / dist) * speed * dt;
      y += (dy / dist) * speed * dt;
    }
  }

  void render(Canvas canvas, double time) {
    final wingFlap = sin(time * 8) * 0.5 + 0.5; // 0..1

    canvas.save();
    canvas.translate(x, y);

    final wingPaint = Paint()..color = color.withValues(alpha: 0.7);

    // Left wing (triangle that flaps)
    final leftWing = Path()
      ..moveTo(0, 0)
      ..lineTo(-6, -4 * wingFlap - 2)
      ..lineTo(-2, 3)
      ..close();
    canvas.drawPath(leftWing, wingPaint);

    // Right wing
    final rightWing = Path()
      ..moveTo(0, 0)
      ..lineTo(6, -4 * wingFlap - 2)
      ..lineTo(2, 3)
      ..close();
    canvas.drawPath(rightWing, wingPaint);

    // Body
    final bodyPaint = Paint()..color = const Color(0xFF5D4037);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 2, height: 5),
      bodyPaint,
    );

    canvas.restore();
  }
}

/// A floating light dot that drifts down from the top.
class _LightDot {
  double x;
  double y;
  double speedY;
  double swayPhase;
  double opacity;
  double radius;

  _LightDot(Random rng)
      : x = rng.nextDouble() * 300,
        y = -rng.nextDouble() * 50,
        speedY = 8 + rng.nextDouble() * 6,
        swayPhase = rng.nextDouble() * pi * 2,
        opacity = 0.3 + rng.nextDouble() * 0.4,
        radius = 1.5 + rng.nextDouble() * 1.5;

  void update(double dt, double w, double grassY, Random rng) {
    y += speedY * dt;
    x += sin(swayPhase + y * 0.05) * 0.5;

    // Reset when past grass line
    if (y > grassY) {
      y = -5;
      x = rng.nextDouble() * w;
      opacity = 0.3 + rng.nextDouble() * 0.4;
    }
  }

  void render(Canvas canvas) {
    final paint = Paint()
      ..color = Color.fromRGBO(255, 255, 200, opacity);
    canvas.drawCircle(Offset(x, y), radius, paint);
  }
}
