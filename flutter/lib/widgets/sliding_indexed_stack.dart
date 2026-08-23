import 'package:flutter/material.dart';

/// Keeps every child mounted (like [IndexedStack]) and slides between them
/// when [index] changes. Higher-index tabs paint on top, so back-to-Today
/// reads as a pop.
class SlidingIndexedStack extends StatefulWidget {
  const SlidingIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 280),
    this.curve = Curves.easeOutCubic,
  });

  final int index;
  final List<Widget> children;
  final Duration duration;
  final Curve curve;

  @override
  State<SlidingIndexedStack> createState() => _SlidingIndexedStackState();
}

class _SlidingIndexedStackState extends State<SlidingIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late int _index;
  late int _previous;

  @override
  void initState() {
    super.initState();
    _index = widget.index;
    _previous = widget.index;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(SlidingIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.index == _index) return;
    _previous = _index;
    _index = widget.index;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = widget.curve.transform(_controller.value);
        final animating = t < 1 && _previous != _index;
        final forward = _index >= _previous;
        final inDx = (forward ? 1.0 : -1.0) * (1 - t);
        final outDx = (forward ? -1.0 : 1.0) * t;

        return Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < widget.children.length; i++)
              _layer(
                dx: !animating
                    ? 0
                    : i == _index
                        ? inDx
                        : i == _previous
                            ? outDx
                            : 0,
                visible: i == _index || (animating && i == _previous),
                active: i == _index,
                child: widget.children[i],
              ),
          ],
        );
      },
    );
  }

  Widget _layer({
    required double dx,
    required bool visible,
    required bool active,
    required Widget child,
  }) {
    return Offstage(
      offstage: !visible,
      child: TickerMode(
        enabled: visible,
        child: ExcludeSemantics(
          excluding: !active,
          child: IgnorePointer(
            ignoring: !active,
            child: FractionalTranslation(
              translation: Offset(dx, 0),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
