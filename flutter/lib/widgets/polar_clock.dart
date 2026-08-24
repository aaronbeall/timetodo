import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:timetodo/models/scheduled_task.dart';
import 'package:timetodo/time_utils.dart';

class _TaskRange {
  final ScheduledTask task;
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

  _ArcGeom copyWith({
    double? start,
    double? duration,
    double? opacity,
    double? lane,
    double? laneCount,
  }) {
    return _ArcGeom(
      id: id,
      start: start ?? this.start,
      duration: duration ?? this.duration,
      color: color,
      opacity: opacity ?? this.opacity,
      lane: lane ?? this.lane,
      laneCount: laneCount ?? this.laneCount,
    );
  }
}

enum _MoveGrab { body, start, end }

class PolarClock extends StatefulWidget {
  static const moveActionsExtent = 48.0;
  final TimeOfDay currentTime;
  final List<ScheduledTask> tasks;
  final double size;
  final ValueChanged<ScheduledTask>? onTaskTap;
  final bool animate;
  final bool showNow;
  final bool enableMove;
  final String? movingTaskId;
  final ValueChanged<ScheduledTask>? onMoveStart;
  final VoidCallback? onMoveCancel;
  final void Function(ScheduledTask task, TimeOfDay start, TimeOfDay end)?
      onMoveCommit;

  const PolarClock({
    super.key,
    required this.currentTime,
    required this.tasks,
    this.size = 300,
    this.onTaskTap,
    this.animate = true,
    this.showNow = true,
    this.enableMove = false,
    this.movingTaskId,
    this.onMoveStart,
    this.onMoveCancel,
    this.onMoveCommit,
  });

  @override
  State<PolarClock> createState() => _PolarClockState();
}

