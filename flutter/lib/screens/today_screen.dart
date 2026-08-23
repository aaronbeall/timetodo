import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:timetodo/data/demo_schedule.dart';
import 'package:timetodo/models/task.dart';
import 'package:timetodo/providers/task_provider.dart';
import 'package:timetodo/widgets/polar_clock.dart';
import 'package:timetodo/widgets/task_list_item.dart';
import 'package:timetodo/widgets/add_task_dialog.dart';
import 'package:timetodo/widgets/change_toast.dart';
import 'package:timetodo/widgets/flip_host.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  static const _minClock = 76.0;
  /// Fan-out may start once this much of the stack (from its top) is on-screen.
  static const _fanStartCapItems = 2.0;
  /// Scroll distance over which the stack goes from collapsed to fully fanned.
  static const _fanScrollItems = 5.0;

  TimeOfDay _currentTime = TimeOfDay.now();
  DateTime _currentDate = DateTime.now();
  final _scrollController = ScrollController();
  final _fanKey = GlobalKey();
  final _fanT = ValueNotifier(0.0);
  final _fanTail = ValueNotifier(0.0);
  Timer? _timer;
  double _viewportH = 0;
  double _collapsedH = 0;
  double _travel = 1;
  int _fanCount = 0;
  double? _fanDocTop;
  bool? _fanClippedAtRest;
  final _flipKeys = <String, GlobalKey>{};

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
    _scrollController.addListener(_updateFanFromScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateFanFromScroll();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.removeListener(_updateFanFromScroll);
    _fanT.dispose();
    _fanTail.dispose();
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

  String _ordinalSuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  Widget _buildDateTitle(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.appBarTheme.titleTextStyle ??
        theme.textTheme.titleLarge ??
        const TextStyle(fontSize: 20, fontWeight: FontWeight.w500);
    final onSurface = base.color ?? theme.colorScheme.onSurface;
    final weekday = DateFormat.EEEE().format(_currentDate);
    final month = DateFormat.MMMM().format(_currentDate);
    final day = _currentDate.day;
    final primarySize = (base.fontSize ?? 20) * 0.92;
    final suffixSize = primarySize * 0.52;
    final secondary = base.copyWith(
      fontSize: primarySize * 0.62,
      fontWeight: FontWeight.w400,
      color: onSurface.withOpacity(0.4),
      height: 1.15,
      letterSpacing: 0.15,
    );
    final primary = base.copyWith(
      fontSize: primarySize,
      fontWeight: FontWeight.w500,
      height: 1.15,
    );

    return IntrinsicWidth(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(weekday, style: secondary),
              const SizedBox(width: 16),
              const Spacer(),
              Text('${_currentDate.year}', style: secondary),
            ],
          ),
          Text.rich(
            TextSpan(
              style: primary,
              children: [
                TextSpan(text: '$month $day'),
                WidgetSpan(
                  alignment: PlaceholderAlignment.top,
                  child: Transform.translate(
                    offset: const Offset(1, 1),
                    child: Text(
                      _ordinalSuffix(day),
                      style: primary.copyWith(
                        fontSize: suffixSize,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _updateFanFromScroll() {
    if (!mounted || _fanCount == 0) {
      _fanT.value = 0;
      _fanTail.value = 0;
      return;
    }
    final offset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    final reduce =
        mounted && MediaQuery.maybeOf(context)?.disableAnimations == true;
    final t = _fanProgress(
      offset: offset,
      viewportH: _viewportH,
      collapsedH: _collapsedH,
      layoutTravel: _travel,
      reduce: reduce,
    );
    _fanT.value = t;
    _fanTail.value = _fanTailHeight(
      t: t,
      travel: _travel,
      viewportH: _viewportH,
      collapsedH: _collapsedH,
    );
  }

  double _fanProgress({
    required double offset,
    required double viewportH,
    required double collapsedH,
    required double layoutTravel,
    required bool reduce,
  }) {
    if (reduce || layoutTravel <= 0) return 1;
    final itemH = _UpcomingDeck.itemExtent;
    final startDepth = math.min(collapsedH, itemH * _fanStartCapItems);
    final animTravel = math.max(
      1.0,
      math.min(layoutTravel, itemH * _fanScrollItems),
    );
    final fanContext = _fanKey.currentContext;
    if (fanContext == null) return 0;
    final fanBox = fanContext.findRenderObject();
    final scrollable = Scrollable.maybeOf(fanContext);
    if (fanBox is! RenderBox || !fanBox.hasSize || scrollable == null) {
      return 0;
    }
    final viewportBox = scrollable.context.findRenderObject();
    if (viewportBox is! RenderBox) return 0;
    final fanTop = fanBox.localToGlobal(Offset.zero).dy -
        viewportBox.localToGlobal(Offset.zero).dy;
    final docTop = fanTop + offset;
    if (_fanDocTop == null || offset.abs() < 0.5) {
      _fanDocTop = docTop;
      _fanClippedAtRest = docTop + startDepth > viewportH + 1;
    }
    final clipped = _fanClippedAtRest ?? false;
    final restTop = _fanDocTop ?? docTop;
    final raw = clipped
        ? (offset - (restTop + startDepth - viewportH)) / animTravel
        : offset / animTravel;
    return raw.clamp(0.0, 1.0);
  }

  double _fanTailHeight({
    required double t,
    required double travel,
    required double viewportH,
    required double collapsedH,
  }) {
    final docTop = _fanDocTop ?? collapsedH;
    const addH = 56.0;
    const bottomPad = 32.0;
    final slack = math.max(
      0.0,
      viewportH - docTop - collapsedH - addH - bottomPad,
    );
    return slack + travel * (1 - t);
  }

  int _startMinutes(Task task) {
    if (task.startTime == null) return 24 * 60;
    return task.startTime!.hour * 60 + task.startTime!.minute;
  }

  int _recencyMinutes(Task task) {
    final TimeOfDay? mark = task.endTime ?? task.startTime;
    if (mark == null) return 24 * 60;
    final now = _currentTime.hour * 60 + _currentTime.minute;
    final at = mark.hour * 60 + mark.minute;
    var ago = now - at;
    if (ago < 0) ago += 24 * 60;
    return ago;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 64,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: SizedBox(
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _buildDateTitle(context),
              Align(
                alignment: Alignment.centerRight,
                child: PopupMenuButton<DemoScheduleKind>(
                  tooltip: 'Test schedule',
                  onSelected: (kind) {
                    final undo =
                        context.read<TaskProvider>().loadDemoSchedule(kind);
                    final label = switch (kind) {
                      DemoScheduleKind.light => 'Light day',
                      DemoScheduleKind.typical => 'Typical day',
                      DemoScheduleKind.packed => 'Packed day',
                    };
                    showChangeToast(
                      context,
                      message: 'Loaded $label',
                      onUndo: undo,
                    );
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
              ),
            ],
          ),
        ),
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
              .where((t) => t.isUpcoming(_currentTime))
              .toList()
            ..sort((a, b) => _startMinutes(a).compareTo(_startMinutes(b)));
          final allDayOpen = todayTasks
              .where((t) => t.isAllDay && !t.isCompleted && !t.isCanceled)
              .toList();
          final settled = [
            ...timedOpen.where((t) => t.isMissed(_currentTime)),
            ...todayTasks.where((t) => t.isCompleted || t.isCanceled),
          ]..sort((a, b) => _recencyMinutes(a).compareTo(_recencyMinutes(b)));
          final fanTasks = [...upcoming, ...settled];

          final liveIds = todayTasks.map((t) => t.id).toSet();
          _flipKeys.removeWhere((id, _) => !liveIds.contains(id));

          Widget item(
            Task task, {
            bool shadow = false,
            required String token,
          }) {
            return FlipHost(
              key: _flipKeys.putIfAbsent(task.id, GlobalKey.new),
              token: token,
              child: TaskListItem(
                task: task,
                currentTime: _currentTime,
                showShadow: shadow,
                onSnooze: () {
                  final undo = taskProvider.snoozeTask(task.id);
                  showChangeToast(
                    context,
                    message: 'Snoozed ${task.label} 15 min',
                    onUndo: undo,
                  );
                },
                onExtend: () {
                  final undo = taskProvider.extendTask(task.id);
                  showChangeToast(
                    context,
                    message: 'Extended ${task.label} 15 min',
                    onUndo: undo,
                  );
                },
                onComplete: () {
                  final undo = taskProvider.completeTask(task.id);
                  showChangeToast(
                    context,
                    message: 'Completed ${task.label}',
                    onUndo: undo,
                  );
                },
                onCancel: () {
                  final undo = taskProvider.cancelTask(task.id);
                  showChangeToast(
                    context,
                    message: 'Skipped ${task.label}',
                    onUndo: undo,
                  );
                },
                onDoNow: () {
                  final undo =
                      taskProvider.doNowTask(task.id, _currentTime);
                  showChangeToast(
                    context,
                    message: 'Started ${task.label} now',
                    onUndo: undo,
                  );
                  _scrollToTop();
                },
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final maxClock = math.min(
                constraints.maxWidth - 24,
                constraints.maxHeight * 0.62,
              );
              const frameInset = 5.0;
              const pipPad = 12.0;
              final spacerHeight = maxClock + 16;
              final hasConnector =
                  (active.isNotEmpty || allDayOpen.isNotEmpty) &&
                      fanTasks.isNotEmpty;
              final n = fanTasks.length;
              final fanExtents = fanTasks
                  .map(TaskListItem.stackExtentFor)
                  .toList(growable: false);
              final collapsed = n == 0
                  ? 0.0
                  : _UpcomingDeck.collapsedHeight(fanExtents);
              final expanded =
                  n == 0 ? 0.0 : _UpcomingDeck.expandedHeight(fanExtents);
              final travel = math.max(0.0, expanded - collapsed);

              if (_fanCount != n) {
                _fanCount = n;
                _fanDocTop = null;
                _fanClippedAtRest = null;
              }
              _viewportH = constraints.maxHeight;
              _collapsedH = collapsed;
              _travel = math.max(1.0, travel);

              final fanChildren = [
                for (var i = 0; i < fanTasks.length; i++)
                  item(
                    fanTasks[i],
                    shadow: true,
                    token:
                        'fan:$i:${TaskListItem.stackExtentFor(fanTasks[i])}:${_startMinutes(fanTasks[i])}',
                  ),
              ];

              WidgetsBinding.instance.addPostFrameCallback((_) {
                _updateFanFromScroll();
              });

              return Stack(
                    children: [
                      CustomScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: SizedBox(height: spacerHeight),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                ...[
                                  for (var i = 0; i < active.length; i++)
                                    item(
                                      active[i],
                                      token:
                                          'active:$i:${_startMinutes(active[i])}',
                                    ),
                                ],
                                ...[
                                  for (var i = 0; i < allDayOpen.length; i++)
                                    item(
                                      allDayOpen[i],
                                      token: 'allday:$i',
                                    ),
                                ],
                                AnimatedSize(
                                  duration: MediaQuery.disableAnimationsOf(
                                            context,
                                          )
                                      ? Duration.zero
                                      : kTaskListAnimDuration,
                                  curve: kTaskListAnimCurve,
                                  child: hasConnector
                                      ? const _ActiveUpcomingConnector()
                                      : const SizedBox.shrink(),
                                ),
                                if (fanTasks.isNotEmpty)
                                  KeyedSubtree(
                                    key: _fanKey,
                                    child: ValueListenableBuilder<double>(
                                      valueListenable: _fanT,
                                      builder: (context, t, _) {
                                        return _UpcomingDeck(
                                          t: t,
                                          extents: fanExtents,
                                          children: fanChildren,
                                        );
                                      },
                                    ),
                                  ),
                                _buildAddTaskGhost(context, taskProvider),
                                ValueListenableBuilder<double>(
                                  valueListenable: _fanTail,
                                  builder: (context, tail, _) {
                                    if (tail <= 0) {
                                      return const SizedBox.shrink();
                                    }
                                    return SizedBox(height: tail);
                                  },
                                ),
                              ]),
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
                          final remaining = (spacerHeight - offset)
                              .clamp(0.0, spacerHeight);
                          final size = remaining.clamp(_minClock, maxClock);
                          final clockT = maxClock == _minClock
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
                              : math.max(
                                  0.0,
                                  (remaining - size - bezel) / 2,
                                );
                          final timeScale =
                              (size / maxClock).clamp(0.42, 1.0);
                          final theme = Theme.of(context);

                          return Positioned(
                            left: left,
                            top: top,
                            child: IgnorePointer(
                              ignoring: clockT < 0.82,
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
                                    padding:
                                        EdgeInsets.all(frameInset * frameT),
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
                                              child:
                                                  _buildClockCenter(context),
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

class _ActiveUpcomingConnector extends StatelessWidget {
  const _ActiveUpcomingConnector();

  @override
  Widget build(BuildContext context) {
    final color = Color.alphaBlend(
      Theme.of(context).colorScheme.onSurface.withOpacity(0.16),
      Theme.of(context).scaffoldBackgroundColor,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: CustomPaint(
          size: const Size(8, 18),
          painter: _ConnectorPainter(color),
        ),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  final Color color;

  _ConnectorPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final cx = size.width / 2;
    const radius = 2.25;
    const lineWidth = 2.0;
    final top = 0.0;
    final bottom = size.height - radius;
    canvas.drawRRect(
      RRect.fromLTRBR(
        cx - lineWidth / 2,
        top,
        cx + lineWidth / 2,
        bottom,
        const Radius.circular(1),
      ),
      paint,
    );
    canvas.drawCircle(Offset(cx, bottom), radius, paint);
  }

  @override
  bool shouldRepaint(_ConnectorPainter oldDelegate) => oldDelegate.color != color;
}

class _UpcomingDeck extends StatefulWidget {
  static const itemExtent = TaskListItem.stackExtent;
  static const _baseScale = 0.96;
  static const _focal = 880.0;
  static const _zStep = 40.0;
  static const _yPerZ = 0.32;
  static const _tiltPerZ = 0.0019;
  static const _maxTilt = 0.22;
  static const _perspective = 0.0011;

  static double collapsedHeight(List<double> extents) {
    if (extents.isEmpty) return 0;
    return extents.first + math.max(0, extents.length - 1) * _zStep * _yPerZ;
  }

  static double expandedHeight(List<double> extents) {
    var sum = 0.0;
    for (final e in extents) {
      sum += e;
    }
    return sum;
  }

  final double t;
  final List<double> extents;
  final List<Widget> children;

  const _UpcomingDeck({
    required this.t,
    required this.extents,
    required this.children,
  });

  @override
  State<_UpcomingDeck> createState() => _UpcomingDeckState();
}

class _UpcomingDeckState extends State<_UpcomingDeck> {
  late List<double> _heights;

  @override
  void initState() {
    super.initState();
    _heights = List<double>.from(widget.extents);
  }

  @override
  void didUpdateWidget(_UpcomingDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.extents.length != widget.extents.length) {
      _heights = List<double>.from(widget.extents);
    }
  }

  void _reportHeight(int index, double height) {
    if (index < 0 || index >= _heights.length) return;
    if ((height - _heights[index]).abs() < 0.25) return;
    setState(() {
      _heights[index] = height;
    });
  }

  @override
  Widget build(BuildContext context) {
    final children = widget.children;
    if (children.isEmpty) return const SizedBox.shrink();
    final n = children.length;
    while (_heights.length < n) {
      _heights.add(_UpcomingDeck.itemExtent);
    }
    if (_heights.length > n) {
      _heights = _heights.sublist(0, n);
    }
    final t = widget.t;
    final collapsed = _UpcomingDeck.collapsedHeight(_heights);
    final expanded = _UpcomingDeck.expandedHeight(_heights);
    final height = collapsed + (expanded - collapsed) * t;

    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          for (var i = n - 1; i >= 0; i--)
            Positioned(
              top: _topFor(i, t),
              left: 0,
              right: 0,
              child: Transform(
                alignment: Alignment.topCenter,
                transform: _paperTransform(_zFor(i, t), t),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      _shadowFor(
                        _zFor(i, t),
                        Theme.of(context).brightness,
                      ),
                    ],
                  ),
                  child: RepaintBoundary(
                    child: _MeasureHeight(
                      onChange: (h) => _reportHeight(i, h),
                      child: children[i],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _zFor(int i, double t) => i * _UpcomingDeck._zStep * (1 - t);

  double _topFor(int i, double t) {
    var y = 0.0;
    for (var j = 0; j < i; j++) {
      y += _heights[j];
    }
    return _zFor(i, t) * _UpcomingDeck._yPerZ + y * t;
  }

  BoxShadow _shadowFor(double z, Brightness brightness) {
    final depth = (z / (_UpcomingDeck._zStep * 7)).clamp(0.0, 1.0);
    final dark = brightness == Brightness.dark;
    final opacity = (dark ? 0.16 : 0.045) + depth * (dark ? 0.34 : 0.18);
    return BoxShadow(
      color: Colors.black.withOpacity(opacity),
      blurRadius: 8 + depth * 10,
      offset: Offset(0, 2 + depth * 4),
    );
  }

  Matrix4 _paperTransform(double z, double t) {
    final rest = 1.0 - (1.0 - _UpcomingDeck._baseScale) * (1 - t);
    final scale = rest * _UpcomingDeck._focal / (_UpcomingDeck._focal + z);
    final tilt = math.min(z * _UpcomingDeck._tiltPerZ, _UpcomingDeck._maxTilt);
    return Matrix4.identity()
      ..setEntry(3, 2, _UpcomingDeck._perspective)
      ..rotateX(tilt)
      ..scale(scale, scale);
  }
}

class _MeasureHeight extends SingleChildRenderObjectWidget {
  final ValueChanged<double> onChange;

  const _MeasureHeight({
    required this.onChange,
    required Widget child,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMeasureHeight(onChange);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderMeasureHeight renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureHeight extends RenderProxyBox {
  _RenderMeasureHeight(this.onChange);

  ValueChanged<double> onChange;
  double? _last;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (_last != null && (height - _last!).abs() < 0.25) return;
    _last = height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onChange(height);
    });
  }
}
