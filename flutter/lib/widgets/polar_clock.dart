import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

class _ArcGeom {
  final String id;
  final double start;
  final double duration;
  final Color color;
  final double opacity;
  final double lane;
  final double laneCount;

  const _ArcGeom({
    required this.id,
    required this.start,
    required this.duration,
    required this.color,
    required this.opacity,
    required this.lane,
    required this.laneCount,
  });

  String get signature =>
      '$id:${start.toStringAsFixed(1)}:${duration.toStringAsFixed(1)}:'
      '${lane.toStringAsFixed(2)}:${color.value}:${opacity.toStringAsFixed(2)}';
}

class PolarClock extends StatefulWidget {
  final TimeOfDay currentTime;
  final List<Task> tasks;
  final double size;
  final ValueChanged<Task>? onTaskTap;

  const PolarClock({
    super.key,
    required this.currentTime,
    required this.tasks,
    this.size = 300,
    this.onTaskTap,
  });

  @override
  State<PolarClock> createState() => _PolarClockState();
}

class _PolarClockState extends State<PolarClock>
    with SingleTickerProviderStateMixin {
  static const _animDuration = Duration(milliseconds: 480);

  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  Map<String, _ArcGeom> _from = {};
  Map<String, _ArcGeom> _to = {};

  @override
  void initState() {
    super.initState();
    _to = _snapshot(widget.tasks, widget.currentTime);
    _from = Map.of(_to);
    _controller = AnimationController(vsync: this, duration: _animDuration);
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _from = Map.of(_to);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncArcs(reduce: MediaQuery.disableAnimationsOf(context));
  }

  @override
  void didUpdateWidget(PolarClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncArcs(reduce: MediaQuery.disableAnimationsOf(context));
  }

  void _syncArcs({required bool reduce}) {
    final next = _snapshot(widget.tasks, widget.currentTime);
    if (_signature(next) == _signature(_to)) return;
    _from = _displayed(_curve.value);
    _to = next;
    if (reduce) {
      _from = Map.of(_to);
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  String _signature(Map<String, _ArcGeom> arcs) {
    final ids = arcs.keys.toList()..sort();
    return ids.map((id) => arcs[id]!.signature).join('|');
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, _) {
          final arcs = _displayed(_curve.value).values.toList();
          return _ArcHitTarget(
            arcs: arcs,
            onTapId: widget.onTaskTap == null
                ? null
                : (id) {
                    Task? task;
                    for (final t in widget.tasks) {
                      if (t.id == id) {
                        task = t;
                        break;
                      }
                    }
                    if (task != null) widget.onTaskTap!(task);
                  },
            child: CustomPaint(
              painter: PolarClockPainter(
                currentTime: widget.currentTime,
                arcs: arcs,
                trackColor: Theme.of(context).colorScheme.outlineVariant,
                nowColor: Theme.of(context).colorScheme.onSurface,
                nowOnColor: Theme.of(context).colorScheme.surface,
              ),
            ),
          );
        },
      ),
    );
  }

  Map<String, _ArcGeom> _displayed(double t) {
    final ids = {..._from.keys, ..._to.keys};
    final result = <String, _ArcGeom>{};
    for (final id in ids) {
      final a = _from[id];
      final b = _to[id];
      if (a == null && b != null) {
        result[id] = _lerpArc(_spawn(b), b, t);
      } else if (a != null && b == null) {
        result[id] = _lerpArc(a, _vanish(a), t);
      } else if (a != null && b != null) {
        result[id] = _lerpArc(a, b, t);
      }
    }
    return result;
  }

  _ArcGeom _spawn(_ArcGeom target) => _ArcGeom(
        id: target.id,
        start: target.start,
        duration: 0,
        color: target.color,
        opacity: 0,
        lane: target.lane,
        laneCount: target.laneCount,
      );

  _ArcGeom _vanish(_ArcGeom source) => _ArcGeom(
        id: source.id,
        start: source.start,
        duration: source.duration,
        color: source.color,
        opacity: 0,
        lane: source.lane,
        laneCount: source.laneCount,
      );

  _ArcGeom _lerpArc(_ArcGeom a, _ArcGeom b, double t) {
    return _ArcGeom(
      id: b.id,
      start: _lerpMinutes(a.start, b.start, t),
      duration: lerpDouble(a.duration, b.duration, t)!,
      color: Color.lerp(a.color, b.color, t)!,
      opacity: lerpDouble(a.opacity, b.opacity, t)!,
      lane: lerpDouble(a.lane, b.lane, t)!,
      laneCount: lerpDouble(a.laneCount, b.laneCount, t)!,
    );
  }

  double _lerpMinutes(double a, double b, double t) {
    var delta = b - a;
    const day = PolarClockPainter._minutesPerDay;
    if (delta > day / 2) delta -= day;
    if (delta < -day / 2) delta += day;
    var value = a + delta * t;
    value %= day;
    if (value < 0) value += day;
    return value;
  }
}

