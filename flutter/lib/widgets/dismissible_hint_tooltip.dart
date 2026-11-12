import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Inverse-surface tooltip chip with a close control. Dismissal is persisted.
class DismissibleHintTooltip extends StatefulWidget {
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
  State<DismissibleHintTooltip> createState() => _DismissibleHintTooltipState();
}

class _DismissibleHintTooltipState extends State<DismissibleHintTooltip> {
  static final Map<String, bool> _dismissed = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_dismissed.containsKey(widget.prefsKey)) return;
    final prefs = await SharedPreferences.getInstance();
    _dismissed[widget.prefsKey] = prefs.getBool(widget.prefsKey) ?? false;
    if (mounted) setState(() {});
  }

  Future<void> _dismiss() async {
    _dismissed[widget.prefsKey] = true;
    setState(() {});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(widget.prefsKey, true);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.show || (_dismissed[widget.prefsKey] ?? false)) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 2, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.message,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onInverseSurface,
                        height: 1.25,
                      ),
                ),
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: _dismiss,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: scheme.onInverseSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
