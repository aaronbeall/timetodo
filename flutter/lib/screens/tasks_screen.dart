import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timetodo/models/scheduled_task.dart';
import 'package:timetodo/models/task.dart';
import 'package:timetodo/providers/task_provider.dart';
import 'package:timetodo/screens/settings_screen.dart';
import 'package:timetodo/widgets/task_editor.dart';
import 'package:timetodo/widgets/task_time_arc.dart';
import 'package:timetodo/widgets/add_task_dialog.dart';
import 'package:timetodo/widgets/change_toast.dart';
import 'package:timetodo/time_utils.dart';

enum _TasksFilter { active, archived }

class TasksScreen extends StatefulWidget {
  const TasksScreen({
    super.key,
    this.focusTick = 0,
    this.isActive = true,
    this.revealTaskId,
    this.revealTick = 0,
  });

  /// Bumped whenever the Tasks tab is selected so editors commit.
  final int focusTick;
  final bool isActive;
  final String? revealTaskId;
  final int revealTick;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String? _expandedTaskId;
  Task? _headingDraft;
  _TasksFilter _filter = _TasksFilter.active;
  final _repeatFilters = <String>{};
  final _editorKey = GlobalKey<TaskEditorState>();
  final _listController = ScrollController();
  final _expandedRowKey = GlobalKey();

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
        _expandedTaskId = null;
        _headingDraft = null;
      });
    }
    if (widget.revealTick != oldWidget.revealTick &&
        widget.revealTaskId != null) {
      _editorKey.currentState?.commit();
      setState(() {
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
    if (_expandedTaskId == null) return;
    final ctx = _expandedRowKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.12,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _toggleTask(String taskId) {
    _editorKey.currentState?.commit();
    setState(() {
      _expandedTaskId = _expandedTaskId == taskId ? null : taskId;
      _headingDraft = null;
    });
  }

  /// Mutate after this frame so hover/InkWell hit-tests don't run on a row
  /// that was removed during the same pointer-up.
  void _afterRowSettles(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _expandedTaskId = null;
        _headingDraft = null;
      });
      action();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => openSettings(context),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Consumer<TaskProvider>(
        builder: (context, taskProvider, child) {
          final List<Task> source;
          if (_filter == _TasksFilter.archived) {
            source = [...taskProvider.archivedTasks]..sort(_compareSavedTime);
          } else {
            source = [...taskProvider.activeTasks]..sort(_compareSavedTime);
          }
          final tags = _uniqueFilterTags(source);
          final activeTags =
              _repeatFilters.where(tags.contains).toSet();
          final tasks = activeTags.isEmpty
              ? source
              : source.where((task) => _matchesFilter(task, activeTags)).toList();

          return Column(
            children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<_TasksFilter>(
              segments: const [
                ButtonSegment(
                  value: _TasksFilter.active,
                  label: Text('Active'),
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
                  _repeatFilters.clear();
                });
              },
                  ),
                ),
                const SizedBox(width: 4),
                MenuAnchor(
                  alignmentOffset: const Offset(0, 8),
                  builder: (context, controller, _) {
                    return IconButton(
                      tooltip: 'Filter by schedule',
                      isSelected: activeTags.isNotEmpty,
                      onPressed: tags.isEmpty
                          ? null
                          : () {
                              if (controller.isOpen) {
                                controller.close();
                              } else {
                                controller.open();
                              }
                            },
                      icon: Badge(
                        isLabelVisible: activeTags.isNotEmpty,
                        smallSize: 8,
                        child: const Icon(Icons.filter_list),
                      ),
                    );
                  },
                  menuChildren: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tag in tags)
                              FilterChip(
                                label: Text(tag),
                                selected: _repeatFilters.contains(tag),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _repeatFilters.add(tag);
                                    } else {
                                      _repeatFilters.remove(tag);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: tasks.isEmpty
                ? Center(
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
                          source.isEmpty
                              ? (_filter == _TasksFilter.archived
                                  ? 'No archived tasks'
                                  : 'No tasks yet')
                              : 'No tasks match this filter',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.5),
                              ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
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
                    Widget row = Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          // Collapsed view
                          ListTile(
                            leading: TaskTimeArc(
                              task: ScheduledTask(
                                task: shown,
                                date: shown.startDate,
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
                                      final label = task.label;
                                      final id = task.id;
                                      final messenger =
                                          ScaffoldMessenger.of(context);
                                      _afterRowSettles(() {
                                        final undo = taskProvider
                                            .permanentlyDeleteTask(id);
                                        showChangeToastOn(
                                          messenger,
                                          message: 'Deleted $label',
                                          onUndo: undo,
                                        );
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
                                      final label = task.label;
                                      final id = task.id;
                                      final messenger =
                                          ScaffoldMessenger.of(context);
                                      _afterRowSettles(() {
                                        final undo =
                                            taskProvider.unarchiveTask(id);
                                        showChangeToastOn(
                                          messenger,
                                          message: 'Restored $label',
                                          onUndo: undo,
                                        );
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
                              onMinimize: () {
                                setState(() {
                                  _expandedTaskId = null;
                                  _headingDraft = null;
                                });
                              },
                              onArchive: () {
                                final label = task.label;
                                final id = task.id;
                                final messenger =
                                    ScaffoldMessenger.of(context);
                                _afterRowSettles(() {
                                  final undo = taskProvider.archiveTask(id);
                                  showChangeToastOn(
                                    messenger,
                                    message: 'Archived $label',
                                    onUndo: undo,
                                  );
                                });
                              },
                            ),
                        ],
                      ),
                    );
                    if (isExpanded) {
                      row = KeyedSubtree(key: _expandedRowKey, child: row);
                    }
                    return KeyedSubtree(key: ValueKey(task.id), child: row);
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addNewTask(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  int _compareSavedTime(Task a, Task b) {
    if (a.isAllDay != b.isAllDay) return a.isAllDay ? -1 : 1;
    final aMin = a.startTime == null ? 24 * 60 : minutesOf(a.startTime!);
    final bMin = b.startTime == null ? 24 * 60 : minutesOf(b.startTime!);
    if (aMin != bMin) return aMin.compareTo(bMin);
    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
  }

  List<String> _uniqueFilterTags(List<Task> tasks) {
    final tags = <String>{};
    for (final task in tasks) {
      if (task.isAllDay) tags.add('All Day');
      final repeat = _getRepeatDescription(task);
      tags.add(repeat.isEmpty ? 'One time' : repeat);
    }
    final list = tags.toList()..sort();
    return list;
  }

  bool _matchesFilter(Task task, Set<String> tags) {
    if (tags.contains('All Day') && task.isAllDay) return true;
    final repeat = _getRepeatDescription(task);
    final label = repeat.isEmpty ? 'One time' : repeat;
    return tags.contains(label);
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
        initialDate: dateOnly(DateTime.now()),
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
