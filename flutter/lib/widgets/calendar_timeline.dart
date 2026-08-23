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

String formatHourLabel(int hour) {
  final h = hour % 24;
  final display = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  final period = h >= 12 ? 'PM' : 'AM';
  return '$display $period';
}

class CalendarEventBlock extends StatelessWidget {
  final ScheduledTask task;
  final bool compact;

  const CalendarEventBlock({
    super.key,
    required this.task,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canvas = theme.scaffoldBackgroundColor;
    final struck = task.isCompleted || task.isCanceled;
    final ink = taskInkColor(task.color, theme.brightness);
    final wash = taskWash(
      task.color,
      canvas,
      struck || task.isAllDay ? 0.08 : 0.12,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(4),
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
    );
  }
}

class DayTimeline extends StatelessWidget {
  final List<ScheduledTask> tasks;
  final double hourHeight;
  final bool showHourLabels;
  final int? nowMinutes;
  final bool compact;

  const DayTimeline({
    super.key,
    required this.tasks,
    required this.hourHeight,
    this.showHourLabels = false,
    this.nowMinutes,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final blocks = layoutTimeline(tasks);
    final height = hourHeight * 24;
    final theme = Theme.of(context);
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final colW = constraints.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var h = 0; h < 24; h++)
                Positioned(
                  top: h * hourHeight,
                  left: 0,
                  right: 0,
                  child: Divider(
                    height: 1,
                    color: theme.dividerColor.withOpacity(
                      h % 6 == 0 ? 0.5 : 0.2,
                    ),
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
    final top = (block.startMin / kMinutesPerDay) * dayHeight;
    final h = ((block.endMin - block.startMin) / kMinutesPerDay) * dayHeight;
    final laneW = totalWidth / block.lanes;
    return Positioned(
      top: top,
      height: h.clamp(12.0, dayHeight),
      left: block.lane * laneW + 1,
      width: (laneW - 2).clamp(4.0, totalWidth),
      child: CalendarEventBlock(task: block.task, compact: compact),
    );
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

class AxisCaption extends StatelessWidget {
  final String text;
  final bool twoLine;

  const AxisCaption({super.key, required this.text, this.twoLine = false});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.tertiary;
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
  final bool compact;

  const HourRail({
    super.key,
    required this.hourHeight,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kHourRailWidth,
      height: hourHeight * 24,
      child: Stack(
        children: [
          for (var h = 0; h < 24; h++)
            Positioned(
              top: h * hourHeight - (compact ? 8 : 6),
              left: 0,
              right: 4,
              child: AxisCaption(
                text: formatHourLabel(h),
                twoLine: compact,
              ),
            ),
        ],
      ),
    );
  }
}

class AllDayStack extends StatelessWidget {
  final List<ScheduledTask> tasks;
  final bool compact;

  const AllDayStack({
    super.key,
    required this.tasks,
    this.compact = false,
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
                child: CalendarEventBlock(task: task, compact: compact),
              ),
            ),
        ],
      ),
    );
  }
}
