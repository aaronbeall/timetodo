import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:timetodo/models/scheduled_task.dart';
import 'package:timetodo/models/task.dart';
import 'package:timetodo/providers/task_provider.dart';
import 'package:timetodo/widgets/task_editor.dart';
import 'package:timetodo/widgets/task_time_arc.dart';
import 'package:timetodo/widgets/add_task_dialog.dart';
import 'package:timetodo/widgets/change_toast.dart';
import 'package:timetodo/time_utils.dart';

enum _TasksFilter { day, all, archived }

class TasksScreen extends StatefulWidget {
  const TasksScreen({
    super.key,
    this.focusTick = 0,
    this.isActive = true,
    this.revealTaskId,
    this.revealTick = 0,
  });

  /// Bumped whenever the Tasks tab is selected so the list jumps to today.
  final int focusTick;
  final bool isActive;
  final String? revealTaskId;
  final int revealTick;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _expandedTaskId;
  Task? _headingDraft;
  _TasksFilter _filter = _TasksFilter.day;
  final _editorKey = GlobalKey<TaskEditorState>();
  final _listController = ScrollController();
  final _rowKeys = <String, GlobalKey>{};

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TasksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusTick != oldWidget.focusTick) {
      _editorKey.currentState?.commit();
      setState(() {
        _selectedDate = DateTime.now();
        _expandedTaskId = null;
        _headingDraft = null;
      });
    }
    if (widget.revealTick != oldWidget.revealTick &&
        widget.revealTaskId != null) {
      _editorKey.currentState?.commit();
      setState(() {
        _selectedDate = DateTime.now();
        _expandedTaskId = widget.revealTaskId;
        _headingDraft = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToExpanded();
        });
      });
    }
  }

  void _scrollToExpanded() {
    final id = _expandedTaskId;
    if (id == null) return;
    final ctx = _rowKeys[id]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.12,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<_TasksFilter>(
              segments: const [
                ButtonSegment(
                  value: _TasksFilter.day,
                  label: Text('Day'),
                  icon: Icon(Icons.today_outlined),
                ),
                ButtonSegment(
                  value: _TasksFilter.all,
                  label: Text('All'),
                  icon: Icon(Icons.inbox_outlined),
                ),
                ButtonSegment(
                  value: _TasksFilter.archived,
                  label: Text('Archived'),
                  icon: Icon(Icons.inventory_2_outlined),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (value) {
                _editorKey.currentState?.commit();
                setState(() {
                  _filter = value.first;
                  _expandedTaskId = null;
                  _headingDraft = null;
                });
              },
            ),
          ),
          if (_filter == _TasksFilter.day)
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
                final List<Task> tasks;
                if (_filter == _TasksFilter.archived) {
                  tasks = [...taskProvider.archivedTasks]
                    ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
                } else if (_filter == _TasksFilter.all) {
                  tasks = [...taskProvider.activeTasks]
                    ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
                } else {
                  final scheduled = taskProvider.getTasksForDate(_selectedDate);
                  scheduled.sort((a, b) {
                  if (a.isAllDay && !b.isAllDay) return 1;
                  if (!a.isAllDay && b.isAllDay) return -1;
                  if (a.startTime == null) return 1;
                  if (b.startTime == null) return -1;
                  final aMinutes = a.startTime!.hour * 60 + a.startTime!.minute;
                  final bMinutes = b.startTime!.hour * 60 + b.startTime!.minute;
                  return aMinutes.compareTo(bMinutes);
                  });
                  tasks = scheduled.map((s) => s.task).toList();
                }

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
                          _filter == _TasksFilter.archived
                              ? 'No archived tasks'
                              : _filter == _TasksFilter.all
                              ? 'No tasks yet'
                              : 'No tasks for this day',
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
                  controller: _listController,
                  padding: const EdgeInsets.all(16),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final isExpanded = _expandedTaskId == task.id;
                    final shown =
                        isExpanded && _headingDraft?.id == task.id
                            ? _headingDraft!
                            : task;
                    final rowKey =
                        _rowKeys.putIfAbsent(task.id, GlobalKey.new);

                    return Card(
                      key: rowKey,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          // Collapsed view
                          ListTile(
                            leading: TaskTimeArc(
                              task: ScheduledTask(
                                task: shown,
                                date: _filter == _TasksFilter.day
                                    ? _selectedDate
                                    : shown.startDate,
                              ),
                            ),
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
                          if (isExpanded && task.isArchived)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      final undo = taskProvider
                                          .permanentlyDeleteTask(task.id);
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
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Delete'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                                  ),
                                  const Spacer(),
                                  FilledButton.tonalIcon(
                                    onPressed: () {
                                      final undo =
                                          taskProvider.unarchiveTask(task.id);
                                      showChangeToast(
                                        context,
                                        message: 'Restored ${task.label}',
                                        onUndo: undo,
                                      );
                                      setState(() {
                                        _expandedTaskId = null;
                                        _headingDraft = null;
                                      });
                                    },
                                    icon: const Icon(Icons.unarchive_outlined),
                                    label: const Text('Restore'),
                                  ),
                                ],
                              ),
                            )
                          else if (isExpanded)
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
                              onArchive: () {
                                final undo =
                                    taskProvider.archiveTask(task.id);
                                showChangeToast(
                                  context,
                                  message: 'Archived ${task.label}',
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
        return Task.weeklyRepeatLabel(task.repeatWeekdays, task.startDate);
      case RepeatType.monthly:
        return 'Monthly';
      case RepeatType.custom:
        final n = task.repeatInterval ?? 1;
        return n == 1 ? 'Every day' : 'Every $n days';
      case RepeatType.none:
        return '';
    }
  }

  Future<void> _addNewTask(BuildContext context) async {
    final created = await showDialog<Task>(
      context: context,
      builder: (context) => AddTaskDialog(
        initialDate: dateOnly(
          _filter == _TasksFilter.day ? _selectedDate : DateTime.now(),
        ),
        initialStartTime: TimeOfDay.now(),
      ),
    );
    if (!mounted || created == null) return;
    setState(() => _expandedTaskId = created.id);
  }
}

class _TaskRowTitle extends StatelessWidget {
  final Task task;

  const _TaskRowTitle({required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = taskInkColor(task.color, theme.brightness);
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w500,
      color: ink,
    );

    return Row(
      children: [
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

