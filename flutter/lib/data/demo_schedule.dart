import 'package:flutter/material.dart';
import 'package:timetodo/models/task.dart';
import 'package:timetodo/models/task_occurrence.dart';
import 'package:timetodo/time_utils.dart';

enum DemoScheduleKind {
  light,
  typical,
  packed,
}

class DemoSchedule {
  final List<Task> tasks;
  final List<TaskOccurrence> occurrences;

  const DemoSchedule({required this.tasks, required this.occurrences});
}

TimeOfDay _t(int hour, int minute) => TimeOfDay(hour: hour, minute: minute);

TimeOfDay _fromMinutes(int minutes) {
  final m = minutes % (24 * 60);
  final normalized = m < 0 ? m + 24 * 60 : m;
  return TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60);
}

const _weekdays = [
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
];

const _mwf = [DateTime.monday, DateTime.wednesday, DateTime.friday];

const _palette = [
  Color(0xFF5C6BC0),
  Color(0xFFFFB74D),
  Color(0xFF42A5F5),
  Color(0xFF26A69A),
  Color(0xFF7E57C2),
  Color(0xFFEF5350),
  Color(0xFFAB47BC),
  Color(0xFF29B6F6),
  Color(0xFF66BB6A),
  Color(0xFFFF7043),
  Color(0xFF26C6DA),
  Color(0xFFEC407A),
];

class _DemoBuilder {
  _DemoBuilder(this.today)
      : date = dateOnly(today),
        historyStart = dateOnly(today).subtract(const Duration(days: 21));

  final DateTime today;
  final DateTime date;
  final DateTime historyStart;
  int _n = 0;

  Task timed({
    required String label,
    required TimeOfDay start,
    required TimeOfDay end,
    Color? color,
    RepeatType repeat = RepeatType.none,
    List<int>? weekdays,
    DateTime? startDate,
    DateTime? until,
  }) {
    final i = _n++;
    final begins = startDate ??
        (repeat == RepeatType.none ? date : historyStart);
    return Task(
      id: 'demo-$i',
      label: label,
      startTime: start,
      endTime: end,
      color: color ?? _palette[i % _palette.length],
      startDate: begins,
      endDate: until,
      repeatType: repeat,
      repeatWeekdays: weekdays,
    );
  }

  Task allDay(
    String label,
    Color color, {
    RepeatType repeat = RepeatType.daily,
    DateTime? until,
  }) {
    final i = _n++;
    return Task(
      id: 'demo-$i',
      label: label,
      isAllDay: true,
      color: color,
      startDate: repeat == RepeatType.none ? date : historyStart,
      endDate: until,
      repeatType: repeat,
    );
  }
}

DemoSchedule buildDemoSchedule(DateTime day, DemoScheduleKind kind) {
  final tasks = switch (kind) {
    DemoScheduleKind.light => _light(day),
    DemoScheduleKind.typical => _typical(day),
    DemoScheduleKind.packed => _packed(day),
  };
  return DemoSchedule(
    tasks: tasks,
    occurrences: _history(tasks, dateOnly(day)),
  );
}

List<Task> _light(DateTime day) {
  final d = _DemoBuilder(day);
  return [
    d.timed(
      label: 'Sleep',
      start: _t(23, 0),
      end: _t(7, 0),
      color: const Color(0xFF5C6BC0),
      repeat: RepeatType.daily,
    ),
    d.timed(
      label: 'Work',
      start: _t(9, 0),
      end: _t(17, 0),
      color: const Color(0xFF42A5F5),
      repeat: RepeatType.weekly,
      weekdays: _weekdays,
    ),
    d.timed(
      label: 'Dinner',
      start: _t(18, 30),
      end: _t(19, 30),
      color: const Color(0xFFFF7043),
    ),
    d.allDay('Drink water', const Color(0xFF29B6F6)),
    ..._archived(d),
  ];
}

List<Task> _typical(DateTime day) {
  final d = _DemoBuilder(day);
  return [
    d.timed(
      label: 'Sleep',
      start: _t(22, 0),
      end: _t(7, 0),
      color: const Color(0xFF5C6BC0),
      repeat: RepeatType.daily,
    ),
    d.timed(
      label: 'Morning routine',
      start: _t(7, 0),
      end: _t(9, 30),
      color: const Color(0xFFFFB74D),
      repeat: RepeatType.daily,
    ),
    d.timed(
      label: 'Deep work',
      start: _t(9, 30),
      end: _t(15, 0),
      color: const Color(0xFF42A5F5),
      repeat: RepeatType.weekly,
      weekdays: _weekdays,
    ),
    d.timed(
      label: 'Collaboration block',
      start: _t(11, 0),
      end: _t(13, 30),
      color: const Color(0xFF26A69A),
      repeat: RepeatType.weekly,
      weekdays: _weekdays,
    ),
    d.timed(
      label: 'Project time',
      start: _t(15, 0),
      end: _t(19, 0),
      color: const Color(0xFF7E57C2),
      repeat: RepeatType.weekly,
      weekdays: _weekdays,
    ),
    d.timed(
      label: 'Workout',
      start: _t(17, 30),
      end: _t(19, 30),
      color: const Color(0xFFEF5350),
      repeat: RepeatType.weekly,
      weekdays: _mwf,
    ),
    d.timed(
      label: 'Evening',
      start: _t(19, 30),
      end: _t(22, 0),
      color: const Color(0xFFAB47BC),
      repeat: RepeatType.daily,
    ),
    d.allDay('Drink water', const Color(0xFF29B6F6)),
    ..._archived(d),
  ];
}

