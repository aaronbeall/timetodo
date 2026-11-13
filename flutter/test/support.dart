import 'package:flutter/material.dart';
import 'package:timetodo/data/task_store.dart';
import 'package:timetodo/models/task.dart';
import 'package:timetodo/models/task_occurrence.dart';
import 'package:timetodo/providers/task_provider.dart';

// Several tests cover DST changes (US dates: 2026-03-08 and 2026-11-01).
// They only catch regressions in a DST time zone, so also run:
//   TZ=America/New_York flutter test

/// Keeps the provider's data in memory so tests never touch disk.
class MemoryTaskStore implements TaskStore {
  TaskSnapshot saved = const TaskSnapshot(tasks: [], occurrences: []);

  @override
  Future<TaskSnapshot> load() async => saved;

  @override
  Future<void> save(TaskSnapshot data) async => saved = data;
}

TaskProvider newProvider() => TaskProvider(MemoryTaskStore());

TimeOfDay t(int hour, [int minute = 0]) =>
    TimeOfDay(hour: hour, minute: minute);

DateTime d(int year, int month, int day) => DateTime(year, month, day);

Task dailyTask({
  String id = 'walk',
  required DateTime from,
  TimeOfDay? start,
  TimeOfDay? end,
  RepeatType repeat = RepeatType.daily,
  int? interval,
  List<int>? weekdays,
  bool allDay = false,
}) {
  return Task(
    id: id,
    label: id,
    color: Colors.blue,
    startDate: from,
    startTime: start ?? t(9),
    endTime: end ?? t(10),
    isAllDay: allDay,
    repeatType: repeat,
    repeatInterval: interval,
    repeatWeekdays: weekdays,
  );
}

TaskOccurrence occurrence(String taskId, DateTime day) => TaskOccurrence(
      id: TaskOccurrence.idFor(taskId, day),
      taskId: taskId,
      date: day,
    );
