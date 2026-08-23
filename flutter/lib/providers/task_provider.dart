import 'package:flutter/material.dart';
import 'package:timetodo/data/demo_schedule.dart';
import 'package:timetodo/data/task_store.dart';
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
    return activeTasks
        .where((task) => task.occursOn(day))
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
      _tasks[index] = updatedTask.copyWith();
    });
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

  VoidCallback? _patchOccurrence(
    String taskId,
    DateTime day,
    TaskOccurrence Function(TaskOccurrence base) update,
  ) {
    final task = taskById(taskId);
    if (task == null || task.isArchived || !task.occursOn(day)) return null;
    final date = dateOnly(day);
    final existing = _occurrence(taskId, date);
    final base = existing ??
        TaskOccurrence(
          id: TaskOccurrence.idFor(taskId, date),
          taskId: taskId,
          date: date,
        );
    return _undoable(() {
      final next = update(base);
      final i = _occurrences.indexWhere((o) => o.id == next.id);
      if (i == -1) {
        _occurrences.add(next);
      } else {
        _occurrences[i] = next;
      }
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
}
