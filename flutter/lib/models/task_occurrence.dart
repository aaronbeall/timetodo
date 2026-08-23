import 'package:flutter/material.dart';
import 'package:timetodo/time_utils.dart';

/// Per-day overrides and status for a [Task] series.
class TaskOccurrence {
  final String id;
  final String taskId;
  final DateTime date;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  /// When set, overrides the series all-day flag for this day only.
  final bool? isAllDay;
  final bool isCompleted;
  final bool isCanceled;
  final DateTime updatedAt;

  TaskOccurrence({
    required this.id,
    required this.taskId,
    required this.date,
    this.startTime,
    this.endTime,
    this.isAllDay,
    this.isCompleted = false,
    this.isCanceled = false,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  static String idFor(String taskId, DateTime date) =>
      '${taskId}_${dateKey(date)}';

  TaskOccurrence copyWith({
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool? isAllDay,
    bool? isCompleted,
    bool? isCanceled,
    bool clearTimes = false,
    bool inheritAllDay = false,
  }) {
    return TaskOccurrence(
      id: id,
      taskId: taskId,
      date: date,
      startTime: clearTimes ? null : (startTime ?? this.startTime),
      endTime: clearTimes ? null : (endTime ?? this.endTime),
      isAllDay: inheritAllDay ? null : (isAllDay ?? this.isAllDay),
      isCompleted: isCompleted ?? this.isCompleted,
      isCanceled: isCanceled ?? this.isCanceled,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskId': taskId,
      'date': dateOnly(date).toIso8601String(),
      'startTime': startTime == null
          ? null
          : '${startTime!.hour}:${startTime!.minute}',
      'endTime':
          endTime == null ? null : '${endTime!.hour}:${endTime!.minute}',
      'isAllDay': isAllDay,
      'isCompleted': isCompleted,
      'isCanceled': isCanceled,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TaskOccurrence.fromJson(Map<String, dynamic> json) {
    TimeOfDay? parseTime(String? timeStr) {
      if (timeStr == null) return null;
      final parts = timeStr.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    return TaskOccurrence(
      id: json['id'] as String,
      taskId: json['taskId'] as String,
      date: dateOnly(DateTime.parse(json['date'] as String)),
      startTime: parseTime(json['startTime'] as String?),
      endTime: parseTime(json['endTime'] as String?),
      isAllDay: json['isAllDay'] as bool?,
      isCompleted: json['isCompleted'] as bool? ?? false,
      isCanceled: json['isCanceled'] as bool? ?? false,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }
}
