import 'package:flutter_test/flutter_test.dart';
import 'package:timetodo/models/task.dart';
import 'package:timetodo/providers/task_provider.dart';
import 'package:timetodo/time_utils.dart';

import 'support.dart';

ScheduledTimes _times(TaskProvider p, String id, DateTime day) {
  final item = p.scheduledOn(day).where((s) => s.id == id).toList();
  if (item.isEmpty) return const ScheduledTimes.absent();
  return ScheduledTimes(item.single.startTime, item.single.endTime);
}

class ScheduledTimes {
  final Object? start;
  final Object? end;
  final bool present;
  const ScheduledTimes(this.start, this.end) : present = true;
  const ScheduledTimes.absent()
      : start = null,
        end = null,
        present = false;

  @override
  bool operator ==(Object other) =>
      other is ScheduledTimes &&
      other.present == present &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(start, end, present);

  @override
  String toString() => present ? '$start–$end' : 'absent';
}

void main() {
  final today = dateOnly(DateTime.now());

  group('scheduledOn', () {
    test('a daily task appears every day from its start', () {
      final p = newProvider()
        ..addTask(dailyTask(from: addDays(today, -3)));
      expect(p.scheduledOn(addDays(today, -4)), isEmpty);
      expect(p.scheduledOn(addDays(today, -3)).single.id, 'walk');
      expect(p.scheduledOn(addDays(today, 30)).single.id, 'walk');
    });

    test('a one-off task appears only on its day', () {
      final p = newProvider()
        ..addTask(dailyTask(from: today, repeat: RepeatType.none));
      expect(p.scheduledOn(today).single.id, 'walk');
      expect(p.scheduledOn(addDays(today, 1)), isEmpty);
    });
  });

  group('occurrence edits', () {
    test('changing one day leaves the series alone, and undo restores it', () {
      final p = newProvider()..addTask(dailyTask(from: today));
      final day = addDays(today, 2);
      final undo = p.commitOccurrenceEdits(
        taskId: 'walk',
        day: day,
        writeTimes: true,
        isAllDay: false,
        startTime: t(14),
        endTime: t(15),
        writeStatus: false,
        isCompleted: false,
        isCanceled: false,
        applyFollowing: false,
      );
      expect(_times(p, 'walk', day), ScheduledTimes(t(14), t(15)));
      expect(_times(p, 'walk', addDays(day, 1)), ScheduledTimes(t(9), t(10)));

      undo!();
      expect(_times(p, 'walk', day), ScheduledTimes(t(9), t(10)));
    });

    test('"this and later" keeps earlier days and moves later ones', () {
      final p = newProvider()..addTask(dailyTask(from: addDays(today, -5)));
      final pivot = addDays(today, 2);
      p.commitOccurrenceEdits(
        taskId: 'walk',
        day: pivot,
        writeTimes: true,
        isAllDay: false,
        startTime: t(18),
        endTime: t(19),
        writeStatus: false,
        isCompleted: false,
        isCanceled: false,
        applyFollowing: true,
      );
      for (var i = -5; i < 2; i++) {
        expect(_times(p, 'walk', addDays(today, i)), ScheduledTimes(t(9), t(10)),
            reason: 'day $i keeps the old time');
      }
      for (var i = 2; i < 10; i++) {
        expect(_times(p, 'walk', addDays(today, i)), ScheduledTimes(t(18), t(19)),
            reason: 'day $i uses the new time');
      }
      final task = p.taskById('walk')!;
      expect(task.eras.length, 2);
      expect(task.eras.first.to, addDays(pivot, -1));
      expect(task.eras.last.from, pivot);
    });

    test('"this and later" from the day after a DST change keeps that day',
        () {
      // US clocks spring forward on Sun Mar 8 2026. Closing the old era the
      // day before Mar 9 must land on Mar 8, not Mar 7.
      final p = newProvider()..addTask(dailyTask(from: d(2026, 3, 1)));
      p.commitOccurrenceEdits(
        taskId: 'walk',
        day: d(2026, 3, 9),
        writeTimes: true,
        isAllDay: false,
        startTime: t(18),
        endTime: t(19),
        writeStatus: false,
        isCompleted: false,
        isCanceled: false,
        applyFollowing: true,
      );
      expect(p.taskById('walk')!.eras.first.to, d(2026, 3, 8));
      expect(_times(p, 'walk', d(2026, 3, 8)), ScheduledTimes(t(9), t(10)));
      expect(_times(p, 'walk', d(2026, 3, 9)), ScheduledTimes(t(18), t(19)));
    });

    test('complete, skip and clear are mutually exclusive', () {
      final p = newProvider()..addTask(dailyTask(from: today));
      p.completeTask('walk', today);
      var item = p.scheduledOn(today).single;
      expect((item.isCompleted, item.isCanceled), (true, false));

      p.cancelTask('walk', today);
      item = p.scheduledOn(today).single;
      expect((item.isCompleted, item.isCanceled), (false, true));

      p.clearOccurrenceStatus('walk', today);
      item = p.scheduledOn(today).single;
      expect((item.isCompleted, item.isCanceled), (false, false));
    });

    test('snooze pushes both ends 15 minutes and wraps midnight', () {
      final p = newProvider()
        ..addTask(dailyTask(from: today, start: t(23, 50), end: t(23, 55)));
      p.snoozeTask('walk', today);
      expect(_times(p, 'walk', today), ScheduledTimes(t(0, 5), t(0, 10)));
    });

    test('edits on a day the task does not occur are refused', () {
      final p = newProvider()..addTask(dailyTask(from: today));
      expect(p.completeTask('walk', addDays(today, -1)), isNull);
    });
  });

  group('series changes', () {
    test('editing the schedule keeps past days and clears future overrides',
        () {
      final p = newProvider()..addTask(dailyTask(from: addDays(today, -3)));
      p.setOccurrenceTimeframe('walk', addDays(today, 1),
          isAllDay: false, startTime: t(11), endTime: t(12));

      final edited = p.taskById('walk')!.copyWith(
            startTime: t(7),
            endTime: t(8),
          );
      p.updateTask(edited);

      expect(_times(p, 'walk', addDays(today, -1)), ScheduledTimes(t(9), t(10)));
      expect(_times(p, 'walk', today), ScheduledTimes(t(7), t(8)));
      expect(_times(p, 'walk', addDays(today, 1)), ScheduledTimes(t(7), t(8)),
          reason: 'override on a later day is cleared');
    });

    test('archive stops later days; unarchive resumes from today', () {
      final p = newProvider()..addTask(dailyTask(from: addDays(today, -3)));
      p.archiveTask('walk');
      expect(p.taskById('walk')!.isArchived, isTrue);
      expect(p.scheduledOn(addDays(today, 1)), isEmpty);
      expect(p.scheduledOn(addDays(today, -1)), isNotEmpty);

      p.unarchiveTask('walk');
      expect(p.taskById('walk')!.isArchived, isFalse);
      expect(p.scheduledOn(addDays(today, 1)), isNotEmpty);
    });
  });

  group('stats', () {
    test('seriesStats counts each day once', () {
      final p = newProvider()..addTask(dailyTask(from: addDays(today, -9)));
      for (var i = 1; i <= 3; i++) {
        p.completeTask('walk', addDays(today, -i));
      }
      p.cancelTask('walk', addDays(today, -4));
      p.cancelTask('walk', addDays(today, -5));
      final stats = p.seriesStats(p.taskById('walk')!);
      expect(stats.total, 10);
      expect(stats.completed, 3);
      expect(stats.skipped, 2);
    });

    test('seriesStats counts each day once across DST changes', () {
      final p = newProvider()
        ..addTask(dailyTask(id: 'spring', from: d(2026, 3, 1)))
        ..addTask(dailyTask(id: 'fall', from: d(2026, 10, 25)));
      expect(
        p.seriesStats(p.taskById('spring')!, asOf: d(2026, 3, 15)).total,
        15,
      );
      expect(
        p.seriesStats(p.taskById('fall')!, asOf: d(2026, 11, 8)).total,
        15,
      );
    });

    test('completionStreak counts fully resolved days back from today', () {
      final p = newProvider()..addTask(dailyTask(from: addDays(today, -5)));
      p.completeTask('walk', today);
      p.completeTask('walk', addDays(today, -1));
      p.cancelTask('walk', addDays(today, -2));
      expect(p.completionStreak(), 3);
    });
  });
}
