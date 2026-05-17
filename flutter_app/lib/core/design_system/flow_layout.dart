import 'package:flutter/material.dart';

/// Wraps tag chips — mirrors FlowLayout.swift.
class FlowLayout extends StatelessWidget {
  const FlowLayout({super.key, required this.spacing, required this.children});

  final double spacing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: spacing, runSpacing: spacing, children: children);
  }
}
