import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timetodo/models/scheduled_task.dart';
import 'package:timetodo/providers/polar_clock_settings.dart';
import 'package:timetodo/providers/task_provider.dart';
import 'package:timetodo/widgets/polar_clock.dart';

/// Compact polar-clock glyph for navigation, mirroring today's schedule.
class PolarNavIcon extends StatelessWidget {
  static const maxTracks = 3;

  final bool selected;

  const PolarNavIcon({super.key, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;
    final tasks = context.watch<TaskProvider>().getTasksForToday();
    final polar = context.watch<PolarClockSettings>();
    final look = polar.look.copyWith(hourLabels: 0, hours12: false);
    final arcs = _navArcs(tasks, look);
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(
        painter: _PolarNavPainter(
          color: color,
          arcs: arcs,
          selected: selected,
          look: look,
        ),
      ),
    );
  }
}

class _NavArc {
  final double startMinutes;
  final double durationMinutes;
  final double lane;
  final double laneCount;

  const _NavArc({
    required this.startMinutes,
    required this.durationMinutes,
    required this.lane,
    required this.laneCount,
  });

  String get signature =>
      '${startMinutes.toStringAsFixed(1)}:${durationMinutes.toStringAsFixed(1)}:'
      '${lane.toStringAsFixed(1)}:${laneCount.toStringAsFixed(1)}';
}

List<_NavArc> _navArcs(
  List<ScheduledTask> todayTasks,
  PolarClockLook look,
) {
  const minutesPerDay = 24 * 60;
  final tracks = assignPolarTracks(
    polarTimedTasks(todayTasks),
    maxTracks: PolarNavIcon.maxTracks,
  );
  if (tracks.isEmpty) return const [];
  final laneCount = tracks.length.toDouble();
  final arcs = <_NavArc>[];
  for (final entry in tracks.entries) {
    for (final task in entry.value) {
      var start = task.startTime!.hour * 60 + task.startTime!.minute;
      final end = task.endTime!.hour * 60 + task.endTime!.minute;
      var duration =
          start <= end ? end - start : minutesPerDay - start + end;
      arcs.add(_NavArc(
        startMinutes: start.toDouble(),
        durationMinutes: duration.toDouble(),
        lane: entry.key.toDouble(),
        laneCount: laneCount,
      ));
    }
  }
  return arcs;
}

class _PolarNavPainter extends CustomPainter {
  final Color color;
  final List<_NavArc> arcs;
  final bool selected;
  final PolarClockLook look;

  _PolarNavPainter({
    required this.color,
    required this.arcs,
    required this.selected,
    required this.look,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final maxR = size.shortestSide / 2 - 0.6;
    final inner = maxR * 0.32;
    final outer = maxR;

    final ring = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawCircle(c, maxR, ring);

    if (arcs.isEmpty) {
      return;
    }

    final n = math.max(1.0, arcs.first.laneCount);
    final gap = n > 1 ? math.min(1.4, (outer - inner) * 0.08) : 0.0;
    final trackWidth = ((outer - inner) - gap * (n - 1)) / n;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = math.max(selected ? 1.8 : 1.6, trackWidth * 0.92);

    for (final arc in arcs) {
      final innerEdge = inner + arc.lane * (trackWidth + gap);
      final radius = innerEdge + trackWidth / 2;
      final sweep =
          (arc.durationMinutes / look.cycleMinutes) * 2 * math.pi;
      if (sweep < 0.04) continue;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: radius),
        PolarClockPainter.angleForMinutes(arc.startMinutes, look: look),
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PolarNavPainter oldDelegate) {
    if (oldDelegate.color != color ||
        oldDelegate.selected != selected ||
        oldDelegate.look != look) {
      return true;
    }
    if (oldDelegate.arcs.length != arcs.length) return true;
    for (var i = 0; i < arcs.length; i++) {
      if (oldDelegate.arcs[i].signature != arcs[i].signature) return true;
    }
    return false;
  }
}
