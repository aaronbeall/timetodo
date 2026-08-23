import 'package:timetodo/models/task.dart';
import 'package:timetodo/models/task_occurrence.dart';

class TaskSnapshot {
  final List<Task> tasks;
  final List<TaskOccurrence> occurrences;

  const TaskSnapshot({
    required this.tasks,
    required this.occurrences,
  });

  TaskSnapshot copy() => TaskSnapshot(
        tasks: tasks.map((t) => t.copyWith(updatedAt: t.updatedAt)).toList(),
        occurrences: occurrences
            .map(
              (o) => TaskOccurrence(
                id: o.id,
                taskId: o.taskId,
                date: o.date,
                startTime: o.startTime,
                endTime: o.endTime,
                isAllDay: o.isAllDay,
                isCompleted: o.isCompleted,
                isCanceled: o.isCanceled,
                updatedAt: o.updatedAt,
              ),
            )
            .toList(),
      );
}

/// Local or remote backing store. Swap implementations for cloud sync later.
abstract class TaskStore {
  Future<TaskSnapshot> load();
  Future<void> save(TaskSnapshot data);
}
