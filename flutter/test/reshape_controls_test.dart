import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetodo/widgets/dismissible_hint_tooltip.dart';
import 'package:timetodo/widgets/task_timeframe_field.dart';

const _key = DismissibleHintTooltip.reshapeLongPressKey;
const _message = 'Next time, long-press an arc to reshape';

Widget _host(Widget child, {double width = 390}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

void main() {
  setUp(HintPrefs.resetForTest);

  group('DismissibleHintTooltip', () {
    testWidgets('shows when never dismissed', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        _host(const DismissibleHintTooltip(prefsKey: _key, message: _message)),
      );
      await tester.pumpAndSettle();
      expect(find.text(_message), findsOneWidget);
    });

    testWidgets('never flashes when already dismissed', (tester) async {
      SharedPreferences.setMockInitialValues({_key: true});
      await tester.pumpWidget(
        _host(const DismissibleHintTooltip(prefsKey: _key, message: _message)),
      );
      // First frame, before prefs have loaded: hidden.
      expect(find.text(_message), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text(_message), findsNothing);
    });

    testWidgets('dismissing hides every instance and persists', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        _host(
          const Column(
            children: [
              DismissibleHintTooltip(prefsKey: _key, message: _message),
              DismissibleHintTooltip(prefsKey: _key, message: _message),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(_message), findsNWidgets(2));

      await tester.tap(find.byTooltip('Dismiss').first);
      await tester.pumpAndSettle();
      expect(find.text(_message), findsNothing);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(_key), isTrue);
    });

    testWidgets('show: false hides it', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        _host(
          const DismissibleHintTooltip(
            prefsKey: _key,
            message: _message,
            show: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(_message), findsNothing);
    });
  });

  group('TaskTimeframeField with actions', () {
    Widget field({VoidCallback? onReset}) => TaskTimeframeField(
          isAllDay: false,
          startTime: const TimeOfDay(hour: 15, minute: 0),
          endTime: const TimeOfDay(hour: 22, minute: 25),
          showAllDayToggle: false,
          showTrailingTimeIcon: false,
          leadingIcons: true,
          onMove: () {},
          onResetTimes: onReset,
          onTimeframeChanged: (_) {},
        );

    for (final width in [320.0, 390.0]) {
      testWidgets('label stays on one line at ${width.toInt()}px',
          (tester) async {
        await tester.pumpWidget(_host(field(onReset: () {}), width: width));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Reshape'), findsOneWidget);
        expect(find.text('Reset'), findsOneWidget);

        final label = tester.getSize(find.text('Timeframe'));
        final duration = tester.getSize(find.text('Duration'));
        // Same single-line height as the Duration label, which has no actions.
        expect(label.height, duration.height);
      });
    }

    testWidgets('Reset is hidden when there is nothing to reset',
        (tester) async {
      await tester.pumpWidget(_host(field()));
      await tester.pumpAndSettle();
      expect(find.text('Reshape'), findsOneWidget);
      expect(find.text('Reset'), findsNothing);
    });
  });
}
