import 'dart:math';
import 'package:flutter/material.dart';

/// Continuously emits small golden particles rising from a plant.
///
/// Uses [AnimatedBuilder] + [AnimationController] (not Flame).
/// Each particle is a small circle (3-4px) that rises ~20px over 2 seconds
/// while fading out, with a gentle horizontal sway.
class SunshineParticleEmitter extends StatefulWidget {
  /// How often to spawn a new particle (in seconds).
  final double intervalSeconds;

  /// Width of the emission zone.
  final double emitWidth;

  const SunshineParticleEmitter({
    super.key,
    this.intervalSeconds = 3.0,
    this.emitWidth = 20,
  });

  @override
  State<SunshineParticleEmitter> createState() =>
      _SunshineParticleEmitterState();
}

class _SunshineParticleEmitterState extends State<SunshineParticleEmitter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final Random _rng = Random();
  double _elapsed = 0;
  double _spawnTimer = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60), // long-running
    )..addListener(_tick);
    _controller.repeat();
    // Spawn one immediately
    _spawnParticle();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _tick() {
    final now = _controller.lastElapsedDuration;
    if (now == null) return;

    final seconds = now.inMicroseconds / 1e6;
    final dt = seconds - _elapsed;
    _elapsed = seconds;

    if (dt <= 0 || dt > 1) return; // skip large gaps

    // Update existing particles
    for (final p in _particles) {
      p.age += dt;
      p.y -= 10 * dt; // rise ~10px/s
      p.x += sin(p.age * 2.5 + p.phase) * 3 * dt; // gentle sway
    }

    // Remove dead particles
    _particles.removeWhere((p) => p.age >= p.lifetime);

    // Spawn timer
    _spawnTimer += dt;
    if (_spawnTimer >= widget.intervalSeconds) {
      _spawnTimer -= widget.intervalSeconds;
      _spawnParticle();
    }

    if (mounted) setState(() {});
  }

  void _spawnParticle() {
    final halfW = widget.emitWidth / 2;
    _particles.add(_Particle(
      x: _rng.nextDouble() * widget.emitWidth - halfW,
      y: 0,
      size: 3.0 + _rng.nextDouble() * 1.5,
      lifetime: 1.8 + _rng.nextDouble() * 0.8,
      phase: _rng.nextDouble() * 2 * pi,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.emitWidth + 16, // extra space for sway
      height: 28,
      child: CustomPaint(
        painter: _ParticlePainter(
          particles: _particles,
          centerOffsetX: (widget.emitWidth + 16) / 2,
        ),
      ),
    );
  }
}

class _Particle {
  double x;
  double y;
  double age;
  final double size;
  final double lifetime;
  final double phase;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.lifetime,
    required this.phase,
  }) : age = 0;

  double get opacity => (1.0 - (age / lifetime)).clamp(0.0, 1.0);
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double centerOffsetX;

  const _ParticlePainter({
    required this.particles,
    required this.centerOffsetX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = Color.fromARGB(
          (p.opacity * 220).round(),
          0xFF,
          0xD5,
          0x4F,
        );
      canvas.drawCircle(
        Offset(centerOffsetX + p.x, size.height + p.y),
        p.size / 2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
