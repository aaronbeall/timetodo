import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timetodo/data/demo_schedule.dart';
import 'package:timetodo/providers/task_provider.dart';
import 'package:timetodo/providers/theme_controller.dart';
import 'package:timetodo/screens/about_screen.dart';
import 'package:timetodo/widgets/change_toast.dart';

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
            onTap: () {
              final undo = tasks.loadDemoSchedule(DemoScheduleKind.light);
              showChangeToast(
                context,
                message: 'Loaded Light day',
                onUndo: undo,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_view_day_outlined),
            title: const Text('Typical day'),
            subtitle: const Text('Load a typical test schedule'),
            onTap: () {
              final undo = tasks.loadDemoSchedule(DemoScheduleKind.typical);
              showChangeToast(
                context,
                message: 'Loaded Typical day',
                onUndo: undo,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.view_week_outlined),
            title: const Text('Packed day'),
            subtitle: const Text('Load a packed test schedule'),
            onTap: () {
              final undo = tasks.loadDemoSchedule(DemoScheduleKind.packed);
              showChangeToast(
                context,
                message: 'Loaded Packed day',
                onUndo: undo,
              );
            },
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

void _stub(BuildContext context, String message) {
  showChangeToast(context, message: message);
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
