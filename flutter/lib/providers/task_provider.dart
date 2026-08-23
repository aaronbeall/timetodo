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

  void addTask(Task task) {
    _tasks.add(task);
    notifyListeners();
  }

  void updateTask(Task updatedTask) {
    final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index != -1) {
      _tasks[index] = updatedTask;
      notifyListeners();
    }
  }

  void deleteTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  void snoozeTask(String id) {
    final task = _tasks.firstWhere((t) => t.id == id);
    if (task.startTime == null) return;
    updateTask(
      task.copyWith(
        startTime: _addMinutes(task.startTime!, 15),
        endTime: task.endTime != null ? _addMinutes(task.endTime!, 15) : null,
      ),
    );
  }

  void extendTask(String id) {
    final task = _tasks.firstWhere((t) => t.id == id);
    if (task.endTime == null) return;
    updateTask(task.copyWith(endTime: _addMinutes(task.endTime!, 15)));
  }

  void completeTask(String id) {
    final task = _tasks.firstWhere((t) => t.id == id);
    updateTask(task.copyWith(isCompleted: true, isCanceled: false));
  }

  void cancelTask(String id) {
    final task = _tasks.firstWhere((t) => t.id == id);
    updateTask(task.copyWith(isCanceled: true, isCompleted: false));
  }

  void doNowTask(String id, TimeOfDay now) {
    final task = _tasks.firstWhere((t) => t.id == id);
    if (task.startTime == null) return;
    final start = task.startTime!.hour * 60 + task.startTime!.minute;
    var duration = 30;
    if (task.endTime != null) {
      final end = task.endTime!.hour * 60 + task.endTime!.minute;
      duration = start <= end ? end - start : 24 * 60 - start + end;
      if (duration <= 0) duration = 30;
    }
    updateTask(
      task.copyWith(
        startTime: now,
        endTime: _addMinutes(now, duration),
        isCompleted: false,
        isCanceled: false,
      ),
    );
  }

  void loadDemoSchedule(DemoScheduleKind kind) {
    _tasks
      ..clear()
      ..addAll(buildDemoSchedule(DateTime.now(), kind));
    notifyListeners();
  }
}
