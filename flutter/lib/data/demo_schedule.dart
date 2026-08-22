import 'package:flutter/material.dart';
import 'package:timetodo/models/task.dart';

enum DemoScheduleKind {
  light,
  typical,
  packed,
}

TimeOfDay _t(int hour, int minute) => TimeOfDay(hour: hour, minute: minute);

TimeOfDay _fromMinutes(int minutes) {
  final m = minutes % (24 * 60);
  final normalized = m < 0 ? m + 24 * 60 : m;
  return TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60);
}

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
  _DemoBuilder(this.day)
      : date = DateTime(day.year, day.month, day.day);

  final DateTime day;
  final DateTime date;
  int _n = 0;

  Task timed({
    required String label,
    required TimeOfDay start,
    required TimeOfDay end,
    Color? color,
    RepeatType repeat = RepeatType.none,
  }) {
    final i = _n++;
    return Task(
      id: 'demo-$i',
      label: label,
      startTime: start,
      endTime: end,
      color: color ?? _palette[i % _palette.length],
      date: date,
      repeatType: repeat,
    );
  }

  Task allDay(String label, Color color) {
    final i = _n++;
    return Task(
      id: 'demo-$i',
      label: label,
      isAllDay: true,
      color: color,
      date: date,
      repeatType: RepeatType.daily,
    );
  }
}

List<Task> buildDemoSchedule(DateTime day, DemoScheduleKind kind) {
  switch (kind) {
    case DemoScheduleKind.light:
      return _light(day);
    case DemoScheduleKind.typical:
      return _typical(day);
    case DemoScheduleKind.packed:
      return _packed(day);
  }
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
      repeat: RepeatType.weekdays,
    ),
    d.timed(
      label: 'Dinner',
      start: _t(18, 30),
      end: _t(19, 30),
      color: const Color(0xFFFF7043),
    ),
    d.allDay('Drink water', const Color(0xFF29B6F6)),
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
      repeat: RepeatType.weekdays,
    ),
    d.timed(
      label: 'Collaboration block',
      start: _t(11, 0),
      end: _t(13, 30),
      color: const Color(0xFF26A69A),
      repeat: RepeatType.weekdays,
    ),
    d.timed(
      label: 'Project time',
      start: _t(15, 0),
      end: _t(19, 0),
      color: const Color(0xFF7E57C2),
    ),
    d.timed(
      label: 'Workout',
      start: _t(17, 30),
      end: _t(19, 30),
      color: const Color(0xFFEF5350),
    ),
    d.timed(
      label: 'Evening',
      start: _t(19, 30),
      end: _t(22, 0),
      color: const Color(0xFFAB47BC),
    ),
    d.allDay('Drink water', const Color(0xFF29B6F6)),
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
      label: 'Night notes',
      start: _t(22, 0),
      end: _t(23, 30),
    ),
    d.timed(
      label: 'Wind down',
      start: _t(21, 15),
      end: _t(22, 45),
    ),
    d.allDay('Drink water', const Color(0xFF29B6F6)),
    d.allDay('Inbox zero', const Color(0xFF78909C)),
  ];

  void span(String label, int startMin, int durationMin) {
    tasks.add(
      d.timed(
        label: label,
        start: _fromMinutes(startMin),
        end: _fromMinutes(startMin + durationMin),
      ),
    );
  }

  // Long covering blocks that overlap each other.
  for (var start = 6 * 60 + 30; start < 22 * 60; start += 90) {
    span('Focus ${1 + (start ~/ 90)}', start, 150);
  }

  // Dense 45-minute meetings every 20 minutes through the workday.
  for (var start = 9 * 60; start < 18 * 60; start += 20) {
    span('Meeting ${1 + ((start - 9 * 60) ~/ 20)}', start, 45);
  }

  // Short pings stacked on the late morning.
  for (var start = 10 * 60; start < 12 * 60 + 30; start += 12) {
    span('Ping ${1 + ((start - 10 * 60) ~/ 12)}', start, 25);
  }

  // Afternoon review pile-up.
  for (var start = 14 * 60; start < 16 * 60 + 30; start += 15) {
    span('Review ${1 + ((start - 14 * 60) ~/ 15)}', start, 50);
  }

  // Evening stack.
  span('Commute', 17 * 60 + 15, 40);
  span('Gym', 17 * 60 + 45, 75);
  span('Errands', 18 * 60 + 10, 55);
  span('Cook', 18 * 60 + 40, 70);
  span('Family', 19 * 60 + 15, 100);
  span('Read', 20 * 60 + 30, 80);

  return tasks;
}
