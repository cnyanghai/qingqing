import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/particles.dart' as fp;
import 'package:flutter/material.dart';

/// A single flower drawn with teardrop-shaped petals, radial gradient,
/// curved stem, and small leaves. Sways gently in the wind.
class FlowerComponent extends PositionComponent with HasGameReference {
  final String quadrant;
  final int index;
  final int totalFlowers;

  double _time = 0;
  late double _flowerX;
  late double _flowerY;
  late double _flowerSize;
  late Color _primaryColor;
  late Color _secondaryColor;
  late double _swayPhase;
  late double _swayFreq;

  double _nextPetalEmitTime = 0;
  final _rng = Random();

  // Color mapping per quadrant (richer gradient)
  static const _colorMap = <String, List<Color>>{
    'red': [Color(0xFFE57373), Color(0xFFEF9A9A)],
    'yellow': [Color(0xFFFFB74D), Color(0xFFFFE082)],
    'green': [Color(0xFF81C784), Color(0xFFA5D6A7)],
    'blue': [Color(0xFF64B5F6), Color(0xFF90CAF9)],
  };

  FlowerComponent({
    required this.quadrant,
    required this.index,
    required this.totalFlowers,
  });

  @override
  Future<void> onLoad() async {
    final colors = _colorMap[quadrant] ?? const [Color(0xFF90A4AE), Color(0xFFB0BEC5)];
    _primaryColor = colors[0];
    _secondaryColor = colors[1];

    // Each flower has a unique sway phase and frequency
    _swayPhase = index * 0.7;
    _swayFreq = 1.3 + (index % 5) * 0.15;

    // Flower size: 14-20 px
    _flowerSize = 14.0 + ((index * 3 + 5) % 7);

    // Randomize first petal emission
    _nextPetalEmitTime = 2.0 + _rng.nextDouble() * 5.0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    // Compute position each frame (depends on game size)
    final w = game.size.x;
    final h = game.size.y;
    final grassLineY = h * 0.72;

    // Golden angle distribution for x
    final xRaw = (index * 137.508) % w;
    _flowerX = xRaw.clamp(12.0, w - 12.0);

    // y near grass line
    final yHash = ((index * 7 + 13) % 20) - 10;
    _flowerY = grassLineY + yHash.toDouble();

    // Petal particle emission (~1 every 5s)
    if (_time >= _nextPetalEmitTime) {
      _emitPetalParticle();
      _nextPetalEmitTime = _time + 4.0 + _rng.nextDouble() * 3.0;
    }
  }

  @override
  void render(Canvas canvas) {
    final swayAngle = sin(_time * _swayFreq + _swayPhase) * 0.06;

    // --- Stem (bezier curve, drawn first so it's behind the bloom) ---
    _drawStem(canvas, _flowerX, _flowerY, _flowerSize, swayAngle);

    // --- Flower head ---
    canvas.save();
    canvas.translate(_flowerX, _flowerY);
    canvas.rotate(swayAngle);

    _drawPetals(canvas, _flowerSize);
    _drawPistil(canvas, _flowerSize);

    canvas.restore();
  }

