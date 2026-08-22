import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:timetodo/data/demo_schedule.dart';
import 'package:timetodo/models/task.dart';
import 'package:timetodo/providers/task_provider.dart';
import 'package:timetodo/widgets/polar_clock.dart';
import 'package:timetodo/widgets/task_list_item.dart';
import 'package:timetodo/widgets/add_task_dialog.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  static const _minClock = 76.0;

  TimeOfDay _currentTime = TimeOfDay.now();
  DateTime _currentDate = DateTime.now();
  final _scrollController = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _currentTime = TimeOfDay.now();
        _currentDate = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  String _formatTimeNumber(TimeOfDay time) {
    final hour =
        time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatTimePeriod(TimeOfDay time) {
    return time.hour >= 12 ? 'PM' : 'AM';
  }

  bool _isPM(TimeOfDay time) {
    return time.hour >= 12;
  }

  String _formatDate(DateTime date) {
    return DateFormat("MMM d, ''yy").format(date);
  }

  int _startMinutes(Task task) {
    if (task.startTime == null) return 24 * 60;
    return task.startTime!.hour * 60 + task.startTime!.minute;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_formatDate(_currentDate)),
        elevation: 0,
        actions: [
          PopupMenuButton<DemoScheduleKind>(
            tooltip: 'Test schedule',
            onSelected: (kind) {
              context.read<TaskProvider>().loadDemoSchedule(kind);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: DemoScheduleKind.light,
                child: Text('Light day'),
              ),
              PopupMenuItem(
                value: DemoScheduleKind.typical,
                child: Text('Typical day'),
              ),
              PopupMenuItem(
                value: DemoScheduleKind.packed,
                child: Text('Packed day'),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('Test schedule'),
            ),
          ),
        ],
      ),
      body: Consumer<TaskProvider>(
        builder: (context, taskProvider, child) {
          final todayTasks = taskProvider.getTasksForToday();
          final timedOpen = todayTasks
              .where((t) =>
                  !t.isAllDay && !t.isCompleted && !t.isCanceled)
              .toList();
          final active = timedOpen
              .where((t) => t.isActive(_currentTime))
              .toList()
            ..sort((a, b) => _startMinutes(a).compareTo(_startMinutes(b)));
          final upcoming = timedOpen
              .where((t) => !t.isActive(_currentTime))
              .toList()
            ..sort((a, b) => _startMinutes(a).compareTo(_startMinutes(b)));
          final allDayOpen = todayTasks
              .where((t) => t.isAllDay && !t.isCompleted && !t.isCanceled)
              .toList();
          final settled = todayTasks
              .where((t) => t.isCompleted || t.isCanceled)
              .toList()
            ..sort((a, b) => _startMinutes(a).compareTo(_startMinutes(b)));

          Widget item(Task task) => TaskListItem(
                task: task,
                currentTime: _currentTime,
                onSnooze: () => taskProvider.snoozeTask(task.id),
                onExtend: () => taskProvider.extendTask(task.id),
                onComplete: () => taskProvider.completeTask(task.id),
                onCancel: () => taskProvider.cancelTask(task.id),
              );

          final listChildren = <Widget>[
            ...active.map(item),
            ...upcoming.map(
              (task) => _UpcomingScale(child: item(task)),
            ),
            ...allDayOpen.map(item),
            ...settled.map(item),
            _buildAddTaskGhost(context, taskProvider),
          ];

          return LayoutBuilder(
            builder: (context, constraints) {
              final maxClock = math.min(
                constraints.maxWidth - 24,
                constraints.maxHeight * 0.62,
              );
              const frameInset = 5.0;
              const pipPad = 12.0;
              final spacerHeight = maxClock + 16;

              return Stack(
                children: [
                  CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: SizedBox(height: spacerHeight),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate(listChildren),
                        ),
                      ),
                    ],
                  ),
                  AnimatedBuilder(
                    animation: _scrollController,
                    builder: (context, _) {
                      final offset = _scrollController.hasClients
                          ? _scrollController.offset
                          : 0.0;
                      final remaining =
                          (spacerHeight - offset).clamp(0.0, spacerHeight);
                      final size = remaining.clamp(_minClock, maxClock);
                      final t = maxClock == _minClock
                          ? 1.0
                          : ((maxClock - size) / (maxClock - _minClock))
                              .clamp(0.0, 1.0);
                      final docked = remaining <= _minClock;
                      final frameT = docked ? 1.0 : 0.0;
                      final bezel = frameInset * 2 * frameT;
                      final left =
                          (constraints.maxWidth - size - bezel) / 2;
                      final top = docked
                          ? pipPad
                          : math.max(0.0, (remaining - size - bezel) / 2);
                      final timeScale =
                          (size / maxClock).clamp(0.42, 1.0);
                      final theme = Theme.of(context);

                      return Positioned(
                        left: left,
                        top: top,
                        child: IgnorePointer(
                          ignoring: t < 0.82,
                          child: GestureDetector(
                            onTap: _scrollToTop,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color.lerp(
                                  Colors.transparent,
                                  theme.colorScheme.surface,
                                  frameT,
                                ),
                                borderRadius: BorderRadius.circular(
                                  8 + 10 * frameT,
                                ),
                                border: Border.all(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.18 * frameT),
                                  width: 1.5 * frameT,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withOpacity(0.22 * frameT),
                                    blurRadius: 18 * frameT,
                                    offset: Offset(0, 6 * frameT),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(frameInset * frameT),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    6 + 6 * frameT,
                                  ),
                                  child: SizedBox(
                                    width: size,
                                    height: size,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        PolarClock(
                                          currentTime: _currentTime,
                                          tasks: todayTasks,
                                          size: size,
                                        ),
                                        Transform.scale(
                                          scale: timeScale,
                                          child: _buildClockCenter(context),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAddTaskGhost(BuildContext context, TaskProvider taskProvider) {
    final muted = Theme.of(context).colorScheme.onSurface.withOpacity(0.35);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAddTaskDialog(context, taskProvider),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.add_rounded, size: 18, color: muted),
                const SizedBox(width: 8),
                Text(
                  'Add task',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: muted,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClockCenter(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface,
        ) ??
        const TextStyle();
    final periodSize = (baseStyle.fontSize ?? 28) * 0.5;
    final periodStyle = baseStyle.copyWith(
      fontSize: periodSize,
      color: baseStyle.color?.withOpacity(0.5),
    );

    return _isPM(_currentTime)
        ? Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(_formatTimeNumber(_currentTime), style: baseStyle),
              Text(_formatTimePeriod(_currentTime), style: periodStyle),
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_formatTimeNumber(_currentTime), style: baseStyle),
              Transform.translate(
                offset: const Offset(0, 1),
                child: Text(_formatTimePeriod(_currentTime), style: periodStyle),
              ),
            ],
          );
  }

  void _showAddTaskDialog(BuildContext context, TaskProvider taskProvider) {
    showDialog(
      context: context,
      builder: (context) => AddTaskDialog(
        initialDate: DateTime.now(),
        initialStartTime: _currentTime,
      ),
    );
  }
}

class _UpcomingScale extends StatelessWidget {
  static const scale = 0.96;

  final Widget child;

  const _UpcomingScale({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: constraints.maxWidth * scale,
            child: FittedBox(
              fit: BoxFit.fitWidth,
              child: SizedBox(
                width: constraints.maxWidth,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
