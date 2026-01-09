import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timetodo/models/task.dart';

class TaskListItem extends StatelessWidget {
  final Task task;
  final bool isActive;
  final bool isAllDay;
  final VoidCallback? onSnooze;
  final VoidCallback? onComplete;
  final VoidCallback? onDelete;

  const TaskListItem({
    super.key,
    required this.task,
    this.isActive = false,
    this.isAllDay = false,
    this.onSnooze,
    this.onComplete,
    this.onDelete,
  });

  String _formatTime(TimeOfDay time) {
    final hour = time.hour;
    final minute = time.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  String _getTimeRange() {
    if (task.isAllDay) return 'All Day';
    if (task.startTime != null && task.endTime != null) {
      return '${_formatTime(task.startTime!)} - ${_formatTime(task.endTime!)}';
    }
    if (task.startTime != null) {
      return 'Starts at ${_formatTime(task.startTime!)}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isActive ? 4 : 1,
      color: isActive
          ? task.color.withOpacity(0.1)
          : isAllDay
              ? colorScheme.surfaceContainerHighest
              : colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Color indicator
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: task.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),

            // Task details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: isAllDay
                          ? colorScheme.onSurface.withOpacity(0.6)
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getTimeRange(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isAllDay
                          ? colorScheme.onSurface.withOpacity(0.4)
                          : colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),

            // Action buttons
            if (!isAllDay) ...[
              if (isActive && onSnooze != null)
                IconButton(
                  icon: const Icon(Icons.snooze),
                  onPressed: onSnooze,
                  tooltip: 'Snooze 15 min',
                  color: colorScheme.primary,
                ),
              if (isActive && onComplete != null)
                IconButton(
                  icon: const Icon(Icons.check_circle_outline),
                  onPressed: onComplete,
                  tooltip: 'Complete',
                  color: Colors.green,
                ),
              if (!isActive && onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                  color: colorScheme.error,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
