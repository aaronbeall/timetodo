import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:timetodo/models/scheduled_task.dart';
import 'package:timetodo/providers/polar_clock_settings.dart';
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
  final String visualKey;
  final double start;
  final double duration;
  final double drawStart;
  final double drawDuration;
  final double condense;
  final Color color;
  final double opacity;
  final double lane;
  final double laneCount;

  const _ArcGeom({
    required this.id,
    String? visualKey,
    required this.start,
    required this.duration,
    double? drawStart,
    double? drawDuration,
    this.condense = 0,
    required this.color,
    required this.opacity,
    required this.lane,
    required this.laneCount,
  })  : visualKey = visualKey ?? id,
        drawStart = drawStart ?? start,
        drawDuration = drawDuration ?? duration;

  bool get opposite => condense > 0.5;

  String get signature =>
      '$visualKey:${start.toStringAsFixed(1)}:${duration.toStringAsFixed(1)}:'
      '${drawStart.toStringAsFixed(1)}:${drawDuration.toStringAsFixed(1)}:'
      '${condense.toStringAsFixed(2)}:${lane.toStringAsFixed(2)}:'
      '${color.value}:${opacity.toStringAsFixed(2)}';

  _ArcGeom copyWith({
    double? start,
    double? duration,
    double? drawStart,
    double? drawDuration,
    double? condense,
    double? opacity,
    double? lane,
    double? laneCount,
  }) {
    return _ArcGeom(
      id: id,
      visualKey: visualKey,
      start: start ?? this.start,
      duration: duration ?? this.duration,
      drawStart: drawStart ?? this.drawStart,
      drawDuration: drawDuration ?? this.drawDuration,
      condense: condense ?? this.condense,
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
  final double hourLabelOpacity;
  /// When true, ignore time labels and 12-hour span (always a 24-hour ring).
  final bool compactLook;
  final double? holeFraction;

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
    this.hourLabelOpacity = 1,
    this.compactLook = false,
    this.holeFraction,
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
  PolarClockLook _look = const PolarClockLook();
  bool _viewingPm = false;

  @override
  void initState() {
    super.initState();
    _to = _snapshot(
      widget.tasks,
      widget.currentTime,
      look: _look,
      viewingPm: _viewingPm,
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
    final settings = context.watch<PolarClockSettings>();
    final nextLook = _effectiveLook(settings.look);
    final nextPm = widget.compactLook
        ? false
        : settings.viewingPm(widget.currentTime);
    final lookChanged = nextLook != _look;
    _look = nextLook;
    _viewingPm = nextPm;
    _syncArcs(
      reduce: lookChanged || MediaQuery.disableAnimationsOf(context),
    );
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
    if (widget.compactLook != oldWidget.compactLook ||
        widget.holeFraction != oldWidget.holeFraction) {
      _look = _effectiveLook(context.read<PolarClockSettings>().look);
      _viewingPm = false;
    }
    _syncArcs(reduce: MediaQuery.disableAnimationsOf(context));
  }

  PolarClockLook _effectiveLook(PolarClockLook look) {
    var next = look;
    if (widget.compactLook) {
      next = next.copyWith(hourLabels: 0, hours12: false, hourTrack: false);
    }
    if (widget.holeFraction != null) {
      next = next.copyWith(holeFraction: widget.holeFraction);
    }
    return next;
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
    var mapped = _look.minutesFromAngle(angle);
    if (!_look.hours12) return mapped;
    final size = Size(widget.size, widget.size);
    final m = _PolarMetrics.of(size, look: _look);
    final inOpposite =
        delta.distance >= m.oppositeInner && delta.distance <= m.oppositeOuter;
    final offset = _viewingPm
        ? (inOpposite ? 0.0 : PolarClockLook.cycle12)
        : (inOpposite ? PolarClockLook.cycle12 : 0.0);
    return mapped + offset;
  }

  _MoveGrab? _grabAt(Offset local, _ArcGeom arc) {
    final size = Size(widget.size, widget.size);
    final band = PolarClockPainter.bandFor(arc, size, look: _look);
    final startPt = PolarClockPainter.pointAt(
      size,
      band.mid,
      arc.drawStart,
      look: _look,
    );
    final endMin = (arc.drawStart + arc.drawDuration) % _look.cycleMinutes;
    final endPt = PolarClockPainter.pointAt(
      size,
      band.mid,
      endMin,
      look: _look,
    );
    final handleR = 16.0;
    final ds = (local - startPt).distance;
    final de = (local - endPt).distance;
    if (ds <= handleR && ds <= de) return _MoveGrab.start;
    if (de <= handleR) return _MoveGrab.end;
    if (PolarClockPainter.idAt(local, size, [arc], look: _look) == arc.id) {
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
      look: _look,
      viewingPm: _viewingPm,
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
          final laid = PolarClockPainter.layoutMoveChips(
            clockSize,
            moving,
            look: _look,
            use24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
          );
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
                  look: _look,
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
                      look: _look,
                      use24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
                      viewingPm: _viewingPm,
                      hourLabelOpacity: widget.hourLabelOpacity,
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
        visualKey: target.visualKey,
        start: target.start,
        duration: 0,
        drawStart: target.drawStart,
        drawDuration: 0,
        condense: target.condense,
        color: target.color,
        opacity: 0,
        lane: target.lane,
        laneCount: target.laneCount,
      );

  _ArcGeom _vanish(_ArcGeom source) => _ArcGeom(
        id: source.id,
        visualKey: source.visualKey,
        start: source.start,
        duration: source.duration,
        drawStart: source.drawStart,
        drawDuration: source.drawDuration,
        condense: source.condense,
        color: source.color,
        opacity: 0,
        lane: source.lane,
        laneCount: source.laneCount,
      );

  _ArcGeom _lerpArc(_ArcGeom a, _ArcGeom b, double t) {
    return _ArcGeom(
      id: b.id,
      visualKey: b.visualKey,
      start: _lerpMinutes(a.start, b.start, t),
      duration: lerpDouble(a.duration, b.duration, t)!,
      drawStart: _lerpMinutes(a.drawStart, b.drawStart, t),
      drawDuration: lerpDouble(a.drawDuration, b.drawDuration, t)!,
      condense: lerpDouble(a.condense, b.condense, t)!,
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

/// Center hub: live clock digits, plus AM/PM toggle when the polar span is 12 hours.
class PolarClockHub extends StatelessWidget {
  final TimeOfDay time;
  final TextStyle timeStyle;
  final TextStyle periodStyle;
  final bool showTime;

  const PolarClockHub({
    super.key,
    required this.time,
    required this.timeStyle,
    required this.periodStyle,
    this.showTime = true,
  });

  @override
  Widget build(BuildContext context) {
    final polar = context.watch<PolarClockSettings>();
    final use24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final hours12 = polar.look.hours12;
    if (!showTime && !hours12) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showTime)
          IgnorePointer(
            child: Text(
              formatTimeDigits(time, use24Hour: use24),
              style: timeStyle,
            ),
          ),
        if (hours12) ...[
          if (showTime) const SizedBox(height: 4),
          PolarMeridianToggle(
            isPm: polar.viewingPm(time),
            style: periodStyle,
            onChanged: (pm) => polar.setViewingPm(pm, time),
          ),
        ] else if (showTime) ...[
          if (formatTimePeriod(time, use24Hour: use24) case final period?) ...[
            const SizedBox(height: 4),
            IgnorePointer(
              child: Text(period, style: periodStyle),
            ),
          ],
        ],
      ],
    );
  }
}

class PolarMeridianToggle extends StatelessWidget {
  final bool isPm;
  final TextStyle style;
  final ValueChanged<bool> onChanged;

  const PolarMeridianToggle({
    super.key,
    required this.isPm,
    required this.style,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = style.fontSize ?? 12;
    final radius = BorderRadius.circular(size);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.35),
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MeridianCell(
              label: 'AM',
              selected: !isPm,
              style: style,
              onTap: () => onChanged(false),
            ),
            ColoredBox(
              color: scheme.outline.withValues(alpha: 0.28),
              child: SizedBox(width: 1, height: size * 1.35),
            ),
            _MeridianCell(
              label: 'PM',
              selected: isPm,
              style: style,
              onTap: () => onChanged(true),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeridianCell extends StatelessWidget {
  final String label;
  final bool selected;
  final TextStyle style;
  final VoidCallback onTap;

  const _MeridianCell({
    required this.label,
    required this.selected,
    required this.style,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = style.fontSize ?? 12;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ColoredBox(
        color: selected
            ? scheme.onSurface.withValues(alpha: 0.14)
            : Colors.transparent,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: size * 0.55,
            vertical: size * 0.22,
          ),
          child: Text(
            label,
            style: style.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: (style.color ?? scheme.onSurface).withValues(
                alpha: selected ? 0.92 : 0.42,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Map<String, _ArcGeom> _snapshot(
  List<ScheduledTask> tasks,
  TimeOfDay now, {
  PolarClockLook look = const PolarClockLook(),
  bool viewingPm = false,
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

  final map = <String, _ArcGeom>{};
  if (!look.hours12) {
    final lanes = assignPolarTracksFromRanges(ranges);
    final laneCount = lanes.length.toDouble();
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

  const half = PolarClockLook.cycle12;
  final nowPm = look.hours12 && viewingPm;
  final current = <_TaskRange>[];
  final opposite = <_TaskRange>[];
  for (final range in ranges) {
    for (final seg in _segments(range)) {
      void addClip(int a, int b) {
        if (b - a < 1) return;
        final clip = _TaskRange(task: range.task, start: a, end: b);
        final pm = a >= half;
        if (pm == nowPm) {
          current.add(clip);
        } else {
          opposite.add(clip);
        }
      }

      if (seg.$1 < half && seg.$2 > half) {
        addClip(seg.$1, half);
        addClip(half, seg.$2);
      } else {
        addClip(seg.$1, seg.$2);
      }
    }
  }

  final lanes = assignPolarTracksFromRanges(current);
  final laneCount = math.max(1.0, lanes.length.toDouble());
  for (final entry in lanes.entries) {
    for (final range in entry.value) {
      final task = range.task;
      final duration = (range.end - range.start).toDouble();
      if (duration < 0.4) continue;
      final full = ranges.firstWhere((r) => r.task.id == task.id);
      map['${task.id}:${range.start}'] = _ArcGeom(
        id: task.id,
        visualKey: '${task.id}:${range.start}',
        start: full.start.toDouble(),
        duration: _durationMinutes(full).toDouble(),
        drawStart: range.start.toDouble(),
        drawDuration: duration,
        color: task.color,
        opacity: fullColor || task.isUpcoming(now) ? 0.95 : 0.38,
        lane: entry.key.toDouble(),
        laneCount: laneCount,
      );
    }
  }
  for (final range in opposite) {
    final task = range.task;
    final duration = (range.end - range.start).toDouble();
    if (duration < 0.4) continue;
    final full = ranges.firstWhere((r) => r.task.id == task.id);
    map['${task.id}:${range.start}'] = _ArcGeom(
      id: task.id,
      visualKey: '${task.id}:${range.start}',
      start: full.start.toDouble(),
      duration: _durationMinutes(full).toDouble(),
      drawStart: range.start.toDouble(),
      drawDuration: duration,
      condense: 1,
      color: task.color,
      opacity: (fullColor || task.isUpcoming(now) ? 0.95 : 0.38) * 0.85,
      lane: 0,
      laneCount: 1,
    );
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
  final PolarClockLook look;

  const _ArcHitTarget({
    required this.arcs,
    required this.moving,
    required this.onTapId,
    required this.onLongPressId,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.look,
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
      look: look,
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
      ..onPointerUp = onPointerUp
      ..look = look;
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
    required PolarClockLook look,
  })  : _arcs = arcs,
        _moving = moving,
        _look = look;

  List<_ArcGeom> _arcs;
  bool _moving;
  PolarClockLook _look;
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

  set look(PolarClockLook value) {
    _look = value;
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
    return PolarClockPainter.idAt(position, size, _arcs, look: _look);
  }
}

class _PolarMetrics {
  final double holeRadius;
  final double hourTrackWidth;
  final double hourTrackRadius;
  final double tracksInner;
  final double currentInner;
  final double oppositeInner;
  final double oppositeOuter;
  final double tracksOuter;
  final double nowInnerRadius;
  final double shaftWidth;
  final double tipRadius;
  final bool hours12;
  final double labelRadius;

  const _PolarMetrics({
    required this.holeRadius,
    required this.hourTrackWidth,
    required this.hourTrackRadius,
    required this.tracksInner,
    required this.currentInner,
    required this.oppositeInner,
    required this.oppositeOuter,
    required this.tracksOuter,
    required this.nowInnerRadius,
    required this.shaftWidth,
    required this.tipRadius,
    required this.hours12,
    required this.labelRadius,
  });

  factory _PolarMetrics.of(Size size, {required PolarClockLook look}) {
    final hours12 = look.hours12;
    final maxRadius = math.min(size.width, size.height) / 2;
    final labelCount = look.hourLabels;
    final maxBand = math.max(0.0, maxRadius * 0.14);
    final wanted = labelCount >= 12 ? 17.0 : 14.0;
    final labelBand = labelCount <= 0 ? 0.0 : wanted.clamp(0.0, maxBand);
    final usable = maxRadius - labelBand;
    final holeFrac = look.holeFraction ?? (look.hourTrack ? 0.22 : 0.28);
    final holeRadius = usable * holeFrac;
    final hourTrackWidth =
        look.hourTrack ? math.max(6.0, usable * 0.035) : 0.0;
    final hourTrackRadius = holeRadius + hourTrackWidth / 2;
    final tracksInner = look.hourTrack
        ? hourTrackRadius + hourTrackWidth / 2 + 3
        : holeRadius;
    final nowInnerRadius = look.hourTrack
        ? hourTrackRadius - hourTrackWidth / 2
        : holeRadius;
    final shaftWidth = math.max(3.0, (usable - nowInnerRadius) * 0.018);
    final tipRadius = shaftWidth * 1.15;
    final capPad = tipRadius + 1.6;
    final tracksOuter = usable - capPad;
    final oppositeBand = hours12 ? hourTrackWidth : 0.0;
    final gap = hours12 ? 3.0 : 0.0;
    final oppositeInner = tracksInner;
    final oppositeOuter = tracksInner + oppositeBand;
    final currentInner = hours12 ? oppositeOuter + gap : tracksInner;
    final labelRadius = labelCount <= 0
        ? tracksOuter
        : tracksOuter + capPad + labelBand * 0.42;
    return _PolarMetrics(
      holeRadius: holeRadius,
      hourTrackWidth: hourTrackWidth,
      hourTrackRadius: hourTrackRadius,
      tracksInner: tracksInner,
      currentInner: currentInner,
      oppositeInner: oppositeInner,
      oppositeOuter: oppositeOuter,
      tracksOuter: tracksOuter,
      nowInnerRadius: nowInnerRadius,
      shaftWidth: shaftWidth,
      tipRadius: tipRadius,
      hours12: hours12,
      labelRadius: labelRadius,
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
  final PolarClockLook look;
  final bool use24Hour;
  final bool viewingPm;
  final double hourLabelOpacity;

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
    this.look = const PolarClockLook(),
    this.use24Hour = false,
    this.viewingPm = false,
    this.hourLabelOpacity = 1,
  });

  static double angleForMinutes(
    num minutes, {
    PolarClockLook look = const PolarClockLook(),
  }) {
    return look.angleForMinutes(minutes);
  }

  double _angleForMinutes(num minutes) => look.angleForMinutes(minutes);

  static String? idAt(
    Offset position,
    Size size,
    List<_ArcGeom> arcs, {
    PolarClockLook look = const PolarClockLook(),
  }) {
    final m = _PolarMetrics.of(size, look: look);
    final center = Offset(size.width / 2, size.height / 2);
    if (m.tracksOuter <= m.tracksInner) return null;

    final delta = position - center;
    final dist = delta.distance;
    var angle = math.atan2(delta.dy, delta.dx);
    var minutes = look.minutesFromAngle(angle);
    final cycle = look.cycleMinutes.toDouble();

    final visible = arcs
        .where((a) => a.opacity > 0.015 && a.drawDuration > 0.4)
        .toList()
      ..sort((a, b) => b.lane.compareTo(a.lane));

    for (final arc in visible) {
      final band = bandFor(arc, size, look: look);
      if (dist < band.inner || dist > band.outer) continue;
      var t = minutes;
      final start = look.mapMinutes(arc.drawStart);
      if (t < start) t += cycle;
      if (t >= start && t < start + arc.drawDuration) {
        return arc.id;
      }
    }
    return null;
  }

  static ({double inner, double outer, double mid}) bandFor(
    _ArcGeom arc,
    Size size, {
    PolarClockLook look = const PolarClockLook(),
  }) {
    final m = _PolarMetrics.of(size, look: look);
    final n = math.max(1.0, arc.laneCount);
    final span = m.tracksOuter - m.currentInner;
    final gap = n > 1 ? math.min(2.5, span * 0.015) : 0.0;
    final trackWidth = (span - gap * (n - 1)) / n;
    final expandedInner = m.currentInner + arc.lane * (trackWidth + gap);
    final expandedOuter = expandedInner + trackWidth;
    if (!look.hours12 || arc.condense <= 0) {
      return (
        inner: expandedInner,
        outer: expandedOuter,
        mid: expandedInner + trackWidth / 2,
      );
    }
    final inner = lerpDouble(expandedInner, m.oppositeInner, arc.condense)!;
    final outer = lerpDouble(expandedOuter, m.oppositeOuter, arc.condense)!;
    return (inner: inner, outer: outer, mid: (inner + outer) / 2);
  }

  static Offset pointAt(
    Size size,
    double radius,
    double minutes, {
    PolarClockLook look = const PolarClockLook(),
  }) {
    final center = Offset(size.width / 2, size.height / 2);
    final angle = look.angleForMinutes(minutes);
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
  static ({Rect start, Rect end}) layoutMoveChips(
    Size size,
    _ArcGeom arc, {
    PolarClockLook look = const PolarClockLook(),
    bool use24Hour = false,
  }) {
    final band = bandFor(arc, size, look: look);
    final metrics = _PolarMetrics.of(size, look: look);
    final handleVisualR = _moveHandleRadius(band) + 2;
    final midR = (metrics.currentInner + metrics.tracksOuter) / 2;
    final inward = band.mid > midR;
    final startPt = pointAt(size, band.mid, arc.drawStart, look: look);
    final endMin =
        (arc.drawStart + arc.drawDuration) % look.cycleMinutes;
    final endPt = pointAt(size, band.mid, endMin, look: look);
    return (
      start: _chipFromHandle(
        size: size,
        handle: startPt,
        minutes: arc.start,
        handleVisualR: handleVisualR,
        inward: inward,
        use24Hour: use24Hour,
      ),
      end: _chipFromHandle(
        size: size,
        handle: endPt,
        minutes: (arc.start + arc.duration) % _minutesPerDay,
        handleVisualR: handleVisualR,
        inward: inward,
        use24Hour: use24Hour,
      ),
    );
  }

  static Rect _chipFromHandle({
    required Size size,
    required Offset handle,
    required double minutes,
    required double handleVisualR,
    required bool inward,
    bool use24Hour = false,
  }) {
    final painter = _timeChipPainter(minutes, use24Hour: use24Hour);
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

  static TextPainter _timeChipPainter(
    double minutes, {
    Color? color,
    bool use24Hour = false,
  }) {
    final time = timeFromMinutes(minutes.round());
    final digits = formatTimeDigits(time, use24Hour: use24Hour);
    final period = formatTimePeriod(time, use24Hour: use24Hour);
    final text = period == null ? digits : '$digits $period';
    return TextPainter(
      text: TextSpan(
        text: text,
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
    final m = _PolarMetrics.of(size, look: look);
    final center = Offset(size.width / 2, size.height / 2);

    if (look.hourTrack) {
      _drawHourTrack(canvas, center, m.hourTrackRadius, m.hourTrackWidth);
    }

    if (m.tracksOuter > m.currentInner) {
      if (look.hours12) {
        _drawOppositeParent(canvas, center, m);
      }
      final visible =
          arcs.where((a) => a.opacity > 0.015 && a.drawDuration > 0.4);
      if (look.trackBackground) {
        _drawTrackBackground(canvas, center, m, visible.toList());
      }
      if (visible.isEmpty && !look.trackBackground) {
        _drawGhostHourTracks(canvas, center, m.currentInner, m.tracksOuter);
      } else {
        for (final arc in visible) {
          _drawTaskTrack(canvas, size, center, arc);
        }
      }
    }

    _drawHourLabels(canvas, size, m);

    if (look.originLine) {
      _drawOriginLine(canvas, center, m);
    }

    if (showNow) {
      final livePm = look.nowIsPm(currentTime);
      final tipAt = look.hours12 && viewingPm != livePm
          ? m.oppositeOuter
          : m.tracksOuter;
      _drawNowIndicator(
        canvas,
        center,
        m.nowInnerRadius,
        tipAt,
        m.shaftWidth,
        m.tipRadius,
      );
    }

    if (movingId != null) {
      _drawMovingBorder(canvas, size);
      _drawMoveHandles(canvas, size);
    }
  }

  void _drawOppositeParent(Canvas canvas, Offset center, _PolarMetrics m) {
    final width = math.max(1.0, m.oppositeOuter - m.oppositeInner);
    canvas.drawCircle(
      center,
      m.oppositeInner + width / 2,
      Paint()
        ..color = trackColor.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  void _drawTrackBackground(
    Canvas canvas,
    Offset center,
    _PolarMetrics m,
    List<_ArcGeom> visible,
  ) {
    var laneCount = 1.0;
    for (final arc in visible) {
      if (!arc.opposite) laneCount = math.max(laneCount, arc.laneCount);
    }
    final n = laneCount;
    final span = m.tracksOuter - m.currentInner;
    final gap = n > 1 ? math.min(2.5, span * 0.015) : 0.0;
    final trackWidth = (span - gap * (n - 1)) / n;
    final paint = Paint()
      ..color = trackColor.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.0, trackWidth * 0.92);
    for (var i = 0; i < n; i++) {
      final inner = m.currentInner + i * (trackWidth + gap);
      canvas.drawCircle(center, inner + trackWidth / 2, paint);
    }
  }

  void _drawOriginLine(Canvas canvas, Offset center, _PolarMetrics m) {
    final angle = look.angleForMinutes(0);
    final inner = math.max(m.nowInnerRadius, m.hourTrackRadius - m.hourTrackWidth / 2);
    final outer = m.tracksOuter;
    final paint = Paint()
      ..color = nowColor.withValues(alpha: 0.38)
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      polarOffset(center, inner, angle),
      polarOffset(center, outer, angle),
      paint,
    );
  }

  void _drawHourLabels(Canvas canvas, Size size, _PolarMetrics m) {
    final count = look.hourLabels;
    if (count <= 0 || hourLabelOpacity <= 0.01) return;
    final cycle = look.cycleMinutes;
    final radius = m.labelRadius;
    final fontSize = (size.shortestSide * 0.036).clamp(9.0, 13.0);
    for (var i = 0; i < count; i++) {
      final minutes = i * (cycle / count);
      final labelMinutes =
          look.hours12 && viewingPm ? minutes + PolarClockLook.cycle12 : minutes;
      final angle = look.angleForMinutes(minutes);
      final label = formatPolarHourLabel(
        labelMinutes.round(),
        polarHours12: look.hours12,
        use24Hour: use24Hour,
      );
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: nowColor.withValues(alpha: 0.55 * hourLabelOpacity),
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final pos = polarOffset(Offset(size.width / 2, size.height / 2), radius, angle);
      painter.paint(
        canvas,
        Offset(pos.dx - painter.width / 2, pos.dy - painter.height / 2),
      );
    }
  }

  void _drawMovingBorder(Canvas canvas, Size size) {
    for (final moving in arcs.where((a) => a.id == movingId)) {
      final band = bandFor(moving, size, look: look);
      final center = Offset(size.width / 2, size.height / 2);
      final radius = band.mid;
      final trackWidth = band.outer - band.inner;
      final startAngle = _angleForMinutes(moving.drawStart);
      final sweepAngle =
          (moving.drawDuration / look.cycleMinutes) * 2 * math.pi;
      if (sweepAngle < 0.004) continue;
      canvas.drawPath(
        _roundedTrackPath(center, radius, trackWidth, startAngle, sweepAngle),
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true,
      );
    }
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

    double fillFraction;
    if (!look.hours12) {
      final currentMinutes =
          currentTime.hour * 60 + currentTime.minute.toDouble();
      if (currentMinutes <= 0) return;
      fillFraction = currentMinutes / PolarClockLook.cycle24;
    } else {
      final livePm = look.nowIsPm(currentTime);
      if (viewingPm != livePm) {
        fillFraction = livePm && !viewingPm ? 1 : 0;
      } else {
        final currentMinutes = look.mapMinutes(
          currentTime.hour * 60 + currentTime.minute,
        );
        if (currentMinutes <= 0) return;
        fillFraction = currentMinutes / look.cycleMinutes;
      }
    }
    if (fillFraction <= 0) return;

    final filledPaint = Paint()
      ..color = trackColor.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _angleForMinutes(0),
      2 * math.pi * fillFraction,
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
    Size size,
    Offset center,
    _ArcGeom arc,
  ) {
    final band = bandFor(arc, size, look: look);
    final radius = band.mid;
    final trackWidth = band.outer - band.inner;
    final startAngle = _angleForMinutes(arc.drawStart);
    final sweepAngle =
        (arc.drawDuration / look.cycleMinutes) * 2 * math.pi;
    if (sweepAngle < 0.004) return;

    canvas.drawPath(
      _roundedTrackPath(center, radius, trackWidth, startAngle, sweepAngle),
      Paint()
        ..color = arc.color.withOpacity(arc.opacity)
        ..style = PaintingStyle.fill,
    );

    if (!showNow || arc.condense > 0.08) return;
    if (look.hours12 && viewingPm != look.nowIsPm(currentTime)) return;
    final now = look.mapMinutes(
      (currentTime.hour * 60 + currentTime.minute).toDouble(),
    );
    var nowU = now;
    final start = look.mapMinutes(arc.drawStart);
    final end = start + arc.drawDuration;
    if (nowU < start) nowU += look.cycleMinutes;
    if (nowU < start || nowU >= end) return;
    if (arc.opacity < 0.2) return;

    final remaining = end - nowU;
    final remainingSweep = (remaining / look.cycleMinutes) * 2 * math.pi;
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
    final pieces = arcs.where((a) => a.id == movingId);
    if (pieces.isEmpty) return;
    _ArcGeom? chipArc;
    for (final moving in pieces) {
      chipArc ??= moving;
      final band = bandFor(moving, size, look: look);
      final r = _moveHandleRadius(band);
      final startPt =
          pointAt(size, band.mid, moving.drawStart, look: look);
      final endMin =
          (moving.drawStart + moving.drawDuration) % look.cycleMinutes;
      final endPt = pointAt(size, band.mid, endMin, look: look);
      final taskEnd = (moving.start + moving.duration) % _minutesPerDay;
      final clipEnd = (moving.drawStart + moving.drawDuration) % _minutesPerDay;
      if ((moving.drawStart - moving.start).abs() < 1) {
        _drawHandle(canvas, startPt, r);
      }
      if ((clipEnd - taskEnd).abs() < 1) {
        _drawHandle(canvas, endPt, r);
      }
    }
    final moving = chipArc!;
    final laid = layoutMoveChips(size, moving, look: look, use24Hour: use24Hour);
    final chips = moveChips ?? (start: laid.start, end: laid.end);
    final endMin = (moving.start + moving.duration) % _minutesPerDay;
    _drawTimeChip(canvas, chips.start, moving.start);
    _drawTimeChip(canvas, chips.end, endMin);
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
      use24Hour: use24Hour,
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
        oldDelegate.moveChips != moveChips ||
        oldDelegate.look != look ||
        oldDelegate.use24Hour != use24Hour ||
        oldDelegate.viewingPm != viewingPm ||
        oldDelegate.hourLabelOpacity != hourLabelOpacity;
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
