import 'package:flutter/material.dart';

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String dateKey(DateTime date) {
  final d = dateOnly(date);
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

bool isSameDay(DateTime a, DateTime b) => dateOnly(a) == dateOnly(b);

int minutesOf(TimeOfDay time) => time.hour * 60 + time.minute;

TimeOfDay timeFromMinutes(int minutes) {
  final m = minutes % (24 * 60);
  final normalized = m < 0 ? m + 24 * 60 : m;
  return TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60);
}

TimeOfDay addTimeMinutes(TimeOfDay time, int minutes) =>
    timeFromMinutes(minutesOf(time) + minutes);

int durationMinutes(TimeOfDay start, TimeOfDay end) {
  final startM = minutesOf(start);
  final endM = minutesOf(end);
  if (startM <= endM) return endM - startM;
  return 24 * 60 - startM + endM;
}

String formatDurationMinutes(int minutes) {
  if (minutes < 1) return '0 min';
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) return hours == 1 ? '1 hr' : '$hours hr';
  return '$hours hr $rest min';
}

String dayOrdinal(int day) {
  if (day >= 11 && day <= 13) return '${day}th';
  switch (day % 10) {
    case 1:
      return '${day}st';
    case 2:
      return '${day}nd';
    case 3:
      return '${day}rd';
    default:
      return '${day}th';
  }
}

Color taskInkColor(Color base, Brightness brightness) {
  final hsl = HSLColor.fromColor(base);
  if (brightness == Brightness.dark) {
    return hsl
        .withLightness(hsl.lightness.clamp(0.72, 0.86))
        .withSaturation(hsl.saturation.clamp(0.4, 1))
        .toColor();
  }
  return hsl
      .withLightness(hsl.lightness.clamp(0.22, 0.36))
      .withSaturation(hsl.saturation.clamp(0.5, 1))
      .toColor();
}
