import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted "don't show again" state for one-off hints.
///
/// Every hint key has a single shared [ValueNotifier], so dismissing a hint in
/// one place hides it everywhere at once. The value is `null` while the saved
/// state is still loading. Callers treat that as hidden so a hint the user
/// already dismissed never flashes on screen.
class HintPrefs {
  HintPrefs._();

  static final Map<String, ValueNotifier<bool?>> _dismissed = {};

  /// `true` = dismissed, `false` = should show, `null` = still loading.
  static ValueListenable<bool?> dismissed(String key) => _notifier(key);

  /// Whether the hint for [key] is known to be visible right now.
  static bool isVisible(String key) => _notifier(key).value == false;

  static Future<void> dismiss(String key) async {
    _notifier(key).value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, true);
    } catch (_) {
      // Persisting is best-effort; the hint stays hidden for this session.
    }
  }

  static ValueNotifier<bool?> _notifier(String key) {
    return _dismissed.putIfAbsent(key, () {
      final notifier = ValueNotifier<bool?>(null);
      _load(key, notifier);
      return notifier;
    });
  }

  static Future<void> _load(String key, ValueNotifier<bool?> notifier) async {
    bool stored;
    try {
      final prefs = await SharedPreferences.getInstance();
      stored = prefs.getBool(key) ?? false;
    } catch (_) {
      stored = false;
    }
    // A dismiss that landed while loading wins.
    notifier.value ??= stored;
  }

  @visibleForTesting
  static void resetForTest() {
    for (final notifier in _dismissed.values) {
      notifier.dispose();
    }
    _dismissed.clear();
  }
}

/// Inverse-surface tooltip chip with a close control. Dismissal is persisted
/// and shared through [HintPrefs].
class DismissibleHintTooltip extends StatelessWidget {
  static const reshapeLongPressKey = 'timetodo.hint.reshapeLongPress';

  final String prefsKey;
  final String message;
  final bool show;

  const DismissibleHintTooltip({
    super.key,
    required this.prefsKey,
    required this.message,
    this.show = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    return ValueListenableBuilder<bool?>(
      valueListenable: HintPrefs.dismissed(prefsKey),
      builder: (context, dismissed, _) {
        if (dismissed != false) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        return Material(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 2, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onInverseSurface,
                      height: 1.25,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Dismiss',
                  onPressed: () => HintPrefs.dismiss(prefsKey),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: scheme.onInverseSurface,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
