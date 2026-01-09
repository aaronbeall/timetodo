import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timetodo/models/task.dart';
import 'package:timetodo/providers/task_provider.dart';
import 'package:timetodo/widgets/polar_clock.dart';
import 'package:timetodo/widgets/task_list_item.dart';
import 'package:timetodo/widgets/add_task_dialog.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  TimeOfDay _currentTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _updateTime();
  }

  void _updateTime() {
    setState(() {
      _currentTime = TimeOfDay.now();
    });
    Future.delayed(const Duration(seconds: 1), _updateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        elevation: 0,
      ),
      body: Consumer<TaskProvider>(
        builder: (context, taskProvider, child) {
          final todayTasks = taskProvider.getTasksForToday();
          final activeTasks = todayTasks
              .where((t) => t.isActive(_currentTime) && !t.isAllDay)
              .toList();
          final upcomingTasks = todayTasks
              .where((t) => t.isUpcoming(_currentTime) && !t.isAllDay)
              .toList();
          final allDayTasks =
              todayTasks.where((t) => t.isAllDay && !t.isCompleted).toList();

          return Column(
            children: [
              // Polar Clock
              Expanded(
                flex: 2,
                child: Center(
                  child: PolarClock(
                    currentTime: _currentTime,
                    tasks: todayTasks,
                    size: MediaQuery.of(context).size.width * 0.8,
                  ),
                ),
              ),

              // Task List
              Expanded(
                flex: 3,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Active Tasks
                    if (activeTasks.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Active',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                      ...activeTasks.map((task) => TaskListItem(
                            task: task,
                            isActive: true,
                            onSnooze: () => taskProvider.snoozeTask(task.id),
                            onComplete: () =>
                                taskProvider.completeTask(task.id),
                          )),
                      const SizedBox(height: 16),
                    ],

                    // Upcoming Tasks
                    if (upcomingTasks.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Upcoming',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.6),
                              ),
                        ),
                      ),
                      ...upcomingTasks.map((task) => TaskListItem(
                            task: task,
                            isActive: false,
                            onDelete: () => taskProvider.deleteTask(task.id),
                          )),
                      const SizedBox(height: 16),
                    ],

                    // All-Day Tasks
                    if (allDayTasks.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'All Day',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.4),
                              ),
                        ),
                      ),
                      ...allDayTasks.map((task) => TaskListItem(
                            task: task,
                            isAllDay: true,
                          )),
                      const SizedBox(height: 16),
                    ],

                    // Add Task Button
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddTaskDialog(context, taskProvider),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Task'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, TaskProvider taskProvider) {
    showDialog(
      context: context,
      builder: (context) => AddTaskDialog(
        initialDate: DateTime.now(),
        initialStartTime: _currentTime,
      ),
    );
  }
}
