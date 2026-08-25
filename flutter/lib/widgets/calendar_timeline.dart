import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:timetodo/models/scheduled_task.dart';
import 'package:timetodo/time_utils.dart';

const kMinutesPerDay = 24 * 60;
const kHourRailWidth = 52.0;
const kAllDayRowHeight = 26.0;

class TimelineBlock {
  final ScheduledTask task;
  final int startMin;
  final int endMin;
  final int lane;
  final int lanes;

  const TimelineBlock({
    required this.task,
    required this.startMin,
    required this.endMin,
    required this.lane,
    required this.lanes,
  });
}

List<ScheduledTask> allDayTasks(List<ScheduledTask> tasks) =>
    tasks.where((t) => t.isAllDay && !t.isCanceled).toList();

List<TimelineBlock> layoutTimeline(List<ScheduledTask> tasks) {
  final intervals = <({ScheduledTask task, int start, int end})>[];
  for (final task in tasks) {
    if (task.isAllDay ||
        task.isCanceled ||
        task.startTime == null ||
        task.endTime == null) {
      continue;
    }
    final start = minutesOf(task.startTime!);
    final end = minutesOf(task.endTime!);
    if (start < end) {
      intervals.add((task: task, start: start, end: end));
    } else {
      intervals.add((task: task, start: start, end: kMinutesPerDay));
      if (end > 0) {
        intervals.add((task: task, start: 0, end: end));
      }
    }
  }
  intervals.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    if (byStart != 0) return byStart;
    return (b.end - b.start).compareTo(a.end - a.start);
  });

  final laneEnds = <int>[];
  final placed = <({ScheduledTask task, int start, int end, int lane})>[];
  for (final item in intervals) {
    var lane = -1;
    for (var i = 0; i < laneEnds.length; i++) {
      if (laneEnds[i] <= item.start) {
        lane = i;
        break;
      }
    }
    if (lane == -1) {
      lane = laneEnds.length;
      laneEnds.add(item.end);
    } else {
      laneEnds[lane] = item.end;
    }
    placed.add((task: item.task, start: item.start, end: item.end, lane: lane));
  }

  final lanes = laneEnds.isEmpty ? 1 : laneEnds.length;
  return [
    for (final p in placed)
      TimelineBlock(
        task: p.task,
        startMin: p.start,
        endMin: p.end,
        lane: p.lane,
        lanes: lanes,
      ),
  ];
}

String formatHourLabel(int hour, {required bool use24Hour}) =>
    formatAxisTime(hour * 60, use24Hour: use24Hour);


List<int> axisMarkMinutes(List<ScheduledTask> tasks) {
  final marks = <int>{};
  for (final block in layoutTimeline(tasks)) {
    marks.add(block.startMin);
    if (block.startMin == 0) marks.add(0);
    if (block.endMin >= kMinutesPerDay) {
      marks.add(kMinutesPerDay);
    } else {
      marks.add(block.endMin);
    }
  }
  return marks.toList()..sort();
}

List<int> spaceAxisMarks(
  List<int> sorted, {
  required double hourHeight,
  double minGap = 20,
}) {
  if (sorted.isEmpty) return sorted;
  bool pinned(int m) => m == 0 || m == kMinutesPerDay;
  final kept = <int>[];
  for (final m in sorted) {
    if (pinned(m)) {
      if (kept.isNotEmpty && !pinned(kept.last)) {
        final px = ((m - kept.last) / 60) * hourHeight;
        if (px < minGap) kept.removeLast();
      }
      kept.add(m);
      continue;
    }
    if (kept.isEmpty) {
      kept.add(m);
      continue;
    }
    final px = ((m - kept.last) / 60) * hourHeight;
    if (px >= minGap) kept.add(m);
  }
  return kept;
}

class CalendarEventBlock extends StatelessWidget {
  final ScheduledTask task;
  final bool compact;
  final VoidCallback? onTap;

