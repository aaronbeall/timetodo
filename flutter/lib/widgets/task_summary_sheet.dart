import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timetodo/models/reports_snapshot.dart';
import 'package:timetodo/models/scheduled_task.dart';
import 'package:timetodo/models/task.dart';
import 'package:timetodo/models/task_occurrence.dart';
import 'package:timetodo/providers/task_provider.dart';
import 'package:timetodo/time_utils.dart';
import 'package:timetodo/widgets/change_toast.dart';
import 'package:timetodo/widgets/polar_clock.dart';
import 'package:timetodo/widgets/task_repeat_field.dart';
import 'package:timetodo/widgets/task_time_arc.dart';
import 'package:timetodo/widgets/task_timeframe_field.dart';

Future<void> showTaskSummarySheet(
  BuildContext context, {
  required ScheduledTask task,
  required TimeOfDay now,
  required VoidCallback onEdit,
  VoidCallback? onMove,
  bool inlinePolarMove = false,
}) async {
  final draft = _OccurrenceDraft.from(task, now);
  var openParent = false;
  var startMove = false;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return _TaskSummarySheet(
        task: task,
        now: now,
        draft: draft,
        onEditParent: () {
          openParent = true;
          Navigator.of(sheetContext).pop();
        },
        onMove: onMove == null
            ? null
            : () {
                startMove = true;
                Navigator.of(sheetContext).pop();
              },
        inlinePolarMove: inlinePolarMove,
      );
    },
  );
  if (!context.mounted) return;
  if (startMove) {
    onMove?.call();
    return;
  }
  final undo = _commitDraft(context, task, draft);
  if (openParent) onEdit();
  if (undo != null) {
    showChangeToast(
      context,
      message: _commitMessage(task.label, draft),
      onUndo: undo,
    );
  }
}

class _OccurrenceDraft {
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  _StatusChoice status;
  bool applyFollowing = false;

  final TimeOfDay? initialStart;
  final TimeOfDay? initialEnd;
  final TimeOfDay? seriesStart;
  final TimeOfDay? seriesEnd;
  final _StatusChoice initialStatus;

  _OccurrenceDraft({
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.initialStart,
    required this.initialEnd,
    required this.seriesStart,
    required this.seriesEnd,
    required this.initialStatus,
  });

  factory _OccurrenceDraft.from(ScheduledTask task, TimeOfDay now) {
    final status = _statusOf(task, now);
    final era = task.era;
    return _OccurrenceDraft(
      startTime: task.startTime,
      endTime: task.endTime,
      status: status,
      initialStart: task.startTime,
      initialEnd: task.endTime,
      seriesStart: era.startTime,
      seriesEnd: era.endTime,
      initialStatus: status,
    );
  }

  bool get timesChanged =>
      startTime != initialStart || endTime != initialEnd;

  bool get differsFromSeries =>
      startTime != seriesStart || endTime != seriesEnd;

  bool get statusChanged => status != initialStatus;

  bool get writesStatus {
    if (!statusChanged) return false;
    return status == _StatusChoice.complete ||
        status == _StatusChoice.skipped ||
        status == _StatusChoice.upcoming;
  }

  bool get isDirty => timesChanged || writesStatus || applyFollowing;
}

VoidCallback? _commitDraft(
  BuildContext context,
  ScheduledTask task,
  _OccurrenceDraft draft,
) {
  if (!draft.isDirty) return null;
  final provider = context.read<TaskProvider>();
  final today = dateOnly(DateTime.now());
  final day = dateOnly(task.date);
  final canEditTimes = !day.isBefore(today);
  return provider.commitOccurrenceEdits(
    taskId: task.id,
    day: day,
    writeTimes: canEditTimes && !task.isAllDay && draft.timesChanged,
    isAllDay: task.isAllDay,
    startTime: draft.startTime,
    endTime: draft.endTime,
    writeStatus: draft.writesStatus,
    isCompleted: draft.status == _StatusChoice.complete,
    isCanceled: draft.status == _StatusChoice.skipped,
    applyFollowing: canEditTimes && draft.applyFollowing,
  );
}

