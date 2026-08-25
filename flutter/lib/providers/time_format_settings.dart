import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TimeFormatMode { system, h12, h24 }

class TimeFormatSettings extends ChangeNotifier {
  static const _key = 'timetodo.timeFormat';

  TimeFormatMode mode = TimeFormatMode.system;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    mode = switch (prefs.getString(_key)) {
      'h12' => TimeFormatMode.h12,
      'h24' => TimeFormatMode.h24,
      _ => TimeFormatMode.system,
    };
    notifyListeners();
  }

  Future<void> setMode(TimeFormatMode next) async {
    if (mode == next) return;
    mode = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      switch (next) {
        TimeFormatMode.system => 'system',
        TimeFormatMode.h12 => 'h12',
        TimeFormatMode.h24 => 'h24',
      },
    );
  }

  bool resolve24Hour(bool system24Hour) {
    return switch (mode) {
      TimeFormatMode.system => system24Hour,
      TimeFormatMode.h12 => false,
      TimeFormatMode.h24 => true,
    };
  }
}
