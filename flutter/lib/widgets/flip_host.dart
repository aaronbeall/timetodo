import 'package:flutter/material.dart';

const kTaskListAnimDuration = Duration(milliseconds: 480);
const kTaskListAnimCurve = Curves.easeInOutCubic;

/// Keeps a row visually in its previous place, then eases to the new layout.
///
/// Uses document Y (viewport Y + scroll offset) so scrolling does not trigger
/// a move animation. Pass [token] that changes only when the row's list slot
/// should animate (section, order, height class).
class FlipHost extends StatefulWidget {
  final String token;
  final Widget child;

  const FlipHost({
    super.key,
    required this.token,
    required this.child,
  });

  @override
  State<FlipHost> createState() => _FlipHostState();
}

class _FlipHostState extends State<FlipHost>
    with SingleTickerProviderStateMixin {
  final _paintKey = GlobalKey();
  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  Offset _delta = Offset.zero;
  double? _prevPageY;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: kTaskListAnimDuration,
    );
    _curve = CurvedAnimation(parent: _controller, curve: kTaskListAnimCurve);
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _remember());
  }

  @override
  void didUpdateWidget(FlipHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _flip());
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  Offset get _translation =>
      Offset.lerp(_delta, Offset.zero, _curve.value) ?? Offset.zero;

  double? _pageY() {
    final ctx = _paintKey.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    final global = box.localToGlobal(Offset.zero);
    final scrollable = Scrollable.maybeOf(ctx);
    final pixels = scrollable?.position.pixels ?? 0;
    return global.dy + pixels - _translation.dy;
  }

  void _remember() {
    _prevPageY = _pageY();
  }

  void _flip() {
    if (!mounted) return;
    final next = _pageY();
    final prev = _prevPageY;
    _prevPageY = next;
    if (next == null || prev == null) return;
    final dy = prev - next;
    if (dy.abs() < 1) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _delta = Offset.zero;
      _controller.value = 1;
      return;
    }
    _delta = Offset(0, dy);
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: _translation,
      child: KeyedSubtree(
        key: _paintKey,
        child: widget.child,
      ),
    );
  }
}
