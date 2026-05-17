import 'package:flutter/material.dart';

/// Decorative gradient blobs — mirrors Blobs.swift.
class Blobs extends StatelessWidget {
  const Blobs({super.key, required this.accent, this.opacity = 0.8});

  final Color accent;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -80,
              child: _blob(340, accent.withValues(alpha: 0.20), 170),
            ),
            Positioned(
              bottom: -60,
              left: -60,
              child: _blob(300, accent.withValues(alpha: 0.12), 150),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob(double size, Color center, double radius) {
    return ImageFiltered(
      imageFilter: ColorFilter.mode(Colors.transparent, BlendMode.dst),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [center, Colors.transparent],
            radius: radius / (size / 2),
          ),
        ),
      ),
    );
  }
}
