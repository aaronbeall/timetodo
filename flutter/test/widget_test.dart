// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:timetodo/main.dart';
import 'package:timetodo/providers/task_provider.dart';

void main() {
  testWidgets('TimeToDo app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TimeToDoApp());

    // Verify that the app starts with Today screen
    expect(find.text('Today'), findsOneWidget);
    
    // Verify navigation to Tasks screen
    expect(find.text('Tasks'), findsOneWidget);
  });
}
