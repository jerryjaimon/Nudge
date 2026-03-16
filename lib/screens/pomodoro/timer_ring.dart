// lib/screens/pomodoro/timer_ring.dart
import 'dart:math';
import 'package:flutter/material.dart';

class TimerRing extends StatelessWidget {
  final double progress; // 0..1
  final Color color;
  final Widget child;

  const TimerRing({
    super.key,
    required this.progress,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          color: color,
          bg: Colors.white.withOpacity(0.10),
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bg;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.bg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - stroke;

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = bg;

    final fgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(0.95);

    canvas.drawCircle(center, radius, bgPaint);

    const start = -pi / 2;
    final sweep = (2 * pi) * progress.clamp(0.0, 1.0);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.bg != bg;
  }
}
