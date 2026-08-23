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

TimeOfDay? _timeFromJson(String? timeStr) {
  if (timeStr == null) return null;
  final parts = timeStr.split(':');
  return TimeOfDay(
    hour: int.parse(parts[0]),
    minute: int.parse(parts[1]),
  );
}

String? _timeToJson(TimeOfDay? time) =>
    time == null ? null : '${time.hour}:${time.minute}';

bool _weekdaysEqual(List<int>? a, List<int>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  final sa = [...a]..sort();
  final sb = [...b]..sort();
  for (var i = 0; i < sa.length; i++) {
    if (sa[i] != sb[i]) return false;
  }
  return true;
}

/// One open/close stretch of a [Task] schedule (repeat + default times).
class TaskEra {
  final DateTime from;
  final DateTime? to;
  final RepeatType repeatType;
  final int? repeatInterval;
  final List<int>? repeatWeekdays;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final bool isAllDay;

  TaskEra({
    required DateTime from,
    DateTime? to,
    this.repeatType = RepeatType.none,
    this.repeatInterval,
    this.repeatWeekdays,
    this.startTime,
    this.endTime,
    this.isAllDay = false,
  })  : from = dateOnly(from),
        to = to == null ? null : dateOnly(to);

  bool get isOpen => to == null;

  bool covers(DateTime date) {
    final day = dateOnly(date);
    if (day.isBefore(from)) return false;
    if (to != null && day.isAfter(to!)) return false;
    return true;
  }

  /// Whether a repeating era generates [date]. Always false for [RepeatType.none].
  bool generatesOn(DateTime date) {
    if (!covers(date)) return false;
    if (repeatType == RepeatType.none) return false;
    final day = dateOnly(date);
    final daysDiff = day.difference(from).inDays;
    switch (repeatType) {
      case RepeatType.none:
        return false;
      case RepeatType.daily:
        return true;
      case RepeatType.weekly:
        final days = repeatWeekdays;
        if (days == null || days.isEmpty) {
          return day.weekday == from.weekday;
        }
        return days.contains(day.weekday);
      case RepeatType.monthly:
        return day.day == from.day;
      case RepeatType.custom:
        final interval = repeatInterval ?? 1;
        if (interval < 1) return false;
        return daysDiff % interval == 0;
    }
  }

  bool sameRuleAndTime(TaskEra other) {
    return repeatType == other.repeatType &&
        repeatInterval == other.repeatInterval &&
        _weekdaysEqual(repeatWeekdays, other.repeatWeekdays) &&
        isAllDay == other.isAllDay &&
        startTime == other.startTime &&
        endTime == other.endTime;
  }

  bool scheduleEquals(TaskEra other) {
    return sameRuleAndTime(other) && from == other.from && to == other.to;
  }

  TaskEra copyWith({
    DateTime? from,
    DateTime? to,
    bool clearTo = false,
    RepeatType? repeatType,
    int? repeatInterval,
    List<int>? repeatWeekdays,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool? isAllDay,
    bool clearTimes = false,
  }) {
    return TaskEra(
      from: from ?? this.from,
      to: clearTo ? null : (to ?? this.to),
      repeatType: repeatType ?? this.repeatType,
      repeatInterval: repeatInterval ?? this.repeatInterval,
      repeatWeekdays: repeatWeekdays ?? this.repeatWeekdays,
      startTime: clearTimes ? null : (startTime ?? this.startTime),
      endTime: clearTimes ? null : (endTime ?? this.endTime),
      isAllDay: isAllDay ?? this.isAllDay,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from': from.toIso8601String(),
      'to': to?.toIso8601String(),
      'repeatType': repeatType.name,
      'repeatInterval': repeatInterval,
      'repeatWeekdays': repeatWeekdays,
      'startTime': _timeToJson(startTime),
      'endTime': _timeToJson(endTime),
      'isAllDay': isAllDay,
    };
  }

  factory TaskEra.fromJson(Map<String, dynamic> json) {
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
    return TaskEra(
      from: dateOnly(DateTime.parse(json['from'] as String)),
      to: json['to'] != null
          ? dateOnly(DateTime.parse(json['to'] as String))
          : null,
      repeatType: repeatType,
      repeatInterval: json['repeatInterval'] as int?,
      repeatWeekdays: weekdays,
      startTime: _timeFromJson(json['startTime'] as String?),
      endTime: _timeFromJson(json['endTime'] as String?),
      isAllDay: json['isAllDay'] as bool? ?? false,
    );
  }
}

