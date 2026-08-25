import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timetodo/app_navigation.dart';
import 'package:timetodo/data/demo_schedule.dart';
import 'package:timetodo/models/scheduled_task.dart';
import 'package:timetodo/models/task.dart';
import 'package:timetodo/providers/polar_clock_settings.dart';
import 'package:timetodo/providers/task_provider.dart';
import 'package:timetodo/providers/theme_controller.dart';
import 'package:timetodo/providers/time_format_settings.dart';
import 'package:timetodo/screens/about_screen.dart';
import 'package:timetodo/widgets/change_toast.dart';
import 'package:timetodo/widgets/polar_clock.dart';

void openSettings(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
  );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeController = context.watch<ThemeController>();
    final timeFormat = context.watch<TimeFormatSettings>();
    final tasks = context.watch<TaskProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
        children: [
          _sectionLabel(theme, 'Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {themeController.mode},
              onSelectionChanged: (value) =>
                  themeController.setMode(value.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Time',
              style: theme.textTheme.bodyLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SegmentedButton<TimeFormatMode>(
              segments: const [
                ButtonSegment(
                  value: TimeFormatMode.system,
                  label: Text('System'),
                ),
                ButtonSegment(
                  value: TimeFormatMode.h12,
                  label: Text('12-hour'),
                ),
                ButtonSegment(
                  value: TimeFormatMode.h24,
                  label: Text('24-hour'),
                ),
              ],
              selected: {timeFormat.mode},
              onSelectionChanged: (value) => timeFormat.setMode(value.first),
            ),
          ),
          const SizedBox(height: 16),
          _sectionLabel(theme, 'Polar clock'),
          _PolarClockSettings(),
          const SizedBox(height: 16),
          _sectionLabel(theme, 'Data'),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('Export data'),
            subtitle: const Text('Coming soon'),
            onTap: () => _stub(context, 'Export is not available yet'),
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Import data'),
            subtitle: const Text('Coming soon'),
            onTap: () => _stub(context, 'Import is not available yet'),
          ),
          const SizedBox(height: 16),
          _sectionLabel(theme, 'Support TimeToDo'),
          ListTile(
            leading: const Icon(Icons.volunteer_activism_outlined),
            title: const Text('Tip jar'),
            subtitle: const Text('Coming soon'),
            onTap: () => _stub(context, 'Tip jar is not available yet'),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share_outlined),
            title: const Text('Share the app'),
            subtitle: const Text('Coming soon'),
            onTap: () => _stub(context, 'Sharing is not available yet'),
          ),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Rate TimeToDo'),
            subtitle: const Text('Coming soon'),
            onTap: () => _stub(context, 'Ratings are not available yet'),
          ),
          const SizedBox(height: 16),
          _sectionLabel(theme, 'Developer'),
          ListTile(
            leading: const Icon(Icons.wb_sunny_outlined),
            title: const Text('Light day'),
            subtitle: const Text('Load a light test schedule'),
            onTap: () => _loadDemoAndGoHome(
              context,
              tasks,
              DemoScheduleKind.light,
              'Light day',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_view_day_outlined),
            title: const Text('Typical day'),
            subtitle: const Text('Load a typical test schedule'),
            onTap: () => _loadDemoAndGoHome(
              context,
              tasks,
              DemoScheduleKind.typical,
              'Typical day',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.view_week_outlined),
            title: const Text('Packed day'),
            subtitle: const Text('Load a packed test schedule'),
            onTap: () => _loadDemoAndGoHome(
              context,
              tasks,
              DemoScheduleKind.packed,
              'Packed day',
            ),
          ),
          ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: theme.colorScheme.error,
            ),
            title: Text(
              'Delete all data',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            subtitle: const Text('Remove every task and occurrence'),
            onTap: () => _confirmClear(context, tasks),
          ),
          const SizedBox(height: 16),
          _sectionLabel(theme, 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About TimeToDo'),
            subtitle: const Text('Privacy, credits, and support'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AboutScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PolarClockSettings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final polar = context.watch<PolarClockSettings>();
    final look = polar.look;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Center(
            child: SizedBox(
              width: 168,
              height: 168,
              child: IgnorePointer(
                child: PolarClock(
                  currentTime: const TimeOfDay(hour: 10, minute: 24),
                  tasks: _polarPreviewTasks(),
                  size: 168,
                  animate: false,
                  showNow: false,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Time of day labels',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 0, label: Text('None')),
                  ButtonSegment(value: 4, label: Text('4')),
                  ButtonSegment(value: 8, label: Text('8')),
                  ButtonSegment(value: 12, label: Text('12')),
                ],
                selected: {look.hourLabels},
                onSelectionChanged: (value) {
                  if (value.isEmpty) return;
                  polar.setHourLabels(value.first);
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '12 o’clock position',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              SegmentedButton<PolarClockOrigin>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: PolarClockOrigin.left,
                    icon: _OriginGlyph(PolarClockOrigin.left),
                    tooltip: 'Left',
                  ),
                  ButtonSegment(
                    value: PolarClockOrigin.top,
                    icon: _OriginGlyph(PolarClockOrigin.top),
                    tooltip: 'Top',
                  ),
                  ButtonSegment(
                    value: PolarClockOrigin.right,
                    icon: _OriginGlyph(PolarClockOrigin.right),
                    tooltip: 'Right',
                  ),
                  ButtonSegment(
                    value: PolarClockOrigin.bottom,
                    icon: _OriginGlyph(PolarClockOrigin.bottom),
                    tooltip: 'Bottom',
                  ),
                ],
                selected: {look.origin},
                onSelectionChanged: (value) {
                  if (value.isEmpty) return;
                  polar.setOrigin(value.first);
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'One full circle is',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('24 hours')),
                  ButtonSegment(value: true, label: Text('12 hours')),
                ],
                selected: {look.hours12},
                onSelectionChanged: (value) {
                  if (value.isEmpty) return;
                  polar.setHours12(value.first);
                },
              ),
            ],
          ),
        ),
        SwitchListTile(
          title: const Text('Track background'),
          value: look.trackBackground,
          onChanged: polar.setTrackBackground,
        ),
        SwitchListTile(
          title: const Text('12 o’clock line'),
          value: look.originLine,
          onChanged: polar.setOriginLine,
        ),
      ],
    );
  }
}

