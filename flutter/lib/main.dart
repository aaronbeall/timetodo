import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timetodo/data/local_task_store.dart';
import 'package:timetodo/providers/task_provider.dart';
import 'package:timetodo/screens/today_screen.dart';
import 'package:timetodo/screens/tasks_screen.dart';
import 'package:timetodo/screens/calendar_screen.dart';
import 'package:timetodo/screens/reports_screen.dart';
import 'package:timetodo/models/task.dart';

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
    return ChangeNotifierProvider(
      create: (_) {
        final provider = TaskProvider(LocalTaskStore());
        provider.load();
        return provider;
      },
      child: MaterialApp(
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
        home: const MainScreen(),
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
  String? _revealTaskId;
  int _revealTick = 0;

  void _openTaskEditor(Task task) {
    setState(() {
      _currentIndex = 1;
      _revealTaskId = task.id;
      _revealTick++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          TodayScreen(onEditTask: _openTaskEditor),
          TasksScreen(
            focusTick: _tasksFocusTick,
            isActive: _currentIndex == 1,
            revealTaskId: _revealTaskId,
            revealTick: _revealTick,
          ),
          CalendarScreen(onEditTask: _openTaskEditor),
          const ReportsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
            if (index == 1) {
              _tasksFocusTick++;
            }
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_outlined),
            selectedIcon: Icon(Icons.task),
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
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}
