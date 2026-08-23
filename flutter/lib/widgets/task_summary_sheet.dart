import 'package:flutter/material.dart';
import 'package:timetodo/models/scheduled_task.dart';
import 'package:timetodo/models/task.dart';
import 'package:timetodo/time_utils.dart';
import 'package:timetodo/widgets/task_time_arc.dart';

Future<void> showTaskSummarySheet(
  BuildContext context, {
  required ScheduledTask task,
  required TimeOfDay now,
  required VoidCallback onEdit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final ink = taskInkColor(task.color, theme.brightness);
      final muted = theme.colorScheme.onSurfaceVariant;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  TaskTimeArc(task: task),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      task.label,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SummaryLine(
                icon: Icons.schedule_rounded,
                text: _timeLine(sheetContext, task),
                color: muted,
              ),
              if (!task.isAllDay &&
                  task.startTime != null &&
                  task.endTime != null) ...[
                const SizedBox(height: 10),
                _SummaryLine(
                  icon: Icons.timelapse_rounded,
                  text: formatDurationMinutes(
                    durationMinutes(task.startTime!, task.endTime!),
                  ),
                  color: muted,
                ),
              ],
              if (task.repeatType != RepeatType.none) ...[
                const SizedBox(height: 10),
                _SummaryLine(
                  icon: Icons.repeat_rounded,
                  text: _repeatLine(task),
                  color: muted,
                ),
              ],
              const SizedBox(height: 10),
              _SummaryLine(
                icon: _statusIcon(task, now),
                text: _statusLine(task, now),
                color: muted,
              ),
              const SizedBox(height: 22),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  onEdit();
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SummaryLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _SummaryLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: color,
                ),
          ),
        ),
      ],
    );
  }
}

String _timeLine(BuildContext context, ScheduledTask task) {
  if (task.isAllDay) return 'All day';
  if (task.startTime != null && task.endTime != null) {
    return '${task.startTime!.format(context)} – ${task.endTime!.format(context)}';
  }
  if (task.startTime != null) {
    return 'Starts at ${task.startTime!.format(context)}';
  }
  return 'No time set';
}

String _repeatLine(ScheduledTask task) {
  switch (task.repeatType) {
    case RepeatType.daily:
      return 'Every day';
    case RepeatType.weekly:
      return Task.weeklyRepeatLabel(task.repeatWeekdays, task.task.startDate);
    case RepeatType.monthly:
      return 'Monthly';
    case RepeatType.custom:
      final n = task.repeatInterval ?? 1;
      return n <= 1 ? 'Every day' : 'Every $n days';
    case RepeatType.none:
      return 'Does not repeat';
  }
}

IconData _statusIcon(ScheduledTask task, TimeOfDay now) {
  if (task.isCompleted) return Icons.check_circle_outline;
  if (task.isCanceled) return Icons.cancel_outlined;
  if (task.isMissed(now)) return Icons.hourglass_bottom_rounded;
  if (task.isActive(now)) return Icons.play_circle_outline;
  if (task.isAllDay) return Icons.wb_sunny_outlined;
  return Icons.upcoming_outlined;
}

String _statusLine(ScheduledTask task, TimeOfDay now) {
  if (task.isCompleted) return 'Completed';
  if (task.isCanceled) return 'Skipped';
  if (task.isMissed(now)) return 'Expired';
  if (task.isActive(now)) return 'In progress';
  if (task.isAllDay) return 'Open all day';
  return 'Upcoming';
}
