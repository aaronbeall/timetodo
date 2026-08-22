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
    if (_isAllDay) return 'All day';
    if (task.startTime != null && task.endTime != null) {
      return '${_formatTime(task.startTime!)}–${_formatTime(task.endTime!)}';
    }
    if (task.startTime != null) return _formatTime(task.startTime!);
    return '';
  }

  Color _inkColor(Color base, Brightness brightness) {
    final hsl = HSLColor.fromColor(base);
    if (brightness == Brightness.dark) {
      return hsl
          .withLightness(hsl.lightness.clamp(0.72, 0.86))
          .withSaturation(hsl.saturation.clamp(0.4, 1))
          .toColor();
    }
    return hsl
        .withLightness(hsl.lightness.clamp(0.22, 0.36))
        .withSaturation(hsl.saturation.clamp(0.5, 1))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = _inkColor(task.color, theme.brightness);
    final wash = _isDone
        ? task.color.withOpacity(0.08)
        : task.color.withOpacity(_isAllDay ? 0.08 : 0.12);
    final fill = task.color.withOpacity(0.2);
    final textOpacity = _isDone
        ? 0.55
        : _isAllDay
            ? 0.7
            : 1.0;

    final titleStyle = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w500,
      fontSize: 15,
      color: ink.withOpacity(textOpacity),
      decoration: _isDone ? TextDecoration.lineThrough : null,
      decorationColor: ink.withOpacity(0.5),
    );

    final timeStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w500,
      color: ink.withOpacity(textOpacity * 0.92),
      decoration: _isDone ? TextDecoration.lineThrough : null,
      decorationColor: ink.withOpacity(0.4),
      letterSpacing: 0.1,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: wash)),
            if (_isActive)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: task.elapsedFraction(currentTime),
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: fill,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
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
            const SizedBox(width: 6),
            if (_isActive) ...[
              if (task.isInSnoozeGrace(currentTime))
                _ActionButton(
                  icon: Icons.snooze_rounded,
                  color: ink,
                  onPressed: onSnooze,
                  tooltip: 'Snooze 15 min',
                )
              else
                _ActionButton(
                  icon: Icons.more_time_rounded,
                  color: ink,
                  onPressed: onExtend,
                  tooltip: 'Extend 15 min',
                ),
              const SizedBox(width: 4),
              _ActionButton(
                icon: Icons.check_rounded,
                color: ink,
                onPressed: onComplete,
                tooltip: 'Complete',
              ),
            ] else if (!_isAllDay && !_isDone && onCancel != null)
              _ActionButton(
                icon: Icons.close_rounded,
                color: ink,
                onPressed: onCancel,
                tooltip: 'Skip today',
              ),
          ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final String tooltip;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withOpacity(0.16),
        disabledBackgroundColor: color.withOpacity(0.08),
        iconSize: 22,
        minimumSize: const Size(44, 44),
        maximumSize: const Size(44, 44),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
      ),
    );
  }
}
