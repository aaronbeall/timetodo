import 'package:flutter/material.dart';
import 'package:timetodo/models/task.dart';

class TaskListItem extends StatelessWidget {
  final Task task;
  final TimeOfDay currentTime;
  final VoidCallback? onSnooze;
  final VoidCallback? onExtend;
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;

  const TaskListItem({
    super.key,
    required this.task,
    required this.currentTime,
    this.onSnooze,
    this.onExtend,
    this.onComplete,
    this.onCancel,
  });

  bool get _isActive => task.isActive(currentTime);
  bool get _isDone => task.isCompleted || task.isCanceled;
  bool get _isAllDay => task.isAllDay;

  String _formatTime(TimeOfDay time) {
    final hour = time.hour;
    final minute = time.minute;
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final period = hour >= 12 ? 'p' : 'a';
    if (minute == 0) return '$displayHour$period';
    return '$displayHour:${minute.toString().padLeft(2, '0')}$period';
  }

  String _timeLabel() {
    if (_isAllDay) return '';
    if (task.startTime != null && task.endTime != null) {
      return '${_formatTime(task.startTime!)}–${_formatTime(task.endTime!)}';
    }
    if (task.startTime != null) return _formatTime(task.startTime!);
    return '';
  }

  Color _inkColor(Color base) {
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withLightness(hsl.lightness.clamp(0.18, 0.42))
        .withSaturation(hsl.saturation.clamp(0.35, 1))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = _inkColor(task.color);
    final wash = _isActive
        ? task.color.withOpacity(0.28)
        : _isDone
            ? task.color.withOpacity(0.08)
            : task.color.withOpacity(_isAllDay ? 0.1 : 0.16);
    final textOpacity = _isDone
        ? 0.55
        : _isAllDay
            ? 0.7
            : 1.0;

    final titleStyle = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: _isActive ? FontWeight.w600 : FontWeight.w500,
      fontSize: _isActive ? 16 : 15,
      color: ink.withOpacity(textOpacity),
      decoration: _isDone ? TextDecoration.lineThrough : null,
      decorationColor: ink.withOpacity(0.5),
    );

    final timeStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: _isActive ? FontWeight.w600 : FontWeight.w500,
      color: ink.withOpacity(textOpacity * 0.85),
      decoration: _isDone ? TextDecoration.lineThrough : null,
      decorationColor: ink.withOpacity(0.4),
      letterSpacing: 0.1,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          12,
          _isActive ? 10 : 8,
          6,
          _isActive ? 10 : 8,
        ),
        decoration: BoxDecoration(
          color: wash,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            if (task.isCompleted) ...[
              Icon(
                Icons.check_rounded,
                size: 18,
                color: ink.withOpacity(textOpacity),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                task.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
            ),
            const SizedBox(width: 8),
            Text(_timeLabel(), style: timeStyle),
            if (_isActive) ...[
              if (task.isInSnoozeGrace(currentTime))
                _TintedIcon(
                  icon: Icons.snooze_rounded,
                  color: ink,
                  onPressed: onSnooze,
                  tooltip: 'Snooze 15 min',
                )
              else
                _TintedIcon(
                  icon: Icons.more_time_rounded,
                  color: ink,
                  onPressed: onExtend,
                  tooltip: 'Extend 15 min',
                ),
              _TintedIcon(
                icon: Icons.check_rounded,
                color: ink,
                onPressed: onComplete,
                tooltip: 'Complete',
              ),
            ] else if (!_isAllDay && !_isDone && onCancel != null)
              _TintedIcon(
                icon: Icons.close_rounded,
                color: ink,
                onPressed: onCancel,
                tooltip: 'Skip today',
              ),
          ],
        ),
      ),
    );
  }
}

class _TintedIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final String tooltip;

  const _TintedIcon({
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18),
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      color: color.withOpacity(0.7),
    );
  }
}
