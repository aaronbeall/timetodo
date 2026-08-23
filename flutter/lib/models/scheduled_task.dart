import 'package:flutter/material.dart';
import 'package:timetodo/models/task.dart';
import 'package:timetodo/models/task_occurrence.dart';
import 'package:timetodo/time_utils.dart';

/// A task series as it appears on one calendar day.
class ScheduledTask {
  final Task task;
  final DateTime date;
  final TaskOccurrence? occurrence;

  const ScheduledTask({
    required this.task,
    required this.date,
    this.occurrence,
  });

  TaskEra get era => task.eraCovering(date) ?? task.currentEra;

  String get id => task.id;
  String get label => task.label;
  Color get color => task.color;
  bool get isAllDay => occurrence?.isAllDay ?? era.isAllDay;
  RepeatType get repeatType => era.repeatType;
  int? get repeatInterval => era.repeatInterval;
  List<int>? get repeatWeekdays => era.repeatWeekdays;

  TimeOfDay? get startTime => occurrence?.startTime ?? era.startTime;
  TimeOfDay? get endTime => occurrence?.endTime ?? era.endTime;
  bool get isCompleted => occurrence?.isCompleted ?? false;
  bool get isCanceled => occurrence?.isCanceled ?? false;

  bool isActive(TimeOfDay currentTime) {
    if (isAllDay || isCompleted || isCanceled) return false;
    if (startTime == null || endTime == null) return false;
    final current = minutesOf(currentTime);
    final start = minutesOf(startTime!);
    final end = minutesOf(endTime!);
    if (start <= end) {
      return current >= start && current < end;
    }
    return current >= start || current < end;
  }

  bool isUpcoming(TimeOfDay currentTime) {
    if (isAllDay || isCompleted || isCanceled) return false;
    if (startTime == null) return false;
    // Overnight ranges (e.g. 22:00–07:00) are also "before start" after
    // midnight; those slots are active, not upcoming.
    if (isActive(currentTime)) return false;
    return minutesOf(currentTime) < minutesOf(startTime!);
  }

  bool isMissed(TimeOfDay currentTime) {
    if (isAllDay || isCompleted || isCanceled) return false;
    if (startTime == null) return false;
    return !isActive(currentTime) && !isUpcoming(currentTime);
  }

  static const snoozeGraceMinutes = 15;

  int minutesSinceStart(TimeOfDay currentTime) {
    if (startTime == null) return 0;
    final current = minutesOf(currentTime);
    final start = minutesOf(startTime!);
    if (current >= start) return current - start;
    return 24 * 60 - start + current;
  }

  bool isInSnoozeGrace(TimeOfDay currentTime) {
    if (!isActive(currentTime)) return false;
    return minutesSinceStart(currentTime) < snoozeGraceMinutes;
  }

  double elapsedFraction(TimeOfDay currentTime) {
    if (startTime == null || endTime == null) return 0;
    final start = minutesOf(startTime!);
    final end = minutesOf(endTime!);
    final duration = start <= end ? end - start : 24 * 60 - start + end;
    if (duration <= 0) return 0;
    return (minutesSinceStart(currentTime) / duration).clamp(0.0, 1.0);
  }
}
