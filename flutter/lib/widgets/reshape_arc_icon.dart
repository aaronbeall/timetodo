import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Arc on a circular track, with a small 4-way move glyph in the hole.
class ReshapeArcIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const ReshapeArcIcon({super.key, this.size = 18, this.color});

  @override
  Widget build(BuildContext context) {
    final paintColor = color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ReshapeArcIconPainter(paintColor),
      ),
    );
  }
}

class _ReshapeArcIconPainter extends CustomPainter {
  final Color color;

  _ReshapeArcIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * 0.38;
    final track = Paint()
      ..color = color.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.09
      ..strokeCap = StrokeCap.round;
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.14
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(c, r, track);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi * 0.72,
      math.pi * 0.85,
      false,
      arc,
    );

    final m = size.shortestSide * 0.13;
    final arm = size.shortestSide * 0.16;
    final head = size.shortestSide * 0.07;
    final move = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawLine(Offset(c.dx, c.dy - arm), Offset(c.dx, c.dy + arm), move);
    canvas.drawLine(Offset(c.dx - arm, c.dy), Offset(c.dx + arm, c.dy), move);

    Path arrow(Offset tip, Offset a, Offset b) {
      return Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(b.dx, b.dy);
    }

    canvas.drawPath(
      arrow(
        Offset(c.dx, c.dy - arm - m * 0.15),
        Offset(c.dx - head, c.dy - arm + head * 0.4),
        Offset(c.dx + head, c.dy - arm + head * 0.4),
      ),
      move,
    );
    canvas.drawPath(
      arrow(
        Offset(c.dx, c.dy + arm + m * 0.15),
        Offset(c.dx - head, c.dy + arm - head * 0.4),
        Offset(c.dx + head, c.dy + arm - head * 0.4),
      ),
      move,
    );
    canvas.drawPath(
      arrow(
        Offset(c.dx - arm - m * 0.15, c.dy),
        Offset(c.dx - arm + head * 0.4, c.dy - head),
        Offset(c.dx - arm + head * 0.4, c.dy + head),
      ),
      move,
    );
    canvas.drawPath(
      arrow(
        Offset(c.dx + arm + m * 0.15, c.dy),
        Offset(c.dx + arm - head * 0.4, c.dy - head),
        Offset(c.dx + arm - head * 0.4, c.dy + head),
      ),
      move,
    );
  }

  @override
  bool shouldRepaint(covariant _ReshapeArcIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
