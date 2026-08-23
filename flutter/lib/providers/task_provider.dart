import 'package:flutter/material.dart';
import 'package:timetodo/data/demo_schedule.dart';
import 'package:timetodo/data/task_store.dart';
import 'package:timetodo/models/reports_snapshot.dart';
import 'package:timetodo/models/scheduled_task.dart';
import 'package:timetodo/models/task.dart';
import 'package:timetodo/models/task_occurrence.dart';
import 'package:timetodo/time_utils.dart';

class TaskProvider extends ChangeNotifier {
  TaskProvider(this._store);

  final TaskStore _store;
  final List<Task> _tasks = [];
  final List<TaskOccurrence> _occurrences = [];
  bool loaded = false;

  List<Task> get tasks => List.unmodifiable(_tasks);
  List<Task> get activeTasks =>
      _tasks.where((t) => t.isOpen()).toList(growable: false);
  List<Task> get archivedTasks =>
      _tasks.where((t) => t.isArchived).toList(growable: false);

  Future<void> load() async {
    final snapshot = await _store.load();
    _tasks
      ..clear()
      ..addAll(snapshot.tasks);
    _occurrences
      ..clear()
      ..addAll(snapshot.occurrences);
    loaded = true;
    notifyListeners();
  }

  Future<void> _persist() => _store.save(
        TaskSnapshot(tasks: List.of(_tasks), occurrences: List.of(_occurrences)),
      );

  TaskSnapshot _capture() => TaskSnapshot(
        tasks: List.of(_tasks),
        occurrences: List.of(_occurrences),
      ).copy();

  void _restore(TaskSnapshot snapshot) {
    _tasks
      ..clear()
      ..addAll(snapshot.tasks);
    _occurrences
      ..clear()
      ..addAll(snapshot.occurrences);
    notifyListeners();
    _persist();
  }

  VoidCallback _undoable(VoidCallback apply) {
    final previous = _capture();
    apply();
    notifyListeners();
    _persist();
    return () => _restore(previous);
  }

  List<ScheduledTask> scheduledOn(DateTime date) {
    final day = dateOnly(date);
    return _tasks
        .where((task) => !task.isArchived && task.occursOn(day))
        .map(
          (task) => ScheduledTask(
            task: task,
            date: day,
            occurrence: _occurrence(task.id, day),
          ),
        )
        .toList();
  }

  List<ScheduledTask> getTasksForToday() => scheduledOn(DateTime.now());

  List<ScheduledTask> getTasksForDate(DateTime date) => scheduledOn(date);

  TaskOccurrence? _occurrence(String taskId, DateTime date) {
    final key = dateKey(date);
    for (final o in _occurrences) {
      if (o.taskId == taskId && dateKey(o.date) == key) return o;
    }
    return null;
  }

