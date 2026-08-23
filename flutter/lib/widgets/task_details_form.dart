import 'package:flutter/material.dart';
import 'package:timetodo/models/task.dart';
import 'package:timetodo/time_utils.dart';
import 'package:timetodo/widgets/task_color_picker.dart';
import 'package:timetodo/widgets/task_repeat_field.dart';
import 'package:timetodo/widgets/task_timeframe_field.dart';

class TaskDetailsForm extends StatelessWidget {
  final TextEditingController labelController;
  final DateTime date;
  final DateTime startDate;
  final DateTime? endDate;
  final ValueChanged<DateTime>? onStartDateChanged;
  final ValueChanged<DateTime?>? onEndDateChanged;
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
  final List<Task> restoreSuggestions;
  final ValueChanged<Task>? onApplySuggestion;

  const TaskDetailsForm({
    super.key,
    required this.labelController,
    required this.date,
    required this.startDate,
    this.endDate,
    this.onStartDateChanged,
    this.onEndDateChanged,
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
    this.restoreSuggestions = const [],
    this.onApplySuggestion,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
        if (restoreSuggestions.isNotEmpty && onApplySuggestion != null) ...[
          const SizedBox(height: 8),
          for (final past in restoreSuggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                title: Text(
                  past.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(_activeRange(context, past)),
                onTap: () => onApplySuggestion!(past),
              ),
            ),
        ],
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
          key: ValueKey(
            '$repeatType-$repeatInterval-${repeatWeekdays?.join(',')}',
          ),
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

String _activeRange(BuildContext context, Task task) {
  final loc = MaterialLocalizations.of(context);
  final start = loc.formatMediumDate(task.firstFrom);
  final endDate = task.eras.last.to;
  if (endDate == null) return start;
  final end = loc.formatMediumDate(endDate);
  if (start == end) return start;
  return '$start – $end';
}
