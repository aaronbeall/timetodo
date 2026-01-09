import 'package:flutter/material.dart';
import 'package:timetodo/models/task.dart';

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
    if (task.startTime != null) {
      final currentMinutes = task.startTime!.hour * 60 + task.startTime!.minute;
      final newMinutes = currentMinutes + 15;
      final newHours = newMinutes ~/ 60;
      final newMins = newMinutes % 60;

      final updatedTask = task.copyWith(
        startTime: TimeOfDay(hour: newHours % 24, minute: newMins),
        endTime: task.endTime != null
            ? TimeOfDay(
                hour: (task.endTime!.hour * 60 + task.endTime!.minute + 15) ~/
                        60 %
                    24,
                minute: (task.endTime!.minute + 15) % 60,
              )
            : null,
      );
      updateTask(updatedTask);
    }
  }

  void completeTask(String id) {
    final task = _tasks.firstWhere((t) => t.id == id);
    final updatedTask = task.copyWith(isCompleted: true);
    updateTask(updatedTask);
  }
}
