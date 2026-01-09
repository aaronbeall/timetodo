import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:timetodo/models/task.dart';

class _TaskRange {
  final Task task;
  final int start; // minutes from midnight
  final int end; // minutes from midnight

  _TaskRange({
    required this.task,
    required this.start,
    required this.end,
  });
}

class PolarClock extends StatelessWidget {
  final TimeOfDay currentTime;
  final List<Task> tasks;
  final double size;

  const PolarClock({
    super.key,
    required this.currentTime,
    required this.tasks,
    this.size = 300,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: PolarClockPainter(
          currentTime: currentTime,
          tasks: tasks,
        ),
      ),
    );
  }
}

class PolarClockPainter extends CustomPainter {
  final TimeOfDay currentTime;
  final List<Task> tasks;

  PolarClockPainter({
    required this.currentTime,
    required this.tasks,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // Draw 24-hour track (outermost)
    _drawHourTrack(canvas, center, radius, currentTime);

    // Get active tasks and assign them to tracks based on overlaps
    final activeTasks = tasks
        .where((t) => !t.isAllDay && !t.isCompleted && t.startTime != null && t.endTime != null)
        .toList();

    if (activeTasks.isEmpty) return;

    // Assign tasks to tracks to avoid overlaps
    final taskTracks = _assignTasksToTracks(activeTasks);
    final maxTracks = taskTracks.length;
    
    if (maxTracks == 0) return;

    final taskRadius = radius * 0.7;
    final availableRadius = radius - taskRadius;
    final taskTrackWidth = availableRadius / (maxTracks + 1);

    // Draw each track
    taskTracks.forEach((trackIndex, trackTasks) {
      final trackRadius = taskRadius + (trackIndex + 1) * taskTrackWidth;
      for (final task in trackTasks) {
        _drawTaskTrack(canvas, center, trackRadius, taskTrackWidth * 0.8, task);
      }
    });
  }

  Map<int, List<Task>> _assignTasksToTracks(List<Task> tasks) {
    // Convert tasks to time ranges for easier overlap detection
    final taskRanges = tasks.map((task) {
      final start = task.startTime!.hour * 60 + task.startTime!.minute;
      final end = task.endTime!.hour * 60 + task.endTime!.minute;
      return _TaskRange(task: task, start: start, end: end);
    }).toList();

    // Sort by start time
    taskRanges.sort((a, b) => a.start.compareTo(b.start));

    final Map<int, List<Task>> tracks = {};
    final List<List<_TaskRange>> trackRanges = [];

    for (final taskRange in taskRanges) {
      // Find the first track where this task doesn't overlap
      int trackIndex = -1;
      for (int i = 0; i < trackRanges.length; i++) {
        bool overlaps = false;
        for (final existingRange in trackRanges[i]) {
          if (_rangesOverlap(taskRange, existingRange)) {
            overlaps = true;
            break;
          }
        }
        if (!overlaps) {
          trackIndex = i;
          break;
        }
      }

      // If no track found, create a new one
      if (trackIndex == -1) {
        trackIndex = trackRanges.length;
        trackRanges.add([]);
        tracks[trackIndex] = [];
      }

      trackRanges[trackIndex].add(taskRange);
      tracks[trackIndex]!.add(taskRange.task);
    }

    return tracks;
  }

  bool _rangesOverlap(_TaskRange a, _TaskRange b) {
    // Handle midnight wrap-around
    if (a.start <= a.end && b.start <= b.end) {
      // Both ranges are within the same day
      return !(a.end <= b.start || b.end <= a.start);
    } else if (a.start > a.end && b.start > b.end) {
      // Both wrap around midnight
      return true;
    } else if (a.start > a.end) {
      // Only a wraps around
      return !(a.end <= b.start && b.end <= a.start);
    } else {
      // Only b wraps around
      return !(b.end <= a.start && a.end <= b.start);
    }
  }

  void _drawHourTrack(
    Canvas canvas,
    Offset center,
    double radius,
    TimeOfDay currentTime,
  ) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;

    // Draw full circle track
    canvas.drawCircle(center, radius, paint);

    // Draw filled portion up to current time
    final currentMinutes = currentTime.hour * 60 + currentTime.minute;
    final totalMinutes = 24 * 60;
    final progress = currentMinutes / totalMinutes;

    final filledPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;

    if (progress > 0) {
      final sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // Start at top (12 o'clock)
        sweepAngle,
        false,
        filledPaint,
      );
    }
  }

  void _drawTaskTrack(
    Canvas canvas,
    Offset center,
    double radius,
    double width,
    Task task,
  ) {
    if (task.startTime == null || task.endTime == null) return;

    final paint = Paint()
      ..color = task.color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    final startMinutes = task.startTime!.hour * 60 + task.startTime!.minute;
    final endMinutes = task.endTime!.hour * 60 + task.endTime!.minute;

    final startAngle = (startMinutes / (24 * 60)) * 2 * math.pi - math.pi / 2;
    double sweepAngle;

    if (endMinutes > startMinutes) {
      sweepAngle = ((endMinutes - startMinutes) / (24 * 60)) * 2 * math.pi;
    } else {
      // Task spans midnight
      sweepAngle = ((24 * 60 - startMinutes + endMinutes) / (24 * 60)) *
          2 *
          math.pi;
    }

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(PolarClockPainter oldDelegate) {
    return oldDelegate.currentTime != currentTime ||
        oldDelegate.tasks != tasks;
  }
}
