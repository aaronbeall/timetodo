import 'package:flutter/material.dart';
import 'package:timetodo/models/task.dart';

class DayTaskSlice {
  final Color color;
  final bool completed;
  final bool skipped;

  const DayTaskSlice({
    required this.color,
    required this.completed,
    required this.skipped,
  });

  bool get unresolved => !completed && !skipped;
}

class DayReport {
  final DateTime day;
  final List<DayTaskSlice> slices;

  const DayReport({required this.day, required this.slices});
}

class TaskStreakRow {
  final Task task;
  final int streak;

  const TaskStreakRow({required this.task, required this.streak});
}

class ReportsSnapshot {
  final int streak;
  final int completed;
  final int skipped;
  final int unresolved;
  final List<DayReport> last7;
  final List<double?> last14Rates;
  final List<TaskStreakRow> taskStreaks;

  const ReportsSnapshot({
    required this.streak,
    required this.completed,
    required this.skipped,
    required this.unresolved,
    required this.last7,
    required this.last14Rates,
    required this.taskStreaks,
  });

  /// Completions among non-skipped instances.
  double? get completionRate {
    final denom = completed + unresolved;
    if (denom == 0) return null;
    return completed / denom;
  }

  /// Skips among completed + skipped (expired/open excluded).
  double? get skipRate {
    final denom = completed + skipped;
    if (denom == 0) return null;
    return skipped / denom;
  }
}
