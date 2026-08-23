import 'package:flutter/material.dart';
import 'package:timetodo/models/task.dart';
import 'package:timetodo/widgets/task_details_form.dart';

class TaskEditor extends StatefulWidget {
  final Task task;
  final bool viewActive;
  final void Function(Task task, String message) onCommit;
  final void Function(Task preview)? onDraftChanged;
  final VoidCallback onArchive;
  final VoidCallback? onMinimize;

  const TaskEditor({
    super.key,
    required this.task,
    required this.viewActive,
    required this.onCommit,
    this.onDraftChanged,
    required this.onArchive,
    this.onMinimize,
  });

  @override
  State<TaskEditor> createState() => TaskEditorState();
}

class TaskEditorState extends State<TaskEditor> {
  late TextEditingController _labelController;
  late TimeOfDay? _startTime;
  late TimeOfDay? _endTime;
  late bool _isAllDay;
  late Color _selectedColor;
  late RepeatType _repeatType;
  late int? _repeatInterval;
  late List<int>? _repeatWeekdays;
  late DateTime _startDate;
  late DateTime? _endDate;
  late DateTime _savedStartDate;
  late DateTime? _savedEndDate;
  late String _savedLabel;
  late TimeOfDay? _savedStart;
  late TimeOfDay? _savedEnd;
  late bool _savedAllDay;
  late Color _savedColor;
  late RepeatType _savedRepeatType;
  late int? _savedInterval;
  late List<int>? _savedWeekdays;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.task.label);
    _apply(widget.task);
    _rememberSaved();
    _labelController.addListener(_onLabel);
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyDraft());
  }

  void _apply(Task task) {
    _startTime = task.startTime;
    _endTime = task.endTime;
    _isAllDay = task.isAllDay;
    _selectedColor = task.color;
    _repeatType = task.repeatType;
    _repeatInterval = task.repeatInterval;
    _repeatWeekdays =
        task.repeatWeekdays == null ? null : List<int>.from(task.repeatWeekdays!);
    _startDate = task.startDate;
    _endDate = task.endDate;
  }

  void _rememberSaved() {
    _savedLabel = _labelController.text.trim();
    _savedStart = _startTime;
    _savedEnd = _endTime;
    _savedAllDay = _isAllDay;
    _savedColor = _selectedColor;
    _savedRepeatType = _repeatType;
    _savedInterval = _repeatInterval;
    _savedWeekdays =
        _repeatWeekdays == null ? null : List<int>.from(_repeatWeekdays!);
    _savedStartDate = _startDate;
    _savedEndDate = _endDate;
  }

  void _onLabel() {
    if (!mounted) return;
    setState(() {});
    _notifyDraft();
  }

  void _edit(VoidCallback fn) {
    setState(fn);
    _notifyDraft();
  }

  Task preview() {
    final label = _labelController.text.trim();
    return Task(
      id: widget.task.id,
      label: label.isEmpty ? widget.task.label : label,
      startTime: _isAllDay ? null : _startTime,
      endTime: _isAllDay ? null : _endTime,
      isAllDay: _isAllDay,
      color: _selectedColor,
      startDate: _startDate,
      endDate: _endDate,
      repeatType: _repeatType,
      repeatInterval: _repeatType == RepeatType.custom ? _repeatInterval : null,
      repeatWeekdays: _repeatType == RepeatType.weekly ? _repeatWeekdays : null,
      createdAt: widget.task.createdAt,
    );
  }

  void _notifyDraft() {
    widget.onDraftChanged?.call(preview());
  }

  @override
  void didUpdateWidget(TaskEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewActive && !widget.viewActive) {
      commit();
    }
    if (oldWidget.task.id != widget.task.id) {
      _labelController.removeListener(_onLabel);
      _labelController.dispose();
      _labelController = TextEditingController(text: widget.task.label);
      _apply(widget.task);
      _rememberSaved();
      _labelController.addListener(_onLabel);
      _notifyDraft();
    }
  }

  @override
  void dispose() {
    _labelController.removeListener(_onLabel);
    _labelController.dispose();
    super.dispose();
  }

  bool get isDirty {
    final label = _labelController.text.trim();
    if (label != _savedLabel) return true;
    if (_isAllDay != _savedAllDay) return true;
    if (!_isAllDay) {
      if (_startTime != _savedStart || _endTime != _savedEnd) return true;
    }
    if (_selectedColor != _savedColor) return true;
    if (_repeatType != _savedRepeatType) return true;
    if (_repeatInterval != _savedInterval) return true;
    if (!_listEquals(_repeatWeekdays, _savedWeekdays)) return true;
    if (_startDate != _savedStartDate) return true;
    if (_endDate != _savedEndDate) return true;
    return false;
  }

  bool _listEquals(List<int>? a, List<int>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null || a.length != b.length) return false;
    final sa = [...a]..sort();
    final sb = [...b]..sort();
    for (var i = 0; i < sa.length; i++) {
      if (sa[i] != sb[i]) return false;
    }
    return true;
  }

  Task? draft() {
    final label = _labelController.text.trim();
    if (label.isEmpty) return null;
    if (!_isAllDay && _startTime == null) return null;
    return Task(
      id: widget.task.id,
      label: label,
      startTime: _isAllDay ? null : _startTime,
      endTime: _isAllDay ? null : _endTime,
      isAllDay: _isAllDay,
      color: _selectedColor,
      startDate: _startDate,
      endDate: _endDate,
      repeatType: _repeatType,
      repeatInterval: _repeatType == RepeatType.custom ? _repeatInterval : null,
      repeatWeekdays: _repeatType == RepeatType.weekly ? _repeatWeekdays : null,
      createdAt: widget.task.createdAt,
    );
  }

  void commit() {
    if (!isDirty) return;
    final task = draft();
    if (task == null) return;
    widget.onCommit(task, _commitMessage(task));
    _rememberSaved();
  }

  String _commitMessage(Task next) {
    final name = next.label.trim().isEmpty ? 'Task' : next.label.trim();
    final changes = <String>[];
    if (next.label.trim() != _savedLabel) changes.add('name');
    final timeChanged = next.isAllDay != _savedAllDay ||
        (!next.isAllDay &&
            (next.startTime != _savedStart || next.endTime != _savedEnd));
    if (timeChanged) changes.add('time');
    if (next.color != _savedColor) changes.add('color');
    final repeatChanged = next.repeatType != _savedRepeatType ||
        next.repeatInterval != _savedInterval ||
        !_listEquals(next.repeatWeekdays, _savedWeekdays);
    if (repeatChanged) changes.add('repeat');
    if (next.startDate != _savedStartDate || next.endDate != _savedEndDate) {
      changes.add('dates');
    }

    if (changes.length == 1) {
      switch (changes.first) {
        case 'name':
          return 'Renamed to $name';
        case 'time':
          return next.isAllDay
              ? '$name set to all day'
              : 'Updated $name time';
        case 'color':
          return 'Updated $name color';
        case 'repeat':
          return 'Updated $name repeat';
        case 'dates':
          return 'Updated $name dates';
      }
    }
    return 'Updated $name';
  }

  void _revert() {
    _edit(() {
      _labelController.value = TextEditingValue(
        text: _savedLabel,
        selection: TextSelection.collapsed(offset: _savedLabel.length),
      );
      _startTime = _savedStart;
      _endTime = _savedEnd;
      _isAllDay = _savedAllDay;
      _selectedColor = _savedColor;
      _repeatType = _savedRepeatType;
      _repeatInterval = _savedInterval;
      _repeatWeekdays =
          _savedWeekdays == null ? null : List<int>.from(_savedWeekdays!);
      _startDate = _savedStartDate;
      _endDate = _savedEndDate;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dirty = isDirty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            TaskDetailsForm(
            labelController: _labelController,
            startDate: _startDate,
            endDate: _endDate,
            date: _startDate,
            isAllDay: _isAllDay,
            startTime: _startTime,
            endTime: _endTime,
            color: _selectedColor,
            repeatType: _repeatType,
            repeatInterval: _repeatInterval,
            repeatWeekdays: _repeatWeekdays,
            onAllDayChanged: (value) => _edit(() => _isAllDay = value),
            onTimeframeChanged: (range) {
              _edit(() {
                _startTime = range.$1;
                _endTime = range.$2;
              });
            },
            onColorChanged: (color) => _edit(() => _selectedColor = color),
            onRepeatChanged: ({required type, interval, weekdays}) {
              _edit(() {
                _repeatType = type;
                _repeatInterval = interval;
                _repeatWeekdays = weekdays;
              });
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton.icon(
                onPressed: widget.onArchive,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Archive'),
              ),
              const Spacer(),
              if (dirty) ...[
                FilledButton.tonalIcon(
                  onPressed: _revert,
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text(
                    'Revert',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () {
                    commit();
                    widget.onMinimize?.call();
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Save'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