  Task? taskById(String id) {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i == -1) return null;
    return _tasks[i];
  }

  List<Task> matchArchived(String query) {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return [];
    return _tasks
        .where((t) => !t.isOpen() && t.label.toLowerCase().contains(q))
        .take(5)
        .toList();
  }

  VoidCallback addTask(Task task) {
    return _undoable(() {
      _tasks.add(task);
    });
  }

  VoidCallback? updateTask(Task updatedTask) {
    final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index == -1) return null;
    return _undoable(() {
      final old = _tasks[index];
      final today = dateOnly(DateTime.now());
      var next = updatedTask.copyWith();
      if (old.isOpen(asOf: today) && dateOnly(old.startDate).isBefore(today)) {
        _sealPastSeries(old, today);
        if (dateOnly(next.startDate).isBefore(today)) {
          next = next.copyWith(startDate: today);
        }
        _clearTimeOverridesOnOrAfter(old.id, today);
      }
      final i = _tasks.indexWhere((t) => t.id == next.id);
      if (i != -1) _tasks[i] = next;
    });
  }

  /// Leaves days before [today] on a sealed copy of [old] so later series
  /// edits do not rewrite history. Occurrences are only moved, never created.
  void _sealPastSeries(Task old, DateTime today) {
    final yesterday = today.subtract(const Duration(days: 1));
    final historicId = '${old.id}_until_${dateKey(yesterday)}';
    if (_tasks.any((t) => t.id == historicId)) return;
    _tasks.add(
      old.copyWith(
        id: historicId,
        endDate: yesterday,
      ),
    );
    for (var i = 0; i < _occurrences.length; i++) {
      final o = _occurrences[i];
      if (o.taskId != old.id) continue;
      if (!dateOnly(o.date).isBefore(today)) continue;
      _occurrences[i] = TaskOccurrence(
        id: TaskOccurrence.idFor(historicId, o.date),
        taskId: historicId,
        date: o.date,
        startTime: o.startTime,
        endTime: o.endTime,
        isAllDay: o.isAllDay,
        isCompleted: o.isCompleted,
        isCanceled: o.isCanceled,
        updatedAt: o.updatedAt,
      );
    }
  }

  void _clearTimeOverridesOnOrAfter(String taskId, DateTime from) {
    final start = dateOnly(from);
    for (var i = 0; i < _occurrences.length; i++) {
      final o = _occurrences[i];
      if (o.taskId != taskId) continue;
      if (dateOnly(o.date).isBefore(start)) continue;
      if (!_hasTimeOverride(o)) continue;
      _occurrences[i] = o.copyWith(clearTimes: true, inheritAllDay: true);
    }
  }

  VoidCallback? archiveTask(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return null;
    return _undoable(() {
      _tasks[index] = _tasks[index].copyWith(isArchived: true);
    });
  }

  VoidCallback? unarchiveTask(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return null;
    return _undoable(() {
      _tasks[index] = _tasks[index].copyWith(isArchived: false);
    });
  }

  /// Removes the series. Occurrence history (completions, skips) is kept.
  VoidCallback? permanentlyDeleteTask(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return null;
    return _undoable(() {
      _tasks.removeAt(index);
    });
  }

  VoidCallback restoreAsNew(Task archived, DateTime startDate) {
    final clone = archived.copyWith(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      label: archived.label,
      startTime: archived.startTime,
      endTime: archived.endTime,
      isAllDay: archived.isAllDay,
      color: archived.color,
      startDate: dateOnly(startDate),
      clearEndDate: true,
      repeatType: archived.repeatType,
      repeatInterval: archived.repeatInterval,
      repeatWeekdays: archived.repeatWeekdays,
      isArchived: false,
      createdAt: DateTime.now(),
    );
    return addTask(clone);
  }

  TaskOccurrence _baseOccurrence(String taskId, DateTime date) {
    final day = dateOnly(date);
    return _occurrence(taskId, day) ??
        TaskOccurrence(
          id: TaskOccurrence.idFor(taskId, day),
          taskId: taskId,
          date: day,
        );
  }

  void _upsertOccurrence(TaskOccurrence next) {
    final i = _occurrences.indexWhere((o) => o.id == next.id);
    if (i == -1) {
      _occurrences.add(next);
    } else {
      _occurrences[i] = next;
    }
  }

  bool _hasTimeOverride(TaskOccurrence? o) {
    if (o == null) return false;
    return o.isAllDay != null || o.startTime != null || o.endTime != null;
  }

  VoidCallback? _patchOccurrence(
    String taskId,
    DateTime day,
    TaskOccurrence Function(TaskOccurrence base) update,
  ) {
    final task = taskById(taskId);
    if (task == null || task.isArchived || !task.occursOn(day)) return null;
    final date = dateOnly(day);
    final base = _baseOccurrence(taskId, date);
    return _undoable(() {
      _upsertOccurrence(update(base));
    });
  }

  VoidCallback? snoozeTask(String taskId, DateTime day) {
    final task = taskById(taskId);
    if (task == null) return null;
    final scheduled = ScheduledTask(
      task: task,
      date: dateOnly(day),
      occurrence: _occurrence(taskId, day),
    );
    if (scheduled.startTime == null) return null;
    return _patchOccurrence(taskId, day, (base) {
      final start = scheduled.startTime!;
      return base.copyWith(
        startTime: addTimeMinutes(start, 15),
        endTime: scheduled.endTime != null
            ? addTimeMinutes(scheduled.endTime!, 15)
            : null,
        isCompleted: false,
        isCanceled: false,
      );
    });
  }

  VoidCallback? extendTask(String taskId, DateTime day) {
    final task = taskById(taskId);
    if (task == null) return null;
    final scheduled = ScheduledTask(
      task: task,
      date: dateOnly(day),
      occurrence: _occurrence(taskId, day),
    );
    if (scheduled.endTime == null) return null;
    return _patchOccurrence(
      taskId,
      day,
      (base) => base.copyWith(
        startTime: scheduled.startTime,
        endTime: addTimeMinutes(scheduled.endTime!, 15),
      ),
    );
  }

  VoidCallback? completeTask(String taskId, DateTime day) {
    return _patchOccurrence(
      taskId,
      day,
      (base) => base.copyWith(isCompleted: true, isCanceled: false),
    );
  }

  VoidCallback? cancelTask(String taskId, DateTime day) {
    return _patchOccurrence(
      taskId,
      day,
      (base) => base.copyWith(isCanceled: true, isCompleted: false),
    );
  }

  VoidCallback? clearOccurrenceStatus(String taskId, DateTime day) {
    return _patchOccurrence(
      taskId,
      day,
      (base) => base.copyWith(isCompleted: false, isCanceled: false),
    );
  }

  VoidCallback? setOccurrenceTimeframe(
    String taskId,
    DateTime day, {
    required bool isAllDay,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
  }) {
    return _patchOccurrence(taskId, day, (base) {
      if (isAllDay) {
        return base.copyWith(isAllDay: true, clearTimes: true);
      }
      return base.copyWith(
        isAllDay: false,
        startTime: startTime,
        endTime: endTime,
      );
    });
  }

  /// Writes this day's times onto the series from [day] forward. Days before
  /// [day] keep their existing times (frozen onto the occurrence if needed).
  VoidCallback? applyTimesToFollowing(String taskId, DateTime day) {
    final task = taskById(taskId);
    if (task == null) return null;
    final from = dateOnly(day);
    if (!task.occursOn(from)) return null;
    final scheduled = ScheduledTask(
      task: task,
      date: from,
      occurrence: _occurrence(taskId, from),
    );
    return _undoable(() {
      _pushTimesToFollowing(
        taskId: taskId,
        from: from,
        newAllDay: scheduled.isAllDay,
        newStart: scheduled.startTime,
        newEnd: scheduled.endTime,
      );
    });
  }

  /// One undoable write for instance-sheet edits (times, status, following).
  VoidCallback? commitOccurrenceEdits({
    required String taskId,
    required DateTime day,
    required bool writeTimes,
    required bool isAllDay,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    required bool writeStatus,
    required bool isCompleted,
    required bool isCanceled,
    required bool applyFollowing,
  }) {
    if (!writeTimes && !writeStatus && !applyFollowing) return null;
    final task = taskById(taskId);
    final date = dateOnly(day);
    if (task == null || task.isArchived || !task.occursOn(date)) return null;
    return _undoable(() {
      if (writeTimes || writeStatus) {
        var next = _baseOccurrence(taskId, date);
        if (writeTimes) {
          next = isAllDay
              ? next.copyWith(isAllDay: true, clearTimes: true)
              : next.copyWith(
                  isAllDay: false,
                  startTime: startTime,
                  endTime: endTime,
                );
        }
        if (writeStatus) {
          next = next.copyWith(
            isCompleted: isCompleted,
            isCanceled: isCanceled,
          );
        }
        _upsertOccurrence(next);
      }
      if (applyFollowing) {
        _pushTimesToFollowing(
          taskId: taskId,
          from: date,
          newAllDay: isAllDay,
          newStart: startTime,
          newEnd: endTime,
        );
      }
    });
  }

  void _pushTimesToFollowing({
    required String taskId,
    required DateTime from,
    required bool newAllDay,
    TimeOfDay? newStart,
    TimeOfDay? newEnd,
  }) {
    final task = taskById(taskId);
    if (task == null || !task.occursOn(from)) return;
    final oldAllDay = task.isAllDay;
    final oldStart = task.startTime;
    final oldEnd = task.endTime;

    var cursor = dateOnly(task.startDate);
    while (cursor.isBefore(from)) {
      if (task.occursOn(cursor) && !_hasTimeOverride(_occurrence(taskId, cursor))) {
        _upsertOccurrence(
          _baseOccurrence(taskId, cursor).copyWith(
            isAllDay: oldAllDay,
            startTime: oldAllDay ? null : oldStart,
            endTime: oldAllDay ? null : oldEnd,
            clearTimes: oldAllDay,
          ),
        );
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      _tasks[index] = task.copyWith(
        isAllDay: newAllDay,
        startTime: newAllDay ? null : newStart,
        endTime: newAllDay ? null : newEnd,
        clearTimes: newAllDay,
      );
    }

    for (var i = 0; i < _occurrences.length; i++) {
      final o = _occurrences[i];
      if (o.taskId != taskId) continue;
      if (dateOnly(o.date).isBefore(from)) continue;
      _occurrences[i] = o.copyWith(clearTimes: true, inheritAllDay: true);
    }
  }

  VoidCallback? doNowTask(String taskId, DateTime day, TimeOfDay now) {
    final task = taskById(taskId);
    if (task == null) return null;
    final scheduled = ScheduledTask(
      task: task,
      date: dateOnly(day),
      occurrence: _occurrence(taskId, day),
    );
    if (scheduled.startTime == null) return null;
    var duration = 30;
    if (scheduled.endTime != null) {
      duration = durationMinutes(scheduled.startTime!, scheduled.endTime!);
      if (duration <= 0) duration = 30;
    }
    return _patchOccurrence(
      taskId,
      day,
      (base) => base.copyWith(
        startTime: now,
        endTime: addTimeMinutes(now, duration),
        isCompleted: false,
        isCanceled: false,
      ),
    );
  }

  VoidCallback loadDemoSchedule(DemoScheduleKind kind) {
    return _undoable(() {
      _tasks
        ..clear()
        ..addAll(buildDemoSchedule(DateTime.now(), kind));
      _occurrences.clear();
    });
  }

  VoidCallback clearAllData() {
    return _undoable(() {
      _tasks.clear();
      _occurrences.clear();
    });
  }

  int completedCountOn(DateTime date) {
    final key = dateKey(date);
    return _occurrences
        .where((o) => dateKey(o.date) == key && o.isCompleted)
        .length;
  }

  int scheduledCountOn(DateTime date) => scheduledOn(date).length;

  /// Consecutive days ending today (or yesterday if today has no tasks yet)
  /// where every scheduled task was completed or skipped.
  int completionStreak({DateTime? asOf}) {
    var cursor = dateOnly(asOf ?? DateTime.now());
    var streak = 0;
    for (var i = 0; i < 400; i++) {
      final items = scheduledOn(cursor);
      if (items.isEmpty) {
        if (streak == 0 && i == 0) {
          cursor = cursor.subtract(const Duration(days: 1));
          continue;
        }
        if (streak == 0) {
          cursor = cursor.subtract(const Duration(days: 1));
          continue;
        }
        break;
      }
      final resolved =
          items.every((t) => t.isCompleted || t.isCanceled);
      if (!resolved) break;
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  ReportsSnapshot reportsSnapshot({DateTime? asOf}) {
    final today = dateOnly(asOf ?? DateTime.now());
    var completed = 0;
    var skipped = 0;
    var unresolved = 0;

    DateTime earliest = today;
    for (final task in _tasks) {
      if (task.isArchived) continue;
      final start = dateOnly(task.startDate);
      if (start.isBefore(earliest)) earliest = start;
    }
    if (today.difference(earliest).inDays > 730) {
      earliest = today.subtract(const Duration(days: 730));
    }

    for (var cursor = earliest;
        !cursor.isAfter(today);
        cursor = cursor.add(const Duration(days: 1))) {
      for (final item in scheduledOn(cursor)) {
        if (item.isCompleted) {
          completed++;
        } else if (item.isCanceled) {
          skipped++;
        } else {
          unresolved++;
        }
      }
    }

    final last7 = [
      for (var i = 6; i >= 0; i--)
        _dayReport(today.subtract(Duration(days: i))),
    ];
    final last14Rates = [
      for (var i = 13; i >= 0; i--)
        _dayCompletionRate(today.subtract(Duration(days: i))),
    ];

    final streaks = activeTasks
        .map((task) => TaskStreakRow(task: task, streak: _taskStreak(task, today)))
        .toList()
      ..sort((a, b) {
        final byStreak = b.streak.compareTo(a.streak);
        if (byStreak != 0) return byStreak;
        return a.task.label.toLowerCase().compareTo(b.task.label.toLowerCase());
      });

    return ReportsSnapshot(
      streak: completionStreak(asOf: today),
      completed: completed,
      skipped: skipped,
      unresolved: unresolved,
      last7: last7,
      last14Rates: last14Rates,
      taskStreaks: streaks,
    );
  }

  DayReport _dayReport(DateTime day) {
    return DayReport(
      day: dateOnly(day),
      slices: [
        for (final item in scheduledOn(day))
          DayTaskSlice(
            color: item.color,
            completed: item.isCompleted,
            skipped: item.isCanceled,
          ),
      ],
    );
  }

  double? _dayCompletionRate(DateTime day) {
    var completed = 0;
    var open = 0;
    for (final item in scheduledOn(day)) {
      if (item.isCanceled) continue;
      if (item.isCompleted) {
        completed++;
      } else {
        open++;
      }
    }
    final denom = completed + open;
    if (denom == 0) return null;
    return completed / denom;
  }

  String _rootSeriesId(String id) {
    final i = id.indexOf('_until_');
    return i == -1 ? id : id.substring(0, i);
  }

  Iterable<Task> _lineage(Task task) {
    final root = _rootSeriesId(task.id);
    final prefix = '${root}_until_';
    return _tasks.where((t) => t.id == root || t.id.startsWith(prefix));
  }

  /// In-memory walk of one series through [asOf] (default today), max 730 days.
  TaskSeriesStats seriesStats(Task task, {DateTime? asOf}) {
    final today = dateOnly(asOf ?? DateTime.now());
    var total = 0;
    var completed = 0;
    var skipped = 0;
    for (final series in _lineage(task)) {
      var cursor = dateOnly(series.startDate);
      var last = today;
      if (series.endDate != null) {
        final ended = dateOnly(series.endDate!);
        if (ended.isBefore(last)) last = ended;
      }
      if (last.isBefore(cursor)) continue;
      if (last.difference(cursor).inDays > 730) {
        cursor = last.subtract(const Duration(days: 730));
      }
      for (; !cursor.isAfter(last); cursor = cursor.add(const Duration(days: 1))) {
        if (!series.occursOn(cursor)) continue;
        total++;
        final o = _occurrence(series.id, cursor);
        if (o == null) continue;
        if (o.isCompleted) {
          completed++;
        } else if (o.isCanceled) {
          skipped++;
        }
      }
    }
    return TaskSeriesStats(
      total: total,
      completed: completed,
      skipped: skipped,
    );
  }

  ScheduledTask? _instanceOnLineage(Task live, DateTime day) {
    for (final series in _lineage(live)) {
      if (!series.occursOn(day)) continue;
      return ScheduledTask(
        task: series,
        date: dateOnly(day),
        occurrence: _occurrence(series.id, day),
      );
    }
    return null;
  }

  int _taskStreak(Task task, DateTime asOf) {
    var cursor = dateOnly(asOf);
    var streak = 0;
    for (var i = 0; i < 400; i++) {
      final item = _instanceOnLineage(task, cursor);
      if (item == null) {
        if (streak == 0 && i == 0) {
          cursor = cursor.subtract(const Duration(days: 1));
          continue;
        }
        if (streak == 0) {
          cursor = cursor.subtract(const Duration(days: 1));
          continue;
        }
        break;
      }
      if (!item.isCompleted && !item.isCanceled) break;
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}
