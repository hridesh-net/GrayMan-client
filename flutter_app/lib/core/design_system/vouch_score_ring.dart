import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Mirrors VouchScoreRing in GiveVouchSheet.swift.
class VouchScoreRing extends StatelessWidget {
  const VouchScoreRing({super.key, required this.score, this.size = 64});

  final int score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final progress = (score.clamp(1, 100)) / 100.0;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(progress: progress),
        child: Center(
          child: Text(
            '$score',
            style: TextStyle(
              fontSize: size * 0.28,
              fontWeight: FontWeight.w800,
              color: AppColors.shadowGrey,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final bg = Paint()
      ..color = AppColors.soft
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final fg = Paint()
      ..color = AppColors.burntPeach
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bg);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}