List<Task> _packed(DateTime day) {
  final d = _DemoBuilder(day);
  final tasks = <Task>[
    d.timed(
      label: 'Sleep',
      start: _t(22, 30),
      end: _t(6, 30),
      color: const Color(0xFF5C6BC0),
      repeat: RepeatType.daily,
    ),
    d.timed(
      label: 'Morning routine',
      start: _t(6, 30),
      end: _t(8, 30),
      color: const Color(0xFFFFB74D),
      repeat: RepeatType.daily,
    ),
    d.timed(
      label: 'Deep work',
      start: _t(9, 0),
      end: _t(12, 0),
      color: const Color(0xFF42A5F5),
      repeat: RepeatType.weekly,
      weekdays: _weekdays,
    ),
    d.timed(
      label: 'Collaboration',
      start: _t(13, 0),
      end: _t(15, 30),
      color: const Color(0xFF26A69A),
      repeat: RepeatType.weekly,
      weekdays: _weekdays,
    ),
    d.timed(
      label: 'Project time',
      start: _t(15, 30),
      end: _t(18, 30),
      color: const Color(0xFF7E57C2),
      repeat: RepeatType.weekly,
      weekdays: _weekdays,
    ),
    d.timed(
      label: 'Workout',
      start: _t(18, 30),
      end: _t(19, 45),
      color: const Color(0xFFEF5350),
      repeat: RepeatType.weekly,
      weekdays: _mwf,
    ),
    d.timed(
      label: 'Evening',
      start: _t(20, 0),
      end: _t(22, 30),
      color: const Color(0xFFAB47BC),
      repeat: RepeatType.daily,
    ),
    d.allDay('Drink water', const Color(0xFF29B6F6)),
  ];

  void todayBlock(String label, int startMin, int durationMin) {
    tasks.add(
      d.timed(
        label: label,
        start: _fromMinutes(startMin),
        end: _fromMinutes(startMin + durationMin),
      ),
    );
  }

  todayBlock('Standup', 9 * 60 + 15, 45);
  todayBlock('Design review', 10 * 60, 90);
  todayBlock('Client call', 11 * 60, 60);
  todayBlock('1:1', 13 * 60 + 15, 50);
  todayBlock('Planning workshop', 14 * 60, 120);
  todayBlock('Hiring loop', 16 * 60, 90);
  todayBlock('Inbox', 12 * 60 + 15, 35);
  todayBlock('Slack catch-up', 15 * 60 + 10, 25);
  tasks.addAll(_archived(d));
  return tasks;
}

/// Closed series for Tasks → Archived (reopen / add-from-archive).
List<Task> _archived(_DemoBuilder d) {
  final lastWeek = d.date.subtract(const Duration(days: 5));
  final lastMonth = d.date.subtract(const Duration(days: 18));
  return [
    d.timed(
      label: 'Spanish class',
      start: _t(18, 0),
      end: _t(19, 0),
      color: const Color(0xFF26C6DA),
      repeat: RepeatType.weekly,
      weekdays: [DateTime.tuesday, DateTime.thursday],
      until: lastWeek,
    ),
    d.timed(
      label: 'Physio',
      start: _t(16, 0),
      end: _t(16, 45),
      color: const Color(0xFF66BB6A),
      repeat: RepeatType.weekly,
      weekdays: [DateTime.wednesday],
      until: d.date.subtract(const Duration(days: 12)),
    ),
    d.timed(
      label: 'Conference travel',
      start: _t(8, 0),
      end: _t(20, 0),
      color: const Color(0xFFFF7043),
      startDate: lastMonth,
      until: lastMonth.add(const Duration(days: 2)),
    ),
    d.allDay(
      'Meditate',
      const Color(0xFFAB47BC),
      until: lastWeek,
    ),
  ];
}

List<TaskOccurrence> _history(List<Task> tasks, DateTime today) {
  final occurrences = <TaskOccurrence>[];
  final yesterday = today.subtract(const Duration(days: 1));

  for (final task in tasks) {
    if (task.repeatType == RepeatType.none) {
      occurrences.add(_pin(task, dateOnly(task.startDate)));
      continue;
    }

    var cursor = dateOnly(task.firstFrom);
    while (!cursor.isAfter(yesterday)) {
      if (task.occursOn(cursor)) {
        final roll = _mix(task.id, cursor);
        final bias = _bias(task.label);
        if (roll < bias.completeUntil) {
          occurrences.add(_status(task, cursor, completed: true));
        } else if (roll < bias.skipUntil) {
          occurrences.add(_status(task, cursor, skipped: true));
        }
      }
      cursor = cursor.add(const Duration(days: 1));
    }
  }
  return occurrences;
}

({int completeUntil, int skipUntil}) _bias(String label) {
  final lower = label.toLowerCase();
  if (lower.contains('water')) return (completeUntil: 8, skipUntil: 9);
  if (lower.contains('sleep')) return (completeUntil: 7, skipUntil: 8);
  if (lower.contains('workout') || lower.contains('gym')) {
    return (completeUntil: 4, skipUntil: 7);
  }
  return (completeUntil: 6, skipUntil: 8);
}

int _mix(String id, DateTime day) => Object.hash(id, dateKey(day)).abs() % 10;

TaskOccurrence _pin(Task task, DateTime day) {
  return TaskOccurrence(
    id: TaskOccurrence.idFor(task.id, day),
    taskId: task.id,
    date: dateOnly(day),
  );
}

TaskOccurrence _status(
  Task task,
  DateTime day, {
  bool completed = false,
  bool skipped = false,
}) {
  return TaskOccurrence(
    id: TaskOccurrence.idFor(task.id, day),
    taskId: task.id,
    date: dateOnly(day),
    isCompleted: completed,
    isCanceled: skipped,
  );
}
