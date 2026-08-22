import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:timetodo/models/task.dart';

class _TaskRange {
  final Task task;
  final int start;
  final int end;

  _TaskRange({
    required this.task,
    required this.start,
    required this.end,
  });
}

class PolarClock extends StatelessWidget {
  final TimeOfDay currentTime;
  final List<Task> tasks;
  final double size;

  const PolarClock({
    super.key,
    required this.currentTime,
    required this.tasks,
    this.size = 300,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: PolarClockPainter(
          currentTime: currentTime,
          tasks: tasks,
          trackColor: Theme.of(context).colorScheme.outlineVariant,
          nowColor: Theme.of(context).colorScheme.onSurface,
          nowOnColor: Theme.of(context).colorScheme.surface,
        ),
      ),
    );
  }
}

class PolarClockPainter extends CustomPainter {
  static const _minutesPerDay = 24 * 60;

  final TimeOfDay currentTime;
  final List<Task> tasks;
  final Color trackColor;
  final Color nowColor;
  final Color nowOnColor;

  PolarClockPainter({
    required this.currentTime,
    required this.tasks,
    required this.trackColor,
    required this.nowColor,
    required this.nowOnColor,
  });

  /// Midnight at 9 o'clock (left), sweeping clockwise.
  double _angleForMinutes(num minutes) {
    return math.pi + 2 * math.pi * (minutes / _minutesPerDay);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;
    final holeRadius = maxRadius * 0.22;
    final hourTrackWidth = math.max(6.0, maxRadius * 0.035);
    final hourTrackRadius = holeRadius + hourTrackWidth / 2;
    final tracksInner = hourTrackRadius + hourTrackWidth / 2 + 3;
    final tracksOuter = maxRadius - 2;

    _drawHourTrack(canvas, center, hourTrackRadius, hourTrackWidth);

    final timedTasks = tasks
        .where((t) =>
            !t.isAllDay &&
            !t.isCompleted &&
            !t.isCanceled &&
            t.startTime != null &&
            t.endTime != null)
        .toList();

    final lanes = _assignTasksToTracks(timedTasks);
    final laneCount = lanes.length;
    if (tracksOuter > tracksInner) {
      if (laneCount > 0) {
        final gap = laneCount > 1
            ? math.min(2.5, (tracksOuter - tracksInner) * 0.015)
            : 0.0;
        final trackWidth =
            ((tracksOuter - tracksInner) - gap * (laneCount - 1)) / laneCount;

        for (var i = 0; i < laneCount; i++) {
          final innerEdge = tracksInner + i * (trackWidth + gap);
          final radius = innerEdge + trackWidth / 2;
          for (final task in lanes[i]!) {
            _drawTaskTrack(canvas, center, radius, trackWidth, task);
          }
        }
      } else {
        _drawGhostHourTracks(canvas, center, tracksInner, tracksOuter);
      }
    }

    _drawNowIndicator(
      canvas,
      center,
      hourTrackRadius - hourTrackWidth / 2,
      maxRadius,
    );
  }

  Map<int, List<Task>> _assignTasksToTracks(List<Task> tasks) {
    final taskRanges = tasks.map((task) {
      final start = task.startTime!.hour * 60 + task.startTime!.minute;
      final end = task.endTime!.hour * 60 + task.endTime!.minute;
      return _TaskRange(task: task, start: start, end: end);
    }).toList()
      ..sort((a, b) {
        final durationA = _durationMinutes(a);
        final durationB = _durationMinutes(b);
        final byDuration = durationB.compareTo(durationA);
        if (byDuration != 0) return byDuration;
        return a.start.compareTo(b.start);
      });

    final Map<int, List<Task>> tracks = {};
    final List<List<_TaskRange>> trackRanges = [];

    for (final taskRange in taskRanges) {
      var trackIndex = -1;
      for (var i = 0; i < trackRanges.length; i++) {
        final overlaps = trackRanges[i].any(
          (existing) => _rangesOverlap(taskRange, existing),
        );
        if (!overlaps) {
          trackIndex = i;
          break;
        }
      }

      if (trackIndex == -1) {
        trackIndex = trackRanges.length;
        trackRanges.add([]);
        tracks[trackIndex] = [];
      }

      trackRanges[trackIndex].add(taskRange);
      tracks[trackIndex]!.add(taskRange.task);
    }

    return tracks;
  }

