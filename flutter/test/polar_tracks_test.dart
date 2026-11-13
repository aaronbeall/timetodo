import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetodo/models/scheduled_task.dart';
import 'package:timetodo/widgets/polar_clock.dart';

import 'support.dart';

ScheduledTask _at(String id, TimeOfDay start, TimeOfDay end) => ScheduledTask(
      task: dailyTask(id: id, from: d(2026, 1, 1), start: start, end: end),
      date: d(2026, 5, 4),
    );

Map<String, int> _trackOf(Map<int, List<ScheduledTask>> tracks) => {
      for (final entry in tracks.entries)
        for (final task in entry.value) task.id: entry.key,
    };

void main() {
  group('assignPolarTracks', () {
    test('non-overlapping tasks share one track', () {
      final tracks = assignPolarTracks([
        _at('a', t(9), t(10)),
        _at('b', t(10), t(11)), // touching ends do not overlap
        _at('c', t(13), t(14)),
      ]);
      expect(tracks.length, 1);
      expect(tracks[0]!.length, 3);
    });

    test('overlapping tasks never share a track', () {
      final tasks = [
        _at('long', t(8), t(17)),
        _at('mid', t(9), t(12)),
        _at('short', t(10), t(11)),
        _at('later', t(13), t(14)),
      ];
      final tracks = assignPolarTracks(tasks);
      for (final lane in tracks.values) {
        for (var i = 0; i < lane.length; i++) {
          for (var j = i + 1; j < lane.length; j++) {
            final a = lane[i], b = lane[j];
            final overlap = minutesOfDay(a.startTime!) <
                    minutesOfDay(b.endTime!) &&
                minutesOfDay(b.startTime!) < minutesOfDay(a.endTime!);
            expect(overlap, isFalse, reason: '${a.id} vs ${b.id}');
          }
        }
      }
      expect(tracks.length, 3);
    });

    test('longest task goes innermost and gaps get reused', () {
      final lanes = _trackOf(assignPolarTracks([
        _at('short', t(10), t(11)),
        _at('long', t(8), t(17)),
        _at('later', t(18), t(19)),
      ]));
      expect(lanes['long'], 0);
      expect(lanes['later'], 0);
      expect(lanes['short'], 1);
    });

    test('overnight tasks wrap past midnight when checking overlap', () {
      final lanes = _trackOf(assignPolarTracks([
        _at('sleep', t(22), t(7)),
        _at('early', t(6), t(8)),
        _at('noon', t(12), t(13)),
      ]));
      expect(lanes['sleep'], isNot(lanes['early']));
      expect(lanes['noon'], lanes['sleep']);
    });

    test('maxTracks drops tasks that would need another lane', () {
      final tracks = assignPolarTracks([
        _at('a', t(9), t(12)),
        _at('b', t(10), t(11)),
        _at('c', t(10), t(11)),
      ], maxTracks: 2);
      expect(tracks.length, 2);
      expect(tracks.values.expand((l) => l).length, 2);
    });
  });

  test('polarTimedTasks leaves out all-day tasks', () {
    final allDay = ScheduledTask(
      task: dailyTask(id: 'water', from: d(2026, 1, 1), allDay: true),
      date: d(2026, 5, 4),
    );
    final timed = _at('a', t(9), t(10));
    expect(polarTimedTasks([allDay, timed]).map((x) => x.id), ['a']);
  });
}

int minutesOfDay(TimeOfDay time) => time.hour * 60 + time.minute;