String _commitMessage(String label, _OccurrenceDraft draft) {
  if (draft.applyFollowing && !draft.writesStatus) {
    return 'Applied time to future $label';
  }
  if (draft.writesStatus && !draft.timesChanged && !draft.applyFollowing) {
    return switch (draft.status) {
      _StatusChoice.complete => 'Completed $label',
      _StatusChoice.skipped => 'Skipped $label',
      _StatusChoice.upcoming => '$label set to upcoming',
      _ => 'Updated $label',
    };
  }
  if (draft.timesChanged && !draft.writesStatus && !draft.applyFollowing) {
    return 'Updated $label time';
  }
  return 'Updated $label';
}

enum _StatusChoice {
  upcoming,
  inProgress,
  openAllDay,
  expired,
  skipped,
  complete,
}

class _TaskSummarySheet extends StatefulWidget {
  final ScheduledTask task;
  final TimeOfDay now;
  final _OccurrenceDraft draft;
  final VoidCallback onEditParent;
  final VoidCallback? onMove;
  final bool inlinePolarMove;

  const _TaskSummarySheet({
    required this.task,
    required this.now,
    required this.draft,
    required this.onEditParent,
    this.onMove,
    this.inlinePolarMove = false,
  });

  @override
  State<_TaskSummarySheet> createState() => _TaskSummarySheetState();
}

class _TaskSummarySheetState extends State<_TaskSummarySheet> {
  bool _showInlinePolar = false;

  ScheduledTask get task => widget.task;
  _OccurrenceDraft get draft => widget.draft;