Map<String, _ArcGeom> _snapshot(List<Task> tasks, TimeOfDay now) {
  final timed = tasks
      .where((t) =>
          !t.isAllDay &&
          !t.isCanceled &&
          t.startTime != null &&
          t.endTime != null)
      .toList();
  final lanes = _assignTasksToTracks(timed);
  final laneCount = lanes.length.toDouble();
  final map = <String, _ArcGeom>{};
  for (final entry in lanes.entries) {
    for (final task in entry.value) {
      final start = task.startTime!.hour * 60 + task.startTime!.minute;
      final end = task.endTime!.hour * 60 + task.endTime!.minute;
      final duration =
          start <= end ? end - start : PolarClockPainter._minutesPerDay - start + end;
      map[task.id] = _ArcGeom(
        id: task.id,
        start: start.toDouble(),
        duration: duration.toDouble(),
        color: task.color,
        opacity: task.isUpcoming(now) ? 0.95 : 0.38,
        lane: entry.key.toDouble(),
        laneCount: laneCount,
      );
    }
  }
  return map;
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
  return PolarClockPainter._minutesPerDay - range.start + range.end;
}

List<(int, int)> _segments(_TaskRange range) {
  if (range.start == range.end) {
    return [(range.start, range.end)];
  }
  if (range.start < range.end) {
    return [(range.start, range.end)];
  }
  return [
    (range.start, PolarClockPainter._minutesPerDay),
    (0, range.end),
  ];
}

bool _rangesOverlap(_TaskRange a, _TaskRange b) {
  for (final sa in _segments(a)) {
    for (final sb in _segments(b)) {
      if (sa.$1 < sb.$2 && sb.$1 < sa.$2) return true;
    }
  }
  return false;
}

class _ArcHitTarget extends SingleChildRenderObjectWidget {
  final List<_ArcGeom> arcs;
  final ValueChanged<String>? onTapId;

  const _ArcHitTarget({
    required this.arcs,
    required this.onTapId,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderArcHit(arcs: arcs, onTapId: onTapId);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderArcHit renderObject,
  ) {
    renderObject
      ..arcs = arcs
      ..onTapId = onTapId;
  }
}

class _RenderArcHit extends RenderProxyBox {
  _RenderArcHit({
    required List<_ArcGeom> arcs,
    required this.onTapId,
  }) : _arcs = arcs;

  List<_ArcGeom> _arcs;
  ValueChanged<String>? onTapId;

  set arcs(List<_ArcGeom> value) {
    _arcs = value;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (onTapId == null || size == Size.zero || !size.contains(position)) {
      return false;
    }
    if (!_containsArc(position)) return false;
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  @override
  void handleEvent(PointerEvent event, covariant HitTestEntry entry) {
    if (event is PointerUpEvent && onTapId != null) {
      final id = _idAt(event.localPosition);
      if (id != null) onTapId!(id);
    }
  }

  bool _containsArc(Offset position) => _idAt(position) != null;

  String? _idAt(Offset position) {
    return PolarClockPainter.idAt(position, size, _arcs);
  }
}

class PolarClockPainter extends CustomPainter {
  static const _minutesPerDay = 24 * 60;

  final TimeOfDay currentTime;
  final List<_ArcGeom> arcs;
  final Color trackColor;
  final Color nowColor;
  final Color nowOnColor;

  PolarClockPainter({
    required this.currentTime,
    required this.arcs,
    required this.trackColor,
    required this.nowColor,
    required this.nowOnColor,
  });