  const CalendarEventBlock({
    super.key,
    required this.task,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final struck = task.isCompleted || task.isCanceled;
    final ink = taskInkColor(task.color, theme.brightness);
    final fill = task.color.withValues(
      alpha: struck || task.isAllDay ? 0.16 : 0.28,
    );
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            border: Border(
              left: BorderSide(color: task.color, width: compact ? 3 : 4),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 3 : 6,
              vertical: compact ? 1 : 3,
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                task.label,
                maxLines: compact ? 2 : 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: ink.withOpacity(struck ? 0.55 : 1),
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 9 : 11,
                  height: 1.15,
                  decoration: struck ? TextDecoration.lineThrough : null,
                  decorationColor: ink.withOpacity(0.45),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double axisOffsetY(int minutes, double hourHeight) {
  if (minutes >= kMinutesPerDay) return hourHeight * 24;
  if (minutes <= 0) return 0;
  return (minutes / 60) * hourHeight;
}

/// Half the axis hour-digit height; the number sits on the hairline.
const kAxisNumberHalf = 5.0;

class DayTimeline extends StatelessWidget {
  final List<ScheduledTask> tasks;
  final double hourHeight;
  final bool showHourLabels;
  final int? nowMinutes;
  final bool compact;
  final ValueChanged<ScheduledTask>? onTaskTap;
  final List<int>? axisMarks;

  const DayTimeline({
    super.key,
    required this.tasks,
    required this.hourHeight,
    this.showHourLabels = false,
    this.nowMinutes,
    this.compact = false,
    this.onTaskTap,
    this.axisMarks,
  });

  @override
  Widget build(BuildContext context) {
    final blocks = layoutTimeline(tasks);
    final height = hourHeight * 24;
    final theme = Theme.of(context);
    final marks = axisMarks ??
        spaceAxisMarks(axisMarkMinutes(tasks), hourHeight: hourHeight);
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final colW = constraints.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                size: Size(colW, height),
                painter: _AxisHairlinePainter(
                  marks: marks,
                  hourHeight: hourHeight,
                  blocks: blocks,
                  color: theme.dividerColor.withValues(alpha: 0.28),
                ),
              ),
              for (final block in blocks)
                _event(context, block, height, colW),
              if (nowMinutes != null)
                Positioned(
                  top: (nowMinutes! / 60) * hourHeight - 10,
                  left: -_TimelineNowHandPainter.overhang,
                  right: 0,
                  height: 20,
                  child: const IgnorePointer(child: TimelineNowHand()),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _event(
    BuildContext context,
    TimelineBlock block,
    double dayHeight,
    double totalWidth,
  ) {
    final box = timelineEventBox(block, dayHeight, totalWidth);
    return Positioned(
      top: box.top,
      height: box.height,
      left: box.left,
      width: box.width,
      child: CalendarEventBlock(
        task: block.task,
        compact: compact,
        onTap: onTaskTap == null ? null : () => onTaskTap!(block.task),
      ),
    );
  }
}

Rect timelineEventBox(TimelineBlock block, double dayHeight, double totalWidth) {
  final top = (block.startMin / kMinutesPerDay) * dayHeight;
  final h = ((block.endMin - block.startMin) / kMinutesPerDay) * dayHeight;
  final laneW = totalWidth / block.lanes;
  return Rect.fromLTWH(
    block.lane * laneW + 1,
    top,
    (laneW - 2).clamp(4.0, totalWidth),
    h.clamp(12.0, dayHeight),
  );
}

class _AxisHairlinePainter extends CustomPainter {
  final List<int> marks;
  final double hourHeight;
  final List<TimelineBlock> blocks;
  final Color color;

  _AxisHairlinePainter({
    required this.marks,
    required this.hourHeight,
    required this.blocks,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round;
    final dayHeight = hourHeight * 24;
    for (final minutes in marks) {
      final y = axisOffsetY(minutes, hourHeight);
      final gaps = _occupiedX(y, size.width, dayHeight);
      var x = 0.0;
      for (final span in gaps) {
        if (span.start > x + 0.5) {
          _drawDotted(canvas, x, span.start, y, paint);
        }
        if (span.end > x) x = span.end;
      }
      if (x < size.width - 0.5) {
        _drawDotted(canvas, x, size.width, y, paint);
      }
    }
  }

  static void _drawDotted(
    Canvas canvas,
    double from,
    double to,
    double y,
    Paint paint,
  ) {
    const dash = 2.0;
    const gap = 3.0;
    var x = from;
    while (x < to) {
      final end = x + dash > to ? to : x + dash;
      if (end - x > 0.4) {
        canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      }
      x += dash + gap;
    }
  }

  List<({double start, double end})> _occupiedX(
    double y,
    double width,
    double dayHeight,
  ) {
    final raw = <({double start, double end})>[];
    for (final block in blocks) {
      final box = timelineEventBox(block, dayHeight, width);
      if (y < box.top || y > box.bottom) continue;
      raw.add((start: box.left, end: box.right));
    }
    raw.sort((a, b) => a.start.compareTo(b.start));
    final merged = <({double start, double end})>[];
    for (final span in raw) {
      if (merged.isEmpty || span.start > merged.last.end) {
        merged.add(span);
      } else {
        final last = merged.removeLast();
        merged.add((
          start: last.start,
          end: span.end > last.end ? span.end : last.end,
        ));
      }
    }
    return merged;
  }

  @override
  bool shouldRepaint(covariant _AxisHairlinePainter oldDelegate) {
    return oldDelegate.hourHeight != hourHeight ||
        oldDelegate.color != color ||
        oldDelegate.marks != marks ||
        oldDelegate.blocks != blocks;
  }
}

class TimelineNowHand extends StatelessWidget {
  const TimelineNowHand({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomPaint(
      painter: _TimelineNowHandPainter(
        nowColor: theme.colorScheme.onSurface,
        nowOnColor: theme.colorScheme.surface,
      ),
    );
  }
}

class _TimelineNowHandPainter extends CustomPainter {
  static const overhang = 8.0;

  final Color nowColor;
  final Color nowOnColor;

  _TimelineNowHandPainter({
    required this.nowColor,
    required this.nowOnColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const shaftWidth = 3.0;
    final tipRadius = shaftWidth * 1.15;
    final cy = size.height / 2;
    const tipCenter = overhang;
    final shaftStart = tipCenter + tipRadius * 0.35;
    final shaftEnd = size.width;

    final shaft = RRect.fromLTRBR(
      shaftStart,
      cy - shaftWidth / 2,
      shaftEnd,
      cy + shaftWidth / 2,
      Radius.circular(shaftWidth / 2),
    );

    canvas.drawRRect(
      shaft.inflate(2.5),
      Paint()..color = nowOnColor.withOpacity(0.45),
    );
    canvas.drawRRect(
      shaft,
      Paint()..color = nowColor.withOpacity(0.92),
    );

    final tip = Offset(tipCenter, cy);
    canvas.drawCircle(
      tip,
      tipRadius + 1.6,
      Paint()..color = nowOnColor.withOpacity(0.55),
    );
    canvas.drawCircle(
      tip,
      tipRadius,
      Paint()..color = nowColor.withOpacity(0.95),
    );
    canvas.drawCircle(
      tip,
      tipRadius * 0.38,
      Paint()..color = nowOnColor.withOpacity(0.9),
    );
  }

  @override
  bool shouldRepaint(_TimelineNowHandPainter oldDelegate) =>
      oldDelegate.nowColor != nowColor || oldDelegate.nowOnColor != nowOnColor;
}

class ScheduleNowBar extends StatelessWidget {
  const ScheduleNowBar({super.key});

  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.now();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        height: 22,
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: AxisCaption(
                text: formatAxisTime(
                  minutesOf(now),
                  use24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
                ),
                twoLine: true,
              ),
            ),
            const SizedBox(width: 2),
            const Expanded(child: TimelineNowHand()),
          ],
        ),
      ),
    );
  }
}

class AxisCaption extends StatelessWidget {
  final String text;
  final bool twoLine;

  const AxisCaption({super.key, required this.text, this.twoLine = false});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    if (!twoLine) {
      return Text(
        text,
        textAlign: TextAlign.right,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 10,
              height: 1.1,
            ),
      );
    }
    final parts = text.split(' ');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          parts.first,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 10,
                height: 1,
              ),
        ),
        if (parts.length > 1)
          Text(
            parts.last,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color.withOpacity(0.75),
                  fontSize: 8,
                  height: 1,
                ),
          ),
      ],
    );
  }
}

