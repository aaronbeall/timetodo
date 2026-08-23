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
  final theme = Theme.of(messenger.context);
  final scheme = theme.colorScheme;
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
        ),
      ),
      action: onUndo == null
          ? null
          : SnackBarAction(
              label: 'Undo',
              textColor: scheme.primary,
              onPressed: onUndo,
            ),
      backgroundColor: scheme.surfaceContainerHigh,
      behavior: SnackBarBehavior.floating,
      dismissDirection: DismissDirection.horizontal,
      duration: const Duration(seconds: 4),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  );
}
