import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timetodo/models/scheduled_task.dart';
import 'package:timetodo/providers/task_provider.dart';
import 'package:timetodo/time_utils.dart';

enum _CalSpan { day, week, month, year }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  _CalSpan _span = _CalSpan.month;
  DateTime _focus = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SegmentedButton<_CalSpan>(
              segments: const [
                ButtonSegment(value: _CalSpan.day, label: Text('Day')),
                ButtonSegment(value: _CalSpan.week, label: Text('Week')),
                ButtonSegment(value: _CalSpan.month, label: Text('Month')),
                ButtonSegment(value: _CalSpan.year, label: Text('Year')),
              ],
              selected: {_span},
              onSelectionChanged: (v) => setState(() => _span = v.first),
            ),
          ),
          Expanded(child: _body(provider)),
        ],
      ),
    );
  }

  Widget _body(TaskProvider provider) {
    switch (_span) {
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

  Widget _header(String title, VoidCallback back, VoidCallback forward) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(onPressed: back, icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          IconButton(onPressed: forward, icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }

  Widget _dayView(TaskProvider provider) {
    final items = provider.scheduledOn(_focus)
      ..sort((a, b) {
        if (a.isAllDay && !b.isAllDay) return 1;
        if (!a.isAllDay && b.isAllDay) return -1;
        return (a.startTime == null ? 9999 : minutesOf(a.startTime!))
            .compareTo(b.startTime == null ? 9999 : minutesOf(b.startTime!));
      });
    return Column(
      children: [
        _header(
          DateFormat.yMMMEd().format(_focus),
          () => setState(() => _focus = _focus.subtract(const Duration(days: 1))),
          () => setState(() => _focus = _focus.add(const Duration(days: 1))),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('Nothing scheduled'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _taskRow(items[i]),
                ),
        ),
      ],
    );
  }

  Widget _weekView(TaskProvider provider) {
    final start = dateOnly(_focus)
        .subtract(Duration(days: dateOnly(_focus).weekday % 7));
    final days = List.generate(7, (i) => start.add(Duration(days: i)));
    return Column(
      children: [
        _header(
          '${DateFormat.MMMd().format(days.first)} – ${DateFormat.MMMd().format(days.last)}',
          () => setState(() => _focus = _focus.subtract(const Duration(days: 7))),
          () => setState(() => _focus = _focus.add(const Duration(days: 7))),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final day in days)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: Theme.of(context).dividerColor.withOpacity(0.4),
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            DateFormat.E().format(day),
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                        Text(
                          '${day.day}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        for (final t in provider.scheduledOn(day).take(8))
                          Container(
                            margin: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                            height: 4,
                            decoration: BoxDecoration(
                              color: t.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _monthView(TaskProvider provider) {
    final first = DateTime(_focus.year, _focus.month, 1);
    final lead = first.weekday % 7;
    final daysInMonth = DateTime(_focus.year, _focus.month + 1, 0).day;
    final cells = lead + daysInMonth;
    final rows = (cells / 7).ceil();
    return Column(
      children: [
        _header(
          DateFormat.yMMMM().format(_focus),
          () => setState(() => _focus = DateTime(_focus.year, _focus.month - 1, 1)),
          () => setState(() => _focus = DateTime(_focus.year, _focus.month + 1, 1)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
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
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              mainAxisExtent: MediaQuery.sizeOf(context).height / (rows + 4),
            ),
            itemCount: rows * 7,
            itemBuilder: (context, i) {
              final dayNum = i - lead + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const SizedBox.shrink();
              }
              final day = DateTime(_focus.year, _focus.month, dayNum);
              final items = provider.scheduledOn(day);
              final today = isSameDay(day, DateTime.now());
              return InkWell(
                onTap: () => setState(() {
                  _focus = day;
                  _span = _CalSpan.day;
                }),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: today
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      children: [
                        Text('$dayNum'),
                        const Spacer(),
                        Wrap(
                          spacing: 2,
                          runSpacing: 2,
                          children: [
                            for (final t in items.take(4))
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: t.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _yearView(TaskProvider provider) {
    return Column(
      children: [
        _header(
          '${_focus.year}',
          () => setState(() => _focus = DateTime(_focus.year - 1, 1, 1)),
          () => setState(() => _focus = DateTime(_focus.year + 1, 1, 1)),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: 12,
            itemBuilder: (context, m) {
              final month = DateTime(_focus.year, m + 1, 1);
              var count = 0;
              final last = DateTime(_focus.year, m + 2, 0).day;
              for (var d = 1; d <= last; d++) {
                count += provider.scheduledOn(DateTime(_focus.year, m + 1, d)).length;
              }
              return InkWell(
                onTap: () => setState(() {
                  _focus = month;
                  _span = _CalSpan.month;
                }),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat.MMM().format(month),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      count == 0 ? '—' : '$count',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _taskRow(ScheduledTask task) {
    final theme = Theme.of(context);
    final time = task.isAllDay
        ? 'All day'
        : task.startTime == null
            ? ''
            : task.startTime!.format(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: task.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              task.label,
              style: theme.textTheme.bodyLarge?.copyWith(
                decoration: task.isCompleted || task.isCanceled
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
          ),
          Text(
            time,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