  ScheduledTask get _preview {
    final day = dateOnly(task.date);
    return ScheduledTask(
      task: task.task,
      date: day,
      occurrence: TaskOccurrence(
        id: TaskOccurrence.idFor(task.id, day),
        taskId: task.id,
        date: day,
        startTime: draft.startTime,
        endTime: draft.endTime,
        isAllDay: task.isAllDay,
        isCompleted: draft.status == _StatusChoice.complete,
        isCanceled: draft.status == _StatusChoice.skipped,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final theme = Theme.of(context);
    final ink = taskInkColor(preview.color, theme.brightness);
    final muted = theme.colorScheme.onSurfaceVariant;
    final today = dateOnly(DateTime.now());
    final day = dateOnly(task.date);
    final canEditTimes = !day.isBefore(today);
    final futureStatus = _usesFutureStatus(task, widget.now, today);
    final status = draft.status;
    final items = _statusItems(futureStatus: futureStatus);
    final stats = context.watch<TaskProvider>().seriesStats(task.task);

    final struck = status == _StatusChoice.skipped ||
        status == _StatusChoice.expired ||
        status == _StatusChoice.complete;
    final titleOpacity = struck ? 0.55 : 1.0;
    final titleStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: ink.withValues(alpha: titleOpacity),
      decoration: struck ? TextDecoration.lineThrough : null,
      decorationColor: ink.withValues(alpha: 0.5),
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TaskTimeArc(task: preview),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (status == _StatusChoice.complete) ...[
                              Icon(
                                Icons.check_rounded,
                                size: 22,
                                color: ink.withValues(alpha: titleOpacity),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                preview.label,
                                style: titleStyle,
                              ),
                            ),
                            if (status == _StatusChoice.expired)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: ink.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'expired',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: ink.withValues(alpha: 0.5),
                                    height: 1,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              _occurrenceDateLabel(day),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: muted,
                              ),
                            ),
                            if (preview.repeatType != RepeatType.none)
                              TaskRepeatBadge(label: _repeatLine(preview)),
                          ],
                        ),
                        if (stats.total > 1) ...[
                          const SizedBox(height: 4),
                          Text(
                            _seriesStatsLine(stats),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: muted.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!preview.isAllDay &&
                  draft.startTime != null &&
                  draft.endTime != null) ...[
                _OccurrenceSpanBar(
                  color: preview.color,
                  start: draft.startTime!,
                  end: draft.endTime!,
                  now: widget.now,
                  isToday: isSameDay(day, today),
                  pastDay: day.isBefore(today),
                  enabled: canEditTimes,
                  onChanged: (start, end) {
                    setState(() {
                      draft.startTime = start;
                      draft.endTime = end;
                      if (!draft.differsFromSeries) {
                        draft.applyFollowing = false;
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
              ],
              if (preview.isAllDay)
                _SummaryLine(
                  icon: Icons.wb_sunny_outlined,
                  text: 'All day',
                  color: muted,
                )
              else if (canEditTimes)
                TaskTimeframeField(
                  isAllDay: false,
                  startTime: draft.startTime,
                  endTime: draft.endTime,
                  showAllDayToggle: false,
                  showTrailingTimeIcon: false,
                  leadingIcons: true,
                  onResetTimes: draft.differsFromSeries
                      ? () {
                          setState(() {
                            draft.startTime = draft.seriesStart;
                            draft.endTime = draft.seriesEnd;
                            draft.applyFollowing = false;
                          });
                        }
                      : null,
                  onMove: _moveAction,
                  onTimeframeChanged: (range) {
                    setState(() {
                      draft.startTime = range.$1;
                      draft.endTime = range.$2;
                      if (!draft.differsFromSeries) {
                        draft.applyFollowing = false;
                      }
                    });
                  },
                )
              else ...[
                _SummaryLine(
                  icon: Icons.schedule_rounded,
                  text: _timeLine(context, preview),
                  color: muted,
                ),
                if (preview.startTime != null &&
                    preview.endTime != null) ...[
                  const SizedBox(height: 10),
                  _SummaryLine(
                    icon: Icons.timelapse_rounded,
                    text: formatDurationMinutes(
                      durationMinutes(preview.startTime!, preview.endTime!),
                    ),
                    color: muted,
                  ),
                ],
              ],
              if (_showInlinePolar &&
                  canEditTimes &&
                  !preview.isAllDay &&
                  draft.startTime != null &&
                  draft.endTime != null) ...[
                const SizedBox(height: 12),
                _inlinePolar(context, preview, day),
              ],
              const SizedBox(height: 4),
              _StatusRow(
                status: status,
                actions: [
                  for (final item in items)
                    if (item.value != status) item,
                ],
                color: muted,
                onSelect: (next) => setState(() => draft.status = next),
              ),
              const SizedBox(height: 18),
              if (canEditTimes)
                FilledButton.tonalIcon(
                  onPressed: draft.differsFromSeries
                      ? () {
                          setState(
                            () => draft.applyFollowing = !draft.applyFollowing,
                          );
                        }
                      : null,
                  icon: const Icon(Icons.event_repeat_outlined),
                  label: Text(
                    draft.applyFollowing
                        ? 'Will apply to future'
                        : 'Apply to future',
                  ),
                  style: draft.applyFollowing
                      ? FilledButton.styleFrom(
                          backgroundColor:
                              theme.colorScheme.primaryContainer,
                          foregroundColor:
                              theme.colorScheme.onPrimaryContainer,
                        )
                      : null,
                ),
              if (canEditTimes) const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: widget.onEditParent,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit task'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  VoidCallback? get _moveAction {
    if (draft.startTime == null || draft.endTime == null) return null;
    if (widget.inlinePolarMove) {
      return () => setState(() => _showInlinePolar = !_showInlinePolar);
    }
    return widget.onMove;
  }

  Widget _inlinePolar(
    BuildContext context,
    ScheduledTask preview,
    DateTime day,
  ) {
    final provider = context.watch<TaskProvider>();
    final others = provider.scheduledOn(day).where((t) => t.id != task.id);
    final now = TimeOfDay.now();
    final today = isSameDay(day, DateTime.now());
    const size = 240.0;
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: PolarClock(
          currentTime: now,
          tasks: [...others, preview],
          size: size,
          animate: false,
          showNow: today,
          fullColor: true,
          enableMove: true,
          liveEdit: true,
          movingTaskId: task.id,
          onMoveCommit: (_, start, end) {
            setState(() {
              draft.startTime = start;
              draft.endTime = end;
              if (!draft.differsFromSeries) {
                draft.applyFollowing = false;
              }
            });
          },
        ),
      ),
    );
  }
}

class _StatusItem {
  final _StatusChoice value;
  final String label;

  const _StatusItem(this.value, this.label);
}

List<_StatusItem> _statusItems({required bool futureStatus}) {
  if (futureStatus) {
    return const [
      _StatusItem(_StatusChoice.upcoming, 'Schedule'),
      _StatusItem(_StatusChoice.skipped, 'Skip'),
    ];
  }
  return const [
    _StatusItem(_StatusChoice.skipped, 'Skip'),
    _StatusItem(_StatusChoice.complete, 'Complete'),
  ];
}

String _statusLabel(_StatusChoice status) {
  return switch (status) {
    _StatusChoice.complete => 'Completed',
    _StatusChoice.skipped => 'Skipped',
    _StatusChoice.expired => 'Expired',
    _StatusChoice.inProgress => 'In progress',
    _StatusChoice.openAllDay => 'Open all day',
    _StatusChoice.upcoming => 'Upcoming',
  };
}

class _StatusRow extends StatelessWidget {
  final _StatusChoice status;
  final List<_StatusItem> actions;
  final Color color;
  final ValueChanged<_StatusChoice> onSelect;

  const _StatusRow({
    required this.status,
    required this.actions,
    required this.color,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(_statusIcon(status), size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _statusLabel(status),
            style: theme.textTheme.bodyLarge?.copyWith(color: color),
          ),
        ),
        for (final action in actions) ...[
          if (action != actions.first) const SizedBox(width: 6),
          FilledButton.tonalIcon(
            onPressed: () => onSelect(action.value),
            icon: Icon(_statusIcon(action.value), size: 18),
            label: Text(action.label),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
              minimumSize: const Size(0, 32),
            ),
          ),
        ],
      ],
    );
  }
}

