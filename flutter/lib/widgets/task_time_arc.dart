import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timetodo/models/scheduled_task.dart';
import 'package:timetodo/providers/polar_clock_settings.dart';
import 'package:timetodo/time_utils.dart';
import 'package:timetodo/widgets/polar_clock.dart';

/// Compact polar track for a task’s time span (Tasks list, occurrence sheet).
/// Origin and 12h vs 24h circle follow [PolarClockSettings] (same rules as PolarClock).
class TaskTimeArc extends StatelessWidget {
  final ScheduledTask task;
  final double size;

  const TaskTimeArc({
    super.key,
    required this.task,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final look = context.watch<PolarClockSettings>().look;
    final startMinutes = task.isAllDay || task.startTime == null
        ? 0
        : minutesOf(task.startTime!);
    final sweepMinutes = task.isAllDay
        ? PolarClockLook.cycle24
        : task.startTime == null
            ? 0
            : task.endTime == null
                ? 30
                : durationMinutes(task.startTime!, task.endTime!);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TaskTimeArcPainter(
          color: task.color,
          trackColor: Theme.of(context).colorScheme.outlineVariant,
          look: look,
          startMinutes: startMinutes,
          sweepMinutes: sweepMinutes,
        ),
      ),
    );
  }
}

class _TaskTimeArcPainter extends CustomPainter {
  static const _day = PolarClockLook.cycle24;
  static const _half = PolarClockLook.cycle12;

  final Color color;
  final Color trackColor;
  final PolarClockLook look;
  final int startMinutes;
  final int sweepMinutes;

  _TaskTimeArcPainter({
    required this.color,
    required this.trackColor,
    required this.look,
    required this.startMinutes,
    required this.sweepMinutes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outer = math.min(size.width, size.height) / 2;
    final hours12 = look.hours12;
    final gap = hours12 ? math.max(1.2, outer * 0.06) : 0.0;
    final trackWidth = hours12
        ? math.max(3.0, (outer - gap) * 0.28)
        : math.max(3.5, outer * 0.34);
    final outerRadius = outer - trackWidth / 2;
    final innerRadius = hours12
        ? outerRadius - trackWidth - gap
        : outerRadius;

    final trackPaint = Paint()
      ..color = trackColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, outerRadius, trackPaint);
    if (hours12) {
      canvas.drawCircle(center, innerRadius, trackPaint);
    }

    if (sweepMinutes < 1) return;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    if (!hours12) {
      _drawOnTrack(
        canvas,
        center,
        outerRadius,
        trackWidth,
        fill,
        startMinutes,
        sweepMinutes.toDouble(),
        PolarClockLook.cycle24,
      );
      return;
    }

    for (final seg in _twelveHourSegments(startMinutes, sweepMinutes)) {
      final pm = seg.$1 >= _half;
      _drawOnTrack(
        canvas,
        center,
        pm ? innerRadius : outerRadius,
        trackWidth,
        fill,
        seg.$1,
        (seg.$2 - seg.$1).toDouble(),
        PolarClockLook.cycle12,
      );
    }
  }

  void _drawOnTrack(
    Canvas canvas,
    Offset center,
    double radius,
    double trackWidth,
    Paint fill,
    int startMinutes,
    double sweepMin,
    int cycle,
  ) {
    final span = sweepMin.clamp(0.0, cycle.toDouble());
    if (span < 0.4) return;
    if (span >= cycle - 0.5) {
      final hole = math.max(1.0, radius - trackWidth / 2);
      final ring = Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(
          Rect.fromCircle(center: center, radius: radius + trackWidth / 2),
        )
        ..addOval(Rect.fromCircle(center: center, radius: hole));
      canvas.drawPath(ring, fill);
      return;
    }
    canvas.drawPath(
      polarRoundedTrackPath(
        center,
        radius,
        trackWidth,
        look.angleForMinutes(startMinutes),
        2 * math.pi * (span / cycle),
      ),
      fill,
    );
  }

  /// Absolute-day segments split at midnight and noon so 12h mode can
  /// place AM on the outer track and PM on the inner track.
  List<(int, int)> _twelveHourSegments(int start, int sweep) {
    final end = start + sweep;
    final raw = <(int, int)>[];
    if (end <= _day) {
      raw.add((start, end));
    } else {
      raw.add((start, _day));
      raw.add((0, end % _day));
    }
    final out = <(int, int)>[];
    for (final seg in raw) {
      if (seg.$1 < _half && seg.$2 > _half) {
        out.add((seg.$1, _half));
        out.add((_half, seg.$2));
      } else if (seg.$2 > seg.$1) {
        out.add(seg);
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(_TaskTimeArcPainter old) =>
      old.color != color ||
      old.trackColor != trackColor ||
      old.look != look ||
      old.startMinutes != startMinutes ||
      old.sweepMinutes != sweepMinutes;
}
