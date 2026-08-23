import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timetodo/models/scheduled_task.dart';
import 'package:timetodo/models/task.dart';
import 'package:timetodo/providers/task_provider.dart';
import 'package:timetodo/time_utils.dart';
import 'package:timetodo/widgets/calendar_timeline.dart';
import 'package:timetodo/widgets/change_toast.dart';
import 'package:timetodo/widgets/polar_clock.dart';
import 'package:timetodo/widgets/task_list_item.dart';
import 'package:timetodo/widgets/task_summary_sheet.dart';

enum _CalSpan { schedule, day, week, month, year }

String _spanLabel(_CalSpan span) => switch (span) {
      _CalSpan.schedule => 'Schedule',
      _CalSpan.day => 'Day',
      _CalSpan.week => 'Week',
      _CalSpan.month => 'Month',
      _CalSpan.year => 'Year',
    };

IconData _spanIcon(_CalSpan span) => switch (span) {
      _CalSpan.schedule => Icons.view_agenda_outlined,
      _CalSpan.day => Icons.view_day_outlined,
      _CalSpan.week => Icons.view_week_outlined,
      _CalSpan.month => Icons.calendar_view_month_outlined,
      _CalSpan.year => Icons.calendar_month_outlined,
    };

class CalendarScreen extends StatefulWidget {
  final ValueChanged<Task>? onEditTask;

  const CalendarScreen({super.key, this.onEditTask});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  _CalSpan _span = _CalSpan.month;
  DateTime _focus = DateTime.now();