String _seriesStatsLine(TaskSeriesStats stats) {
  final n = stats.total;
  final noun = n == 1 ? 'occurrence' : 'occurrences';
  final parts = <String>['$n $noun'];
  final done = stats.completionRate;
  if (done != null) {
    parts.add('${(done * 100).round()}% completed');
  }
  final skip = stats.skipRate;
  if (skip != null) {
    parts.add('${(skip * 100).round()}% skipped');
  }
  return parts.join('  ·  ');
}

bool _usesFutureStatus(
  ScheduledTask task,
  TimeOfDay now,
  DateTime today,
) {
  final day = dateOnly(task.date);
  if (day.isAfter(today)) return true;
  if (day.isBefore(today)) return false;
  return _statusOf(task, now) == _StatusChoice.upcoming;
}

_StatusChoice _statusOf(ScheduledTask task, TimeOfDay now) {
  if (task.isCompleted) return _StatusChoice.complete;
  if (task.isCanceled) return _StatusChoice.skipped;
  if (task.isMissed(now)) return _StatusChoice.expired;
  if (task.isActive(now)) return _StatusChoice.inProgress;
  if (task.isAllDay) return _StatusChoice.openAllDay;
  return _StatusChoice.upcoming;
}

IconData _statusIcon(_StatusChoice status) {
  return switch (status) {
    _StatusChoice.complete => Icons.check_circle_outline,
    _StatusChoice.skipped => Icons.cancel_outlined,
    _StatusChoice.expired => Icons.hourglass_bottom_rounded,
    _StatusChoice.inProgress => Icons.play_circle_outline,
    _StatusChoice.openAllDay => Icons.wb_sunny_outlined,
    _StatusChoice.upcoming => Icons.upcoming_outlined,
  };
}

