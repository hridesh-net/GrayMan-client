import 'dart:ui';
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Android glass substitute — BackdropFilter instead of iOS .glassEffect().
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding, this.borderRadius = 18});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: AppColors.shadowGrey.withValues(alpha: 0.08)),
          ),
          child: child,
        ),
      ),
    );
  }
}