class HourRail extends StatelessWidget {
  final double hourHeight;
  final List<ScheduledTask> tasks;
  final List<int>? marks;

  const HourRail({
    super.key,
    required this.hourHeight,
    this.tasks = const [],
    this.marks,
  });

  @override
  Widget build(BuildContext context) {
    final marks = this.marks ??
        spaceAxisMarks(axisMarkMinutes(tasks), hourHeight: hourHeight);
    return SizedBox(
      width: kHourRailWidth,
      height: hourHeight * 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final minutes in marks)
            Positioned(
              top: axisOffsetY(minutes, hourHeight) - kAxisNumberHalf,
              left: 0,
              right: 4,
              child: AxisCaption(
                text: formatAxisTime(
                  minutes,
                  use24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
                ),
                twoLine: true,
              ),
            ),
        ],
      ),
    );
  }
}

class WeekAllDayLane extends StatelessWidget {
  final List<DateTime> days;
  final List<List<ScheduledTask>> perDay;
  final ValueChanged<ScheduledTask>? onTaskTap;

  const WeekAllDayLane({
    super.key,
    required this.days,
    required this.perDay,
    this.onTaskTap,
  });

  static double heightFor(List<List<ScheduledTask>> perDay) {
    return AllDayStack.heightFor(_pack(_spans(perDay)).length);
  }