class _SummaryLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _SummaryLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: color,
                ),
          ),
        ),
      ],
    );
  }
}

String _occurrenceDateLabel(DateTime day) {
  final now = DateTime.now();
  final months = (now.year - day.year) * 12 + now.month - day.month;
  final format = months.abs() < 12 ? DateFormat.MMMEd() : DateFormat.yMMMEd();
  return format.format(day);
}

String _timeLine(BuildContext context, ScheduledTask task) {
  if (task.isAllDay) return 'All day';
  if (task.startTime != null && task.endTime != null) {
    return '${task.startTime!.format(context)} – ${task.endTime!.format(context)}';
  }
  if (task.startTime != null) {
    return 'Starts at ${task.startTime!.format(context)}';
  }
  return 'No time set';
}

String _repeatLine(ScheduledTask task) {
  switch (task.repeatType) {
    case RepeatType.daily:
      return 'Every day';
    case RepeatType.weekly:
      return Task.weeklyRepeatLabel(task.repeatWeekdays, task.task.startDate);
    case RepeatType.monthly:
      return 'Monthly';
    case RepeatType.custom:
      final n = task.repeatInterval ?? 1;
      return n <= 1 ? 'Every day' : 'Every $n days';
    case RepeatType.none:
      return 'Does not repeat';
  }
}

class _OccurrenceSpanBar extends StatefulWidget {
  final Color color;
  final TimeOfDay start;
  final TimeOfDay end;
  final TimeOfDay now;
  final bool isToday;
  final bool pastDay;
  final bool enabled;
  final void Function(TimeOfDay start, TimeOfDay end) onChanged;

