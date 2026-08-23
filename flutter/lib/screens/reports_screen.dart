import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timetodo/models/reports_snapshot.dart';
import 'package:timetodo/providers/task_provider.dart';
import 'package:timetodo/screens/settings_screen.dart';
import 'package:timetodo/time_utils.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<TaskProvider>().reportsSnapshot();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => openSettings(context),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          _StreakHero(streak: stats.streak),
          const SizedBox(height: 28),
          Text(
            'All time',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RateCard(
                  icon: Icons.check_circle_outline,
                  label: 'Completed',
                  caption: 'Skips excluded',
                  rate: stats.completionRate,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RateCard(
                  icon: Icons.skip_next_rounded,
                  label: 'Skipped',
                  caption: 'Open days excluded',
                  rate: stats.skipRate,
                  color: scheme.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${stats.completed} done · ${stats.skipped} skipped · ${stats.unresolved} open',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Last 14 days',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: _Sparkline(rates: stats.last14Rates),
          ),
          const SizedBox(height: 28),
          Text(
            'This week',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 112,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final day in stats.last7)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _DayStack(day: day),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _TaskStreaks(rows: stats.taskStreaks),
        ],
      ),
    );
  }
}

class _StreakHero extends StatelessWidget {
  final int streak;

  const _StreakHero({required this.streak});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lit = streak > 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer.withOpacity(lit ? 0.95 : 0.45),
            scheme.surfaceContainerHighest.withOpacity(0.4),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          children: [
            Icon(
              lit ? Icons.local_fire_department_rounded : Icons.nights_stay_outlined,
              size: 36,
              color: lit ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              '$streak',
              style: theme.textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.w800,
                height: 0.95,
                fontSize: 88,
                letterSpacing: -3,
                color: scheme.onSurface,
              ),
            ),
            Text(
              streak == 1 ? 'day streak' : 'day streak',
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              lit
                  ? 'Every scheduled task, done or skipped'
                  : 'Finish today to light it up',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RateCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String caption;
  final double? rate;
  final Color color;

  const _RateCard({
    required this.icon,
    required this.label,
    required this.caption,
    required this.rate,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final value = rate ?? 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 14),
            Text(
              rate == null ? '—' : '${(value * 100).round()}%',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              caption,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: rate ?? 0,
                minHeight: 6,
                color: color,
                backgroundColor: color.withOpacity(0.16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  final List<double?> rates;

  const _Sparkline({required this.rates});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return CustomPaint(
      painter: _SparklinePainter(rates: rates, color: color),
      child: const SizedBox.expand(),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double?> rates;
  final Color color;

  _SparklinePainter({required this.rates, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (rates.isEmpty) return;
    final n = rates.length;
    final gap = size.width / n;
    final track = Paint()
      ..color = color.withOpacity(0.14)
      ..style = PaintingStyle.fill;
    final fill = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < n; i++) {
      final x = i * gap + gap * 0.22;
      final w = gap * 0.56;
      canvas.drawRRect(
        RRect.fromLTRBR(x, 0, x + w, size.height, const Radius.circular(3)),
        track,
      );
      final rate = rates[i];
      if (rate == null) continue;
      final h = (rate.clamp(0.0, 1.0) * size.height).clamp(3.0, size.height);
      fill.color = color.withOpacity(0.35 + 0.65 * rate);
      canvas.drawRRect(
        RRect.fromLTRBR(
          x,
          size.height - h,
          x + w,
          size.height,
          const Radius.circular(3),
        ),
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.rates != rates || oldDelegate.color != color;
}

class _DayStack extends StatelessWidget {
  final DayReport day;

  const _DayStack({required this.day});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = isSameDay(day.day, DateTime.now());
    final letter = DateFormat.E().format(day.day)[0];
    return Column(
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.45),
              borderRadius: BorderRadius.circular(8),
            ),
            child: day.slices.isEmpty
                ? const SizedBox.expand()
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final slice in day.slices)
                          Expanded(
                            child: ColoredBox(color: _sliceColor(slice)),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          letter,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: today ? FontWeight.w800 : FontWeight.w500,
            color: today
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Color _sliceColor(DayTaskSlice slice) {
    if (slice.completed) return slice.color;
    if (slice.skipped) return slice.color.withOpacity(0.28);
    return slice.color.withOpacity(0.12);
  }
}

class _TaskStreaks extends StatelessWidget {
  final List<TaskStreakRow> rows;

  const _TaskStreaks({required this.rows});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (rows.isEmpty) {
      return Text(
        'Add tasks to see streaks for each one.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        initiallyExpanded: true,
        leading: Icon(Icons.whatshot_outlined, color: scheme.primary),
        title: Text(
          'Streaks by task',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        subtitle: Text(
          'Days in a row each task was done or skipped',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        children: [
          for (final row in rows) _TaskStreakLine(row: row),
        ],
      ),
    );
  }
}

class _TaskStreakLine extends StatelessWidget {
  final TaskStreakRow row;

  const _TaskStreakLine({required this.row});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = taskInkColor(row.task.color, theme.brightness);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: row.task.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              row.task.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ),
          Text(
            '${row.streak}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            row.streak == 1 ? 'day' : 'days',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
