import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timetodo/data/local_task_store.dart';
import 'package:timetodo/providers/task_provider.dart';
import 'package:timetodo/providers/theme_controller.dart';
import 'package:timetodo/screens/today_screen.dart';
import 'package:timetodo/screens/tasks_screen.dart';
import 'package:timetodo/screens/calendar_screen.dart';
import 'package:timetodo/screens/reports_screen.dart';
import 'package:timetodo/models/task.dart';
import 'package:timetodo/app_navigation.dart';
import 'package:timetodo/widgets/polar_nav_icon.dart';
import 'package:timetodo/widgets/sliding_indexed_stack.dart';

void main() {
  runApp(const TimeToDoApp());
}

SnackBarThemeData _snackBarTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Colors.deepPurple,
    brightness: brightness,
  );
  return SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: scheme.surfaceContainerHigh,
    contentTextStyle: TextStyle(color: scheme.onSurface),
    actionTextColor: scheme.primary,
    elevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
  );
}

class TimeToDoApp extends StatelessWidget {
  const TimeToDoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final theme = ThemeController();
            theme.load();
            return theme;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = TaskProvider(LocalTaskStore());
            provider.load();
            return provider;
          },
        ),
      ],
      child: Consumer<ThemeController>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: 'TimeToDo',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.deepPurple,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              snackBarTheme: _snackBarTheme(Brightness.light),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.deepPurple,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              snackBarTheme: _snackBarTheme(Brightness.dark),
            ),
            themeMode: theme.mode,
            scaffoldMessengerKey: appMessengerKey,
            home: const MainScreen(),
          );
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _tasksFocusTick = 0;
  int _calendarResetTick = 0;
  String? _revealTaskId;
  int _revealTick = 0;

  @override
  void initState() {
    super.initState();
    homeTabIndex.value = _currentIndex;
    homeTabIndex.addListener(_onHomeTab);
  }

  @override
  void dispose() {
    homeTabIndex.removeListener(_onHomeTab);
    super.dispose();
  }

  void _onHomeTab() {
    final index = homeTabIndex.value;
    if (!mounted || index == _currentIndex) return;
    _goToTab(index, fromNotifier: true);
  }

  void _goToTab(int index, {bool fromNotifier = false}) {
    if (index == _currentIndex) {
      if (index == 1) {
        setState(() => _tasksFocusTick++);
      } else if (index == 2) {
        setState(() => _calendarResetTick++);
      }
      return;
    }
    setState(() {
      _currentIndex = index;
      if (!fromNotifier) homeTabIndex.value = index;
      if (index == 1) {
        _tasksFocusTick++;
      } else if (index == 2) {
        _calendarResetTick++;
      }
    });
  }

  void _openTaskEditor(Task task) {
    setState(() {
      _currentIndex = 1;
      homeTabIndex.value = 1;
      _revealTaskId = task.id;
      _revealTick++;
      _tasksFocusTick++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goToTab(0);
      },
      child: Scaffold(
        body: SlidingIndexedStack(
          index: _currentIndex,
          children: [
            TodayScreen(onEditTask: _openTaskEditor),
            TasksScreen(
              focusTick: _tasksFocusTick,
              isActive: _currentIndex == 1,
              revealTaskId: _revealTaskId,
              revealTick: _revealTick,
            ),
            CalendarScreen(
              onEditTask: _openTaskEditor,
              resetTick: _calendarResetTick,
            ),
            const ReportsScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _goToTab,
          destinations: const [
            NavigationDestination(
              icon: PolarNavIcon(),
              selectedIcon: PolarNavIcon(selected: true),
              label: 'Today',
            ),
            NavigationDestination(
              icon: Icon(Icons.checklist_outlined),
              selectedIcon: Icon(Icons.checklist),
              label: 'Tasks',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Calendar',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Stats',
            ),
          ],
        ),
      ),
    );
  }
}