  /// Midnight at 9 o'clock (left), sweeping clockwise.
  static double angleForMinutes(num minutes) {
    return math.pi + 2 * math.pi * (minutes / _minutesPerDay);
  }

  double _angleForMinutes(num minutes) => angleForMinutes(minutes);

  static String? idAt(Offset position, Size size, List<_ArcGeom> arcs) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;
    final holeRadius = maxRadius * 0.22;
    final hourTrackWidth = math.max(6.0, maxRadius * 0.035);
    final hourTrackRadius = holeRadius + hourTrackWidth / 2;
    final tracksInner = hourTrackRadius + hourTrackWidth / 2 + 3;
    final tracksOuter = maxRadius - 2;
    if (tracksOuter <= tracksInner) return null;

    final delta = position - center;
    final dist = delta.distance;
    var angle = math.atan2(delta.dy, delta.dx);
    var minutes = ((angle - math.pi) / (2 * math.pi)) * _minutesPerDay;
    minutes %= _minutesPerDay;
    if (minutes < 0) minutes += _minutesPerDay;

    final visible = arcs
        .where((a) => a.opacity > 0.015 && a.duration > 0.4)
        .toList()
      ..sort((a, b) => b.lane.compareTo(a.lane));

    for (final arc in visible) {
      final n = math.max(1.0, arc.laneCount);
      final gap = n > 1
          ? math.min(2.5, (tracksOuter - tracksInner) * 0.015)
          : 0.0;
      final trackWidth =
          ((tracksOuter - tracksInner) - gap * (n - 1)) / n;
      final innerEdge = tracksInner + arc.lane * (trackWidth + gap);
      final outerEdge = innerEdge + trackWidth;
      if (dist < innerEdge || dist > outerEdge) continue;

      var t = minutes;
      if (t < arc.start) t += _minutesPerDay;
      if (t >= arc.start && t < arc.start + arc.duration) {
        return arc.id;
      }
    }
    return null;
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

    if (tracksOuter > tracksInner) {
      final visible = arcs.where((a) => a.opacity > 0.015 && a.duration > 0.4);
      if (visible.isEmpty) {
        _drawGhostHourTracks(canvas, center, tracksInner, tracksOuter);
      } else {
        for (final arc in visible) {
          _drawTaskTrack(canvas, center, tracksInner, tracksOuter, arc);
        }
      }
    }

    _drawNowIndicator(
      canvas,
      center,
      hourTrackRadius - hourTrackWidth / 2,
      maxRadius,
    );
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
    double tracksInner,
    double tracksOuter,
    _ArcGeom arc,
  ) {
    final n = math.max(1.0, arc.laneCount);
    final gap = n > 1
        ? math.min(2.5, (tracksOuter - tracksInner) * 0.015)
        : 0.0;
    final trackWidth =
        ((tracksOuter - tracksInner) - gap * (n - 1)) / n;
    final innerEdge = tracksInner + arc.lane * (trackWidth + gap);
    final radius = innerEdge + trackWidth / 2;

    final startAngle = _angleForMinutes(arc.start);
    final sweepAngle = (arc.duration / _minutesPerDay) * 2 * math.pi;
    if (sweepAngle < 0.004) return;

    canvas.drawPath(
      _roundedTrackPath(center, radius, trackWidth, startAngle, sweepAngle),
      Paint()
        ..color = arc.color.withOpacity(arc.opacity)
        ..style = PaintingStyle.fill,
    );

    final now = (currentTime.hour * 60 + currentTime.minute).toDouble();
    var nowU = now;
    final end = arc.start + arc.duration;
    if (nowU < arc.start) nowU += _minutesPerDay;
    if (nowU < arc.start || nowU >= end) return;
    if (arc.opacity < 0.2) return;

    final remaining = end - nowU;
    final remainingSweep = (remaining / _minutesPerDay) * 2 * math.pi;
    if (remainingSweep < 0.004) return;

    canvas.drawPath(
      _roundedTrackPath(
        center,
        radius,
        trackWidth,
        _angleForMinutes(nowU),
        remainingSweep,
      ),
      Paint()
        ..color = arc.color.withOpacity(0.95)
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
        oldDelegate.arcs != arcs ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.nowColor != nowColor ||
        oldDelegate.nowOnColor != nowOnColor;
  }
}
