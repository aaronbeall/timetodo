import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timetodo/time_utils.dart';

enum RepeatType {
  none,
  daily,
  weekly,
  monthly,
  custom,
}

/// Series definition. Per-day status lives on [TaskOccurrence].
class Task {
  final String id;
  final String label;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final bool isAllDay;
  final Color color;
  final DateTime startDate;
  final DateTime? endDate;
  final RepeatType repeatType;
  final int? repeatInterval;
  final List<int>? repeatWeekdays;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    required this.id,
    required this.label,
    this.startTime,
    this.endTime,
    this.isAllDay = false,
    required this.color,
    required this.startDate,
    this.endDate,
    this.repeatType = RepeatType.none,
    this.repeatInterval,
    this.repeatWeekdays,
    this.isArchived = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Task copyWith({
    String? id,
    String? label,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool? isAllDay,
    Color? color,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    RepeatType? repeatType,
    int? repeatInterval,
    List<int>? repeatWeekdays,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      label: label ?? this.label,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      color: color ?? this.color,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      repeatType: repeatType ?? this.repeatType,
      repeatInterval: repeatInterval ?? this.repeatInterval,
      repeatWeekdays: repeatWeekdays ?? this.repeatWeekdays,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'startTime': startTime == null
          ? null
          : '${startTime!.hour}:${startTime!.minute}',
      'endTime':
          endTime == null ? null : '${endTime!.hour}:${endTime!.minute}',
      'isAllDay': isAllDay,
      'color': color.value,
      'startDate': dateOnly(startDate).toIso8601String(),
      'endDate': endDate == null ? null : dateOnly(endDate!).toIso8601String(),
      'repeatType': repeatType.name,
      'repeatInterval': repeatInterval,
      'repeatWeekdays': repeatWeekdays,
      'isArchived': isArchived,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
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

    final rawStart = json['startDate'] ?? json['date'];
    final rawRepeat = json['repeatType'] as String?;
    final weekdaysLegacy = rawRepeat == 'weekdays';
    final repeatType = weekdaysLegacy
        ? RepeatType.weekly
        : RepeatType.values.firstWhere(
            (e) => e.name == rawRepeat,
            orElse: () => RepeatType.none,
          );
    List<int>? weekdays;
    if (weekdaysLegacy) {
      weekdays = [
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
      ];
    } else if (json['repeatWeekdays'] != null) {
      weekdays = List<int>.from(json['repeatWeekdays'] as List);
    }
    return Task(
      id: json['id'] as String,
      label: json['label'] as String,
      startTime: parseTime(json['startTime'] as String?),
      endTime: parseTime(json['endTime'] as String?),
      isAllDay: json['isAllDay'] as bool? ?? false,
      color: Color(json['color'] as int),
      startDate: dateOnly(DateTime.parse(rawStart as String)),
      endDate: json['endDate'] != null
          ? dateOnly(DateTime.parse(json['endDate'] as String))
          : null,
      repeatType: repeatType,
      repeatInterval: json['repeatInterval'] as int?,
      repeatWeekdays: weekdays,
      isArchived: json['isArchived'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  bool occursOn(DateTime date) {
    if (isArchived) return false;
    final day = dateOnly(date);
    final start = dateOnly(startDate);
    if (day.isBefore(start)) return false;
    if (endDate != null && day.isAfter(dateOnly(endDate!))) return false;
    if (repeatType == RepeatType.none) return isSameDay(day, start);

    final daysDiff = day.difference(start).inDays;
    switch (repeatType) {
      case RepeatType.none:
        return false;
      case RepeatType.daily:
        return true;
      case RepeatType.weekly:
        final days = repeatWeekdays;
        if (days == null || days.isEmpty) {
          return day.weekday == start.weekday;
        }
        return days.contains(day.weekday);
      case RepeatType.monthly:
        return day.day == start.day;
      case RepeatType.custom:
        final interval = repeatInterval ?? 1;
        if (interval < 1) return false;
        return daysDiff % interval == 0;
    }
  }

  static const mondayToFriday = {
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  };

  static const saturdaySunday = {
    DateTime.saturday,
    DateTime.sunday,
  };

  static String weeklyRepeatLabel(List<int>? weekdays, DateTime startDate) {
    final days = (weekdays == null || weekdays.isEmpty)
        ? {startDate.weekday}
        : weekdays.toSet();
    if (days.length == mondayToFriday.length &&
        days.containsAll(mondayToFriday)) {
      return 'Weekdays';
    }
    if (days.length == saturdaySunday.length &&
        days.containsAll(saturdaySunday)) {
      return 'Weekends';
    }
    final names = (days.toList()..sort())
        .map(_weekdayShortName)
        .join(', ');
    return 'Every $names';
  }

  /// 2024-01-01 is a Monday; DateTime.weekday is 1=Monday … 7=Sunday.
  static String _weekdayShortName(int weekday) {
    final date = DateTime(2024, 1, 1).add(Duration(days: weekday - 1));
    return DateFormat.E().format(date);
  }

  /// Still running as of [asOf] (defaults to today): not archived and not ended.
  bool isOpen({DateTime? asOf}) {
    if (isArchived) return false;
    final day = dateOnly(asOf ?? DateTime.now());
    if (endDate != null && day.isAfter(dateOnly(endDate!))) return false;
    return true;
  }
}
