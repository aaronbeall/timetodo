import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timetodo/models/task.dart';
import 'package:timetodo/providers/task_provider.dart';

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
    _labelController = TextEditingController();
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
          children: [
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Task Label',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('All Day'),
              value: _isAllDay,
              onChanged: (value) {
                setState(() {
                  _isAllDay = value ?? false;
                });
              },
            ),
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
            const Text('Color'),
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
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
      date: _selectedDate,
    );

    Provider.of<TaskProvider>(context, listen: false).addTask(task);
    Navigator.of(context).pop();
  }
}
