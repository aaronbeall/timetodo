import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timetodo/models/scheduled_task.dart';
import 'package:timetodo/models/task.dart';
import 'package:timetodo/providers/task_provider.dart';
import 'package:timetodo/time_utils.dart';
import 'package:timetodo/widgets/change_toast.dart';
import 'package:timetodo/widgets/polar_clock.dart';
import 'package:timetodo/widgets/task_details_form.dart';
import 'package:timetodo/widgets/task_repeat_field.dart';

class AddTaskDialog extends StatefulWidget {
  final DateTime initialDate;
  final TimeOfDay? initialStartTime;

  const AddTaskDialog({
    super.key,
    required this.initialDate,
    this.initialStartTime,
  });

  static Future<Task?> open(
    BuildContext context, {
    required DateTime initialDate,
    TimeOfDay? initialStartTime,
  }) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Navigator.of(context).push<Task>(
      PageRouteBuilder<Task>(
        fullscreenDialog: true,
        opaque: true,
        transitionDuration: reduce
            ? Duration.zero
            : const Duration(milliseconds: 320),
        reverseTransitionDuration: reduce
            ? Duration.zero
            : const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondaryAnimation) {
          return AddTaskDialog(
            initialDate: initialDate,
            initialStartTime: initialStartTime,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  late TextEditingController _labelController;
  late DateTime _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isAllDay = false;
  Color _selectedColor = Colors.blue;
  RepeatType _repeatType = RepeatType.none;
  int? _repeatInterval;
  List<int>? _repeatWeekdays;
  Task? _sourceTask;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController();
    _labelController.addListener(() => setState(() {}));
    _selectedDate = widget.initialDate;
    _startTime = widget.initialStartTime;
    if (_startTime != null) {
      _endTime = TimeOfDay(
        hour: (_startTime!.hour + 1) % 24,
        minute: _startTime!.minute,
      );
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Cancel',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Add Task'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: _saveTask,
                child: const Text('Add'),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _polarPreview(context),
            const SizedBox(height: 20),
            TaskDetailsForm(
              labelController: _labelController,
              date: _selectedDate,
              startDate: _selectedDate,
              endDate: null,
              isAllDay: _isAllDay,
              startTime: _startTime,
              endTime: _endTime,
              color: _selectedColor,
              repeatType: _repeatType,
              repeatInterval: _repeatInterval,
              repeatWeekdays: _repeatWeekdays,
              restoreSuggestions: context
                  .watch<TaskProvider>()
                  .matchArchived(_labelController.text),
              onApplySuggestion: _fillFromPast,
              onAllDayChanged: (value) => setState(() => _isAllDay = value),
              onTimeframeChanged: (range) {
                setState(() {
                  _startTime = range.$1;
                  _endTime = range.$2;
                });
              },
              onColorChanged: (color) => setState(() => _selectedColor = color),
              onRepeatChanged: ({required type, interval, weekdays}) {
                setState(() {
                  _repeatType = type;
                  _repeatInterval = interval;
                  _repeatWeekdays = weekdays;
                });
              },
            ),
          ],
        ),
    );
  }

  static const _previewId = '_add-preview';

  Task _draftTask() {
    final label = _labelController.text.trim();
    return Task(
      id: _previewId,
      label: label.isEmpty ? 'New' : label,
      startTime: _isAllDay ? null : _startTime,
      endTime: _isAllDay ? null : _endTime,
      isAllDay: _isAllDay,
      color: _selectedColor,
      startDate: _selectedDate,
      repeatType: _repeatType,
      repeatInterval: _repeatType == RepeatType.custom ? _repeatInterval : null,
      repeatWeekdays: _repeatType == RepeatType.weekly ? _repeatWeekdays : null,
    );
  }

  List<ScheduledTask> _clockTasks(TaskProvider provider) {
    final day = dateOnly(_selectedDate);
    final tasks = provider
        .scheduledOn(day)
        .where((t) => t.id != _sourceTask?.id)
        .toList();
    final draft = _draftTask();
    if (!draft.isAllDay && draft.startTime != null && draft.endTime != null) {
      tasks.add(ScheduledTask(task: draft, date: day));
    }
    return tasks;
  }

