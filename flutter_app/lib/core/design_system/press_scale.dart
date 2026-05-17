import 'package:flutter/material.dart';

/// Mirrors PressScaleStyle.swift.
class PressScaleButton extends StatefulWidget {
  const PressScaleButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.scale = 0.97,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final double scale;

  @override
  State<PressScaleButton> createState() => _PressScaleButtonState();
}

class _PressScaleButtonState extends State<PressScaleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed != null ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.onPressed != null ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
