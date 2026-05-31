import 'package:flutter/material.dart';

/// Wraps [child] with a subtle scale-down animation on press.
///
/// Uses [Listener] so it does not compete in the gesture arena — any [InkWell],
/// [GestureDetector], or button inside [child] continues to work normally.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.scale = 0.96,
    this.duration = const Duration(milliseconds: 140),
    this.enabled = true,
  });

  /// The widget to wrap.
  final Widget child;

  /// Target scale when pressed (default 0.96 = 4% shrink).
  final double scale;

  /// How long the scale animation takes.
  final Duration duration;

  /// When false the wrapper is a no-op passthrough (useful for disabled states).
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Listener observes raw pointer events without entering the gesture arena,
      // so InkWell / GestureDetector children still receive their tap events.
      onPointerDown: widget.enabled ? (_) => _setPressed(true) : null,
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: (_pressed && widget.enabled) ? widget.scale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
