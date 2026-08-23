import 'package:flutter/material.dart';
import 'package:timetodo/models/task.dart';
import 'package:timetodo/time_utils.dart';
import 'package:timetodo/widgets/task_color_picker.dart';
import 'package:timetodo/widgets/task_repeat_field.dart';
import 'package:timetodo/widgets/task_timeframe_field.dart';

class TaskDetailsForm extends StatelessWidget {
  final TextEditingController labelController;
  final DateTime date;
  final bool isAllDay;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final Color color;
  final RepeatType repeatType;
  final int? repeatInterval;
  final List<int>? repeatWeekdays;
  final ValueChanged<bool> onAllDayChanged;
  final ValueChanged<(TimeOfDay, TimeOfDay)> onTimeframeChanged;
  final ValueChanged<Color> onColorChanged;
  final void Function({
    required RepeatType type,
    int? interval,
    List<int>? weekdays,
  }) onRepeatChanged;

  const TaskDetailsForm({
    super.key,
    required this.labelController,
    required this.date,
    required this.isAllDay,
    required this.startTime,
    required this.endTime,
    required this.color,
    required this.repeatType,
    required this.repeatInterval,
    required this.repeatWeekdays,
    required this.onAllDayChanged,
    required this.onTimeframeChanged,
    required this.onColorChanged,
    required this.onRepeatChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: labelController,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: taskInkColor(color, Theme.of(context).brightness),
          ),
          decoration: const InputDecoration(
            labelText: 'Task',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 8),
        TaskTimeframeField(
          isAllDay: isAllDay,
          startTime: startTime,
          endTime: endTime,
          onAllDayChanged: onAllDayChanged,
          onTimeframeChanged: onTimeframeChanged,
        ),
        const SizedBox(height: 8),
        Text('Color', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        TaskColorPicker(selected: color, onSelected: onColorChanged),
        const SizedBox(height: 16),
        TaskRepeatField(
          date: date,
          repeatType: repeatType,
          repeatInterval: repeatInterval,
          repeatWeekdays: repeatWeekdays,
          onChanged: onRepeatChanged,
        ),
      ],
    );
  }
}
