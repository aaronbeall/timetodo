import 'package:flutter/material.dart';

/// Confirmation toast for data changes, with optional undo.
///
/// Floating, dismissible by swipe, auto-hides after a few seconds.
void showChangeToast(
  BuildContext context, {
  required String message,
  VoidCallback? onUndo,
}) {
  if (!context.mounted) return;
  showChangeToastOn(
    ScaffoldMessenger.of(context),
    message: message,
    onUndo: onUndo,
  );
}

void showChangeToastOn(
  ScaffoldMessengerState messenger, {
  required String message,
  VoidCallback? onUndo,
}) {
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      action: onUndo == null
          ? null
          : SnackBarAction(
              label: 'Undo',
              onPressed: onUndo,
            ),
      behavior: SnackBarBehavior.floating,
      dismissDirection: DismissDirection.horizontal,
      duration: const Duration(seconds: 4),
    ),
  );
}
