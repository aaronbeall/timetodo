import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timetodo/widgets/change_toast.dart';

const kSupportEmail = 'support@metamodernmonkey.com';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Text(
            'TimeToDo',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'A time-based task manager.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Privacy',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'TimeToDo stores your tasks on this device only. There is no '
            'account, no cloud sync, and no analytics in this version. '
            'Nothing is sent to Meta Modern Monkey or anyone else unless '
            'you choose to export or share it yourself.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 28),
          Text(
            'Credits',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Made by Meta Modern Monkey.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 16),
          Text(
            'Support',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.mail_outline),
            title: const Text(kSupportEmail),
            subtitle: const Text('Tap to copy'),
            onTap: () async {
              await Clipboard.setData(const ClipboardData(text: kSupportEmail));
              if (!context.mounted) return;
              showChangeToast(context, message: 'Copied $kSupportEmail');
            },
          ),
        ],
      ),
    );
  }
}
