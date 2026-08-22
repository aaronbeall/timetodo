#!/bin/bash
# Quick restart script for Flutter web development
pkill -f "flutter.*chrome" 2>/dev/null
pkill -f "dart.*flutter_tools" 2>/dev/null
sleep 1
cd "$(dirname "$0")"
flutter run -d chrome
