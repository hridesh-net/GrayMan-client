import 'package:flutter/material.dart';
import 'app_colors.dart';

class AvatarBubble extends StatelessWidget {
  const AvatarBubble({
    super.key,
    required this.initials,
    this.avatarUrl,
    this.size = 56,
    this.gradientStart,
    this.gradientEnd,
  });

  final String initials;
  final String? avatarUrl;
  final double size;
  final Color? gradientStart;
  final Color? gradientEnd;

  @override
  Widget build(BuildContext context) {
    final start = gradientStart ?? AppColors.shadowGrey;
    final end = gradientEnd ?? AppColors.burntPeach;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [start, end], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl != null && avatarUrl!.isNotEmpty
          ? Image.network(avatarUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initials())
          : _initials(),
    );
  }

  Widget _initials() => Center(
        child: Text(
          initials,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * 0.32),
        ),
      );
}
