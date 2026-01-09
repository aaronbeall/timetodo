import 'package:flutter/material.dart';
import 'package:timetodo/models/task.dart';

class TaskEditor extends StatefulWidget {
  final Task task;
  final Function(Task) onSave;
  final VoidCallback onDelete;

  const TaskEditor({
    super.key,
    required this.task,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  late TextEditingController _labelController;
  late TimeOfDay? _startTime;
  late TimeOfDay? _endTime;
  late bool _isAllDay;
  late Color _selectedColor;
  late RepeatType _repeatType;
  late int? _repeatInterval;
  late List<int>? _repeatWeekdays;

  final List<Color> _colors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.pink,
    Colors.amber,
  ];

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.task.label);
    _startTime = widget.task.startTime;
    _endTime = widget.task.endTime;
    _isAllDay = widget.task.isAllDay;
    _selectedColor = widget.task.color;
    _repeatType = widget.task.repeatType;
    _repeatInterval = widget.task.repeatInterval;
    _repeatWeekdays = widget.task.repeatWeekdays;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Task Label',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),

          // All Day Toggle
          CheckboxListTile(
            title: const Text('All Day'),
            value: _isAllDay,
            onChanged: (value) {
              setState(() {
                _isAllDay = value ?? false;
              });
            },
          ),

          // Time Selection
          if (!_isAllDay) ...[
            ListTile(
              title: const Text('Start Time'),
              trailing: Text(_startTime != null
                  ? _startTime!.format(context)
                  : 'Not set'),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _startTime ?? TimeOfDay.now(),
                );
                if (time != null) {
                  setState(() {
                    _startTime = time;
                    if (_endTime == null) {
                      _endTime = TimeOfDay(
                        hour: (time.hour + 1) % 24,
                        minute: time.minute,
                      );
                    }
                  });
                }
              },
            ),
            ListTile(
              title: const Text('End Time'),
              trailing: Text(_endTime != null
                  ? _endTime!.format(context)
                  : 'Not set'),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _endTime ?? TimeOfDay.now(),
                );
                if (time != null) {
                  setState(() {
                    _endTime = time;
                  });
                }
              },
            ),
          ],

          const SizedBox(height: 16),

          // Color Selection
          const Text('Color', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _colors.map((color) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedColor = color;
                  });
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _selectedColor == color
                          ? Colors.black
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Repeat Options
          const Text('Repeat', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButton<RepeatType>(
            value: _repeatType,
            isExpanded: true,
            items: RepeatType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(_getRepeatTypeLabel(type)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _repeatType = value;
                  if (value != RepeatType.custom) {
                    _repeatInterval = null;
                    _repeatWeekdays = null;
                  }
                });
              }
            },
          ),

          // Custom Repeat Options
          if (_repeatType == RepeatType.custom) ...[
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Repeat Every N Days',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  _repeatInterval = value.isNotEmpty ? int.tryParse(value) : null;
                });
              },
            ),
            const SizedBox(height: 16),
            const Text('Repeat on Weekdays:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (int i = 0; i < 7; i++)
                  FilterChip(
                    label: Text(_getWeekdayName(i)),
                    selected: _repeatWeekdays?.contains(i) ?? false,
                    onSelected: (selected) {
                      setState(() {
                        _repeatWeekdays ??= [];
                        if (selected) {
                          _repeatWeekdays!.add(i);
                        } else {
                          _repeatWeekdays!.remove(i);
                        }
                      });
                    },
                  ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _save,
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getRepeatTypeLabel(RepeatType type) {
    switch (type) {
      case RepeatType.none:
        return 'None';
      case RepeatType.daily:
        return 'Daily';
      case RepeatType.weekly:
        return 'Weekly';
      case RepeatType.monthly:
        return 'Monthly';
      case RepeatType.weekdays:
        return 'Weekdays';
      case RepeatType.custom:
        return 'Custom';
    }
  }

  String _getWeekdayName(int weekday) {
    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return weekdays[weekday];
  }

  void _save() {
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

    final updatedTask = widget.task.copyWith(
      label: _labelController.text.trim(),
      startTime: _isAllDay ? null : _startTime,
      endTime: _isAllDay ? null : _endTime,
      isAllDay: _isAllDay,
      color: _selectedColor,
      repeatType: _repeatType,
      repeatInterval: _repeatInterval,
      repeatWeekdays: _repeatWeekdays,
    );

    widget.onSave(updatedTask);
  }
}