  DateTime get _today => dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            IconButton(
              tooltip: 'Previous',
              onPressed: () => _step(-1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              tooltip: 'Next',
              onPressed: () => _step(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
            IconButton(
              tooltip: 'Today',
              onPressed: _isCurrentPeriod
                  ? null
                  : () => setState(() => _focus = DateTime.now()),
              icon: const Icon(Icons.today),
            ),
            Expanded(
              child: Text(
                _periodTitle(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        elevation: 0,
        actions: [
          PopupMenuButton<_CalSpan>(
            initialValue: _span,
            tooltip: 'Calendar view',
            onSelected: (span) => setState(() => _span = span),
            itemBuilder: (context) => [
              for (final span in _CalSpan.values)
                PopupMenuItem(
                  value: span,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_spanIcon(span)),
                    title: Text(_spanLabel(span)),
                    trailing: span == _span
                        ? const Icon(Icons.check, size: 20)
                        : null,
                  ),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _spanLabel(_span),
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _body(provider),
    );
  }

  Widget _body(TaskProvider provider) {
    switch (_span) {
      case _CalSpan.schedule:
        return _scheduleView(provider);
      case _CalSpan.day:
        return _dayView(provider);
      case _CalSpan.week:
        return _weekView(provider);
      case _CalSpan.month:
        return _monthView(provider);
      case _CalSpan.year:
        return _yearView(provider);
    }
  }

  List<DateTime> _weekDays() {
    final start = dateOnly(_focus)
        .subtract(Duration(days: dateOnly(_focus).weekday % 7));
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  String _periodTitle() {
    switch (_span) {
      case _CalSpan.schedule:
        return DateFormat.yMMMEd().format(_focus);
      case _CalSpan.day:
        return (_withinAYear(_focus) ? DateFormat.MMMEd() : DateFormat.yMMMEd())
            .format(_focus);
      case _CalSpan.week:
        final days = _weekDays();
        return '${_weekEdgeTitle(days.first)} – ${_weekEdgeTitle(days.last)}';
      case _CalSpan.month:
        return (_withinAYear(_focus) ? DateFormat.MMMM() : DateFormat.yMMMM())
            .format(_focus);
      case _CalSpan.year:
        return '${_focus.year}';
    }
  }

  /// True when [day] is less than 12 months from today (so Dec 2025 is
  /// "December" in Jan 2026, but Dec 2024 is "December 2024").
  bool _withinAYear(DateTime day) {
    final months =
        (_today.year - day.year) * 12 + _today.month - day.month;
    return months.abs() < 12;
  }

  String _weekEdgeTitle(DateTime day) {
    return (_withinAYear(day) ? DateFormat.MMMd() : DateFormat.yMMMd())
        .format(day);
  }

  bool get _isCurrentPeriod {
    switch (_span) {
      case _CalSpan.schedule:
      case _CalSpan.day:
        return isSameDay(_focus, _today);
      case _CalSpan.week:
        final days = _weekDays();
        return !_today.isBefore(days.first) && !_today.isAfter(days.last);
      case _CalSpan.month:
        return _focus.year == _today.year && _focus.month == _today.month;
      case _CalSpan.year:
        return _focus.year == _today.year;
    }
  }

  void _step(int direction) {
    setState(() {
      switch (_span) {
        case _CalSpan.schedule:
        case _CalSpan.day:
          _focus = _focus.add(Duration(days: direction));
        case _CalSpan.week:
          _focus = _focus.add(Duration(days: 7 * direction));
        case _CalSpan.month:
          _focus = DateTime(_focus.year, _focus.month + direction, 1);
        case _CalSpan.year:
          _focus = DateTime(_focus.year + direction, 1, 1);
      }
    });
  }

  int? _nowMinutesOn(DateTime day) {
    if (!isSameDay(day, DateTime.now())) return null;
    final n = TimeOfDay.now();
    return minutesOf(n);
  }

  PolarClock _polar(
    List<ScheduledTask> tasks, {
    required double size,
    required DateTime day,
  }) {
    final isToday = isSameDay(day, DateTime.now());
    return PolarClock(
      currentTime: isToday ? TimeOfDay.now() : const TimeOfDay(hour: 0, minute: 0),
      tasks: tasks,
      size: size,
      animate: false,
      showNow: isToday,
      onTaskTap: _showInstance,
    );
  }

  void _showInstance(ScheduledTask task) {
    showTaskSummarySheet(
      context,
      task: task,
      now: TimeOfDay.now(),
      onEdit: () => widget.onEditTask?.call(task.task),
    );
  }

  Widget _scheduleView(TaskProvider provider) {
    final items = provider.scheduledOn(_focus)
      ..sort((a, b) {
        if (a.isAllDay && !b.isAllDay) return -1;
        if (!a.isAllDay && b.isAllDay) return 1;
        return (a.startTime == null ? 0 : minutesOf(a.startTime!))
            .compareTo(b.startTime == null ? 0 : minutesOf(b.startTime!));
      });
    final now = TimeOfDay.now();
    return LayoutBuilder(
            builder: (context, constraints) {
              final polarSize =
                  (constraints.maxWidth - 48).clamp(160.0, 280.0);
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  Center(child: _polar(items, size: polarSize, day: _focus)),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Center(
                        child: Text(
                          'Nothing scheduled',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.5),
                              ),
                        ),
                      ),
                    )
                  else
                    for (final task in items)
                      TaskListItem(
                        task: task,
                        currentTime: now,
                        onTap: () => _showInstance(task),
                        onSnooze: () {
                          final undo = provider.snoozeTask(task.id, _focus);
                          showChangeToast(
                            context,
                            message: 'Snoozed ${task.label} 15 min',
                            onUndo: undo,
                          );
                        },
                        onExtend: () {
                          final undo = provider.extendTask(task.id, _focus);
                          showChangeToast(
                            context,
                            message: 'Extended ${task.label} 15 min',
                            onUndo: undo,
                          );
                        },
                        onComplete: () {
                          final undo = provider.completeTask(task.id, _focus);
                          showChangeToast(
                            context,
                            message: 'Completed ${task.label}',
                            onUndo: undo,
                          );
                        },
                        onCancel: () {
                          final undo = provider.cancelTask(task.id, _focus);
                          showChangeToast(
                            context,
                            message: 'Skipped ${task.label}',
                            onUndo: undo,
                          );
                        },
                        onDoNow: () {
                          final undo =
                              provider.doNowTask(task.id, _focus, now);
                          showChangeToast(
                            context,
                            message: 'Started ${task.label} now',
                            onUndo: undo,
                          );
                        },
                      ),
                ],
              );
            },
          );
  }

  Widget _dayView(TaskProvider provider) {
    final items = provider.scheduledOn(_focus);
    final allDay = allDayTasks(items);
    return LayoutBuilder(
            builder: (context, constraints) {
              final polarSize =
                  (constraints.maxWidth - 48).clamp(160.0, 280.0);
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                child: Column(
                  children: [
                    _polar(items, size: polarSize, day: _focus),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: kHourRailWidth,
                          height: AllDayStack.heightFor(allDay.length),
                          child: const Padding(
                            padding: EdgeInsets.only(right: 4, top: 6),
                            child: AxisCaption(text: 'All day'),
                          ),
                        ),
                        Expanded(
                          child: AllDayStack(
                            tasks: allDay,
                            onTaskTap: _showInstance,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HourRail(hourHeight: 44),
                        Expanded(
                          child: DayTimeline(
                            tasks: items,
                            hourHeight: 44,
                            nowMinutes: _nowMinutesOn(_focus),
                            onTaskTap: _showInstance,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
  }

  Widget _weekView(TaskProvider provider) {
    final start = dateOnly(_focus)
        .subtract(Duration(days: dateOnly(_focus).weekday % 7));
    final days = List.generate(7, (i) => start.add(Duration(days: i)));
    final perDay = [for (final d in days) provider.scheduledOn(d)];
    final allDayCounts = [
      for (final list in perDay) allDayTasks(list).length,
    ];
    final allDayH = AllDayStack.heightFor(
      allDayCounts.fold<int>(0, (m, n) => n > m ? n : m),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(kHourRailWidth, 0, 8, 8),
          child: Row(
            children: [
              for (final day in days)
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() {
                      _focus = day;
                      _span = _CalSpan.day;
                    }),
                    child: Column(
                      children: [
                        Text(
                          DateFormat.E().format(day),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          '${day.day}',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: isSameDay(day, _today)
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                SizedBox(
                  height: allDayH,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: kHourRailWidth,
                        child: const Padding(
                          padding: EdgeInsets.only(right: 4, top: 6),
                          child: AxisCaption(text: 'All day'),
                        ),
                      ),
                      for (var i = 0; i < days.length; i++)
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: Theme.of(context)
                                      .dividerColor
                                      .withOpacity(0.35),
                                ),
                              ),
                            ),
                            child: AllDayStack(
                              tasks: allDayTasks(perDay[i]),
                              compact: true,
                              onTaskTap: _showInstance,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HourRail(hourHeight: 28, compact: true),
                    for (var i = 0; i < days.length; i++)
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: Theme.of(context)
                                    .dividerColor
                                    .withOpacity(0.35),
                              ),
                            ),
                          ),
                          child: DayTimeline(
                            tasks: perDay[i],
                            hourHeight: 28,
                            nowMinutes: _nowMinutesOn(days[i]),
                            compact: true,
                            onTaskTap: _showInstance,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _monthView(TaskProvider provider) {
    final first = DateTime(_focus.year, _focus.month, 1);
    final lead = first.weekday % 7;
    final daysInMonth = DateTime(_focus.year, _focus.month + 1, 0).day;
    final rows = ((lead + daysInMonth) / 7).ceil();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              for (final d in ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                Expanded(
                  child: Center(
                    child: Text(d, style: Theme.of(context).textTheme.labelSmall),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 0.92,
            ),
            itemCount: rows * 7,
            itemBuilder: (context, i) {
              final dayNum = i - lead + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const SizedBox.shrink();
              }
              final day = DateTime(_focus.year, _focus.month, dayNum);
              final items = provider.scheduledOn(day);
              final today = isSameDay(day, _today);
              return InkWell(
                onTap: () => setState(() {
                  _focus = day;
                  _span = _CalSpan.day;
                }),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final size = box.biggest.shortestSide;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        if (today)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withOpacity(0.55),
                            ),
                            child: const SizedBox.expand(),
                          ),
                        _polar(items, size: size, day: day),
                        Text(
                          '$dayNum',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: size * 0.18,
                              ),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _yearView(TaskProvider provider) {
    var maxCount = 1;
    final counts = <String, int>{};
    for (var m = 1; m <= 12; m++) {
      final last = DateTime(_focus.year, m + 1, 0).day;
      for (var d = 1; d <= last; d++) {
        final day = DateTime(_focus.year, m, d);
        final n = provider.scheduledOn(day).length;
        counts[dateKey(day)] = n;
        if (n > maxCount) maxCount = n;
      }
    }

    return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 20,
              crossAxisSpacing: 16,
              childAspectRatio: 0.95,
            ),
            itemCount: 12,
            itemBuilder: (context, m) {
              final month = DateTime(_focus.year, m + 1, 1);
              return InkWell(
                onTap: () => setState(() {
                  _focus = month;
                  _span = _CalSpan.month;
                }),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat.MMM().format(month),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: _MonthHeat(
                        year: _focus.year,
                        month: m + 1,
                        counts: counts,
                        maxCount: maxCount,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
  }
}

class _MonthHeat extends StatelessWidget {
  final int year;
  final int month;
  final Map<String, int> counts;
  final int maxCount;

  const _MonthHeat({
    required this.year,
    required this.month,
    required this.counts,
    required this.maxCount,
  });

  @override
  Widget build(BuildContext context) {
    final first = DateTime(year, month, 1);
    final lead = first.weekday % 7;
    final days = DateTime(year, month + 1, 0).day;
    final primary = Theme.of(context).colorScheme.primary;
    final empty = Theme.of(context).colorScheme.outlineVariant.withOpacity(0.35);

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: lead + days,
      itemBuilder: (context, i) {
        if (i < lead) return const SizedBox.shrink();
        final day = DateTime(year, month, i - lead + 1);
        final n = counts[dateKey(day)] ?? 0;
        final t = n == 0 ? 0.0 : (n / maxCount).clamp(0.18, 1.0);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: n == 0 ? empty : primary.withOpacity(t),
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
      },
    );
  }
}
