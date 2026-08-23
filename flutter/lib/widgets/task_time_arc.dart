import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:timetodo/models/task.dart';
import 'package:timetodo/time_utils.dart';

/// Color dot with a 24-hour arc (midnight at 9 o'clock, clockwise).
class TaskTimeArc extends StatelessWidget {
  final Task task;
  final double size;

  const TaskTimeArc({
    super.key,
    required this.task,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TaskTimeArcPainter(
          color: task.color,
          trackColor: Theme.of(context).colorScheme.outlineVariant,
          startMinutes: task.isAllDay || task.startTime == null
              ? 0
              : minutesOf(task.startTime!),
          sweepMinutes: task.isAllDay
              ? 24 * 60
              : task.startTime == null
                  ? 0
                  : task.endTime == null
                      ? 30
                      : math.max(15, durationMinutes(task.startTime!, task.endTime!)),
        ),
      ),
    );
  }
}

class _TaskTimeArcPainter extends CustomPainter {
  static const _minutesPerDay = 24 * 60;

  final Color color;
  final Color trackColor;
  final int startMinutes;
  final int sweepMinutes;

  _TaskTimeArcPainter({
    required this.color,
    required this.trackColor,
    required this.startMinutes,
    required this.sweepMinutes,
  });

  double _angleForMinutes(num minutes) {
    return math.pi + 2 * math.pi * (minutes / _minutesPerDay);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final ringWidth = math.max(2.5, radius * 0.18);
    final ringRadius = radius - ringWidth / 2;
    final dotRadius = ringRadius - ringWidth - 1.5;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, ringRadius, track);

    if (sweepMinutes > 0) {
      final fill = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..strokeCap = StrokeCap.round;
      final start = _angleForMinutes(startMinutes);
      final sweep = 2 * math.pi * (sweepMinutes / _minutesPerDay).clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ringRadius),
        start,
        sweep,
        false,
        fill,
      );
    }

    canvas.drawCircle(center, math.max(3, dotRadius), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TaskTimeArcPainter old) =>
      old.color != color ||
      old.trackColor != trackColor ||
      old.startMinutes != startMinutes ||
      old.sweepMinutes != sweepMinutes;
}
