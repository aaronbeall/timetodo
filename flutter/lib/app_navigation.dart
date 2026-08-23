import 'package:flutter/material.dart';

/// Root tab on [MainScreen] (0 = Today).
final homeTabIndex = ValueNotifier<int>(0);

final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

void goToTodayTab() => homeTabIndex.value = 0;