class _PolarClockState extends State<PolarClock>
    with SingleTickerProviderStateMixin {
  static const _animDuration = Duration(milliseconds: 480);
  static const _snap = 5.0;
  static const _minDuration = 5.0;

  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  Map<String, _ArcGeom> _from = {};
  Map<String, _ArcGeom> _to = {};
  double? _draftStart;
  double? _draftDuration;
  _MoveGrab? _grab;
  _MoveGrab? _pendingLabel;
  Offset? _pointerDownPos;
  double _grabStart = 0;
  double _grabDuration = 0;
  double _grabPointer = 0;
  int _lastSnapped = -1;
  String? _sessionId;
  ({Rect start, Rect end})? _moveChips;

  @override
  void initState() {
    super.initState();
    _to = _snapshot(
      widget.tasks,
      widget.currentTime,
      fullColor: !widget.showNow,
    );
    _from = Map.of(_to);
    if (widget.movingTaskId != null) {
      _primeDraft(widget.movingTaskId!);
    }
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
    if (widget.movingTaskId != oldWidget.movingTaskId) {
      _moveChips = null;
      if (widget.movingTaskId == null) {
        _sessionId = null;
        _draftStart = null;
        _draftDuration = null;
        _grab = null;
      } else {
        _sessionId = widget.movingTaskId;
        if (_draftStart == null) {
          _primeDraft(widget.movingTaskId!);
        }
      }
    }
    _syncArcs(reduce: MediaQuery.disableAnimationsOf(context));
  }

  String? get _activeId => widget.movingTaskId ?? _sessionId;

  bool get _isMoving => _activeId != null && _draftStart != null;

  ScheduledTask? _taskById(String id) {
    for (final task in widget.tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  void _primeDraft(String id) {
    final task = _taskById(id);
    if (task == null ||
        task.isAllDay ||
        task.startTime == null ||
        task.endTime == null) {
      _draftStart = null;
      _draftDuration = null;
      return;
    }
    _draftStart = minutesOf(task.startTime!).toDouble();
    _draftDuration =
        durationMinutes(task.startTime!, task.endTime!).toDouble();
    _lastSnapped = -1;
  }

  double _snapMinutes(double minutes) {
    var value = (minutes / _snap).round() * _snap;
    value %= PolarClockPainter._minutesPerDay;
    if (value < 0) value += PolarClockPainter._minutesPerDay;
    return value;
  }

  double? _minutesAt(Offset local) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final delta = local - center;
    if (delta.distance < 8) return null;
    var angle = math.atan2(delta.dy, delta.dx);
    var minutes =
        ((angle - math.pi) / (2 * math.pi)) * PolarClockPainter._minutesPerDay;
    minutes %= PolarClockPainter._minutesPerDay;
    if (minutes < 0) minutes += PolarClockPainter._minutesPerDay;
    return minutes;
  }

  _MoveGrab? _grabAt(Offset local, _ArcGeom arc) {
    final size = Size(widget.size, widget.size);
    final band = PolarClockPainter.bandFor(arc, size);
    final startPt =
        PolarClockPainter.pointAt(size, band.mid, arc.start);
    final endMin = (arc.start + arc.duration) % PolarClockPainter._minutesPerDay;
    final endPt = PolarClockPainter.pointAt(size, band.mid, endMin);
    final handleR = 16.0;
    final ds = (local - startPt).distance;
    final de = (local - endPt).distance;
    if (ds <= handleR && ds <= de) return _MoveGrab.start;
    if (de <= handleR) return _MoveGrab.end;
    if (PolarClockPainter.idAt(local, size, [arc]) == arc.id) {
      return _MoveGrab.body;
    }
    return null;
  }

  _MoveGrab? _labelAt(Offset local, _ArcGeom arc) {
    final chips = _moveChips;
    if (chips == null) return null;
    final startRect = chips.start.inflate(4);
    final endRect = chips.end.inflate(4);
    final inStart = startRect.contains(local);
    final inEnd = endRect.contains(local);
    if (inStart && inEnd) {
      final cs = (local - chips.start.center).distance;
      final ce = (local - chips.end.center).distance;
      return cs <= ce ? _MoveGrab.start : _MoveGrab.end;
    }
    if (inStart) return _MoveGrab.start;
    if (inEnd) return _MoveGrab.end;
    return null;
  }

  void _beginMove(String id) {
    final task = _taskById(id);
    if (task == null ||
        task.isAllDay ||
        task.startTime == null ||
        task.endTime == null) {
      return;
    }
    HapticFeedback.mediumImpact();
    _sessionId = id;
    _primeDraft(id);
    _syncArcs(reduce: MediaQuery.disableAnimationsOf(context));
    setState(() {});
    widget.onMoveStart?.call(task);
  }

  void _onPointerDown(Offset local) {
    if (!_isMoving) return;
    _ArcGeom? moving;
    for (final arc in _paintArcs(_displayed(_curve.value).values.toList())) {
      if (arc.id == _activeId) {
        moving = arc;
        break;
      }
    }
    if (moving == null) return;
    _pointerDownPos = local;
    final grab = _grabAt(local, moving);
    final pointer = _minutesAt(local);
    if (grab == _MoveGrab.start || grab == _MoveGrab.end) {
      _pendingLabel = null;
      if (pointer == null) {
        _grab = null;
        return;
      }
      _grab = grab;
      _grabStart = _draftStart!;
      _grabDuration = _draftDuration!;
      _grabPointer = pointer;
      return;
    }
    final label = _labelAt(local, moving);
    if (label != null) {
      _grab = null;
      _pendingLabel = label;
      return;
    }
    _pendingLabel = null;
    if (grab == null || pointer == null) {
      _grab = null;
      return;
    }
    _grab = grab;
    _grabStart = _draftStart!;
    _grabDuration = _draftDuration!;
    _grabPointer = pointer;
  }

  void _onPointerMove(Offset local) {
    if (!_isMoving) return;
    if (_pendingLabel != null) {
      if (_pointerDownPos != null &&
          (local - _pointerDownPos!).distance > 12) {
        _pendingLabel = null;
      }
      return;
    }
    if (_grab == null) return;
    final pointer = _minutesAt(local);
    if (pointer == null) return;
    var delta = pointer - _grabPointer;
    const day = PolarClockPainter._minutesPerDay;
    if (delta > day / 2) delta -= day;
    if (delta < -day / 2) delta += day;

    var start = _grabStart;
    var duration = _grabDuration;
    switch (_grab!) {
      case _MoveGrab.body:
        start = _snapMinutes(_grabStart + delta);
        break;
      case _MoveGrab.start:
        final end = (_grabStart + _grabDuration) % day;
        start = _snapMinutes(pointer);
        duration = end - start;
        if (duration <= 0) duration += day;
        if (duration < _minDuration) duration = _minDuration;
        break;
      case _MoveGrab.end:
        start = _grabStart;
        duration = _snapMinutes(pointer) - start;
        if (duration <= 0) duration += day;
        if (duration < _minDuration) duration = _minDuration;
        duration = _snapMinutes(start + duration) - start;
        if (duration <= 0) duration += day;
        if (duration < _minDuration) duration = _minDuration;
        break;
    }
    final snapped = ((start + duration) * 100 + start).round();
    if (snapped != _lastSnapped) {
      _lastSnapped = snapped;
      HapticFeedback.selectionClick();
    }
    setState(() {
      _draftStart = start % day;
      if (_draftStart! < 0) _draftStart = _draftStart! + day;
      _draftDuration = duration;
    });
    _syncArcs(reduce: true);
  }

  void _onPointerUp() {
    final pending = _pendingLabel;
    _grab = null;
    _pendingLabel = null;
    _pointerDownPos = null;
    if (pending == _MoveGrab.start || pending == _MoveGrab.end) {
      _pickMoveTime(pending!);
    }
  }

  Future<void> _pickMoveTime(_MoveGrab which) async {
    final start = _draftStart;
    final duration = _draftDuration;
    if (start == null || duration == null) return;
    const day = PolarClockPainter._minutesPerDay;
    final initial = which == _MoveGrab.start
        ? timeFromMinutes(start.round())
        : timeFromMinutes((start + duration).round() % day);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: which == _MoveGrab.start ? 'Start time' : 'End time',
    );
    if (picked == null || !mounted) return;
    final minutes = minutesOf(picked).toDouble();
    var nextStart = start;
    var nextDuration = duration;
    if (which == _MoveGrab.start) {
      final end = (start + duration) % day;
      nextStart = minutes;
      nextDuration = end - nextStart;
      if (nextDuration <= 0) nextDuration += day;
      if (nextDuration < _minDuration) nextDuration = _minDuration;
    } else {
      nextDuration = minutes - nextStart;
      if (nextDuration <= 0) nextDuration += day;
      if (nextDuration < _minDuration) nextDuration = _minDuration;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _draftStart = nextStart % day;
      if (_draftStart! < 0) _draftStart = _draftStart! + day;
      _draftDuration = nextDuration;
    });
    _syncArcs(reduce: MediaQuery.disableAnimationsOf(context));
  }

  void _commitMove() {
    final id = _activeId;
    final start = _draftStart;
    final duration = _draftDuration;
    if (id == null || start == null || duration == null) return;
    final task = _taskById(id);
    if (task == null) return;
    const day = PolarClockPainter._minutesPerDay;
    widget.onMoveCommit?.call(
      task,
      timeFromMinutes(start.round()),
      timeFromMinutes((start + duration).round() % day),
    );
    setState(() {
      _sessionId = null;
      _draftStart = null;
      _draftDuration = null;
      _grab = null;
    });
  }

  void _cancelMove() {
    setState(() {
      _sessionId = null;
      _draftStart = null;
      _draftDuration = null;
      _grab = null;
    });
    widget.onMoveCancel?.call();
  }

  List<_ArcGeom> _paintArcs(List<_ArcGeom> base) {
    final id = _activeId;
    if (id == null || !_isMoving) return base;
    return [
      for (final arc in base)
        if (arc.id == id)
          arc.copyWith(opacity: 1)
        else
          arc.copyWith(opacity: arc.opacity * 0.22),
    ];
  }

  void _syncArcs({required bool reduce}) {
    final next = _snapshot(
      widget.tasks,
      widget.currentTime,
      fullColor: !widget.showNow,
      draftId: _isMoving ? _activeId : null,
      draftStart: _draftStart,
      draftDuration: _draftDuration,
    );
    if (_signature(next) == _signature(_to)) return;
    _from = _displayed(_curve.value);
    _to = next;
    if (reduce || !widget.animate) {
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
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, _) {
        final arcs = _paintArcs(_displayed(_curve.value).values.toList());
        final scheme = Theme.of(context).colorScheme;
        final clockSize = Size(widget.size, widget.size);
        _ArcGeom? moving;
        if (_isMoving) {
          for (final arc in arcs) {
            if (arc.id == _activeId) {
              moving = arc;
              break;
            }
          }
        }
        if (moving != null) {
          final laid = PolarClockPainter.layoutMoveChips(clockSize, moving);
          _moveChips = (start: laid.start, end: laid.end);
        } else {
          _moveChips = null;
        }
        return SizedBox(
          width: widget.size,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: _ArcHitTarget(
                  arcs: arcs,
                  moving: _isMoving,
                  onTapId: _isMoving || widget.onTaskTap == null
                      ? null
                      : (id) {
                          ScheduledTask? task;
                          for (final t in widget.tasks) {
                            if (t.id == id) {
                              task = t;
                              break;
                            }
                          }
                          if (task != null) widget.onTaskTap!(task);
                        },
                  onLongPressId: !widget.enableMove || _isMoving
                      ? null
                      : _beginMove,
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerUp,
                  child: CustomPaint(
                    size: clockSize,
                    painter: PolarClockPainter(
                      currentTime: widget.currentTime,
                      arcs: arcs,
                      trackColor: scheme.outlineVariant,
                      nowColor: scheme.onSurface,
                      nowOnColor: scheme.surface,
                      showNow: widget.showNow,
                      movingId: _activeId,
                      handleFill: scheme.surface,
                      handleRing: scheme.onSurface,
                      moveChips: _moveChips,
                    ),
                  ),
                ),
              ),
              if (_isMoving)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _cancelMove,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: scheme.onSurfaceVariant,
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _commitMove,
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          minimumSize: const Size(0, 36),
                        ),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
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

Map<String, _ArcGeom> _snapshot(
  List<ScheduledTask> tasks,
  TimeOfDay now, {
  bool fullColor = false,
  String? draftId,
  double? draftStart,
  double? draftDuration,
}) {
  final timed = polarTimedTasks(tasks);
  const day = PolarClockPainter._minutesPerDay;
  final ranges = timed.map((task) {
    if (task.id == draftId && draftStart != null && draftDuration != null) {
      final start = draftStart.round();
      final end = (start + draftDuration.round()) % day;
      return _TaskRange(task: task, start: start, end: end);
    }
    final start = task.startTime!.hour * 60 + task.startTime!.minute;
    final end = task.endTime!.hour * 60 + task.endTime!.minute;
    return _TaskRange(task: task, start: start, end: end);
  }).toList();
  final lanes = assignPolarTracksFromRanges(ranges);
  final laneCount = lanes.length.toDouble();
  final map = <String, _ArcGeom>{};
  for (final entry in lanes.entries) {
    for (final range in entry.value) {
      final task = range.task;
      final duration = _durationMinutes(range).toDouble();
      if (duration < 0.4) continue;
      map[task.id] = _ArcGeom(
        id: task.id,
        start: range.start.toDouble(),
        duration: duration,
        color: task.color,
        opacity: fullColor || task.isUpcoming(now) ? 0.95 : 0.38,
        lane: entry.key.toDouble(),
        laneCount: math.max(1.0, laneCount),
      );
    }
  }
  return map;
}

/// Timed, non-canceled tasks that appear as polar bands.
List<ScheduledTask> polarTimedTasks(List<ScheduledTask> tasks) {
  return tasks
      .where((t) =>
          !t.isAllDay &&
          !t.isCanceled &&
          t.startTime != null &&
          t.endTime != null)
      .toList();
}

/// Packs overlapping tasks onto concentric tracks (0 = innermost).
/// Longer tasks are placed first. [maxTracks] drops bands that would need
/// an extra concurrent lane.
Map<int, List<ScheduledTask>> assignPolarTracks(
  List<ScheduledTask> tasks, {
  int? maxTracks,
}) {
  final ranges = tasks.map((task) {
    final start = task.startTime!.hour * 60 + task.startTime!.minute;
    final end = task.endTime!.hour * 60 + task.endTime!.minute;
    return _TaskRange(task: task, start: start, end: end);
  }).toList();
  return {
    for (final entry in assignPolarTracksFromRanges(
      ranges,
      maxTracks: maxTracks,
    ).entries)
      entry.key: [for (final range in entry.value) range.task],
  };
}

Map<int, List<_TaskRange>> assignPolarTracksFromRanges(
  List<_TaskRange> taskRanges, {
  int? maxTracks,
}) {
  final sorted = [...taskRanges]..sort((a, b) {
      final byDuration = _durationMinutes(b).compareTo(_durationMinutes(a));
      if (byDuration != 0) return byDuration;
      return a.start.compareTo(b.start);
    });

  final Map<int, List<_TaskRange>> tracks = {};
  final List<List<_TaskRange>> trackRanges = [];

  for (final taskRange in sorted) {
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
      if (maxTracks != null && trackRanges.length >= maxTracks) {
        continue;
      }
      trackIndex = trackRanges.length;
      trackRanges.add([]);
      tracks[trackIndex] = [];
    }

    trackRanges[trackIndex].add(taskRange);
    tracks[trackIndex]!.add(taskRange);
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
  final bool moving;
  final ValueChanged<String>? onTapId;
  final ValueChanged<String>? onLongPressId;
  final ValueChanged<Offset>? onPointerDown;
  final ValueChanged<Offset>? onPointerMove;
  final VoidCallback? onPointerUp;

  const _ArcHitTarget({
    required this.arcs,
    required this.moving,
    required this.onTapId,
    required this.onLongPressId,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderArcHit(
      arcs: arcs,
      moving: moving,
      onTapId: onTapId,
      onLongPressId: onLongPressId,
      onPointerDown: onPointerDown,
      onPointerMove: onPointerMove,
      onPointerUp: onPointerUp,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderArcHit renderObject,
  ) {
    renderObject
      ..arcs = arcs
      ..moving = moving
      ..onTapId = onTapId
      ..onLongPressId = onLongPressId
      ..onPointerDown = onPointerDown
      ..onPointerMove = onPointerMove
      ..onPointerUp = onPointerUp;
  }
}

class _RenderArcHit extends RenderProxyBox {
  _RenderArcHit({
    required List<_ArcGeom> arcs,
    required bool moving,
    required this.onTapId,
    required this.onLongPressId,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
  })  : _arcs = arcs,
        _moving = moving;

  List<_ArcGeom> _arcs;
  bool _moving;
  ValueChanged<String>? onTapId;
  ValueChanged<String>? onLongPressId;
  ValueChanged<Offset>? onPointerDown;
  ValueChanged<Offset>? onPointerMove;
  VoidCallback? onPointerUp;

  Timer? _longPress;
  Offset? _down;
  String? _downId;
  bool _longFired = false;
  int? _pointer;

  set arcs(List<_ArcGeom> value) {
    _arcs = value;
  }

  set moving(bool value) {
    _moving = value;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!hasSize) return false;
    if (size == Size.zero || !size.contains(position)) return false;
    if (_moving) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    final canInteract = onTapId != null || onLongPressId != null;
    if (!canInteract) return false;
    if (!_containsArc(position)) return false;
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  @override
  void handleEvent(PointerEvent event, covariant HitTestEntry entry) {
    if (event is PointerDownEvent) {
      _pointer = event.pointer;
      _down = event.localPosition;
      _downId = _idAt(_down!);
      _longFired = false;
      _longPress?.cancel();
      if (_moving) {
        onPointerDown?.call(event.localPosition);
      } else if (_downId != null && onLongPressId != null) {
        _longPress = Timer(const Duration(milliseconds: 450), () {
          _longFired = true;
          onLongPressId!(_downId!);
          if (_down != null) onPointerDown?.call(_down!);
        });
      }
    } else if (event is PointerMoveEvent && event.pointer == _pointer) {
      if (!_longFired &&
          !_moving &&
          _down != null &&
          (event.localPosition - _down!).distance > 14) {
        _longPress?.cancel();
      }
      if (_moving || _longFired) {
        onPointerMove?.call(event.localPosition);
      }
    } else if (event is PointerUpEvent && event.pointer == _pointer) {
      _longPress?.cancel();
      if (_moving || _longFired) {
        onPointerUp?.call();
      } else if (_downId != null && !_longFired) {
        onTapId?.call(_downId!);
      }
      _pointer = null;
    } else if (event is PointerCancelEvent && event.pointer == _pointer) {
      _longPress?.cancel();
      _pointer = null;
      if (_moving) onPointerUp?.call();
    }
  }

  @override
  void dispose() {
    _longPress?.cancel();
    super.dispose();
  }

  bool _containsArc(Offset position) => _idAt(position) != null;

  String? _idAt(Offset position) {
    return PolarClockPainter.idAt(position, size, _arcs);
  }
}

class _PolarMetrics {
  final double holeRadius;
  final double hourTrackWidth;
  final double hourTrackRadius;
  final double tracksInner;
  final double tracksOuter;
  final double nowInnerRadius;
  final double shaftWidth;
  final double tipRadius;

  const _PolarMetrics({
    required this.holeRadius,
    required this.hourTrackWidth,
    required this.hourTrackRadius,
    required this.tracksInner,
    required this.tracksOuter,
    required this.nowInnerRadius,
    required this.shaftWidth,
    required this.tipRadius,
  });

  factory _PolarMetrics.of(Size size) {
    final maxRadius = math.min(size.width, size.height) / 2;
    final holeRadius = maxRadius * 0.22;
    final hourTrackWidth = math.max(6.0, maxRadius * 0.035);
    final hourTrackRadius = holeRadius + hourTrackWidth / 2;
    final tracksInner = hourTrackRadius + hourTrackWidth / 2 + 3;
    final nowInnerRadius = hourTrackRadius - hourTrackWidth / 2;
    final shaftWidth = math.max(3.0, (maxRadius - nowInnerRadius) * 0.018);
    final tipRadius = shaftWidth * 1.15;
    final capPad = tipRadius + 1.6;
    final tracksOuter = maxRadius - capPad;
    return _PolarMetrics(
      holeRadius: holeRadius,
      hourTrackWidth: hourTrackWidth,
      hourTrackRadius: hourTrackRadius,
      tracksInner: tracksInner,
      tracksOuter: tracksOuter,
      nowInnerRadius: nowInnerRadius,
      shaftWidth: shaftWidth,
      tipRadius: tipRadius,
    );
  }
}

class PolarClockPainter extends CustomPainter {
  static const _minutesPerDay = 24 * 60;

  final TimeOfDay currentTime;
  final List<_ArcGeom> arcs;
  final Color trackColor;
  final Color nowColor;
  final Color nowOnColor;
  final bool showNow;
  final String? movingId;
  final Color handleFill;
  final Color handleRing;
  final ({Rect start, Rect end})? moveChips;

  PolarClockPainter({
    required this.currentTime,
    required this.arcs,
    required this.trackColor,
    required this.nowColor,
    required this.nowOnColor,
    this.showNow = true,
    this.movingId,
    this.handleFill = Colors.white,
    this.handleRing = Colors.black,
    this.moveChips,
  });

  /// Midnight at 9 o'clock (left), sweeping clockwise.
  static double angleForMinutes(num minutes) {
    return math.pi + 2 * math.pi * (minutes / _minutesPerDay);
  }

  double _angleForMinutes(num minutes) => angleForMinutes(minutes);

  static String? idAt(Offset position, Size size, List<_ArcGeom> arcs) {
    final m = _PolarMetrics.of(size);
    final center = Offset(size.width / 2, size.height / 2);
    final tracksInner = m.tracksInner;
    final tracksOuter = m.tracksOuter;
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

  static ({double inner, double outer, double mid}) bandFor(
    _ArcGeom arc,
    Size size,
  ) {
    final m = _PolarMetrics.of(size);
    final n = math.max(1.0, arc.laneCount);
    final gap = n > 1
        ? math.min(2.5, (m.tracksOuter - m.tracksInner) * 0.015)
        : 0.0;
    final trackWidth =
        ((m.tracksOuter - m.tracksInner) - gap * (n - 1)) / n;
    final inner = m.tracksInner + arc.lane * (trackWidth + gap);
    final outer = inner + trackWidth;
    return (inner: inner, outer: outer, mid: inner + trackWidth / 2);
  }

  static Offset pointAt(Size size, double radius, double minutes) {
    final center = Offset(size.width / 2, size.height / 2);
    final angle = angleForMinutes(minutes);
    return Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
  }

  static double _moveHandleRadius(({double inner, double outer, double mid}) band) {
    return math.max(5.0, math.min(7.5, (band.outer - band.inner) * 0.28));
  }

  static Rect startTimeChipRect(Size size, _ArcGeom arc) {
    return layoutMoveChips(size, arc).start;
  }

  static Rect endTimeChipRect(Size size, _ArcGeom arc) {
    return layoutMoveChips(size, arc).end;
  }

  /// Labels sit on the handle's polar angle. Outer-half tracks place the chip
  /// toward the center; inner-half tracks place it outward. Offset is the
  /// handle radius plus the chip width so the label circle clears the grabber.
  static ({Rect start, Rect end}) layoutMoveChips(Size size, _ArcGeom arc) {
    final band = bandFor(arc, size);
    final metrics = _PolarMetrics.of(size);
    final handleVisualR = _moveHandleRadius(band) + 2;
    final midR = (metrics.tracksInner + metrics.tracksOuter) / 2;
    final inward = band.mid > midR;
    final startPt = pointAt(size, band.mid, arc.start);
    final endMin = (arc.start + arc.duration) % _minutesPerDay;
    final endPt = pointAt(size, band.mid, endMin);
    return (
      start: _chipFromHandle(
        size: size,
        handle: startPt,
        minutes: arc.start,
        handleVisualR: handleVisualR,
        inward: inward,
      ),
      end: _chipFromHandle(
        size: size,
        handle: endPt,
        minutes: endMin,
        handleVisualR: handleVisualR,
        inward: inward,
      ),
    );
  }

  static Rect _chipFromHandle({
    required Size size,
    required Offset handle,
    required double minutes,
    required double handleVisualR,
    required bool inward,
  }) {
    final painter = _timeChipPainter(minutes);
    final chipW = painter.width + _chipPadX * 2;
    final chipH = painter.height + _chipPadY * 2;
    final clock = Offset(size.width / 2, size.height / 2);
    var radial = handle - clock;
    radial = radial.distance < 1 ? const Offset(0, 1) : radial / radial.distance;
    final dir = inward ? -radial : radial;
    final center = handle + dir * (handleVisualR + chipW / 2);
    return Rect.fromCenter(center: center, width: chipW, height: chipH);
  }


  static const _chipFontSize = 13.5;
  static const _chipPadX = 8.0;
  static const _chipPadY = 5.5;

  static TextPainter _timeChipPainter(double minutes, {Color? color}) {
    final time = timeFromMinutes(minutes.round());
    final hour =
        time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return TextPainter(
      text: TextSpan(
        text: '$hour:$minute $period',
        style: TextStyle(
          color: color ?? const Color(0xE6000000),
          fontSize: _chipFontSize,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final m = _PolarMetrics.of(size);
    final center = Offset(size.width / 2, size.height / 2);

    _drawHourTrack(canvas, center, m.hourTrackRadius, m.hourTrackWidth);

    if (m.tracksOuter > m.tracksInner) {
      final visible = arcs.where((a) => a.opacity > 0.015 && a.duration > 0.4);
      if (visible.isEmpty) {
        _drawGhostHourTracks(canvas, center, m.tracksInner, m.tracksOuter);
      } else {
        for (final arc in visible) {
          _drawTaskTrack(canvas, center, m.tracksInner, m.tracksOuter, arc);
        }
      }
    }

    if (showNow) {
      _drawNowIndicator(
        canvas,
        center,
        m.nowInnerRadius,
        m.tracksOuter,
        m.shaftWidth,
        m.tipRadius,
      );
    }

    if (movingId != null) {
      _drawMovingBorder(canvas, size);
      _drawMoveHandles(canvas, size);
    }
  }

  void _drawMovingBorder(Canvas canvas, Size size) {
    _ArcGeom? moving;
    for (final arc in arcs) {
      if (arc.id == movingId) {
        moving = arc;
        break;
      }
    }
    if (moving == null) return;
    final m = _PolarMetrics.of(size);
    final center = Offset(size.width / 2, size.height / 2);
    final n = math.max(1.0, moving.laneCount);
    final gap = n > 1
        ? math.min(2.5, (m.tracksOuter - m.tracksInner) * 0.015)
        : 0.0;
    final trackWidth =
        ((m.tracksOuter - m.tracksInner) - gap * (n - 1)) / n;
    final innerEdge = m.tracksInner + moving.lane * (trackWidth + gap);
    final radius = innerEdge + trackWidth / 2;
    final startAngle = _angleForMinutes(moving.start);
    final sweepAngle = (moving.duration / _minutesPerDay) * 2 * math.pi;
    if (sweepAngle < 0.004) return;
    final path = _roundedTrackPath(
      center,
      radius,
      trackWidth,
      startAngle,
      sweepAngle,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
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

    if (!showNow) return;

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
    const segmentMinutes = 8 * 60;
    const gapMinutes = 16;
    final sweep =
        ((segmentMinutes - gapMinutes) / _minutesPerDay) * 2 * math.pi;
    final paint = Paint()
      ..color = trackColor.withOpacity(0.16)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < 3; i++) {
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

    if (!showNow) return;
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

  Path _roundedTrackPath(
    Offset center,
    double radius,
    double width,
    double startAngle,
    double sweepAngle,
  ) {
    return polarRoundedTrackPath(
      center,
      radius,
      width,
      startAngle,
      sweepAngle,
    );
  }

  void _drawNowIndicator(
    Canvas canvas,
    Offset center,
    double innerRadius,
    double trackOuterRadius,
    double shaftWidth,
    double tipRadius,
  ) {
    final minutes = currentTime.hour * 60 + currentTime.minute;
    final angle = _angleForMinutes(minutes);
    final tipCenter = trackOuterRadius;
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

  void _drawMoveHandles(Canvas canvas, Size size) {
    _ArcGeom? moving;
    for (final arc in arcs) {
      if (arc.id == movingId) {
        moving = arc;
        break;
      }
    }
    if (moving == null) return;
    final band = bandFor(moving, size);
    final endMin = (moving.start + moving.duration) % _minutesPerDay;
    final startPt = pointAt(size, band.mid, moving.start);
    final endPt = pointAt(size, band.mid, endMin);
    final r = _moveHandleRadius(band);
    final laid = layoutMoveChips(size, moving);
    final chips = moveChips ?? (start: laid.start, end: laid.end);
    _drawTimeChip(canvas, chips.start, moving.start);
    _drawTimeChip(canvas, chips.end, endMin);
    _drawHandle(canvas, startPt, r);
    _drawHandle(canvas, endPt, r);
  }

  void _drawHandle(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius + 2,
      Paint()..color = handleRing.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = handleFill,
    );
    canvas.drawCircle(
      center,
      radius * 0.38,
      Paint()..color = handleRing.withValues(alpha: 0.85),
    );
  }

  void _drawTimeChip(Canvas canvas, Rect rect, double minutes) {
    final painter = _timeChipPainter(
      minutes,
      color: handleRing.withValues(alpha: 0.92),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()..color = handleFill.withValues(alpha: 0.94),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()
        ..color = handleRing.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    painter.paint(
      canvas,
      Offset(rect.left + _chipPadX, rect.top + _chipPadY),
    );
  }

  @override
  bool shouldRepaint(PolarClockPainter oldDelegate) {
    return oldDelegate.currentTime != currentTime ||
        oldDelegate.arcs != arcs ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.nowColor != nowColor ||
        oldDelegate.nowOnColor != nowOnColor ||
        oldDelegate.showNow != showNow ||
        oldDelegate.movingId != movingId ||
        oldDelegate.handleFill != handleFill ||
        oldDelegate.handleRing != handleRing ||
        oldDelegate.moveChips != moveChips;
  }
}

Offset polarOffset(Offset center, double radius, double angle) {
  return Offset(
    center.dx + radius * math.cos(angle),
    center.dy + radius * math.sin(angle),
  );
}

Path polarSharpTrackPath(
  Offset center,
  double outerR,
  double innerR,
  double startAngle,
  double sweepAngle,
) {
  final endAngle = startAngle + sweepAngle;
  final path = Path()
    ..moveTo(
      polarOffset(center, outerR, startAngle).dx,
      polarOffset(center, outerR, startAngle).dy,
    );
  path.arcTo(
    Rect.fromCircle(center: center, radius: outerR),
    startAngle,
    sweepAngle,
    false,
  );
  path.lineTo(
    polarOffset(center, innerR, endAngle).dx,
    polarOffset(center, innerR, endAngle).dy,
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

/// Annular sector with rounded radial corners (not a full round stroke cap).
Path polarRoundedTrackPath(
  Offset center,
  double radius,
  double width,
  double startAngle,
  double sweepAngle, {
  double cornerFraction = 0.22,
  double minCorner = 0.75,
  double? cornerRadius,
}) {
  final outerR = radius + width / 2;
  final innerR = math.max(1.0, radius - width / 2);
  final maxFit = (outerR - innerR) / 2 * 0.9;
  var corner = cornerRadius ?? math.min(width * cornerFraction, 7.0);
  corner = math.min(corner, maxFit);

  if (cornerRadius == null) {
    final innerLength = innerR * sweepAngle;
    if (innerLength < corner * 2 + 1) {
      corner = math.max(0.0, (innerLength - 1) / 2);
    }
  }

  if (corner < minCorner) {
    return polarSharpTrackPath(
      center,
      outerR,
      innerR,
      startAngle,
      sweepAngle,
    );
  }

  final dOuterRaw = math.asin(
    (corner / (outerR - corner)).clamp(0.0, 0.999),
  );
  final dInnerRaw = math.asin(
    (corner / (innerR + corner)).clamp(0.0, 0.999),
  );
  // Fixed-pixel corners: same angular inset so inner/outer don't look different.
  final dOuter =
      cornerRadius != null ? (dOuterRaw + dInnerRaw) / 2 : dOuterRaw;
  final dInner = dOuter;

  if (sweepAngle <= math.max(dOuter, dInner) * 2) {
    return polarSharpTrackPath(
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

  final outerStart = polarOffset(center, outerR, startAngle + dOuter);
  final innerEnd = polarOffset(center, innerR, endAngle - dInner);
  final endOuterCut = polarOffset(center, outerAlong, endAngle);
  final endInnerCut = polarOffset(center, innerAlong, endAngle);
  final startInnerCut = polarOffset(center, innerAlong, startAngle);
  final startOuterCut = polarOffset(center, outerAlong, startAngle);

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
