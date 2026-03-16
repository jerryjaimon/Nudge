import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app.dart' show NudgeTokens;

class OrbitAnimation extends StatefulWidget {
  final double size;
  const OrbitAnimation({super.key, this.size = 300});

  @override
  State<OrbitAnimation> createState() => _OrbitAnimationState();
}

class _OrbitAnimationState extends State<OrbitAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _OrbitPainter(progress: _controller.value),
        );
      },
    );
  }
}

class _OrbitPainter extends CustomPainter {
  final double progress;
  _OrbitPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final coreRadius = size.width * 0.12;

    // 1. Draw "User Core" Glow (Deep Layer)
    final coreGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(0.4),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: coreRadius * 2.5));

    canvas.drawCircle(center, coreRadius * 2.5, coreGlow);

    // 2. Define Orbits
    // Each orbit has: angle offset, tilt (tilt angle of the ellipse), 
    // radiusX, radiusY, speed multiplier, color, name
    final orbits = [
      _OrbitData(
        angleOffset: 0,
        tilt: 0.2,
        radiusX: size.width * 0.35,
        radiusY: size.width * 0.12,
        speed: 1.0,
        color: NudgeTokens.healthB,
        label: 'Health',
      ),
      _OrbitData(
        angleOffset: math.pi * 2 / 3,
        tilt: -0.5,
        radiusX: size.width * 0.4,
        radiusY: size.width * 0.15,
        speed: 0.8,
        color: NudgeTokens.finB,
        label: 'Finance',
      ),
      _OrbitData(
        angleOffset: math.pi * 4 / 3,
        tilt: 0.8,
        radiusX: size.width * 0.38,
        radiusY: size.width * 0.1,
        speed: 1.2,
        color: NudgeTokens.amber,
        label: 'Discipline',
      ),
    ];

    // Sort orbits or parts of orbits by Z-index? 
    // To simplify, we paint the "back" half of trajectories, then the core, then the "front" half.
    
    // Draw Background Trajectories (faint)
    for (var orbit in orbits) {
      _drawTrajectory(canvas, center, orbit, opacity: 0.15);
    }

    // Draw Core
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          Colors.white.withOpacity(0.8),
          NudgeTokens.purple.withOpacity(0.4),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: coreRadius));
    
    canvas.drawCircle(center, coreRadius, corePaint);
    
    // Core detail (ring)
    final coreRing = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, coreRadius * 1.1, coreRing);

    // Draw Nodes
    for (var orbit in orbits) {
      final angle = (progress * 2 * math.pi * orbit.speed) + orbit.angleOffset;
      
      // Calculate local orbital position (on the tilted ellipse)
      final lx = orbit.radiusX * math.cos(angle);
      final ly = orbit.radiusY * math.sin(angle);
      
      // Rotate by tilt
      final x = lx * math.cos(orbit.tilt) - ly * math.sin(orbit.tilt);
      final y = lx * math.sin(orbit.tilt) + ly * math.cos(orbit.tilt);
      
      final pos = center + Offset(x, y);
      
      // z-index logic: Sin(angle) tells us if it's "in front" (positive) or "behind" (negative)
      // Since ly = radiusY * sin(angle), we can use ly (or just sin(angle)).
      final zScale = 0.8 + (math.sin(angle) * 0.3); // Scale between 0.5 and 1.1
      final zOpacity = 0.5 + (math.sin(angle) * 0.5); // Opacity between 0 and 1
      
      _drawNode(canvas, pos, orbit.color, coreRadius * 0.4 * zScale, zOpacity);
    }
  }

  void _drawTrajectory(Canvas canvas, Offset center, _OrbitData orbit, {required double opacity}) {
    final paint = Paint()
      ..color = orbit.color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    const steps = 100;
    for (int i = 0; i <= steps; i++) {
      final a = (i / steps) * 2 * math.pi;
      final lx = orbit.radiusX * math.cos(a);
      final ly = orbit.radiusY * math.sin(a);
      
      final x = lx * math.cos(orbit.tilt) - ly * math.sin(orbit.tilt);
      final y = lx * math.sin(orbit.tilt) + ly * math.cos(orbit.tilt);
      
      if (i == 0) {
        path.moveTo(center.dx + x, center.dy + y);
      } else {
        path.lineTo(center.dx + x, center.dy + y);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawNode(Canvas canvas, Offset pos, Color color, double radius, double opacity) {
    // Outer Glow
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(0.6 * opacity),
          color.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: pos, radius: radius * 3));
    canvas.drawCircle(pos, radius * 3, glow);

    // Inner Core
    final nodePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(opacity),
          color.withOpacity(opacity),
        ],
      ).createShader(Rect.fromCircle(center: pos, radius: radius));
    canvas.drawCircle(pos, radius, nodePaint);
    
    // Shine
    final shine = Paint()
      ..color = Colors.white.withOpacity(0.4 * opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos - Offset(radius * 0.3, radius * 0.3), radius * 0.2, shine);
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) => 
      oldDelegate.progress != progress;
}

class _OrbitData {
  final double angleOffset;
  final double tilt;
  final double radiusX;
  final double radiusY;
  final double speed;
  final Color color;
  final String label;

  _OrbitData({
    required this.angleOffset,
    required this.tilt,
    required this.radiusX,
    required this.radiusY,
    required this.speed,
    required this.color,
    required this.label,
  });
}
