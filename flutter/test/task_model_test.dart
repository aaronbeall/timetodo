import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetodo/models/scheduled_task.dart';
import 'package:timetodo/models/task.dart';

import 'support.dart';

void main() {
  group('TaskEra.generatesOn', () {
    test('daily covers every day from its start', () {
      final era = TaskEra(from: d(2026, 5, 4), repeatType: RepeatType.daily);
      expect(era.generatesOn(d(2026, 5, 3)), isFalse);
      expect(era.generatesOn(d(2026, 5, 4)), isTrue);
      expect(era.generatesOn(d(2027, 1, 1)), isTrue);
    });

    test('respects the closing date', () {
      final era = TaskEra(
        from: d(2026, 5, 4),
        to: d(2026, 5, 6),
        repeatType: RepeatType.daily,
      );
      expect(era.generatesOn(d(2026, 5, 6)), isTrue);
      expect(era.generatesOn(d(2026, 5, 7)), isFalse);
    });

    test('weekly with no weekdays repeats on the start weekday', () {
      // 2026-05-04 is a Monday.
      final era = TaskEra(from: d(2026, 5, 4), repeatType: RepeatType.weekly);
      expect(era.generatesOn(d(2026, 5, 11)), isTrue);
      expect(era.generatesOn(d(2026, 5, 12)), isFalse);
    });

    test('weekly with weekdays uses only those days', () {
      final era = TaskEra(
        from: d(2026, 5, 4),
        repeatType: RepeatType.weekly,
        repeatWeekdays: [DateTime.tuesday, DateTime.saturday],
      );
      expect(era.generatesOn(d(2026, 5, 4)), isFalse); // Mon
      expect(era.generatesOn(d(2026, 5, 5)), isTrue); // Tue
      expect(era.generatesOn(d(2026, 5, 9)), isTrue); // Sat
    });

    test('monthly repeats on the start day of the month', () {
      final era = TaskEra(from: d(2026, 1, 15), repeatType: RepeatType.monthly);
      expect(era.generatesOn(d(2026, 2, 15)), isTrue);
      expect(era.generatesOn(d(2026, 2, 16)), isFalse);
    });

    test('custom every N days stays on cadence across a DST change', () {
      // Every 3 days from Mar 1 2026; US clocks spring forward on Mar 8.
      final era = TaskEra(
        from: d(2026, 3, 1),
        repeatType: RepeatType.custom,
        repeatInterval: 3,
      );
      expect(era.generatesOn(d(2026, 3, 7)), isTrue);
      expect(era.generatesOn(d(2026, 3, 10)), isTrue);
      expect(era.generatesOn(d(2026, 3, 11)), isFalse);
      expect(era.generatesOn(d(2026, 3, 31)), isTrue);
    });

    test('a one-off era never generates by itself', () {
      final era = TaskEra(from: d(2026, 5, 4));
      expect(era.generatesOn(d(2026, 5, 4)), isFalse);
    });
  });

  group('Task eras', () {
    final task = Task(
      id: 'x',
      label: 'x',
      color: Colors.red,
      eras: [
        TaskEra(
          from: d(2026, 1, 1),
          to: d(2026, 1, 31),
          repeatType: RepeatType.daily,
          startTime: t(9),
          endTime: t(10),
        ),
        TaskEra(
          from: d(2026, 2, 1),
          repeatType: RepeatType.daily,
          startTime: t(18),
          endTime: t(19),
        ),
      ],
    );

    test('eraCovering picks the era for each date', () {
      expect(task.eraCovering(d(2025, 12, 31)), isNull);
      expect(task.eraCovering(d(2026, 1, 31))!.startTime, t(9));
      expect(task.eraCovering(d(2026, 2, 1))!.startTime, t(18));
    });

    test('scheduled times follow the era of that day', () {
      expect(ScheduledTask(task: task, date: d(2026, 1, 10)).startTime, t(9));
      expect(ScheduledTask(task: task, date: d(2026, 3, 10)).startTime, t(18));
    });

    test('one-off tasks occur only when pinned', () {
      final oneOff = dailyTask(from: d(2026, 5, 4), repeat: RepeatType.none);
      expect(oneOff.occursOn(d(2026, 5, 4)), isFalse);
      expect(oneOff.occursOn(d(2026, 5, 4), pinned: true), isTrue);
    });

    test('JSON round trip keeps the schedule', () {
      final copy = Task.fromJson(task.toJson());
      expect(copy.eras.length, 2);
      for (var i = 0; i < 2; i++) {
        expect(copy.eras[i].scheduleEquals(task.eras[i]), isTrue);
      }
    });
  });

  group('ScheduledTask status at a date-time', () {
    ScheduledTask on(DateTime day, TimeOfDay start, TimeOfDay end,
        {bool completed = false}) {
      final task = dailyTask(from: d(2026, 1, 1), start: start, end: end);
      return ScheduledTask(
        task: task,
        date: day,
        occurrence: completed
            ? occurrence(task.id, day).copyWith(isCompleted: true)
            : null,
      );
    }

    final evening = DateTime(2026, 11, 12, 20, 26);

    test("tomorrow's afternoon task is upcoming tonight, not missed", () {
      final task = on(d(2026, 11, 13), t(15), t(19));
      expect(task.isUpcomingAt(evening), isTrue);
      expect(task.isMissedAt(evening), isFalse);
    });

    test("today's finished task is missed", () {
      final task = on(d(2026, 11, 12), t(15), t(19));
      expect(task.isMissedAt(evening), isTrue);
    });

    test("yesterday's overnight task is still active after midnight", () {
      final task = on(d(2026, 11, 12), t(22), t(7));
      expect(task.endsAt, DateTime(2026, 11, 13, 7));
      expect(task.isActiveAt(DateTime(2026, 11, 13, 1)), isTrue);
      expect(task.isMissedAt(DateTime(2026, 11, 13, 7)), isTrue);
    });

    test('completed tasks are never missed', () {
      final task = on(d(2026, 11, 12), t(15), t(19), completed: true);
      expect(task.isMissedAt(evening), isFalse);
      expect(task.isActiveAt(evening), isFalse);
    });

    test('a past day is missed at any time of day', () {
      final task = on(d(2026, 11, 10), t(22), t(23));
      expect(task.isMissedAt(DateTime(2026, 11, 12, 8)), isTrue);
    });
  });
}
