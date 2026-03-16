import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app.dart' show NudgeTokens;
import '../utils/nudge_theme_extension.dart';

class DailyProgressRings extends StatelessWidget {
  final double moveProgress;
  final double exerciseProgress;
  final double focusProgress;
  final double habitProgress;
  final int habitsDone;
  final int habitsTotal;

  final String? moveValueText;
  final String? exerciseValueText;
  final String? focusValueText;
  final String? habitValueText;

  const DailyProgressRings({
    super.key,
    required this.moveProgress,
    required this.exerciseProgress,
    required this.focusProgress,
    required this.habitProgress,
    required this.habitsDone,
    required this.habitsTotal,
    this.moveValueText,
    this.exerciseValueText,
    this.focusValueText,
    this.habitValueText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<NudgeThemeExtension>()!;
    final tColor = theme.textColor ?? Colors.white;
    final tDimColor = theme.textDim ?? NudgeTokens.textLow;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: theme.cardDecoration(context),
      child: Row(
        children: [
          SizedBox(
            height: 110,
            width: 110,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1.0),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.elasticOut,
              builder: (context, animValue, _) {
                return CustomPaint(
                  painter: _RingsPainter(
                    move: moveProgress * animValue,
                    exercise: exerciseProgress * animValue,
                    focus: focusProgress * animValue,
                    habit: habitProgress * animValue,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RingStat(
                  label: 'Move',
                  value: moveValueText ?? '${(moveProgress * 100).toInt()}%',
                  color: NudgeTokens.healthB,
                  icon: Icons.local_fire_department_rounded,
                  tColor: tColor,
                  tDimColor: tDimColor,
                ),
                const SizedBox(height: 14),
                _RingStat(
                  label: 'Exercise',
                  value: exerciseValueText ?? '${(exerciseProgress * 100).toInt()}%',
                  color: NudgeTokens.gymB,
                  icon: Icons.fitness_center_rounded,
                  tColor: tColor,
                  tDimColor: tDimColor,
                ),
                const SizedBox(height: 14),
                _RingStat(
                  label: 'Focus',
                  value: focusValueText ?? '${(focusProgress * 100).toInt()}%',
                  color: NudgeTokens.pomB,
                  icon: Icons.timer_rounded,
                  tColor: tColor,
                  tDimColor: tDimColor,
                ),
                const SizedBox(height: 14),
                _RingStat(
                  label: 'Diet',
                  value: '$habitsDone/$habitsTotal',
                  color: NudgeTokens.protB,
                  icon: Icons.restaurant_rounded,
                  tColor: tColor,
                  tDimColor: tDimColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final Color tColor;
  final Color tDimColor;

  const _RingStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.tColor,
    required this.tDimColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  color: tDimColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: tColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RingsPainter extends CustomPainter {
  final double move;
  final double exercise;
  final double focus;
  final double habit;

  _RingsPainter({
    required this.move,
    required this.exercise,
    required this.focus,
    required this.habit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) / 2;
    const spacing = 2.5;
    const strokeWidth = 10.0;

    // Rings from outside in
    _drawRing(canvas, center, maxRadius - (strokeWidth / 2), move, NudgeTokens.healthA, NudgeTokens.healthB);
    _drawRing(canvas, center, maxRadius - strokeWidth - spacing - (strokeWidth / 2), exercise, NudgeTokens.gymA, NudgeTokens.gymB);
    _drawRing(canvas, center, maxRadius - (strokeWidth * 2) - (spacing * 2) - (strokeWidth / 2), focus, NudgeTokens.pomA, NudgeTokens.pomB);
    _drawRing(canvas, center, maxRadius - (strokeWidth * 3) - (spacing * 3) - (strokeWidth / 2), habit, NudgeTokens.protA, NudgeTokens.protB);
  }

  void _drawRing(Canvas canvas, Offset center, double radius, double progress, Color colorA, Color colorB) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    
    // Background track
    final trackPaint = Paint()
      ..color = colorB.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    // Progress arc with gradient
    final sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);
    final gradient = SweepGradient(
      startAngle: -pi / 2,
      endAngle: 3 * pi / 2,
      colors: [colorA, colorB],
      stops: const [0.0, 1.0],
    );

    final progressPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -pi / 2, sweepAngle, false, progressPaint);

    // Add a small "glow" at the tip of the progress arc
    if (progress > 0.05) {
      final tipAngle = -pi / 2 + sweepAngle;
      final tipCenter = Offset(
        center.dx + radius * cos(tipAngle),
        center.dy + radius * sin(tipAngle),
      );
      final glowPaint = Paint()
        ..color = colorB
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6);
      canvas.drawCircle(tipCenter, 4, glowPaint);
      
      final whitePointPaint = Paint()..color = Colors.white;
      canvas.drawCircle(tipCenter, 2, whitePointPaint);
    }

    // Over-achievement indicator (loops)
    if (progress > 1.0) {
      final overPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -pi / 2, 2 * pi, false, overPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter oldDelegate) {
    return oldDelegate.move != move ||
        oldDelegate.exercise != exercise ||
        oldDelegate.focus != focus ||
        oldDelegate.habit != habit;
  }
}
