import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timetodo/models/scheduled_task.dart';
import 'package:timetodo/models/task.dart';
import 'package:timetodo/providers/task_provider.dart';
import 'package:timetodo/screens/settings_screen.dart';
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

  /// Bumped whenever the Calendar tab is selected so the view returns to today.
  final int resetTick;

  const CalendarScreen({
    super.key,
    this.onEditTask,
    this.resetTick = 0,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _pageCenter = 50000;

  _CalSpan _span = _CalSpan.month;
  DateTime _focus = DateTime.now();
  late DateTime _pageOrigin;
  late PageController _pager;

  DateTime get _today => dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _pageOrigin = _periodAnchor(_focus);
    _pager = PageController(initialPage: _pageCenter);
  }

  @override
  void didUpdateWidget(CalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetTick != oldWidget.resetTick) {
      _resetToToday();
    }
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _resetToToday() {
    final target = _today;
    setState(() => _focus = target);
    if (!_pager.hasClients) return;
    final page = _pageForDate(target);
    final current = _pager.page?.round() ?? _pageCenter;
    if (page != current) {
      _pager.jumpToPage(page);
    }
  }

  DateTime _periodAnchor(DateTime d) {
    final day = dateOnly(d);
    switch (_span) {
      case _CalSpan.schedule:
      case _CalSpan.day:
        return day;
      case _CalSpan.week:
        return day.subtract(Duration(days: day.weekday % 7));
      case _CalSpan.month:
        return DateTime(day.year, day.month, 1);
      case _CalSpan.year:
        return DateTime(day.year, 1, 1);
    }
  }

  DateTime _dateForPage(int page) {
    final n = page - _pageCenter;
    final o = _pageOrigin;
    switch (_span) {
      case _CalSpan.schedule:
      case _CalSpan.day:
        return o.add(Duration(days: n));
      case _CalSpan.week:
        return o.add(Duration(days: 7 * n));
      case _CalSpan.month:
        return DateTime(o.year, o.month + n, 1);
      case _CalSpan.year:
        return DateTime(o.year + n, 1, 1);
    }
  }

  int _pageForDate(DateTime d) {
    final a = _periodAnchor(d);
    final o = _pageOrigin;
    switch (_span) {
      case _CalSpan.schedule:
      case _CalSpan.day:
        return _pageCenter + a.difference(o).inDays;
      case _CalSpan.week:
        return _pageCenter + a.difference(o).inDays ~/ 7;
      case _CalSpan.month:
        return _pageCenter + (a.year - o.year) * 12 + a.month - o.month;
      case _CalSpan.year:
        return _pageCenter + a.year - o.year;
    }
  }

  void _replacePager() {
    _pageOrigin = _periodAnchor(_focus);
    _pager.dispose();
    _pager = PageController(initialPage: _pageCenter);
  }

  void _setSpan(_CalSpan span, {DateTime? focus}) {
    setState(() {
      if (focus != null) _focus = focus;
      if (span != _span) {
        _span = span;
        _replacePager();
      }
    });
  }

  void _goTo(DateTime day, {bool animate = true}) {
    final target = dateOnly(day);
    if (!_pager.hasClients) {
      setState(() => _focus = target);
      return;
    }
    final page = _pageForDate(target);
    final current = _pager.page?.round() ?? _pageCenter;
    if (!animate || (page - current).abs() > 2) {
      _pager.jumpToPage(page);
    } else {
      _pager.animateToPage(
        page,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onPageChanged(int page) {
    final day = _dateForPage(page);
    final next = _periodAnchor(day);
    final cur = _periodAnchor(_focus);
    if (next.year == cur.year &&
        next.month == cur.month &&
        next.day == cur.day) {
      return;
    }
    setState(() => _focus = day);
  }

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
                  : () => _goTo(_today),
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
            onSelected: (span) => _setSpan(span),
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
          IconButton(
            tooltip: 'Settings',
            onPressed: () => openSettings(context),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: PageView.builder(
        key: ValueKey(_span),
        controller: _pager,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, page) => _body(provider, _dateForPage(page)),
      ),
    );
  }

  Widget _body(TaskProvider provider, DateTime day) {
    switch (_span) {
      case _CalSpan.schedule:
        return _scheduleView(provider, day);
      case _CalSpan.day:
        return _dayView(provider, day);
      case _CalSpan.week:
        return _weekView(provider, day);
      case _CalSpan.month:
        return _monthView(provider, day);
      case _CalSpan.year:
        return _yearView(provider, day);
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
    _goTo(_shifted(_focus, direction));
  }

  DateTime _shifted(DateTime from, int direction) {
    switch (_span) {
      case _CalSpan.schedule:
      case _CalSpan.day:
        return from.add(Duration(days: direction));
      case _CalSpan.week:
        return from.add(Duration(days: 7 * direction));
      case _CalSpan.month:
        return DateTime(from.year, from.month + direction, 1);
      case _CalSpan.year:
        return DateTime(from.year + direction, 1, 1);
    }
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
      onTaskTap: _showOccurrence,
    );
  }

  Widget _polarWithTime(
    List<ScheduledTask> tasks, {
    required double size,
    required DateTime day,
  }) {
    final polar = _polar(tasks, size: size, day: day);
    if (!isSameDay(day, _today)) return polar;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          polar,
          IgnorePointer(child: _nowHubLabel(size)),
        ],
      ),
    );
  }

  Widget _nowHubLabel(double size) {
    final now = TimeOfDay.now();
    final hour = now.hour == 0 ? 12 : (now.hour > 12 ? now.hour - 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    final color = Theme.of(context).colorScheme.onSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$hour:$minute',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: (size * 0.1).clamp(12.0, 20.0),
            height: 1,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          period,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: (size * 0.045).clamp(8.0, 11.0),
            height: 1,
            color: color.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }

  void _showOccurrence(ScheduledTask task) {
    showTaskSummarySheet(
      context,
      task: task,
      now: TimeOfDay.now(),
      onEdit: () => widget.onEditTask?.call(task.task),
    );
  }

  Widget _scheduleView(TaskProvider provider, DateTime day) {
    final items = provider.scheduledOn(day)
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
                  Center(
                    child: _polarWithTime(items, size: polarSize, day: day),
                  ),
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
                    ),
                  ..._scheduleRows(provider, day, items, now),
                ],
              );
            },
          );
  }

  List<Widget> _scheduleRows(
    TaskProvider provider,
    DateTime day,
    List<ScheduledTask> items,
    TimeOfDay now,
  ) {
    final allDay = items.where((t) => t.isAllDay).toList();
    final timed = items.where((t) => !t.isAllDay).toList();
    final rows = <Widget>[
      for (final task in allDay) _scheduleTile(provider, day, task, now),
    ];
    if (!isSameDay(day, _today)) {
      rows.addAll([
        for (final task in timed) _scheduleTile(provider, day, task, now),
      ]);
      return rows;
    }
    var placedNow = false;
    for (final task in timed) {
      final beforeNow = task.isUpcoming(now) || task.isActive(now);
      if (!placedNow && beforeNow) {
        rows.add(const ScheduleNowBar());
        placedNow = true;
      }
      rows.add(_scheduleTile(provider, day, task, now));
    }
    if (!placedNow) rows.add(const ScheduleNowBar());
    return rows;
  }

  Widget _scheduleTile(
    TaskProvider provider,
    DateTime day,
    ScheduledTask task,
    TimeOfDay now,
  ) {
    return TaskListItem(
      task: task,
      currentTime: now,
      date: day,
      calendarList: true,
      onTap: () => _showOccurrence(task),
      onSnooze: isSameDay(day, _today)
          ? () {
              final undo = provider.snoozeTask(task.id, day);
              showChangeToast(
                context,
                message: 'Snoozed ${task.label} 15 min',
                onUndo: undo,
              );
            }
          : null,
      onExtend: isSameDay(day, _today)
          ? () {
              final undo = provider.extendTask(task.id, day);
              showChangeToast(
                context,
                message: 'Extended ${task.label} 15 min',
                onUndo: undo,
              );
            }
          : null,
      onComplete: isSameDay(day, _today)
          ? () {
              final undo = provider.completeTask(task.id, day);
              showChangeToast(
                context,
                message: 'Completed ${task.label}',
                onUndo: undo,
              );
            }
          : null,
      onCancel: () {
        final undo = provider.cancelTask(task.id, day);
        showChangeToast(
          context,
          message: 'Skipped ${task.label}',
          onUndo: undo,
        );
      },
      onDoNow: isSameDay(day, _today)
          ? () {
              final undo = provider.doNowTask(task.id, day, now);
              showChangeToast(
                context,
                message: 'Started ${task.label} now',
                onUndo: undo,
              );
            }
          : null,
    );
  }

  Widget _dayView(TaskProvider provider, DateTime day) {
    final items = provider.scheduledOn(day);
    final allDay = allDayTasks(items);
    return LayoutBuilder(
            builder: (context, constraints) {
              final polarSize =
                  (constraints.maxWidth - 48).clamp(160.0, 280.0);
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                child: Column(
                  children: [
                    _polarWithTime(items, size: polarSize, day: day),
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
                            onTaskTap: _showOccurrence,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HourRail(hourHeight: 44, tasks: items),
                        Expanded(
                          child: DayTimeline(
                            tasks: items,
                            hourHeight: 44,
                            nowMinutes: _nowMinutesOn(day),
                            onTaskTap: _showOccurrence,
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

  Widget _weekView(TaskProvider provider, DateTime focus) {
    final start = dateOnly(focus)
        .subtract(Duration(days: dateOnly(focus).weekday % 7));
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
                    onTap: () => _setSpan(_CalSpan.day, focus: day),
                    child: Column(
                      children: [
                        Text(
                          DateFormat.E().format(day),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 4),
                        _TodayDayMark(
                          label: '${day.day}',
                          today: isSameDay(day, _today),
                          size: 32,
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
                              color: isSameDay(days[i], _today)
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.07)
                                  : null,
                              border: Border(
                                right: BorderSide(
                                  color: Theme.of(context)
                                      .dividerColor
                                      .withValues(alpha: 0.12),
                                ),
                              ),
                            ),
                            child: AllDayStack(
                              tasks: allDayTasks(perDay[i]),
                              compact: true,
                              onTaskTap: _showOccurrence,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HourRail(
                      hourHeight: 28,
                      tasks: [for (final list in perDay) ...list],
                    ),
                    for (var i = 0; i < days.length; i++)
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: isSameDay(days[i], _today)
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.07)
                                : null,
                            border: Border(
                              right: BorderSide(
                                color: Theme.of(context)
                                    .dividerColor
                                    .withValues(alpha: 0.12),
                              ),
                            ),
                          ),
                          child: DayTimeline(
                            tasks: perDay[i],
                            hourHeight: 28,
                            nowMinutes: _nowMinutesOn(days[i]),
                            compact: true,
                            onTaskTap: _showOccurrence,
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

  Widget _monthView(TaskProvider provider, DateTime day) {
    final first = DateTime(day.year, day.month, 1);
    final lead = first.weekday % 7;
    final daysInMonth = DateTime(day.year, day.month + 1, 0).day;
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
              final cell = DateTime(day.year, day.month, dayNum);
              final items = provider.scheduledOn(cell);
              final today = isSameDay(cell, _today);
              return InkWell(
                onTap: () => _setSpan(_CalSpan.day, focus: cell),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final size = box.biggest.shortestSide;
                    return Center(
                      child: _MonthDayCell(
                        dayNum: dayNum,
                        size: size,
                        today: today,
                        polar: _polar(items, size: size, day: cell),
                      ),
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

  Widget _yearView(TaskProvider provider, DateTime focus) {
    var maxCount = 1;
    final counts = <String, int>{};
    for (var m = 1; m <= 12; m++) {
      final last = DateTime(focus.year, m + 1, 0).day;
      for (var d = 1; d <= last; d++) {
        final date = DateTime(focus.year, m, d);
        final n = provider.scheduledOn(date).length;
        counts[dateKey(date)] = n;
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
              final month = DateTime(focus.year, m + 1, 1);
              return InkWell(
                onTap: () => _setSpan(_CalSpan.month, focus: month),
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
                        year: focus.year,
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

class _TodayHalo extends StatelessWidget {
  final double size;
  final bool showRing;
  final Widget? hub;
  final Widget child;

  const _TodayHalo({
    required this.size,
    required this.showRing,
    required this.child,
    this.hub,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          child,
          if (showRing)
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.primary, width: 2),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          if (hub != null)
            IgnorePointer(
              child: SizedBox(
                width: size * 0.34,
                height: size * 0.34,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary,
                  ),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: scheme.onPrimary),
                    child: Center(child: hub),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TodayDayMark extends StatelessWidget {
  final String label;
  final bool today;
  final double size;

  const _TodayDayMark({
    required this.label,
    required this.today,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: today
            ? BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary,
                border: Border.all(color: scheme.primary, width: 2),
              )
            : const BoxDecoration(),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: today ? FontWeight.w800 : FontWeight.w500,
                  color: today ? scheme.onPrimary : null,
                  height: 1,
                ),
          ),
        ),
      ),
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  final int dayNum;
  final double size;
  final bool today;
  final Widget polar;

  const _MonthDayCell({
    required this.dayNum,
    required this.size,
    required this.today,
    required this.polar,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _TodayHalo(
      size: size,
      showRing: today,
      hub: today
          ? Text(
              '$dayNum',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: size * 0.18,
                    height: 1,
                    color: scheme.onPrimary,
                  ),
            )
          : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          polar,
          if (!today)
            Text(
              '$dayNum',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: size * 0.18,
                    height: 1,
                    color: scheme.onSurface,
                  ),
            ),
        ],
      ),
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
        final today = isSameDay(day, DateTime.now());
        return Padding(
          padding: const EdgeInsets.all(0.6),
          child: AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: today && n == 0
                    ? primary.withValues(alpha: 0.22)
                    : n == 0
                        ? empty
                        : primary.withOpacity(t),
                border: today ? Border.all(color: primary, width: 1.5) : null,
              ),
            ),
          ),
        );
      },
    );
  }
}