  void _drawStem(Canvas canvas, double fx, double fy, double size, double sway) {
    final stemLength = size * 1.8;
    final stemBottom = fy + stemLength;

    // Curved stem
    final stemPaint = Paint()
      ..color = const Color(0xFF388E3C)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final stemPath = Path()
      ..moveTo(fx, fy)
      ..quadraticBezierTo(
        fx + sin(sway) * 6 + 3,
        fy + stemLength * 0.5,
        fx + sin(sway) * 2,
        stemBottom,
      );
    canvas.drawPath(stemPath, stemPaint);

    // Small leaves on stem (1-2)
    final leafPaint = Paint()..color = const Color(0xFF66BB6A);
    final leafY1 = fy + stemLength * 0.35;
    final leafY2 = fy + stemLength * 0.6;

    // Left leaf
    canvas.save();
    canvas.translate(fx - 1, leafY1);
    canvas.rotate(-0.5);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-4, 0), width: 8, height: 4),
      leafPaint,
    );
    canvas.restore();

    // Right leaf (only if flower is big enough)
    if (size > 16) {
      canvas.save();
      canvas.translate(fx + 1, leafY2);
      canvas.rotate(0.5);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(4, 0), width: 7, height: 3.5),
        leafPaint,
      );
      canvas.restore();
    }
  }

  void _drawPetals(Canvas canvas, double size) {
    final petalLength = size * 0.45;
    final petalWidth = size * 0.22;

    for (int i = 0; i < 5; i++) {
      final angle = (i * 2 * pi / 5) - pi / 2;

      canvas.save();
      canvas.rotate(angle);

      // Teardrop-shaped petal path
      final petal = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(-petalWidth, -petalLength * 0.6, 0, -petalLength)
        ..quadraticBezierTo(petalWidth, -petalLength * 0.6, 0, 0);

      // Radial gradient (center deep -> edge light)
      final petalPaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(0, -petalLength * 0.3),
          petalLength * 0.8,
          [_primaryColor, _secondaryColor],
          [0.0, 1.0],
        );

      canvas.drawPath(petal, petalPaint);
      canvas.restore();
    }
  }

  void _drawPistil(Canvas canvas, double size) {
    // Main pistil
    final pistilPaint = Paint()..color = const Color(0xFFFFEB3B);
    canvas.drawCircle(Offset.zero, size * 0.15, pistilPaint);

    // Small detail dots (3-5 darker dots)
    final dotPaint = Paint()..color = const Color(0xFFF9A825);
    final dotCount = 3 + (index % 3);
    final dotRadius = size * 0.03;
    final dotDist = size * 0.08;

    for (int i = 0; i < dotCount; i++) {
      final a = i * 2 * pi / dotCount;
      canvas.drawCircle(
        Offset(cos(a) * dotDist, sin(a) * dotDist),
        dotRadius,
        dotPaint,
      );
    }
  }

  // ---- Petal particle emission ----

  void _emitPetalParticle() {
    final petalColor = _secondaryColor;

    final particle = fp.AcceleratedParticle(
      speed: Vector2(
        (_rng.nextDouble() - 0.5) * 15,
        -10 - _rng.nextDouble() * 10,
      ),
      acceleration: Vector2(
        (_rng.nextDouble() - 0.5) * 5,
        15,
      ),
      lifespan: 3.0,
      child: fp.ScalingParticle(
        lifespan: 3.0,
        to: 0, // scale to 0 = fade out effect
        child: fp.ComputedParticle(
          lifespan: 3.0,
          renderer: (canvas, particle) {
            final progress = particle.progress;
            final rotation = progress * pi * 2;
            canvas.save();
            canvas.rotate(rotation);
            final paint = Paint()
              ..color = petalColor.withValues(alpha: 0.6);
            canvas.drawOval(
              Rect.fromCenter(center: Offset.zero, width: 4, height: 2.5),
              paint,
            );
            canvas.restore();
          },
        ),
      ),
    );

    game.add(
      ParticleSystemComponent(
        position: Vector2(_flowerX, _flowerY),
        particle: particle,
      ),
    );
  }

  /// Plays a "plant" animation: star burst particles.
  /// Pre-built for future integration with check-in success flow.
  void playPlantAnimation() {
    for (int i = 0; i < 8; i++) {
      final angle = i * pi / 4;
      final speed = 30.0 + _rng.nextDouble() * 20;

      final particle = fp.AcceleratedParticle(
        speed: Vector2(cos(angle) * speed, sin(angle) * speed),
        acceleration: Vector2(0, 10),
        lifespan: 0.8,
        child: fp.ScalingParticle(
          lifespan: 0.8,
          to: 0,
          child: fp.CircleParticle(
            radius: 2.5,
            paint: Paint()..color = const Color(0xFFFFD54F),
          ),
        ),
      );

      game.add(
        ParticleSystemComponent(
          position: Vector2(_flowerX, _flowerY),
          particle: particle,
        ),
      );
    }
  }
}
