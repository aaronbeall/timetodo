import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:timetodo/models/task.dart';
import 'package:timetodo/providers/task_provider.dart';
import 'package:timetodo/widgets/task_editor.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _expandedTaskId;

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
      _expandedTaskId = null;
    });
  }

  void _nextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
      _expandedTaskId = null;
    });
  }

  void _toggleTask(String taskId) {
    setState(() {
      _expandedTaskId = _expandedTaskId == taskId ? null : taskId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Date Navigation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _previousDay,
                ),
                Text(
                  DateFormat('EEEE, MMMM d, y').format(_selectedDate),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextDay,
                ),
              ],
            ),
          ),

          // Task List
          Expanded(
            child: Consumer<TaskProvider>(
              builder: (context, taskProvider, child) {
                final tasks = taskProvider.getTasksForDate(_selectedDate);
                tasks.sort((a, b) {
                  if (a.isAllDay && !b.isAllDay) return 1;
                  if (!a.isAllDay && b.isAllDay) return -1;
                  if (a.startTime == null) return 1;
                  if (b.startTime == null) return -1;
                  final aMinutes = a.startTime!.hour * 60 + a.startTime!.minute;
                  final bMinutes = b.startTime!.hour * 60 + b.startTime!.minute;
                  return aMinutes.compareTo(bMinutes);
                });

                if (tasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.task_outlined,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No tasks for this day',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.5),
                              ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final isExpanded = _expandedTaskId == task.id;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          // Collapsed view
                          ListTile(
                            leading: Container(
                              width: 4,
                              height: 40,
                              decoration: BoxDecoration(
                                color: task.color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            title: Text(
                              task.label,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(_getTaskSummary(task)),
                            trailing: IconButton(
                              icon: Icon(
                                isExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                              onPressed: () => _toggleTask(task.id),
                            ),
                            onTap: () => _toggleTask(task.id),
                          ),

                          // Expanded view
                          if (isExpanded)
                            TaskEditor(
                              task: task,
                              onSave: (updatedTask) {
                                taskProvider.updateTask(updatedTask);
                                setState(() {
                                  _expandedTaskId = null;
                                });
                              },
                              onDelete: () {
                                taskProvider.deleteTask(task.id);
                                setState(() {
                                  _expandedTaskId = null;
                                });
                              },
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addNewTask(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _getTaskSummary(Task task) {
    final parts = <String>[];

    if (task.isAllDay) {
      parts.add('All Day');
    } else if (task.startTime != null && task.endTime != null) {
      parts.add(
          '${task.startTime!.format(context)} - ${task.endTime!.format(context)}');
    } else if (task.startTime != null) {
      parts.add('Starts at ${task.startTime!.format(context)}');
    }

    if (task.repeatType != RepeatType.none) {
      parts.add(_getRepeatDescription(task));
    }

    return parts.join(' • ');
  }

  String _getRepeatDescription(Task task) {
    switch (task.repeatType) {
      case RepeatType.daily:
        return 'Daily';
      case RepeatType.weekly:
        return 'Weekly';
      case RepeatType.monthly:
        return 'Monthly';
      case RepeatType.weekdays:
        return 'Weekdays';
      case RepeatType.custom:
        if (task.repeatInterval != null && task.repeatWeekdays != null) {
          return 'Custom';
        }
        return 'Custom';
      default:
        return '';
    }
  }

  void _addNewTask(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final now = DateTime.now();
    final currentTime = TimeOfDay.now();

    final newTask = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: 'New Task',
      startTime: currentTime,
      endTime: TimeOfDay(
        hour: (currentTime.hour + 1) % 24,
        minute: currentTime.minute,
      ),
      color: Colors.blue,
      date: _selectedDate,
    );

    taskProvider.addTask(newTask);
    setState(() {
      _expandedTaskId = newTask.id;
    });
  }
}
