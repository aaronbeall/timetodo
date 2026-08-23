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

  bool _appearsOn(Task task, DateTime date) {
    final day = dateOnly(date);
    return task.occursOn(day, pinned: _occurrence(task.id, day) != null);
  }

  List<ScheduledTask> scheduledOn(DateTime date) {
    final day = dateOnly(date);
    return _tasks
        .where((task) => _appearsOn(task, day))
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
      if (task.repeatType == RepeatType.none) {
        _pinDay(task.id, task.startDate);
      }
    });
  }

  void _pinDay(String taskId, DateTime day) {
    _upsertOccurrence(_baseOccurrence(taskId, dateOnly(day)));
  }

  List<TaskEra> _revisedEras(Task old, TaskEra incoming, DateTime today) {
    final eras = [...old.eras];
    final last = eras.last;
    final newFrom = incoming.from.isBefore(today) ? today : incoming.from;

    if (last.sameRuleAndTime(incoming)) {
      eras[eras.length - 1] = last.copyWith(
        from: last.from.isBefore(today) ? last.from : incoming.from,
        to: incoming.to,
        clearTo: incoming.to == null,
      );
      return eras;
    }

    if (!last.from.isBefore(newFrom)) {
      eras[eras.length - 1] = incoming.copyWith(
        from: last.from,
        to: incoming.to,
        clearTo: incoming.to == null,
      );
      return eras;
    }

    if (last.isOpen && last.repeatType != RepeatType.none) {
      final closed = newFrom.subtract(const Duration(days: 1));
      if (!closed.isBefore(last.from)) {
        eras[eras.length - 1] = last.copyWith(to: closed);
      }
    }
    eras.add(
      incoming.copyWith(
        from: newFrom,
        to: incoming.to,
        clearTo: incoming.to == null,
      ),
    );
    return eras;
  }

  VoidCallback? updateTask(Task updatedTask) {
    final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index == -1) return null;
    return _undoable(() {
      final old = _tasks[index];
      final today = dateOnly(DateTime.now());
      var next = old.copyWith(
        label: updatedTask.label,
        color: updatedTask.color,
      );
      final scheduleChanged =
          !old.currentEra.sameRuleAndTime(updatedTask.currentEra) ||
              old.currentEra.from != updatedTask.currentEra.from ||
              old.currentEra.to != updatedTask.currentEra.to;
      if (scheduleChanged) {
        next = next.copyWith(
          eras: _revisedEras(old, updatedTask.currentEra, today),
        );
        _clearTimeOverridesOnOrAfter(old.id, today);
      }
      _tasks[index] = next;
      if (next.repeatType == RepeatType.none) {
        _pinDay(next.id, next.startDate);
      }
    });
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
      final task = _tasks[index];
      if (!task.currentEra.isOpen) return;
      final eras = [...task.eras];
      eras[eras.length - 1] = eras.last.copyWith(to: dateOnly(DateTime.now()));
      _tasks[index] = task.copyWith(eras: eras);
    });
  }

  VoidCallback? unarchiveTask(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return null;
    return _undoable(() {
      final task = _tasks[index];
      final today = dateOnly(DateTime.now());
      final last = task.currentEra;
      if (last.isOpen) return;
      _tasks[index] = task.copyWith(
        eras: [
          ...task.eras,
          last.copyWith(from: today, clearTo: true),
        ],
      );
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

  /// Reopens [archived] as the same series with a new era from [draft].
  VoidCallback reopenTask(Task archived, Task draft) {
    return _undoable(() {
      final incoming = draft.currentEra.copyWith(
        from: dateOnly(draft.startDate),
        clearTo: true,
      );
      final index = _tasks.indexWhere((t) => t.id == archived.id);
      if (index == -1) {
        _tasks.add(
          archived.copyWith(
            label: draft.label,
            color: draft.color,
            eras: [...archived.eras, incoming],
          ),
        );
      } else {
        final old = _tasks[index];
        final eras = [...old.eras];
        if (eras.last.isOpen) {
          final closed = incoming.from.subtract(const Duration(days: 1));
          if (!closed.isBefore(eras.last.from)) {
            eras[eras.length - 1] = eras.last.copyWith(to: closed);
          }
        }
        _tasks[index] = old.copyWith(
          label: draft.label,
          color: draft.color,
          eras: [...eras, incoming],
        );
      }
      if (incoming.repeatType == RepeatType.none) {
        _pinDay(archived.id, incoming.from);
      }
    });
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
    if (task == null || !_appearsOn(task, day)) return null;
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
    if (!_appearsOn(task, from)) return null;
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
    if (task == null || !_appearsOn(task, date)) return null;
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
    if (task == null || !_appearsOn(task, from)) return;

    var cursor = dateOnly(task.firstFrom);
    while (cursor.isBefore(from)) {
      if (_appearsOn(task, cursor) &&
          !_hasTimeOverride(_occurrence(taskId, cursor))) {
        final era = task.eraCovering(cursor)!;
        _upsertOccurrence(
          _baseOccurrence(taskId, cursor).copyWith(
            isAllDay: era.isAllDay,
            startTime: era.isAllDay ? null : era.startTime,
            endTime: era.isAllDay ? null : era.endTime,
            clearTimes: era.isAllDay,
          ),
        );
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    final incoming = task.currentEra.copyWith(
      from: from,
      isAllDay: newAllDay,
      startTime: newAllDay ? null : newStart,
      endTime: newAllDay ? null : newEnd,
      clearTimes: newAllDay,
      clearTo: true,
    );
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      _tasks[index] = task.copyWith(eras: _revisedEras(task, incoming, from));
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
      for (final task in _tasks) {
        if (task.repeatType == RepeatType.none) {
          _pinDay(task.id, task.startDate);
        }
      }
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
      final start = dateOnly(task.firstFrom);
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

  /// In-memory walk of one series through [asOf] (default today), max 730 days.
  TaskSeriesStats seriesStats(Task task, {DateTime? asOf}) {
    final today = dateOnly(asOf ?? DateTime.now());
    var total = 0;
    var completed = 0;
    var skipped = 0;
    var cursor = dateOnly(task.firstFrom);
    var last = today;
    if (last.isBefore(cursor)) {
      return const TaskSeriesStats(total: 0, completed: 0, skipped: 0);
    }
    if (last.difference(cursor).inDays > 730) {
      cursor = last.subtract(const Duration(days: 730));
    }
    for (; !cursor.isAfter(last); cursor = cursor.add(const Duration(days: 1))) {
      if (!_appearsOn(task, cursor)) continue;
      total++;
      final o = _occurrence(task.id, cursor);
      if (o == null) continue;
      if (o.isCompleted) {
        completed++;
      } else if (o.isCanceled) {
        skipped++;
      }
    }
    return TaskSeriesStats(
      total: total,
      completed: completed,
      skipped: skipped,
    );
  }

  ScheduledTask? _instanceOnLineage(Task live, DateTime day) {
    if (!_appearsOn(live, day)) return null;
    return ScheduledTask(
      task: live,
      date: dateOnly(day),
      occurrence: _occurrence(live.id, day),
    );
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
