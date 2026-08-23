import 'package:flutter/material.dart';
import 'package:timetodo/data/demo_schedule.dart';
import 'package:timetodo/models/task.dart';

TimeOfDay _addMinutes(TimeOfDay time, int minutes) {
  final total = (time.hour * 60 + time.minute + minutes) % (24 * 60);
  final normalized = total < 0 ? total + 24 * 60 : total;
  return TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60);
}

class TaskProvider extends ChangeNotifier {
  final List<Task> _tasks = [];

  List<Task> get tasks => _tasks;

  List<Task> getTasksForDate(DateTime date) {
    return _tasks.where((task) => task.shouldShowOnDate(date)).toList();
  }

  List<Task> getTasksForToday() {
    final today = DateTime.now();
    return getTasksForDate(today);
  }

  VoidCallback addTask(Task task) {
    _tasks.add(task);
    notifyListeners();
    return () {
      _tasks.removeWhere((t) => t.id == task.id);
      notifyListeners();
    };
  }

  VoidCallback? updateTask(Task updatedTask) {
    final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index == -1) return null;
    final previous = _tasks[index].copyWith();
    _tasks[index] = updatedTask;
    notifyListeners();
    return () {
      final i = _tasks.indexWhere((t) => t.id == previous.id);
      if (i != -1) {
        _tasks[i] = previous;
        notifyListeners();
      }
    };
  }

  VoidCallback? deleteTask(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return null;
    final removed = _tasks.removeAt(index);
    notifyListeners();
    return () {
      _tasks.insert(index.clamp(0, _tasks.length), removed);
      notifyListeners();
    };
  }

  VoidCallback? snoozeTask(String id) {
    final task = _taskById(id);
    if (task == null || task.startTime == null) return null;
    return updateTask(
      task.copyWith(
        startTime: _addMinutes(task.startTime!, 15),
        endTime: task.endTime != null ? _addMinutes(task.endTime!, 15) : null,
      ),
    );
  }

  VoidCallback? extendTask(String id) {
    final task = _taskById(id);
    if (task == null || task.endTime == null) return null;
    return updateTask(task.copyWith(endTime: _addMinutes(task.endTime!, 15)));
  }

  VoidCallback? completeTask(String id) {
    final task = _taskById(id);
    if (task == null) return null;
    return updateTask(task.copyWith(isCompleted: true, isCanceled: false));
  }

  VoidCallback? cancelTask(String id) {
    final task = _taskById(id);
    if (task == null) return null;
    return updateTask(task.copyWith(isCanceled: true, isCompleted: false));
  }

  VoidCallback? doNowTask(String id, TimeOfDay now) {
    final task = _taskById(id);
    if (task == null || task.startTime == null) return null;
    final start = task.startTime!.hour * 60 + task.startTime!.minute;
    var duration = 30;
    if (task.endTime != null) {
      final end = task.endTime!.hour * 60 + task.endTime!.minute;
      duration = start <= end ? end - start : 24 * 60 - start + end;
      if (duration <= 0) duration = 30;
    }
    return updateTask(
      task.copyWith(
        startTime: now,
        endTime: _addMinutes(now, duration),
        isCompleted: false,
        isCanceled: false,
      ),
    );
  }

  VoidCallback loadDemoSchedule(DemoScheduleKind kind) {
    final previous = _tasks.map((t) => t.copyWith()).toList();
    _tasks
      ..clear()
      ..addAll(buildDemoSchedule(DateTime.now(), kind));
    notifyListeners();
    return () {
      _tasks
        ..clear()
        ..addAll(previous);
      notifyListeners();
    };
  }

  Task? _taskById(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return null;
    return _tasks[index];
  }
}
