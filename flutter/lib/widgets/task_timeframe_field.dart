import 'package:flutter/material.dart';
import 'package:timetodo/time_utils.dart';

class TaskTimeframeField extends StatelessWidget {
  final bool isAllDay;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final ValueChanged<bool>? onAllDayChanged;
  final ValueChanged<(TimeOfDay start, TimeOfDay end)> onTimeframeChanged;
  final bool showAllDayToggle;
  final bool showTrailingTimeIcon;
  final bool leadingIcons;

  const TaskTimeframeField({
    super.key,
    required this.isAllDay,
    required this.startTime,
    required this.endTime,
    this.onAllDayChanged,
    required this.onTimeframeChanged,
    this.showAllDayToggle = true,
    this.showTrailingTimeIcon = true,
    this.leadingIcons = false,
  });

  @override
  Widget build(BuildContext context) {
    final duration = !isAllDay && startTime != null && endTime != null
        ? durationMinutes(startTime!, endTime!)
        : null;

    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      children: [
        if (showAllDayToggle && onAllDayChanged != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('All day'),
            value: isAllDay,
            onChanged: onAllDayChanged,
          ),
        if (!isAllDay) ...[
          if (leadingIcons) ...[
            _iconRow(
              context,
              icon: Icons.schedule_rounded,
              label: 'Timeframe',
              value: _rangeLabel(context),
              onTap: () => _pickTimeframe(context),
            ),
            if (duration != null)
              _iconRow(
                context,
                icon: Icons.timelapse_rounded,
                label: 'Duration',
                value: formatDurationMinutes(duration),
                onTap: () => _pickDuration(context, duration),
              ),
          ] else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Timeframe'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _rangeLabel(context),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (showTrailingTimeIcon) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.schedule_rounded, color: muted),
                  ],
                ],
              ),
              onTap: () => _pickTimeframe(context),
            ),
            if (duration != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Duration'),
                trailing: Text(
                  formatDurationMinutes(duration),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => _pickDuration(context, duration),
              ),
          ],
        ],
      ],
    );
  }

  Widget _iconRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(color: muted),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _rangeLabel(BuildContext context) {
    if (startTime == null) return 'Set';
    if (endTime == null) return startTime!.format(context);
    return '${startTime!.format(context)} – ${endTime!.format(context)}';
  }

  Future<void> _pickTimeframe(BuildContext context) async {
    final start = await showTimePicker(
      context: context,
      initialTime: startTime ?? TimeOfDay.now(),
      helpText: 'Start time',
    );
    if (start == null || !context.mounted) return;
    final suggestedEnd = endTime ?? addTimeMinutes(start, 60);
    final end = await showTimePicker(
      context: context,
      initialTime: suggestedEnd,
      helpText: 'End time',
    );
    if (end == null || !context.mounted) return;
    onTimeframeChanged((start, end));
  }

  Future<void> _pickDuration(BuildContext context, int current) async {
    if (startTime == null) return;
    const presets = [15, 30, 45, 60, 90, 120, 180];
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Duration',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final minutes in presets)
                ListTile(
                  title: Text(formatDurationMinutes(minutes)),
                  selected: minutes == current,
                  onTap: () => Navigator.pop(context, minutes),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked == null) return;
    onTimeframeChanged((startTime!, addTimeMinutes(startTime!, picked)));
  }
}
