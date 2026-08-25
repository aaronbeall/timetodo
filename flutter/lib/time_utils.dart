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

String formatTimeDigits(TimeOfDay time, {required bool use24Hour}) {
  final minute = time.minute.toString().padLeft(2, '0');
  if (use24Hour) {
    return '${time.hour.toString().padLeft(2, '0')}:$minute';
  }
  final hour =
      time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
  return '$hour:$minute';
}

String? formatTimePeriod(TimeOfDay time, {required bool use24Hour}) {
  if (use24Hour) return null;
  return time.hour >= 12 ? 'PM' : 'AM';
}

/// Compact range labels (list rows): `9:05p` / `21:05`.
String formatTimeCompact(TimeOfDay time, {required bool use24Hour}) {
  final minute = time.minute.toString().padLeft(2, '0');
  if (use24Hour) {
    if (time.minute == 0) return time.hour.toString().padLeft(2, '0');
    return '${time.hour.toString().padLeft(2, '0')}:$minute';
  }
  final hour =
      time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
  final period = time.hour >= 12 ? 'p' : 'a';
  if (time.minute == 0) return '$hour$period';
  return '$hour:$minute$period';
}

String formatAxisTime(int minutes, {required bool use24Hour}) {
  const day = 24 * 60;
  if (minutes <= 0 || minutes >= day) {
    return use24Hour ? '00:00' : '12 AM';
  }
  final time = timeFromMinutes(minutes);
  if (use24Hour) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  final hour =
      time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
  final period = time.hour >= 12 ? 'PM' : 'AM';
  if (time.minute == 0) return '$hour $period';
  return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
}

String formatPolarHourLabel(
  int minutes, {
  required bool polarHours12,
  required bool use24Hour,
}) {
  final tod = timeFromMinutes(minutes % (24 * 60));
  if (use24Hour) {
    return tod.hour.toString();
  }
  final hour =
      tod.hour == 0 ? 12 : (tod.hour > 12 ? tod.hour - 12 : tod.hour);
  if (polarHours12) return '$hour';
  return '$hour${tod.hour >= 12 ? 'p' : 'a'}';
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

Color taskWash(Color color, Color onto, [double opacity = 0.12]) {
  return Color.alphaBlend(color.withOpacity(opacity), onto);
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
