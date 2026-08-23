import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timetodo/providers/task_provider.dart';
import 'package:timetodo/time_utils.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final today = DateTime.now();
    var weekDone = 0;
    var weekTotal = 0;
    for (var i = 0; i < 7; i++) {
      final day = dateOnly(today).subtract(Duration(days: i));
      weekDone += provider.completedCountOn(day);
      weekTotal += provider.scheduledCountOn(day);
    }
    var monthDone = 0;
    var monthTotal = 0;
    for (var i = 0; i < 30; i++) {
      final day = dateOnly(today).subtract(Duration(days: i));
      monthDone += provider.completedCountOn(day);
      monthTotal += provider.scheduledCountOn(day);
    }
    final streak = provider.completionStreak();
    final active = provider.activeTasks.length;
    final archived = provider.archivedTasks.length;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'At a glance',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _stat(context, 'Active tasks', '$active'),
          _stat(context, 'Archived', '$archived'),
          _stat(context, 'Streak', streak == 1 ? '1 day' : '$streak days'),
          const SizedBox(height: 24),
          Text(
            'Completions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _stat(
            context,
            'Last 7 days',
            '$weekDone / $weekTotal',
            detail: weekTotal == 0
                ? 'No scheduled tasks'
                : '${((weekDone / weekTotal) * 100).round()}% resolved',
          ),
          _stat(
            context,
            'Last 30 days',
            '$monthDone / $monthTotal',
            detail: monthTotal == 0
                ? 'No scheduled tasks'
                : '${((monthDone / monthTotal) * 100).round()}% resolved',
          ),
          const SizedBox(height: 24),
          Text(
            'Recent days',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 6; i >= 0; i--)
                Expanded(
                  child: _bar(
                    context,
                    provider,
                    dateOnly(today).subtract(Duration(days: i)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(
    BuildContext context,
    String label,
    String value, {
    String? detail,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyMedium),
                if (detail != null)
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(BuildContext context, TaskProvider provider, DateTime day) {
    final total = provider.scheduledCountOn(day);
    final done = provider.completedCountOn(day);
    final t = total == 0 ? 0.0 : done / total;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Container(
            height: 72,
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: t.clamp(0.08, 1),
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(
                        total == 0 ? 0.15 : 0.85,
                      ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${day.day}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
