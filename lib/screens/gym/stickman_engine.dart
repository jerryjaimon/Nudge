import 'package:flutter/material.dart';

class StickmanPose {
  final Map<String, Offset> joints;
  StickmanPose(this.joints);

  static StickmanPose lerp(StickmanPose a, StickmanPose b, double t) {
    final Map<String, Offset> result = {};
    a.joints.forEach((key, value) {
      if (b.joints.containsKey(key)) {
        result[key] = Offset.lerp(value, b.joints[key], t)!;
      }
    });
    return StickmanPose(result);
  }
}

class ThickStickmanPainter extends CustomPainter {
  final StickmanPose pose;
  final Color accentColor;
  final double thickness;

  ThickStickmanPainter({
    required this.pose,
    required this.accentColor,
    this.thickness = 20.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    
    final bodyPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = thickness * s
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final joints = pose.joints;

    void drawSegment(String j1, String j2, Paint p) {
      if (joints.containsKey(j1) && joints.containsKey(j2)) {
        canvas.drawLine(
          Offset(joints[j1]!.dx * s, joints[j1]!.dy * s),
          Offset(joints[j2]!.dx * s, joints[j2]!.dy * s),
          p,
        );
      }
    }

    // Main Body Parts
    // Head - Drawn with a small offset for separation
    if (joints.containsKey('head')) {
      final headPos = joints['head']!;
      final shoulderPos = joints['shoulder'];
      var drawPos = headPos;
      
      // If we have a shoulder, move head slightly away to create the "icon gap"
      if (shoulderPos != null) {
        final dir = (headPos - shoulderPos);
        if (dir.distance > 0) {
          drawPos = headPos + (dir / dir.distance) * 2.0;
        }
      }

      canvas.drawCircle(
        Offset(drawPos.dx * s, drawPos.dy * s),
        (thickness * 0.6) * s, // Slightly larger head than limb width
        Paint()..color = Colors.white..style = PaintingStyle.fill,
      );
    }

    // Spine
    drawSegment('head', 'shoulder', bodyPaint);
    drawSegment('shoulder', 'hip', bodyPaint);
    
    // Arms
    drawSegment('shoulder', 'elbow', bodyPaint);
    drawSegment('elbow', 'wrist', bodyPaint);

    // Legs
    drawSegment('hip', 'knee', bodyPaint);
    drawSegment('knee', 'ankle', bodyPaint);

    // 3. Accent Overlays (Bones/Glow)
    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.3)
      ..strokeWidth = (thickness * 1.5) * s
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    // Add a subtle glow to the primary moving parts
    drawSegment('shoulder', 'elbow', glowPaint);
    drawSegment('elbow', 'wrist', glowPaint);
    drawSegment('shoulder', 'hip', glowPaint);
  }

  @override
  bool shouldRepaint(covariant ThickStickmanPainter oldDelegate) => true;
}

class AnimatedStickman extends StatelessWidget {
  final StickmanPose poseA;
  final StickmanPose poseB;
  final double progress;
  final Color accentColor;
  final double size;

  const AnimatedStickman({
    super.key,
    required this.poseA,
    required this.poseB,
    required this.progress,
    required this.accentColor,
    this.size = 100,
  });

  @override
  Widget build(BuildContext context) {
    final currentPose = StickmanPose.lerp(poseA, poseB, progress);
    return CustomPaint(
      size: Size(size, size),
      painter: ThickStickmanPainter(
        pose: currentPose,
        accentColor: accentColor,
      ),
    );
  }
}

// ── Specific Poses ────────────────────────────────────────────────────────────

class PushUpPoses {
  static final low = StickmanPose({
    'head': const Offset(15, 68),
    'shoulder': const Offset(28, 72),
    'elbow': const Offset(20, 82),
    'wrist': const Offset(30, 88),
    'hip': const Offset(55, 80),
    'knee': const Offset(70, 84),
    'ankle': const Offset(85, 88),
  });

  static final high = StickmanPose({
    'head': const Offset(15, 38),
    'shoulder': const Offset(28, 42),
    'elbow': const Offset(22, 65),
    'wrist': const Offset(30, 88),
    'hip': const Offset(55, 60),
    'knee': const Offset(70, 74),
    'ankle': const Offset(85, 88),
  });
}
