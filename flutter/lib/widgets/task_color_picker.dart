import 'package:flutter/material.dart';

const kTaskColors = [
  Colors.blue,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.red,
  Colors.teal,
  Colors.pink,
  Colors.amber,
];

class TaskColorPicker extends StatelessWidget {
  final Color selected;
  final ValueChanged<Color> onSelected;

  const TaskColorPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: kTaskColors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final color = kTaskColors[i];
          return _ColorSwatch(
            color: color,
            selected: _sameColor(color, selected),
            onTap: () => onSelected(color),
          );
        },
      ),
    );
  }
}

bool _sameColor(Color a, Color b) => a == b;

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black87;
    final ring = selected
        ? color
        : Theme.of(context).colorScheme.outline.withValues(alpha: 0.35);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.08 : 1,
        duration: const Duration(milliseconds: 160),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: ring, width: selected ? 3 : 1.5),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: selected
              ? Icon(Icons.check_rounded, size: 22, color: onColor)
              : null,
        ),
      ),
    );
  }
}