class _OriginGlyph extends StatelessWidget {
  final PolarClockOrigin origin;

  const _OriginGlyph(this.origin);

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(
        painter: _OriginGlyphPainter(origin: origin, color: color),
      ),
    );
  }
}

class _OriginGlyphPainter extends CustomPainter {
  final PolarClockOrigin origin;
  final Color color;

  _OriginGlyphPainter({required this.origin, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2 - 1.2;
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35;
    canvas.drawCircle(c, r, ring);

    final angle = switch (origin) {
      PolarClockOrigin.left => math.pi,
      PolarClockOrigin.top => -math.pi / 2,
      PolarClockOrigin.right => 0.0,
      PolarClockOrigin.bottom => math.pi / 2,
    };
    final inner = Offset(
      c.dx + math.cos(angle) * r * 0.42,
      c.dy + math.sin(angle) * r * 0.42,
    );
    final outer = Offset(
      c.dx + math.cos(angle) * r,
      c.dy + math.sin(angle) * r,
    );
    final tick = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(inner, outer, tick);
    canvas.drawCircle(
      outer,
      2.1,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _OriginGlyphPainter oldDelegate) {
    return oldDelegate.origin != origin || oldDelegate.color != color;
  }
}

List<ScheduledTask> _polarPreviewTasks() {
  final day = DateTime(2026, 1, 1);
  ScheduledTask band(String id, Color color, int startHour, int endHour) {
    return ScheduledTask(
      task: Task(
        id: id,
        label: id,
        color: color,
        startTime: TimeOfDay(hour: startHour, minute: 0),
        endTime: TimeOfDay(hour: endHour, minute: 0),
        startDate: day,
      ),
      date: day,
    );
  }

  return [
    band('preview-a', const Color(0xFF5B8DEF), 0, 16),
    band('preview-b', const Color(0xFF34C759), 8, 20),
    band('preview-c', const Color(0xFFFF9F0A), 14, 22),
  ];
}

void _stub(BuildContext context, String message) {
  showChangeToast(context, message: message);
}

void _loadDemoAndGoHome(
  BuildContext context,
  TaskProvider tasks,
  DemoScheduleKind kind,
  String name,
) {
  final undo = tasks.loadDemoSchedule(kind);
  goToTodayTab();
  Navigator.of(context).popUntil((route) => route.isFirst);
  final messenger = appMessengerKey.currentState;
  if (messenger != null) {
    showChangeToastOn(
      messenger,
      message: 'Loaded $name',
      onUndo: undo,
    );
  }
}

Future<void> _confirmClear(BuildContext context, TaskProvider tasks) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete all data?'),
      content: const Text(
        'This removes every task and history on this device. You can undo once from the toast.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final undo = tasks.clearAllData();
  showChangeToast(
    context,
    message: 'Cleared all data',
    onUndo: undo,
  );
}
