import 'package:flutter/material.dart';

class DateNavigator extends StatelessWidget {
  final String? label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onJumpToNow;
  final bool showJumpToNow;

  const DateNavigator({
    super.key,
    this.label,
    required this.onPrevious,
    required this.onNext,
    this.onJumpToNow,
    this.showJumpToNow = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = label;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous',
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: InkWell(
                  onTap: onJumpToNow,
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (title != null && title.isNotEmpty)
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (showJumpToNow && onJumpToNow != null)
                        Text(
                          title == null || title.isEmpty ? 'Today' : 'Tap for today',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next',
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