/// Series identity. Schedule-over-time lives on [eras]; per-day status on
/// [TaskOccurrence].
class Task {
  final String id;
  final String label;
  final Color color;
  final List<TaskEra> eras;
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    required this.id,
    required this.label,
    required this.color,
    List<TaskEra>? eras,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool isAllDay = false,
    DateTime? startDate,
    DateTime? endDate,
    RepeatType repeatType = RepeatType.none,
    int? repeatInterval,
    List<int>? repeatWeekdays,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : eras = List.unmodifiable(
          eras ??
              [
                TaskEra(
                  from: dateOnly(startDate ?? DateTime.now()),
                  to: endDate == null ? null : dateOnly(endDate),
                  repeatType: repeatType,
                  repeatInterval: repeatInterval,
                  repeatWeekdays: repeatWeekdays,
                  startTime: isAllDay ? null : startTime,
                  endTime: isAllDay ? null : endTime,
                  isAllDay: isAllDay,
                ),
              ],
        ),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  TaskEra get currentEra => eras.last;

  DateTime get startDate => currentEra.from;
  DateTime? get endDate => currentEra.to;
  RepeatType get repeatType => currentEra.repeatType;
  int? get repeatInterval => currentEra.repeatInterval;
  List<int>? get repeatWeekdays => currentEra.repeatWeekdays;
  TimeOfDay? get startTime => currentEra.startTime;
  TimeOfDay? get endTime => currentEra.endTime;
  bool get isAllDay => currentEra.isAllDay;

  DateTime get firstFrom => eras.first.from;

  /// Last era is still open.
  bool get isArchived => !isOpen();

  TaskEra? eraCovering(DateTime date) {
    final day = dateOnly(date);
    TaskEra? best;
    for (final era in eras) {
      if (!era.covers(day)) continue;
      if (best == null || era.from.isAfter(best.from)) best = era;
    }
    return best;
  }

  /// Repeating days from the covering era, or a non-repeating pin when [pinned].
  bool occursOn(DateTime date, {bool pinned = false}) {
    final era = eraCovering(date);
    if (era == null) return false;
    if (era.repeatType == RepeatType.none) return pinned;
    return era.generatesOn(date);
  }

  Task copyWith({
    String? id,
    String? label,
    Color? color,
    List<TaskEra>? eras,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool? isAllDay,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    bool clearTimes = false,
    RepeatType? repeatType,
    int? repeatInterval,
    List<int>? repeatWeekdays,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    var nextEras = eras ?? this.eras;
    final scheduleTouched = startTime != null ||
        endTime != null ||
        isAllDay != null ||
        startDate != null ||
        endDate != null ||
        clearEndDate ||
        clearTimes ||
        repeatType != null ||
        repeatInterval != null ||
        repeatWeekdays != null;
    if (eras == null && scheduleTouched) {
      final cur = currentEra;
      nextEras = [
        ...this.eras.sublist(0, this.eras.length - 1),
        cur.copyWith(
          from: startDate,
          to: endDate,
          clearTo: clearEndDate,
          repeatType: repeatType,
          repeatInterval: repeatInterval,
          repeatWeekdays: repeatWeekdays,
          startTime: startTime,
          endTime: endTime,
          isAllDay: isAllDay,
          clearTimes: clearTimes,
        ),
      ];
    }
    return Task(
      id: id ?? this.id,
      label: label ?? this.label,
      color: color ?? this.color,
      eras: nextEras,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'color': color.value,
      'eras': eras.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    final rawEras = json['eras'] as List?;
    if (rawEras == null || rawEras.isEmpty) {
      throw const FormatException('Task.eras required');
    }
    return Task(
      id: json['id'] as String,
      label: json['label'] as String,
      color: Color(json['color'] as int),
      eras: [
        for (final e in rawEras)
          TaskEra.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
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

  /// Still running: last era has no close date.
  bool isOpen({DateTime? asOf}) {
    if (!currentEra.isOpen) return false;
    if (asOf == null) return true;
    return !dateOnly(asOf).isBefore(currentEra.from);
  }
}
