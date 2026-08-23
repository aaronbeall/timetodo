import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timetodo/models/task.dart';
import 'package:timetodo/providers/task_provider.dart';
import 'package:timetodo/time_utils.dart';
import 'package:timetodo/widgets/change_toast.dart';
import 'package:timetodo/widgets/task_details_form.dart';

class AddTaskDialog extends StatefulWidget {
  final DateTime initialDate;
  final TimeOfDay? initialStartTime;

  const AddTaskDialog({
    super.key,
    required this.initialDate,
    this.initialStartTime,
  });

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
    return AlertDialog(
      title: const Text('Add Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
          restoreSuggestions:
              context.watch<TaskProvider>().matchArchived(_labelController.text),
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saveTask,
          child: const Text('Add'),
        ),
      ],
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
