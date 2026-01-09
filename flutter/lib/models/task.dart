import 'package:flutter/material.dart';

enum RepeatType {
  none,
  daily,
  weekly,
  monthly,
  weekdays,
  custom,
}

class Task {
  final String id;
  String label;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  bool isAllDay;
  Color color;
  DateTime date;
  RepeatType repeatType;
  int? repeatInterval; // For custom repeats (every N days/weeks)
  List<int>? repeatWeekdays; // 0 = Sunday, 6 = Saturday
  bool isSnoozed;
  bool isCompleted;
  DateTime? snoozedUntil;

  Task({
    required this.id,
    required this.label,
    this.startTime,
    this.endTime,
    this.isAllDay = false,
    required this.color,
    required this.date,
    this.repeatType = RepeatType.none,
    this.repeatInterval,
    this.repeatWeekdays,
    this.isSnoozed = false,
    this.snoozedUntil,
    this.isCompleted = false,
  });

  Task copyWith({
    String? id,
    String? label,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool? isAllDay,
    Color? color,
    DateTime? date,
    RepeatType? repeatType,
    int? repeatInterval,
    List<int>? repeatWeekdays,
    bool? isSnoozed,
    bool? isCompleted,
    DateTime? snoozedUntil,
  }) {
    return Task(
      id: id ?? this.id,
      label: label ?? this.label,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      color: color ?? this.color,
      date: date ?? this.date,
      repeatType: repeatType ?? this.repeatType,
      repeatInterval: repeatInterval ?? this.repeatInterval,
      repeatWeekdays: repeatWeekdays ?? this.repeatWeekdays,
      isSnoozed: isSnoozed ?? this.isSnoozed,
      isCompleted: isCompleted ?? this.isCompleted,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'startTime': startTime != null
          ? '${startTime!.hour}:${startTime!.minute}'
          : null,
      'endTime':
          endTime != null ? '${endTime!.hour}:${endTime!.minute}' : null,
      'isAllDay': isAllDay,
      'color': color.value,
      'date': date.toIso8601String(),
      'repeatType': repeatType.name,
      'repeatInterval': repeatInterval,
      'repeatWeekdays': repeatWeekdays,
      'isSnoozed': isSnoozed,
      'isCompleted': isCompleted,
      'snoozedUntil': snoozedUntil?.toIso8601String(),
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    TimeOfDay? parseTime(String? timeStr) {
      if (timeStr == null) return null;
      final parts = timeStr.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    return Task(
      id: json['id'],
      label: json['label'],
      startTime: parseTime(json['startTime']),
      endTime: parseTime(json['endTime']),
      isAllDay: json['isAllDay'] ?? false,
      color: Color(json['color']),
      date: DateTime.parse(json['date']),
      repeatType: RepeatType.values.firstWhere(
        (e) => e.name == json['repeatType'],
        orElse: () => RepeatType.none,
      ),
      repeatInterval: json['repeatInterval'],
      repeatWeekdays: json['repeatWeekdays'] != null
          ? List<int>.from(json['repeatWeekdays'])
          : null,
      isSnoozed: json['isSnoozed'] ?? false,
      isCompleted: json['isCompleted'] ?? false,
      snoozedUntil: json['snoozedUntil'] != null
          ? DateTime.parse(json['snoozedUntil'])
          : null,
    );
  }

  bool isActive(TimeOfDay currentTime) {
    if (isAllDay || isCompleted || isSnoozed) return false;
    if (startTime == null || endTime == null) return false;

    final current = currentTime.hour * 60 + currentTime.minute;
    final start = startTime!.hour * 60 + startTime!.minute;
    final end = endTime!.hour * 60 + endTime!.minute;

    if (start <= end) {
      return current >= start && current < end;
    } else {
      // Task spans midnight
      return current >= start || current < end;
    }
  }

  bool isUpcoming(TimeOfDay currentTime) {
    if (isAllDay || isCompleted || isSnoozed) return false;
    if (startTime == null) return false;

    final current = currentTime.hour * 60 + currentTime.minute;
    final start = startTime!.hour * 60 + startTime!.minute;

    return current < start;
  }

  bool shouldShowOnDate(DateTime date) {
    if (this.date.year == date.year &&
        this.date.month == date.month &&
        this.date.day == date.day) {
      return true;
    }

    if (repeatType == RepeatType.none) return false;

    // Check if task should repeat on this date
    switch (repeatType) {
      case RepeatType.daily:
        return true;
      case RepeatType.weekly:
        return date.weekday == this.date.weekday;
      case RepeatType.monthly:
        return date.day == this.date.day;
      case RepeatType.weekdays:
        return date.weekday >= 1 && date.weekday <= 5;
      case RepeatType.custom:
        if (repeatInterval != null && repeatWeekdays != null) {
          final daysDiff = date.difference(this.date).inDays;
          if (daysDiff >= 0 && daysDiff % repeatInterval! == 0) {
            return repeatWeekdays!.contains(date.weekday % 7);
          }
        }
        return false;
      default:
        return false;
    }
  }
}