  const _OccurrenceSpanBar({
    required this.color,
    required this.start,
    required this.end,
    required this.now,
    required this.isToday,
    required this.pastDay,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<_OccurrenceSpanBar> createState() => _OccurrenceSpanBarState();
}

enum _SpanGrab { start, end, body }

class _OccurrenceSpanBarState extends State<_OccurrenceSpanBar> {
  static const _day = 24 * 60;
  static const _snap = 5.0;
  static const _minDuration = 5.0;

  _SpanGrab? _grab;
  double _grabStart = 0;
  double _grabDuration = 0;
  double _grabPointer = 0;

  double get _start => minutesOf(widget.start).toDouble();
  double get _duration =>
      durationMinutes(widget.start, widget.end).toDouble();

  double _snapMinutes(double minutes) {
    var value = (minutes / _snap).round() * _snap;
    value %= _day;
    if (value < 0) value += _day;
    return value;
  }

  double _xToMinutes(double x, double width) {
    return (x / width).clamp(0.0, 1.0) * _day;
  }

  void _onDown(Offset local, double width) {
    if (!widget.enabled) return;
    final start = _start;
    final duration = _duration;
    final pointer = _xToMinutes(local.dx, width);
    final startX = (start / _day) * width;
    final endMin = (start + duration) % _day;
    final endX = (endMin / _day) * width;
    const handle = 16.0;
    final ds = (local.dx - startX).abs();
    final de = (local.dx - endX).abs();
    if (ds <= handle && ds <= de) {
      _grab = _SpanGrab.start;
    } else if (de <= handle) {
      _grab = _SpanGrab.end;
    } else {
      _grab = _SpanGrab.body;
    }
    _grabStart = start;
    _grabDuration = duration;
    _grabPointer = pointer;
  }

  void _onMove(Offset local, double width) {
    if (_grab == null) return;
    final pointer = _xToMinutes(local.dx, width);
    var delta = pointer - _grabPointer;
    if (delta > _day / 2) delta -= _day;
    if (delta < -_day / 2) delta += _day;

    var start = _grabStart;
    var duration = _grabDuration;
    switch (_grab!) {
      case _SpanGrab.body:
        start = _snapMinutes(_grabStart + delta);
        break;
      case _SpanGrab.start:
        final end = (_grabStart + _grabDuration) % _day;
        start = _snapMinutes(pointer);
        duration = end - start;
        if (duration <= 0) duration += _day;
        if (duration < _minDuration) duration = _minDuration;
        break;
      case _SpanGrab.end:
        start = _grabStart;
        duration = _snapMinutes(pointer) - start;
        if (duration <= 0) duration += _day;
        if (duration < _minDuration) duration = _minDuration;
        duration = _snapMinutes(start + duration) - start;
        if (duration <= 0) duration += _day;
        if (duration < _minDuration) duration = _minDuration;
        break;
    }
    widget.onChanged(
      timeFromMinutes(start.round()),
      timeFromMinutes((start + duration).round() % _day),
    );
  }

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.outlineVariant;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: widget.enabled
              ? (d) => _onDown(d.localPosition, width)
              : null,
          onPanUpdate: widget.enabled
              ? (d) => _onMove(d.localPosition, width)
              : null,
          onPanEnd: (_) => _grab = null,
          child: SizedBox(
            height: 28,
            width: width,
            child: CustomPaint(
              painter: _SpanBarPainter(
                color: widget.color,
                trackColor: track,
                startMinutes: _start,
                durationMinutes: _duration,
                nowMinutes: minutesOf(widget.now).toDouble(),
                isToday: widget.isToday,
                pastDay: widget.pastDay,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SpanBarPainter extends CustomPainter {
  static const _day = 24 * 60.0;

  final Color color;
  final Color trackColor;
  final double startMinutes;
  final double durationMinutes;
  final double nowMinutes;
  final bool isToday;
  final bool pastDay;

  _SpanBarPainter({
    required this.color,
    required this.trackColor,
    required this.startMinutes,
    required this.durationMinutes,
    required this.nowMinutes,
    required this.isToday,
    required this.pastDay,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    const thickness = 10.0;
    final track = RRect.fromLTRBR(
      0,
      cy - thickness / 2,
      size.width,
      cy + thickness / 2,
      const Radius.circular(5),
    );
    canvas.drawRRect(
      track,
      Paint()..color = trackColor.withValues(alpha: 0.28),
    );

    final faded = color.withValues(alpha: 0.32);
    final solid = color.withValues(alpha: 0.92);
    void fillRange(double fromMin, double toMin, Color fill) {
      if (toMin <= fromMin) return;
      final left = (fromMin / _day) * size.width;
      final right = (toMin / _day) * size.width;
      canvas.drawRRect(
        RRect.fromLTRBR(
          left,
          cy - thickness / 2,
          right,
          cy + thickness / 2,
          const Radius.circular(5),
        ),
        Paint()..color = fill,
      );
    }

    void paintSpan(double from, double to) {
      if (isToday) {
        fillRange(from, math.min(to, nowMinutes), faded);
        fillRange(math.max(from, nowMinutes), to, solid);
      } else if (pastDay) {
        fillRange(from, to, faded);
      } else {
        fillRange(from, to, solid);
      }
    }

    final start = startMinutes;
    final end = (startMinutes + durationMinutes) % _day;
    if (durationMinutes >= _day - 0.5) {
      paintSpan(0, _day);
    } else if (start + durationMinutes <= _day) {
      paintSpan(start, start + durationMinutes);
    } else {
      paintSpan(start, _day);
      paintSpan(0, end);
    }

    if (isToday) {
      final x = (nowMinutes / _day) * size.width;
      final line = Paint()
        ..color = color
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(x, 2), Offset(x, size.height - 2), line);
      canvas.drawCircle(Offset(x, 5), 3.2, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_SpanBarPainter old) =>
      old.color != color ||
      old.trackColor != trackColor ||
      old.startMinutes != startMinutes ||
      old.durationMinutes != durationMinutes ||
      old.nowMinutes != nowMinutes ||
      old.isToday != isToday ||
      old.pastDay != pastDay;
}
