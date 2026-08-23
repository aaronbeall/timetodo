import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:timetodo/models/task.dart';
import 'package:timetodo/providers/task_provider.dart';
import 'package:timetodo/widgets/task_editor.dart';
import 'package:timetodo/widgets/task_time_arc.dart';
import 'package:timetodo/widgets/change_toast.dart';
import 'package:timetodo/time_utils.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({
    super.key,
    this.focusTick = 0,
    this.isActive = true,
  });

  /// Bumped whenever the Tasks tab is selected so the list jumps to today.
  final int focusTick;
  final bool isActive;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _expandedTaskId;
  Task? _headingDraft;
  final _editorKey = GlobalKey<TaskEditorState>();

  @override
  void didUpdateWidget(TasksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusTick != oldWidget.focusTick) {
      _editorKey.currentState?.commit();
      _selectedDate = DateTime.now();
      _expandedTaskId = null;
      _headingDraft = null;
    }
  }

  void _previousDay() {
    _editorKey.currentState?.commit();
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
      _expandedTaskId = null;
      _headingDraft = null;
    });
  }

  void _nextDay() {
    _editorKey.currentState?.commit();
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
      _expandedTaskId = null;
      _headingDraft = null;
    });
  }

  void _toggleTask(String taskId) {
    _editorKey.currentState?.commit();
    setState(() {
      _expandedTaskId = _expandedTaskId == taskId ? null : taskId;
      _headingDraft = null;
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
                    final shown =
                        isExpanded && _headingDraft?.id == task.id
                            ? _headingDraft!
                            : task;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          // Collapsed view
                          ListTile(
                            leading: TaskTimeArc(task: shown),
                            title: _TaskRowTitle(task: shown),
                            subtitle: _TaskRowMeta(
                              timeLabel: _timeSummary(shown),
                              repeatLabel: shown.repeatType == RepeatType.none
                                  ? null
                                  : _getRepeatDescription(shown),
                            ),
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
                              key: _editorKey,
                              task: task,
                              viewActive: widget.isActive,
                              onCommit: (updatedTask, message) {
                                final undo =
                                    taskProvider.updateTask(updatedTask);
                                showChangeToast(
                                  context,
                                  message: message,
                                  onUndo: undo,
                                );
                              },
                              onDraftChanged: (preview) {
                                setState(() => _headingDraft = preview);
                              },
                              onDelete: () {
                                final undo =
                                    taskProvider.deleteTask(task.id);
                                showChangeToast(
                                  context,
                                  message: 'Deleted ${task.label}',
                                  onUndo: undo,
                                );
                                setState(() {
                                  _expandedTaskId = null;
                                  _headingDraft = null;
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

  String _timeSummary(Task task) {
    if (task.isAllDay) return 'All Day';
    if (task.startTime != null && task.endTime != null) {
      return '${task.startTime!.format(context)} – ${task.endTime!.format(context)}';
    }
    if (task.startTime != null) {
      return 'Starts at ${task.startTime!.format(context)}';
    }
    return '';
  }

  String _getRepeatDescription(Task task) {
    switch (task.repeatType) {
      case RepeatType.daily:
        return 'Every day';
      case RepeatType.weekly:
        return 'Weekly';
      case RepeatType.monthly:
        return 'Monthly';
      case RepeatType.weekdays:
        return 'Weekdays';
      case RepeatType.custom:
        final n = task.repeatInterval ?? 1;
        return n == 1 ? 'Every day' : 'Every $n days';
      case RepeatType.none:
        return '';
    }
  }

  void _addNewTask(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
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

    final undo = taskProvider.addTask(newTask);
    showChangeToast(
      context,
      message: 'Added ${newTask.label}',
      onUndo: undo,
    );
    setState(() {
      _expandedTaskId = newTask.id;
    });
  }
}

class _TaskRowTitle extends StatelessWidget {
  final Task task;

  const _TaskRowTitle({required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = task.isCompleted;
    final ink = taskInkColor(task.color, theme.brightness);
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w500,
      decoration: completed ? TextDecoration.lineThrough : null,
      decorationColor: ink.withOpacity(0.45),
      color: ink.withOpacity(completed ? 0.55 : 1),
    );

    return Row(
      children: [
        if (completed) ...[
          Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: task.color,
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            task.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
        ),
      ],
    );
  }
}

class _TaskRowMeta extends StatelessWidget {
  final String timeLabel;
  final String? repeatLabel;

  const _TaskRowMeta({
    required this.timeLabel,
    this.repeatLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (timeLabel.isNotEmpty)
          Flexible(
            child: Text(
              timeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (repeatLabel != null) ...[
          if (timeLabel.isNotEmpty) const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              repeatLabel!,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.1,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

