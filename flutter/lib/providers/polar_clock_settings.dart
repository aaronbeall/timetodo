import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetodo/time_utils.dart';

enum PolarClockOrigin { left, top, right, bottom }

class PolarClockLook {
  static const cycle24 = 24 * 60;
  static const cycle12 = 12 * 60;

  final int hourLabels;
  final PolarClockOrigin origin;
  final bool hours12;
  final bool trackBackground;
  final bool originLine;
  final bool hourTrack;
  final double? holeFraction;

  const PolarClockLook({
    this.hourLabels = 0,
    this.origin = PolarClockOrigin.top,
    this.hours12 = false,
    this.trackBackground = true,
    this.originLine = false,
    this.hourTrack = true,
    this.holeFraction,
  });

  int get cycleMinutes => hours12 ? cycle12 : cycle24;

  double get originRadians => switch (origin) {
        PolarClockOrigin.left => math.pi,
        PolarClockOrigin.top => -math.pi / 2,
        PolarClockOrigin.right => 0,
        PolarClockOrigin.bottom => math.pi / 2,
      };

  bool nowIsPm(TimeOfDay now) => minutesOf(now) >= cycle12;

  double mapMinutes(num minutes) {
    final value = minutes.toDouble() % cycle24;
    final wrapped = value < 0 ? value + cycle24 : value;
    if (!hours12) return wrapped;
    return wrapped % cycle12;
  }

  bool isOpposite(num minutes, {required bool viewingPm}) {
    if (!hours12) return false;
    var wrapped = minutes.toDouble() % cycle24;
    if (wrapped < 0) wrapped += cycle24;
    return (wrapped >= cycle12) != viewingPm;
  }

  double angleForMinutes(num minutes) {
    return originRadians +
        2 * math.pi * (mapMinutes(minutes) / cycleMinutes);
  }

  double minutesFromAngle(double angle) {
    var minutes =
        ((angle - originRadians) / (2 * math.pi)) * cycleMinutes;
    minutes %= cycleMinutes;
    if (minutes < 0) minutes += cycleMinutes;
    return minutes;
  }

  PolarClockLook copyWith({
    int? hourLabels,
    PolarClockOrigin? origin,
    bool? hours12,
    bool? trackBackground,
    bool? originLine,
    bool? hourTrack,
    double? holeFraction,
  }) {
    return PolarClockLook(
      hourLabels: hourLabels ?? this.hourLabels,
      origin: origin ?? this.origin,
      hours12: hours12 ?? this.hours12,
      trackBackground: trackBackground ?? this.trackBackground,
      originLine: originLine ?? this.originLine,
      hourTrack: hourTrack ?? this.hourTrack,
      holeFraction: holeFraction ?? this.holeFraction,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PolarClockLook &&
        other.hourLabels == hourLabels &&
        other.origin == origin &&
        other.hours12 == hours12 &&
        other.trackBackground == trackBackground &&
        other.originLine == originLine &&
        other.hourTrack == hourTrack &&
        other.holeFraction == holeFraction;
  }

  @override
  int get hashCode => Object.hash(
        hourLabels,
        origin,
        hours12,
        trackBackground,
        originLine,
        hourTrack,
        holeFraction,
      );
}

class PolarClockSettings extends ChangeNotifier {
  static const _kLabels = 'timetodo.polar.labels';
  static const _kOrigin = 'timetodo.polar.origin';
  static const _kHours12 = 'timetodo.polar.hours12';
  static const _kTrackBg = 'timetodo.polar.trackBg';
  static const _kOriginLine = 'timetodo.polar.originLine';

  PolarClockLook look = const PolarClockLook();
  bool? _pinnedPm;

  bool viewingPm(TimeOfDay now) {
    if (!look.hours12) return false;
    return _pinnedPm ?? look.nowIsPm(now);
  }

  void followLiveMeridian() {
    if (_pinnedPm == null) return;
    _pinnedPm = null;
    notifyListeners();
  }

  void toggleViewingPm(TimeOfDay now) {
    if (!look.hours12) return;
    final next = !viewingPm(now);
    _pinnedPm = next == look.nowIsPm(now) ? null : next;
    notifyListeners();
  }

  void setViewingPm(bool pm, TimeOfDay now) {
    if (!look.hours12) return;
    _pinnedPm = pm == look.nowIsPm(now) ? null : pm;
    notifyListeners();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    look = PolarClockLook(
      hourLabels: _labelCount(prefs.getInt(_kLabels) ?? 0),
      origin: switch (prefs.getString(_kOrigin)) {
        'left' => PolarClockOrigin.left,
        'right' => PolarClockOrigin.right,
        'bottom' => PolarClockOrigin.bottom,
        _ => PolarClockOrigin.top,
      },
      hours12: prefs.getBool(_kHours12) ?? false,
      trackBackground: prefs.getBool(_kTrackBg) ?? true,
      originLine: prefs.getBool(_kOriginLine) ?? false,
    );
    notifyListeners();
  }

  Future<void> setHourLabels(int count) async {
    look = look.copyWith(hourLabels: _labelCount(count));
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLabels, look.hourLabels);
  }

  Future<void> setOrigin(PolarClockOrigin origin) async {
    look = look.copyWith(origin: origin);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kOrigin,
      switch (origin) {
        PolarClockOrigin.left => 'left',
        PolarClockOrigin.top => 'top',
        PolarClockOrigin.right => 'right',
        PolarClockOrigin.bottom => 'bottom',
      },
    );
  }

  Future<void> setHours12(bool value) async {
    look = look.copyWith(hours12: value);
    if (!value) _pinnedPm = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHours12, value);
  }

  Future<void> setTrackBackground(bool value) async {
    look = look.copyWith(trackBackground: value);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTrackBg, value);
  }

  Future<void> setOriginLine(bool value) async {
    look = look.copyWith(originLine: value);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOriginLine, value);
  }

  static int _labelCount(int value) {
    if (value == 4 || value == 8 || value == 12) return value;
    return 0;
  }
}
