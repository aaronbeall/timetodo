import 'package:flutter/material.dart';
import 'package:timetodo/models/task.dart';

class TaskListItem extends StatelessWidget {
  final Task task;
  final TimeOfDay currentTime;
  final VoidCallback? onSnooze;
  final VoidCallback? onExtend;
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;
  final VoidCallback? onDoNow;
  final bool showShadow;

  /// Full row (action buttons) including the gap below the card.
  static const stackExtent = 62.0;

  /// Completed / skipped rows have no action buttons.
  static const resolvedStackExtent = 44.0;

  static double stackExtentFor(Task task) =>
      task.isCompleted || task.isCanceled ? resolvedStackExtent : stackExtent;

  const TaskListItem({
    super.key,
    required this.task,
    required this.currentTime,
    this.onSnooze,
    this.onExtend,
    this.onComplete,
    this.onCancel,
    this.onDoNow,
    this.showShadow = false,
  });

  bool get _isActive => task.isActive(currentTime);
  bool get _isMissed => task.isMissed(currentTime);
  bool get _isDone => task.isCompleted || task.isCanceled;
  bool get _isAllDay => task.isAllDay;
  bool get _isStruck => _isDone || _isMissed;

  String _formatTime(TimeOfDay time) {
    final hour = time.hour;
    final minute = time.minute;
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final period = hour >= 12 ? 'p' : 'a';
    if (minute == 0) return '$displayHour$period';
    return '$displayHour:${minute.toString().padLeft(2, '0')}$period';
  }

  int _asMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  int _minutesUntil(TimeOfDay target) {
    var delta = _asMinutes(target) - _asMinutes(currentTime);
    if (delta < 0) delta += 24 * 60;
    return delta;
  }

  int _minutesSince(TimeOfDay target) {
    var delta = _asMinutes(currentTime) - _asMinutes(target);
    if (delta < 0) delta += 24 * 60;
    return delta;
  }

  String _formatDuration(int minutes) {
    if (minutes < 1) return 'now';
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (rest == 0) return hours == 1 ? '1 hr' : '$hours hr';
    return '$hours hr $rest min';
  }

  String _exactTimeLabel() {
    if (_isAllDay) return '';
    if (task.startTime != null && task.endTime != null) {
      return '${_formatTime(task.startTime!)}–${_formatTime(task.endTime!)}';
    }
    if (task.startTime != null) return _formatTime(task.startTime!);
    return '';
  }

  String _relativeTimeLabel() {
    if (_isAllDay) return 'All day';
    if (task.startTime == null) return '';

    if (_isActive && task.endTime != null) {
      final left = _minutesUntil(task.endTime!);
      if (left < 1) return 'ending now';
      return '${_formatDuration(left)} left';
    }

    final start = _asMinutes(task.startTime!);
    final now = _asMinutes(currentTime);
    if (now < start) {
      final until = _minutesUntil(task.startTime!);
      if (until < 1) return 'starting now';
      return 'in ${_formatDuration(until)}';
    }

    if (task.endTime != null) {
      final ago = _minutesSince(task.endTime!);
      if (ago < 1) return 'just ended';
      return '${_formatDuration(ago)} ago';
    }

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

  Color _tint(Color color, double opacity, Color onto) {
    return Color.alphaBlend(color.withOpacity(opacity), onto);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canvas = theme.scaffoldBackgroundColor;
    final ink = _inkColor(task.color, theme.brightness);
    final washOpacity = _isStruck || _isAllDay ? 0.08 : 0.12;
    final wash = _tint(task.color, washOpacity, canvas);
    final fill = _tint(task.color, 0.2, wash);
    final textOpacity = _isStruck
        ? 0.55
        : _isAllDay
            ? 0.7
            : 1.0;

    final titleStyle = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w500,
      fontSize: 15,
      color: ink.withOpacity(textOpacity),
      decoration: _isStruck ? TextDecoration.lineThrough : null,
      decorationColor: ink.withOpacity(0.5),
    );

    final timeStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w500,
      fontSize: 13,
      color: ink.withOpacity(textOpacity * 0.92),
      letterSpacing: 0.1,
      height: 1.15,
    );
    final exactStyle = timeStyle?.copyWith(
      fontSize: 10,
      fontWeight: FontWeight.w400,
      color: ink.withOpacity(textOpacity * 0.42),
    );

    final relative = _relativeTimeLabel();
    final exact = _exactTimeLabel();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      theme.brightness == Brightness.dark ? 0.28 : 0.08,
                    ),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: wash)),
            if (_isActive || (_isAllDay && !_isDone))
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _isAllDay
                        ? (currentTime.hour * 60 + currentTime.minute) /
                            (24 * 60)
                        : task.elapsedFraction(currentTime),
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
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      task.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                  ),
                  if (_isMissed) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: ink.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'expired',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          color: ink.withOpacity(0.5),
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (relative.isNotEmpty) Text(relative, style: timeStyle),
                if (exact.isNotEmpty) Text(exact, style: exactStyle),
              ],
            ),
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
            ] else if (_isMissed) ...[
              _ActionButton(
                icon: Icons.play_arrow_rounded,
                color: ink,
                onPressed: onDoNow,
                tooltip: 'Do now',
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
