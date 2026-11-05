import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// A small dependency-free loading spinner.
///
/// The app deliberately avoids Material widgets, so this paints a rotating arc
/// with [CustomPaint] and drives it with a [RotationTransition].
class CompassSpinner extends StatefulWidget {
  final double size;
  final Color color;
  final double strokeWidth;

  const CompassSpinner({
    super.key,
    this.size = 12.0,
    required this.color,
    this.strokeWidth = 1.6,
  });

  @override
  State<CompassSpinner> createState() => _CompassSpinnerState();
}

class _CompassSpinnerState extends State<CompassSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RotationTransition(
        turns: _controller,
        child: CustomPaint(
          painter: _ArcPainter(
            color: widget.color,
            strokeWidth: widget.strokeWidth,
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _ArcPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height)
        .deflate(strokeWidth / 2);
    // ~270° of arc, leaving a gap so the rotation reads as motion.
    canvas.drawArc(rect, -math.pi / 2, math.pi * 1.5, false, paint);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