  int _durationMinutes(_TaskRange range) {
    if (range.start <= range.end) {
      return range.end - range.start;
    }
    return _minutesPerDay - range.start + range.end;
  }

  List<(int, int)> _segments(_TaskRange range) {
    if (range.start == range.end) {
      return [(range.start, range.end)];
    }
    if (range.start < range.end) {
      return [(range.start, range.end)];
    }
    return [(range.start, _minutesPerDay), (0, range.end)];
  }

  bool _rangesOverlap(_TaskRange a, _TaskRange b) {
    for (final sa in _segments(a)) {
      for (final sb in _segments(b)) {
        if (sa.$1 < sb.$2 && sb.$1 < sa.$2) return true;
      }
    }
    return false;
  }

  void _drawHourTrack(
    Canvas canvas,
    Offset center,
    double radius,
    double width,
  ) {
    final backgroundPaint = Paint()
      ..color = trackColor.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.butt;

    canvas.drawCircle(center, radius, backgroundPaint);

    final currentMinutes = currentTime.hour * 60 + currentTime.minute;
    if (currentMinutes <= 0) return;

    final filledPaint = Paint()
      ..color = trackColor.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _angleForMinutes(0),
      2 * math.pi * (currentMinutes / _minutesPerDay),
      false,
      filledPaint,
    );
  }

  void _drawGhostHourTracks(
    Canvas canvas,
    Offset center,
    double tracksInner,
    double tracksOuter,
  ) {
    final trackWidth = (tracksOuter - tracksInner) * 0.72;
    final radius = tracksInner + trackWidth / 2;
    const segmentMinutes = 3 * 60;
    const gapMinutes = 16;
    final sweep =
        ((segmentMinutes - gapMinutes) / _minutesPerDay) * 2 * math.pi;
    final paint = Paint()
      ..color = trackColor.withOpacity(0.16)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < 8; i++) {
      final startMinutes = i * segmentMinutes + gapMinutes / 2;
      canvas.drawPath(
        _roundedTrackPath(
          center,
          radius,
          trackWidth,
          _angleForMinutes(startMinutes),
          sweep,
        ),
        paint,
      );
    }
  }

  void _drawTaskTrack(
    Canvas canvas,
    Offset center,
    double radius,
    double width,
    Task task,
  ) {
    if (task.startTime == null || task.endTime == null) return;

    final startMinutes = task.startTime!.hour * 60 + task.startTime!.minute;
    final endMinutes = task.endTime!.hour * 60 + task.endTime!.minute;

    final startAngle = _angleForMinutes(startMinutes);
    final double sweepAngle;
    if (endMinutes > startMinutes) {
      sweepAngle = ((endMinutes - startMinutes) / _minutesPerDay) * 2 * math.pi;
    } else {
      sweepAngle =
          ((_minutesPerDay - startMinutes + endMinutes) / _minutesPerDay) *
              2 *
              math.pi;
    }

    canvas.drawPath(
      _roundedTrackPath(center, radius, width, startAngle, sweepAngle),
      Paint()
        ..color = task.color.withOpacity(0.9)
        ..style = PaintingStyle.fill,
    );
  }

  Offset _polar(Offset center, double radius, double angle) {
    return Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
  }

  /// Annular sector whose radial cuts use a small corner radius (not a full cap).
  Path _roundedTrackPath(
    Offset center,
    double radius,
    double width,
    double startAngle,
    double sweepAngle,
  ) {
    final outerR = radius + width / 2;
    final innerR = math.max(1.0, radius - width / 2);
    var corner = math.min(width * 0.22, 7.0);
    corner = math.min(corner, (outerR - innerR) / 2 * 0.9);

    final innerLength = innerR * sweepAngle;
    if (innerLength < corner * 2 + 2) {
      corner = math.max(0.0, (innerLength - 2) / 2);
    }

    if (corner < 0.75) {
      return _sharpTrackPath(
        center,
        outerR,
        innerR,
        startAngle,
        sweepAngle,
      );
    }

    final dOuter = math.asin(
      (corner / (outerR - corner)).clamp(0.0, 0.999),
    );
    final dInner = math.asin(
      (corner / (innerR + corner)).clamp(0.0, 0.999),
    );

    if (sweepAngle <= math.max(dOuter, dInner) * 2) {
      return _sharpTrackPath(
        center,
        outerR,
        innerR,
        startAngle,
        sweepAngle,
      );
    }

    final endAngle = startAngle + sweepAngle;
    final outerAlong = (outerR - corner) * math.cos(dOuter);
    final innerAlong = (innerR + corner) * math.cos(dInner);
    final cr = Radius.circular(corner);

    final outerStart = _polar(center, outerR, startAngle + dOuter);
    final innerEnd = _polar(center, innerR, endAngle - dInner);
    final endOuterCut = _polar(center, outerAlong, endAngle);
    final endInnerCut = _polar(center, innerAlong, endAngle);
    final startInnerCut = _polar(center, innerAlong, startAngle);
    final startOuterCut = _polar(center, outerAlong, startAngle);

    final path = Path()..moveTo(outerStart.dx, outerStart.dy);
    path.arcTo(
      Rect.fromCircle(center: center, radius: outerR),
      startAngle + dOuter,
      sweepAngle - 2 * dOuter,
      false,
    );
    path.arcToPoint(endOuterCut, radius: cr, clockwise: true);
    path.lineTo(endInnerCut.dx, endInnerCut.dy);
    path.arcToPoint(innerEnd, radius: cr, clockwise: true);
    path.arcTo(
      Rect.fromCircle(center: center, radius: innerR),
      endAngle - dInner,
      -(sweepAngle - 2 * dInner),
      false,
    );
    path.arcToPoint(startInnerCut, radius: cr, clockwise: true);
    path.lineTo(startOuterCut.dx, startOuterCut.dy);
    path.arcToPoint(outerStart, radius: cr, clockwise: true);
    path.close();
    return path;
  }

  Path _sharpTrackPath(
    Offset center,
    double outerR,
    double innerR,
    double startAngle,
    double sweepAngle,
  ) {
    final endAngle = startAngle + sweepAngle;
    final path = Path()
      ..moveTo(
        _polar(center, outerR, startAngle).dx,
        _polar(center, outerR, startAngle).dy,
      );
    path.arcTo(
      Rect.fromCircle(center: center, radius: outerR),
      startAngle,
      sweepAngle,
      false,
    );
    path.lineTo(
      _polar(center, innerR, endAngle).dx,
      _polar(center, innerR, endAngle).dy,
    );
    path.arcTo(
      Rect.fromCircle(center: center, radius: innerR),
      endAngle,
      -sweepAngle,
      false,
    );
    path.close();
    return path;
  }

  void _drawNowIndicator(
    Canvas canvas,
    Offset center,
    double innerRadius,
    double outerRadius,
  ) {
    final minutes = currentTime.hour * 60 + currentTime.minute;
    final angle = _angleForMinutes(minutes);
    final shaftWidth = math.max(3.0, (outerRadius - innerRadius) * 0.018);
    final tipRadius = shaftWidth * 1.15;
    final haloRadius = tipRadius + 1.6;
    // Keep the cap fully inside the square so it isn't clipped at 12/6.
    final tipCenter = outerRadius - haloRadius - 1;
    final shaftEnd = tipCenter - tipRadius * 0.35;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final shaft = RRect.fromLTRBR(
      innerRadius,
      -shaftWidth / 2,
      shaftEnd,
      shaftWidth / 2,
      Radius.circular(math.min(3.0, shaftWidth / 2)),
    );

    canvas.drawRRect(
      shaft.inflate(2.5),
      Paint()..color = nowOnColor.withOpacity(0.45),
    );
    canvas.drawRRect(
      shaft,
      Paint()..color = nowColor.withOpacity(0.92),
    );

    canvas.drawCircle(
      Offset(tipCenter, 0),
      tipRadius + 1.6,
      Paint()..color = nowOnColor.withOpacity(0.55),
    );
    canvas.drawCircle(
      Offset(tipCenter, 0),
      tipRadius,
      Paint()..color = nowColor.withOpacity(0.95),
    );
    canvas.drawCircle(
      Offset(tipCenter, 0),
      tipRadius * 0.38,
      Paint()..color = nowOnColor.withOpacity(0.9),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(PolarClockPainter oldDelegate) {
    return oldDelegate.currentTime != currentTime ||
        oldDelegate.tasks != tasks ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.nowColor != nowColor ||
        oldDelegate.nowOnColor != nowOnColor;
  }
}
