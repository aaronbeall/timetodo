import 'package:flutter/material.dart';
import 'package:timetodo/models/task.dart';
import 'package:timetodo/time_utils.dart';

class TaskRepeatField extends StatelessWidget {
  final DateTime date;
  final RepeatType repeatType;
  final int? repeatInterval;
  final List<int>? repeatWeekdays;
  final void Function({
    required RepeatType type,
    int? interval,
    List<int>? weekdays,
  }) onChanged;

  const TaskRepeatField({
    super.key,
    required this.date,
    required this.repeatType,
    required this.repeatInterval,
    required this.repeatWeekdays,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<RepeatType>(
          value: repeatType,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Repeat',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(
              value: RepeatType.none,
              child: Text('Does not repeat'),
            ),
            const DropdownMenuItem(
              value: RepeatType.daily,
              child: Text('Every day'),
            ),
            const DropdownMenuItem(
              value: RepeatType.weekly,
              child: Text('Weekly'),
            ),
            const DropdownMenuItem(
              value: RepeatType.weekdays,
              child: Text('Every weekday (Mon–Fri)'),
            ),
            DropdownMenuItem(
              value: RepeatType.monthly,
              child: Text('Monthly on the ${dayOrdinal(date.day)}'),
            ),
            DropdownMenuItem(
              value: RepeatType.custom,
              child: Text(_customSummary()),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            _applyType(value);
          },
        ),
        if (repeatType == RepeatType.weekly) ...[
          const SizedBox(height: 12),
          Text('Repeats on', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          _WeekdayChips(
            firstDayIndex: loc.firstDayOfWeekIndex,
            selected: _effectiveWeekdays(),
            onToggle: _toggleWeekday,
          ),
        ],
        if (repeatType == RepeatType.custom) ...[
          const SizedBox(height: 12),
          TextFormField(
            initialValue: '${repeatInterval ?? 2}',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Repeat every',
              suffixText: 'days',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              final n = int.tryParse(value);
              onChanged(
                type: RepeatType.custom,
                interval: n == null || n < 1 ? 1 : n,
                weekdays: null,
              );
            },
          ),
        ],
      ],
    );
  }

  List<int> _effectiveWeekdays() {
    final days = repeatWeekdays;
    if (days != null && days.isNotEmpty) return List<int>.from(days);
    return [date.weekday];
  }

  String _customSummary() {
    final n = repeatInterval ?? 2;
    return n <= 1 ? 'Custom' : 'Every $n days';
  }

  void _applyType(RepeatType type) {
    switch (type) {
      case RepeatType.none:
      case RepeatType.daily:
      case RepeatType.monthly:
      case RepeatType.weekdays:
        onChanged(type: type, interval: null, weekdays: null);
      case RepeatType.weekly:
        onChanged(
          type: type,
          interval: null,
          weekdays: _effectiveWeekdays(),
        );
      case RepeatType.custom:
        onChanged(
          type: type,
          interval: repeatInterval ?? 2,
          weekdays: null,
        );
    }
  }

  void _toggleWeekday(int weekday) {
    final next = _effectiveWeekdays();
    if (next.contains(weekday)) {
      if (next.length == 1) return;
      next.remove(weekday);
    } else {
      next.add(weekday);
    }
    next.sort();
    onChanged(type: RepeatType.weekly, interval: null, weekdays: next);
  }
}

class _WeekdayChips extends StatelessWidget {
  final int firstDayIndex;
  final List<int> selected;
  final ValueChanged<int> onToggle;

  const _WeekdayChips({
    required this.firstDayIndex,
    required this.selected,
    required this.onToggle,
  });

  static const _narrow = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  /// Material firstDayOfWeekIndex is 0=Sunday … 6=Saturday.
  /// DateTime.weekday is 1=Monday … 7=Sunday.
  static int _dateTimeWeekday(int sundayBased) =>
      sundayBased == 0 ? DateTime.sunday : sundayBased;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < 7; i++) _chip(i),
      ],
    );
  }

  Widget _chip(int i) {
    final sundayBased = (firstDayIndex + i) % 7;
    final weekday = _dateTimeWeekday(sundayBased);
    final on = selected.contains(weekday);
    return FilterChip(
      label: Text(_narrow[sundayBased]),
      selected: on,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => onToggle(weekday),
    );
  }
}
