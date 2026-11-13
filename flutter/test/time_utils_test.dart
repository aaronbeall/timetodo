import 'package:flutter_test/flutter_test.dart';
import 'package:timetodo/time_utils.dart';

import 'support.dart';

// Run with TZ=America/New_York (or any DST zone) to exercise the DST cases:
// 2026-03-08 is 23 hours long there and 2026-11-01 is 25 hours long.
void main() {
  group('addDays', () {
    test('steps one calendar day at a time through DST changes', () {
      for (final start in [d(2026, 3, 1), d(2026, 10, 25)]) {
        var cursor = start;
        final seen = <String>[];
        for (var i = 0; i < 14; i++) {
          seen.add(dateKey(cursor));
          expect(cursor.hour, 0, reason: 'stays at midnight: $cursor');
          cursor = addDays(cursor, 1);
        }
        expect(seen.toSet().length, 14, reason: 'no day repeated: $seen');
        expect(dateKey(cursor), dateKey(DateTime(start.year, start.month,
            start.day + 14)));
      }
    });

    test('goes backwards and across month and year ends', () {
      expect(addDays(d(2026, 3, 9), -1), d(2026, 3, 8));
      expect(addDays(d(2026, 3, 1), -1), d(2026, 2, 28));
      expect(addDays(d(2024, 2, 28), 1), d(2024, 2, 29));
      expect(addDays(d(2026, 12, 31), 1), d(2027, 1, 1));
    });
  });

  group('daysBetween', () {
    test('counts calendar days across DST changes', () {
      expect(daysBetween(d(2026, 3, 1), d(2026, 3, 15)), 14);
      expect(daysBetween(d(2026, 10, 25), d(2026, 11, 8)), 14);
      expect(daysBetween(d(2026, 3, 15), d(2026, 3, 1)), -14);
    });

    test('ignores the time of day', () {
      expect(
        daysBetween(DateTime(2026, 5, 1, 23, 59), DateTime(2026, 5, 2, 0, 1)),
        1,
      );
    });
  });

  group('time of day', () {
    test('durationMinutes wraps past midnight', () {
      expect(durationMinutes(t(9), t(10, 30)), 90);
      expect(durationMinutes(t(22), t(7)), 9 * 60);
      expect(durationMinutes(t(9), t(9)), 0);
    });

    test('addTimeMinutes and timeFromMinutes wrap both ways', () {
      expect(addTimeMinutes(t(23, 50), 15), t(0, 5));
      expect(addTimeMinutes(t(0, 5), -15), t(23, 50));
      expect(timeFromMinutes(24 * 60 + 61), t(1, 1));
    });
  });
}
