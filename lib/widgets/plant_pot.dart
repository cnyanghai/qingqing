import 'package:flutter/material.dart';
import '../config/theme.dart';

/// A single pot slot on the garden shelf.
///
/// Displays either:
/// - An empty slot (dashed outline + "+" icon) when [child] is null
/// - A pot with soil + the provided [child] widget (plant) on top
class PlantPot extends StatelessWidget {
  /// The plant widget to display above the pot. Null means empty slot.
  final Widget? child;

  /// Called when the empty slot "+" is tapped.
  final VoidCallback? onEmptyTap;

  /// Pot top width in logical pixels.
  final double potTopWidth;

  /// Pot bottom width in logical pixels.
  final double potBottomWidth;

  /// Pot height in logical pixels.
  final double potHeight;

  const PlantPot({
    super.key,
    this.child,
    this.onEmptyTap,
    this.potTopWidth = 40,
    this.potBottomWidth = 28,
    this.potHeight = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (child == null) {
      return _buildEmptySlot();
    }
    return _buildFilledPot();
  }

  Widget _buildEmptySlot() {
    return GestureDetector(
      onTap: onEmptyTap,
      child: SizedBox(
        width: potTopWidth + 8,
        height: 60,
        child: Center(
          child: Container(
            width: potTopWidth,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.small),
              border: Border.all(
                color: AppColors.textHint,
                width: 1,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: CustomPaint(
              painter: _DashedBorderPainter(
                color: AppColors.textHint,
                radius: AppRadius.small,
              ),
              child: const Center(
                child: Icon(
                  Icons.add,
                  color: AppColors.textHint,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilledPot() {
    return SizedBox(
      width: potTopWidth + 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Plant area above pot
          if (child != null) child!,
          // Pot
          SizedBox(
            width: potTopWidth + 4,
            height: potHeight + 4,
            child: CustomPaint(
              painter: _PotPainter(
                topWidth: potTopWidth,
                bottomWidth: potBottomWidth,
                height: potHeight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws a trapezoid pot with terracotta gradient and highlight.
class _PotPainter extends CustomPainter {
  final double topWidth;
  final double bottomWidth;
  final double height;

  const _PotPainter({
    required this.topWidth,
    required this.bottomWidth,
    required this.height,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final potTop = 4.0; // leave space for rim
    final potBottom = potTop + height;

    // Trapezoid path
    final potPath = Path()
      ..moveTo(centerX - topWidth / 2, potTop)
      ..lineTo(centerX + topWidth / 2, potTop)
      ..lineTo(centerX + bottomWidth / 2, potBottom)
      ..lineTo(centerX - bottomWidth / 2, potBottom)
      ..close();

    // Terracotta gradient fill
    final potPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFFD4836B), // lighter terracotta top
          Color(0xFFBF6B4E), // darker terracotta bottom
        ],
      ).createShader(Rect.fromLTRB(
        centerX - topWidth / 2,
        potTop,
        centerX + topWidth / 2,
        potBottom,
      ));
    canvas.drawPath(potPath, potPaint);

    // Rim at the top (slightly wider)
    final rimPath = Path();
    final rimHeight = 3.0;
    final rimExtra = 2.0;
    rimPath.moveTo(centerX - topWidth / 2 - rimExtra, potTop);
    rimPath.lineTo(centerX + topWidth / 2 + rimExtra, potTop);
    rimPath.lineTo(centerX + topWidth / 2, potTop + rimHeight);
    rimPath.lineTo(centerX - topWidth / 2, potTop + rimHeight);
    rimPath.close();

    final rimPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFFE09B82), // light rim
          Color(0xFFD4836B), // match body top
        ],
      ).createShader(Rect.fromLTRB(
        centerX - topWidth / 2 - rimExtra,
        potTop,
        centerX + topWidth / 2 + rimExtra,
        potTop + rimHeight,
      ));
    canvas.drawPath(rimPath, rimPaint);

    // Highlight line on left edge (1px)
    final highlightPaint = Paint()
      ..color = const Color(0x40FFFFFF)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(centerX - topWidth / 2 + 1.5, potTop + rimHeight),
      Offset(centerX - bottomWidth / 2 + 1.5, potBottom - 1),
      highlightPaint,
    );

    // Soil ellipse at the pot mouth
    final soilRect = Rect.fromCenter(
      center: Offset(centerX, potTop + rimHeight + 1),
      width: topWidth - 4,
      height: 6,
    );
    final soilPaint = Paint()..color = const Color(0xFF6D4C3D);
    canvas.drawOval(soilRect, soilPaint);
  }

  @override
  bool shouldRepaint(covariant _PotPainter oldDelegate) {
    return oldDelegate.topWidth != topWidth ||
        oldDelegate.bottomWidth != bottomWidth ||
        oldDelegate.height != height;
  }
}

/// Draws a dashed rounded-rect border for the empty slot.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashGap = 3.0;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    // Draw dashed path
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        final extractPath = metric.extractPath(distance, end);
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