  @override
  Widget build(BuildContext context) {
    final packed = _pack(_spans(perDay));
    final height = AllDayStack.heightFor(packed.length);
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inner = math.max(
            0.0,
            constraints.maxWidth - kHourRailWidth * 2,
          );
          final colW = inner / days.length;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: 0,
                width: kHourRailWidth,
                top: 0,
                bottom: 0,
                child: const Padding(
                  padding: EdgeInsets.only(right: 4, top: 6),
                  child: AxisCaption(text: 'All day'),
                ),
              ),
              for (var i = 0; i < days.length; i++)
                Positioned(
                  left: kHourRailWidth + i * colW,
                  width: colW,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isSameDay(days[i], DateTime.now())
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.07)
                          : null,
                    ),
                  ),
                ),
              for (final placed in packed)
                Positioned(
                  left: kHourRailWidth + placed.start * colW + 2,
                  width: (placed.end - placed.start + 1) * colW - 4,
                  top: 2 + placed.lane * kAllDayRowHeight,
                  height: kAllDayRowHeight - 4,
                  child: CalendarEventBlock(
                    task: placed.task,
                    compact: true,
                    onTap: onTaskTap == null
                        ? null
                        : () => onTaskTap!(placed.task),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static List<_WeekAllDaySpan> _spans(List<List<ScheduledTask>> perDay) {
    final indexes = <String, List<int>>{};
    final sample = <String, ScheduledTask>{};
    for (var i = 0; i < perDay.length; i++) {
      for (final task in allDayTasks(perDay[i])) {
        indexes.putIfAbsent(task.id, () => []).add(i);
        sample.putIfAbsent(task.id, () => task);
      }
    }
    final spans = <_WeekAllDaySpan>[];
    for (final id in indexes.keys) {
      final days = [...indexes[id]!]..sort();
      var runStart = days.first;
      var prev = days.first;
      for (var k = 1; k <= days.length; k++) {
        final cur = k == days.length ? null : days[k];
        if (cur == prev + 1) {
          prev = cur!;
          continue;
        }
        spans.add(
          _WeekAllDaySpan(task: sample[id]!, start: runStart, end: prev),
        );
        if (cur != null) {
          runStart = cur;
          prev = cur;
        }
      }
    }
    return spans;
  }

  static List<_WeekAllDayPlaced> _pack(List<_WeekAllDaySpan> spans) {
    final sorted = [...spans]..sort((a, b) {
      final byLen = (b.end - b.start).compareTo(a.end - a.start);
      if (byLen != 0) return byLen;
      return a.start.compareTo(b.start);
    });
    final laneEnds = <int>[];
    final placed = <_WeekAllDayPlaced>[];
    for (final span in sorted) {
      var lane = -1;
      for (var i = 0; i < laneEnds.length; i++) {
        if (laneEnds[i] < span.start) {
          lane = i;
          break;
        }
      }
      if (lane == -1) {
        lane = laneEnds.length;
        laneEnds.add(span.end);
      } else {
        laneEnds[lane] = span.end;
      }
      placed.add(
        _WeekAllDayPlaced(
          task: span.task,
          start: span.start,
          end: span.end,
          lane: lane,
        ),
      );
    }
    return placed;
  }
}

class _WeekAllDaySpan {
  final ScheduledTask task;
  final int start;
  final int end;

  const _WeekAllDaySpan({
    required this.task,
    required this.start,
    required this.end,
  });
}

class _WeekAllDayPlaced {
  final ScheduledTask task;
  final int start;
  final int end;
  final int lane;

  const _WeekAllDayPlaced({
    required this.task,
    required this.start,
    required this.end,
    required this.lane,
  });
}

class AllDayStack extends StatelessWidget {
  final List<ScheduledTask> tasks;
  final bool compact;
  final ValueChanged<ScheduledTask>? onTaskTap;

  const AllDayStack({
    super.key,
    required this.tasks,
    this.compact = false,
    this.onTaskTap,
  });

  static double heightFor(int count) {
    final n = count < 1 ? 1 : count;
    return n * kAllDayRowHeight + 6;
  }

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return SizedBox(height: heightFor(0));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
      child: Column(
        children: [
          for (final task in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: SizedBox(
                height: kAllDayRowHeight - 4,
                width: double.infinity,
                child: CalendarEventBlock(
                  task: task,
                  compact: compact,
                  onTap: onTaskTap == null ? null : () => onTaskTap!(task),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
