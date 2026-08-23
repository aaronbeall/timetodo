import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetodo/data/task_store.dart';
import 'package:timetodo/models/task.dart';
import 'package:timetodo/models/task_occurrence.dart';

/// JSON snapshot in platform prefs (localStorage on web).
/// Keeps [TaskStore] swappable for a later sync backend.
class LocalTaskStore implements TaskStore {
  static const _key = 'timetodo.snapshot.v2';
  static const _version = 2;

  Map<String, dynamic> _map(dynamic value) =>
      Map<String, dynamic>.from(value as Map);

  @override
  Future<TaskSnapshot> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) {
        return const TaskSnapshot(tasks: [], occurrences: []);
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const TaskSnapshot(tasks: [], occurrences: []);
      }
      final data = _map(decoded);
      final tasks = (data['tasks'] as List? ?? [])
          .map((e) => Task.fromJson(_map(e)))
          .toList();
      final occurrences = (data['occurrences'] as List? ?? [])
          .map((e) => TaskOccurrence.fromJson(_map(e)))
          .toList();
      return TaskSnapshot(tasks: tasks, occurrences: occurrences);
    } catch (_) {
      return const TaskSnapshot(tasks: [], occurrences: []);
    }
  }

  @override
  Future<void> save(TaskSnapshot data) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'version': _version,
      'tasks': data.tasks.map((t) => t.toJson()).toList(),
      'occurrences': data.occurrences.map((o) => o.toJson()).toList(),
    });
    await prefs.setString(_key, payload);
  }
}
