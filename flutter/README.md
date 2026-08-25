# Flutter app

Package name: `timetodo`  
Entry: `lib/main.dart` (`TimeToDoApp`)

Product/strategy docs live in the repo root (`docs/`, `TODO.md`), not here.

## Requirements

- Flutter SDK with Dart `>=3.0.0 <4.0.0` (see `pubspec.yaml`)
- A device or emulator: iOS, Android, macOS, or Chrome (`flutter devices`)

From this directory:

```bash
flutter pub get
```

## Run

```bash
flutter run
# or
flutter run -d chrome
flutter run -d macos
```

## Check

```bash
dart analyze
flutter test
```

Lint rules: `analysis_options.yaml` (includes `package:flutter_lints/flutter.yaml`).

## Layout

```
lib/
  main.dart              # MaterialApp, providers, tab shell
  app_navigation.dart
  time_utils.dart
  models/                # Task, TaskEra, TaskOccurrence, ScheduledTask
  data/                  # TaskStore; LocalTaskStore → SharedPreferences JSON
  providers/             # TaskProvider, theme, time format, polar look
  screens/
  widgets/
```

State is `provider`. Tasks persist locally (`timetodo.snapshot.v2` in SharedPreferences). There is no backend.

Settings (theme, 12/24h, polar look) also use SharedPreferences.

## Tests

`test/widget_test.dart` is a smoke test only. Add coverage next to the code you change (`test/`).