  Widget _polarPreview(BuildContext context) {
    final now = TimeOfDay.now();
    final today = isSameDay(_selectedDate, DateTime.now());
    final color = Theme.of(context).colorScheme.onSurface;
    final timed = !_isAllDay && _startTime != null && _endTime != null;
    final provider = context.watch<TaskProvider>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final polarSize = (constraints.maxWidth - 8).clamp(200.0, 320.0);
        return Center(
          child: SizedBox(
            width: polarSize,
            height: polarSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PolarClock(
                  currentTime: now,
                  tasks: _clockTasks(provider),
                  size: polarSize,
                  animate: false,
                  showNow: today,
                  fullColor: true,
                  enableMove: timed,
                  liveEdit: timed,
                  movingTaskId: timed ? _previewId : null,
                  onTaskTap: _peekDayTask,
                  onMoveCommit: (_, start, end) {
                    setState(() {
                      _isAllDay = false;
                      _startTime = start;
                      _endTime = end;
                    });
                  },
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _pickStartDate,
                      child: Text(
                        _startDateLabel(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: (polarSize * 0.055).clamp(14.0, 18.0),
                          height: 1.1,
                          color: color,
                        ),
                      ),
                    ),
                    PolarClockHub(
                      time: now,
                      showTime: false,
                      timeStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        height: 1,
                        color: color,
                      ),
                      periodStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        height: 1,
                        color: color.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _startDateLabel() {
    if (isSameDay(_selectedDate, DateTime.now())) return 'Today';
    final fmt = _selectedDate.year == DateTime.now().year
        ? DateFormat.MMMd()
        : DateFormat.yMMMd();
    return fmt.format(_selectedDate);
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = dateOnly(picked));
  }

  String _timeframeLabel(ScheduledTask task) {
    if (task.isAllDay) return 'All day';
    if (task.startTime != null && task.endTime != null) {
      return '${task.startTime!.format(context)} – ${task.endTime!.format(context)}';
    }
    if (task.startTime != null) {
      return task.startTime!.format(context);
    }
    return '';
  }

  String? _repeatLabel(ScheduledTask task) {
    return switch (task.repeatType) {
      RepeatType.daily => 'Every day',
      RepeatType.weekly =>
        Task.weeklyRepeatLabel(task.repeatWeekdays, task.task.startDate),
      RepeatType.monthly => 'Monthly',
      RepeatType.custom => (task.repeatInterval ?? 1) == 1
          ? 'Every day'
          : 'Every ${task.repeatInterval} days',
      RepeatType.none => null,
    };
  }

  void _peekDayTask(ScheduledTask task) {
    if (task.id == _previewId) return;
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black26,
      builder: (ctx) {
        return GestureDetector(
          onTap: () => Navigator.of(ctx).pop(),
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Material(
              elevation: 8,
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: taskInkColor(task.color, theme.brightness),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (_timeframeLabel(task).isNotEmpty)
                            Text(
                              _timeframeLabel(task),
                              style: theme.textTheme.bodySmall,
                            ),
                          if (_repeatLabel(task) case final repeat?)
                            TaskRepeatBadge(label: repeat),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _saveTask() {
    if (_labelController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task label')),
      );
      return;
    }

    if (!_isAllDay && _startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a start time')),
      );
      return;
    }

    final task = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: _labelController.text.trim(),
      startTime: _isAllDay ? null : _startTime,
      endTime: _isAllDay ? null : _endTime,
      isAllDay: _isAllDay,
      color: _selectedColor,
      startDate: _selectedDate,
      repeatType: _repeatType,
      repeatInterval: _repeatType == RepeatType.custom ? _repeatInterval : null,
      repeatWeekdays: _repeatType == RepeatType.weekly ? _repeatWeekdays : null,
    );

    final provider = Provider.of<TaskProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final source = _sourceTask;
    final undo = source == null
        ? provider.addTask(task)
        : provider.reopenTask(source, task);
    Navigator.of(context).pop(task);
    showChangeToastOn(
      messenger,
      message: 'Added ${task.label}',
      onUndo: undo,
    );
  }

  void _fillFromPast(Task past) {
    setState(() {
      _sourceTask = past;
      _labelController.value = TextEditingValue(
        text: past.label,
        selection: TextSelection.collapsed(offset: past.label.length),
      );
      _isAllDay = past.isAllDay;
      _startTime = past.startTime;
      _endTime = past.endTime;
      if (!_isAllDay && _startTime != null && _endTime == null) {
        _endTime = addTimeMinutes(_startTime!, 60);
      }
      _selectedColor = past.color;
      _repeatType = past.repeatType;
      _repeatInterval = past.repeatInterval;
      _repeatWeekdays =
          past.repeatWeekdays == null ? null : [...past.repeatWeekdays!];
    });
  }
}
