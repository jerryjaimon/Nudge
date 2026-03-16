import 'package:flutter/material.dart';
import 'exercise_db.dart';
import 'stickman_engine.dart';

// ── Animation types ────────────────────────────────────────────────────────────

enum _AnimType {
  lyingPress, pushUp, deadlift, bentRow, pullDown, pullUp,
  squat, lunge, overheadPress, lateralRaise, bicepCurl, tricep,
  plank, crunch, running, calfRaise, legCurl, shrug, generic,
}

// ── Helper paint factories ────────────────────────────────────────────────────

Paint _body(double s) => Paint()
  ..color = Colors.white
  ..strokeWidth = 3.4 * s
  ..strokeCap = StrokeCap.round
  ..style = PaintingStyle.stroke;

Paint _dim(double s) => Paint()
  ..color = Colors.white.withValues(alpha: 0.38)
  ..strokeWidth = 2.5 * s
  ..strokeCap = StrokeCap.round
  ..style = PaintingStyle.stroke;

Paint _ac(Color c, double s, {double w = 2.6}) => Paint()
  ..color = c
  ..strokeWidth = w * s
  ..strokeCap = StrokeCap.round
  ..style = PaintingStyle.stroke;

Paint _fill(Color c, {double a = 0.82}) => Paint()
  ..color = c.withValues(alpha: a)
  ..style = PaintingStyle.fill;

void _head(Canvas cv, double x, double y, double r, Paint p) =>
    cv.drawCircle(Offset(x, y), r, p);

void _line(Canvas cv, double x1, double y1, double x2, double y2, Paint p) =>
    cv.drawLine(Offset(x1, y1), Offset(x2, y2), p);

void _plate(Canvas cv, double cx, double cy, double w, double h, Color c) {
  final f = _fill(c);
  cv.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: w, height: h),
      const Radius.circular(1),
    ),
    f,
  );
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

// ── Main widget ───────────────────────────────────────────────────────────────

class ExerciseIllustration extends StatefulWidget {
  final String exerciseName;
  final double size;

  const ExerciseIllustration({
    super.key,
    required this.exerciseName,
    this.size = 56,
  });

  static Color accentFor(String category) {
    switch (category) {
      case 'Chest':      return const Color(0xFFFF7675);
      case 'Back':       return const Color(0xFF4FC3F7);
      case 'Legs':       return const Color(0xFFFFB74D);
      case 'Shoulders':  return const Color(0xFFCE93D8);
      case 'Arms':       return const Color(0xFF80DEEA);
      case 'Core':       return const Color(0xFF80CBC4);
      case 'Cardio':     return const Color(0xFFF48FB1);
      case 'Full Body':  return const Color(0xFFFFD54F);
      default:           return const Color(0xFF5AC8FA);
    }
  }

  static IconData iconFor(String category) {
    switch (category) {
      case 'Chest':      return Icons.accessibility_new_rounded;
      case 'Back':       return Icons.filter_hdr_rounded;
      case 'Legs':       return Icons.directions_run_rounded;
      case 'Shoulders':  return Icons.keyboard_double_arrow_up_rounded;
      case 'Arms':       return Icons.fitness_center_rounded;
      case 'Core':       return Icons.grid_view_rounded;
      case 'Cardio':     return Icons.directions_bike_rounded;
      case 'Full Body':  return Icons.sports_gymnastics_rounded;
      default:           return Icons.fitness_center_rounded;
    }
  }

  @override
  State<ExerciseIllustration> createState() => _ExerciseIllustrationState();
}

class _ExerciseIllustrationState extends State<ExerciseIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _category() {
    for (final e in ExerciseDB.categories.entries) {
      if (e.value.contains(widget.exerciseName)) return e.key;
    }
    return '';
  }

  static _AnimType _animType(String name) {
    final n = name.toLowerCase();

    // Chest
    if (n.contains('push up') || n.contains('push-up') || n.contains('pushup')) return _AnimType.pushUp;
    if (n.contains('dip') && !n.contains('machine')) return _AnimType.tricep;
    if (n.contains('bench press') || n.contains('floor press') ||
        n.contains('chest press') || n.contains('dumbbell bench') ||
        n.contains('hex press') || n.contains('spoto') || n.contains('guillotine') ||
        n.contains('machine chest') || n.contains('incline') || n.contains('decline') ||
        n.contains('chest fly') || n.contains('cable fly') || n.contains('pec deck') ||
        n.contains('cable crossover') || n.contains('svend') || n.contains('cable crossover')) {
      return _AnimType.lyingPress;
    }

    // Back
    if (n.contains('deadlift') || n.contains('romanian') || n.contains('stiff-leg') ||
        n.contains('sumo dead') || n.contains('trap bar') || n.contains('deficit dead') ||
        n.contains('back extension') || n.contains('hyperextension') ||
        n.contains('good morning')) {
      return _AnimType.deadlift;
    }
    if (n.contains('shrug')) return _AnimType.shrug;
    if (n.contains('pull up') || n.contains('chin up') || n.contains('pull-up') ||
        n.contains('chin-up') || n.contains('muscle up')) {
      return _AnimType.pullUp;
    }
    if (n.contains('pulldown') || n.contains('pull down') || n.contains('pullover') ||
        n.contains('straight-arm') || n.contains('cable pullover')) {
      return _AnimType.pullDown;
    }
    if (n.contains('row') || n.contains('t-bar') || n.contains('renegade')) return _AnimType.bentRow;

    // Legs
    if (n.contains('calf') || n.contains('calf raise') || n.contains('donkey calf')) return _AnimType.calfRaise;
    if (n.contains('leg curl') || n.contains('hamstring curl') || n.contains('nordic') ||
        n.contains('glute-ham') || n.contains('lying leg') || n.contains('seated leg curl') ||
        n.contains('prone leg') || n.contains('standing leg curl')) {
      return _AnimType.legCurl;
    }
    if (n.contains('leg extension')) return _AnimType.legCurl;
    if (n.contains('squat') || n.contains('goblet') || n.contains('hack squat') ||
        n.contains('pistol') || n.contains('sissy') || n.contains('belt squat') ||
        n.contains('leg press') || n.contains('hip thrust') || n.contains('glute bridge')) {
      return _AnimType.squat;
    }
    if (n.contains('lunge') || n.contains('split squat') || n.contains('step up') ||
        n.contains('bulgarian')) {
      return _AnimType.lunge;
    }

    // Shoulders
    if (n.contains('overhead press') || n.contains('shoulder press') ||
        n.contains('military') || n.contains('arnold') || n.contains('push press') ||
        n.contains('behind-the-neck') || n.contains('bradford') || n.contains('z press') ||
        n.contains('handstand push') || n.contains('upright row')) {
      return _AnimType.overheadPress;
    }
    if (n.contains('lateral') || n.contains('front raise') || n.contains('rear delt') ||
        n.contains('face pull') || n.contains('reverse fly') || n.contains('reverse pec')) {
      return _AnimType.lateralRaise;
    }

    // Arms
    if (n.contains('tricep') || n.contains('skull') || n.contains('french') ||
        n.contains('pushdown') || n.contains('close grip bench') ||
        n.contains('overhead ext') || n.contains('tate press') || n.contains('jm press') ||
        n.contains('kickback') || n.contains('bench dip') || n.contains('dip machine') ||
        n.contains('tricep ext')) {
      return _AnimType.tricep;
    }
    if (n.contains('curl') && !n.contains('leg') && !n.contains('ham') &&
        !n.contains('wrist') && !n.contains('nordic')) {
      return _AnimType.bicepCurl;
    }

    // Core
    if (n.contains('plank') || n.contains('hollow') || n.contains('dead bug') ||
        n.contains('bird dog') || n.contains('ab wheel') || n.contains('pallof') ||
        n.contains('flutter') || n.contains('plank jack') || n.contains('mountain climb')) {
      return _AnimType.plank;
    }
    if (n.contains('crunch') || n.contains('sit up') || n.contains('sit-up') ||
        n.contains('leg raise') || n.contains('knee raise') || n.contains('v-up') ||
        n.contains('dragon flag') || n.contains('windshield') || n.contains('cable crunch') ||
        n.contains('ab machine') || n.contains('bicycle crunch') || n.contains('toe touch')) {
      return _AnimType.crunch;
    }

    // Cardio
    if (n.contains('run') || n.contains('treadmill') || n.contains('sprint') ||
        n.contains('jog') || n.contains('walk')) {
      return _AnimType.running;
    }
    if (n.contains('jump rope') || n.contains('burpee') || n.contains('box jump') ||
        n.contains('broad jump') || n.contains('jump')) {
      return _AnimType.running;
    }

    return _AnimType.generic;
  }

  @override
  Widget build(BuildContext context) {
    final cat = _category();
    final accent = ExerciseIllustration.accentFor(cat);
    final type = _animType(widget.exerciseName);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          if (type == _AnimType.generic) {
            return _PulseIllustration(
              progress: _anim.value,
              accent: accent,
              icon: ExerciseIllustration.iconFor(cat),
              size: widget.size,
            );
          }
          if (type == _AnimType.pushUp) {
            return AnimatedStickman(
              poseA: PushUpPoses.low,
              poseB: PushUpPoses.high,
              progress: _anim.value,
              accentColor: accent,
              size: widget.size,
            );
          }
          return CustomPaint(
            painter: _makePainter(type, _anim.value, accent),
          );
        },
      ),
    );
  }

  static CustomPainter _makePainter(_AnimType type, double p, Color c) {
    switch (type) {
      case _AnimType.lyingPress:    return _LyingPressPainter(p, c);
      case _AnimType.pushUp:        return _PushUpPainter(p, c);
      case _AnimType.deadlift:      return _DeadliftPainter(p, c);
      case _AnimType.bentRow:       return _BentRowPainter(p, c);
      case _AnimType.pullDown:      return _PullDownPainter(p, c);
      case _AnimType.pullUp:        return _PullUpPainter(p, c);
      case _AnimType.squat:         return _SquatPainter(p, c);
      case _AnimType.lunge:         return _LungePainter(p, c);
      case _AnimType.overheadPress: return _OHPressPainter(p, c);
      case _AnimType.lateralRaise:  return _LateralRaisePainter(p, c);
      case _AnimType.bicepCurl:     return _BicepCurlPainter(p, c);
      case _AnimType.tricep:        return _TricepPainter(p, c);
      case _AnimType.plank:         return _PlankPainter(p, c);
      case _AnimType.crunch:        return _CrunchPainter(p, c);
      case _AnimType.running:       return _RunningPainter(p, c);
      case _AnimType.calfRaise:     return _CalfRaisePainter(p, c);
      case _AnimType.legCurl:       return _LegCurlPainter(p, c);
      case _AnimType.shrug:         return _ShrugPainter(p, c);
      case _AnimType.generic:       return _LyingPressPainter(p, c);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAINTERS — all use a virtual 100×100 coordinate system, scaled by s = size.width/100
// ─────────────────────────────────────────────────────────────────────────────

// 1. LYING PRESS — front view (head at bottom, bar moves up/away from viewer)
class _LyingPressPainter extends CustomPainter {
  final double p; final Color c;
  _LyingPressPainter(this.p, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final b = _body(s), ac = _ac(c, s, w: 3.2);

    // Head + shoulder line
    _head(canvas, 50*s, 84*s, 6.5*s, b);
    _line(canvas, 24*s, 70*s, 76*s, 70*s, b);

    // barY: chest(73) → extended(42)
    final barY = _lerp(73, 42, p) * s;
    // Arms from shoulders to grip
    _line(canvas, 24*s, 70*s, (20 - 2*p)*s, barY, b);
    _line(canvas, 76*s, 70*s, (80 + 2*p)*s, barY, b);

    // Glow at top
    if (p > 0.68) {
      final t = (p - 0.68) / 0.32;
      canvas.drawLine(Offset(4*s, barY), Offset(96*s, barY), Paint()
        ..color = c.withValues(alpha: t * 0.28)
        ..strokeWidth = 9 * s
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }
    // Barbell shaft
    _line(canvas, 4*s, barY, 96*s, barY, ac);
    // Plates
    _plate(canvas, 8.5*s, barY, 5.5*s, 21*s, c);
    _plate(canvas, 91.5*s, barY, 5.5*s, 21*s, c);
    _plate(canvas, 15*s, barY, 4*s, 14*s, c);
    _plate(canvas, 85*s, barY, 4*s, 14*s, c);
  }

  @override bool shouldRepaint(_LyingPressPainter o) => o.p != p;
}

// 2. PUSH UP — side view, body rises
class _PushUpPainter extends CustomPainter {
  final double p; final Color c;
  _PushUpPainter(this.p, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final b = _body(s), ac = _ac(c, s);

    // Ground
    _line(canvas, 4*s, 84*s, 96*s, 84*s, ac..strokeWidth = 1.5*s);

    // Body rises: shoulder goes from y=76 (low) to y=58 (high)
    final shY = _lerp(76, 58, p) * s;
    // Toes fixed, body is a rigid plank
    _line(canvas, 78*s, 84*s, 20*s, shY, b);  // body line
    _head(canvas, 11*s, shY - 5*s, 5.5*s, b);

    // Arm: shoulder → elbow → hand
    final elbY = _lerp(80, 72, p) * s;
    final elbX = _lerp(15, 18, p) * s;
    _line(canvas, 20*s, shY, elbX, elbY, b);
    _line(canvas, elbX, elbY, 20*s, 84*s, b);
  }

  @override bool shouldRepaint(_PushUpPainter o) => o.p != p;
}

// 3. DEADLIFT — side view, hip hinge to standing
class _DeadliftPainter extends CustomPainter {
  final double p; final Color c;
  _DeadliftPainter(this.p, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final b = _body(s), ac = _ac(c, s, w: 3.0);

    // Ankle fixed
    const ankX = 54.0, ankY = 84.0;
    final kneeX = _lerp(50, 52, p), kneeY = _lerp(70, 72, p);
    final hipX = _lerp(44, 50, p), hipY = _lerp(56, 60, p);
    final shX = _lerp(72, 46, p), shY = _lerp(36, 28, p);
    final hdX = _lerp(80, 44, p), hdY = _lerp(28, 20, p);

    // Legs
    _line(canvas, ankX*s, ankY*s, kneeX*s, kneeY*s, b);
    _line(canvas, kneeX*s, kneeY*s, hipX*s, hipY*s, b);
    // Torso
    _line(canvas, hipX*s, hipY*s, shX*s, shY*s, b);
    _head(canvas, hdX*s, hdY*s, 5.5*s, b);

    // Bar position: floor(84) → hip height(61)
    final barY = _lerp(84, 61, p) * s;
    final gripX = _lerp(66, 46, p) * s;
    // Arms (straight, hanging)
    _line(canvas, shX*s, (shY+4)*s, gripX, barY, b);

    // Bar + plates
    _line(canvas, (gripX/s - 22)*s, barY, (gripX/s + 22)*s, barY, ac);
    _plate(canvas, (gripX/s - 24)*s, barY, 4.5*s, 18*s, c);
    _plate(canvas, (gripX/s + 24)*s, barY, 4.5*s, 18*s, c);
  }

  @override bool shouldRepaint(_DeadliftPainter o) => o.p != p;
}

// 4. BENT ROW — side view, pulling arm
class _BentRowPainter extends CustomPainter {
  final double p; final Color c;
  _BentRowPainter(this.p, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final b = _body(s), ac = _ac(c, s, w: 2.8);

    // Fixed bent-over pose (facing right)
    _head(canvas, 74*s, 30*s, 5.5*s, b);
    _line(canvas, 68*s, 36*s, 44*s, 54*s, b);   // torso
    _line(canvas, 44*s, 54*s, 50*s, 70*s, b);   // upper leg
    _line(canvas, 50*s, 70*s, 54*s, 84*s, b);   // shin

    // Pulling arm: extended → pulled to hip
    final elbX = _lerp(72, 56, p), elbY = _lerp(56, 44, p);
    final handX = _lerp(70, 50, p), handY = _lerp(72, 50, p);
    _line(canvas, 64*s, 40*s, elbX*s, elbY*s, b);
    _line(canvas, elbX*s, elbY*s, handX*s, handY*s, b);

    // Dumbbell/bar at hand
    _line(canvas, (handX-4)*s, handY*s, (handX+4)*s, handY*s, ac..strokeWidth = 3.5*s);
    _plate(canvas, (handX-6)*s, handY*s, 2.5*s, 9*s, c);
    _plate(canvas, (handX+6)*s, handY*s, 2.5*s, 9*s, c);
  }

  @override bool shouldRepaint(_BentRowPainter o) => o.p != p;
}

// 5. PULL DOWN — side view, seated, bar from overhead to chin
class _PullDownPainter extends CustomPainter {
  final double p; final Color c;
  _PullDownPainter(this.p, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final b = _body(s), ac = _ac(c, s, w: 2.8);

    // Seated figure (facing left slightly)
    _head(canvas, 44*s, 28*s, 5.5*s, b);
    _line(canvas, 46*s, 38*s, 50*s, 68*s, b);  // torso
    _line(canvas, 50*s, 68*s, 64*s, 74*s, b);  // thigh
    _line(canvas, 64*s, 74*s, 66*s, 84*s, b);  // shin

    // Cable line (accent, thin, from top)
    final barY = _lerp(22, 50, p) * s;
    final handX = _lerp(38, 42, p) * s;
    _line(canvas, handX, barY, 50*s, 8*s, _ac(c, s, w: 1.2)..color = c.withValues(alpha: 0.5));

    // Arm: shoulder → hand
    _line(canvas, 42*s, 40*s, handX, barY, b);

    // Bar
    _line(canvas, (handX/s - 18)*s, barY, (handX/s + 18)*s, barY, ac);
  }

  @override bool shouldRepaint(_PullDownPainter o) => o.p != p;
}

// 6. PULL UP — side view, body rises
class _PullUpPainter extends CustomPainter {
  final double p; final Color c;
  _PullUpPainter(this.p, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final b = _body(s), ac = _ac(c, s, w: 3.0);

    // Bar at top
    _line(canvas, 22*s, 10*s, 78*s, 10*s, ac);

    // Body rises: p=0 hanging, p=1 chin over bar
    final shY = _lerp(42, 22, p);
    final hipY = _lerp(72, 52, p);
    final feetY = _lerp(92, 72, p);

    // Arms from hands (on bar) to shoulder
    _line(canvas, 36*s, 12*s, 44*s, shY*s, b);
    _line(canvas, 56*s, 12*s, 52*s, shY*s, b);
    // Torso + legs
    _line(canvas, 44*s, shY*s, 48*s, hipY*s, b);
    _head(canvas, 44*s, (shY - 10)*s, 5.5*s, b);
    _line(canvas, 48*s, hipY*s, 50*s, feetY*s, b);
  }

  @override bool shouldRepaint(_PullUpPainter o) => o.p != p;
}

// 7. SQUAT — side view
class _SquatPainter extends CustomPainter {
  final double p; final Color c;
  _SquatPainter(this.p, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final b = _body(s), ac = _ac(c, s, w: 3.2);

    const ankX = 55.0, ankY = 84.0;
    // Joints interpolate: bottom of squat (p=0) → standing (p=1)
    final kneeX = _lerp(42, 53, p), kneeY = _lerp(66, 72, p);
    final hipX = _lerp(46, 52, p), hipY = _lerp(52, 60, p);
    final shX = _lerp(50, 50, p), shY = _lerp(32, 28, p);
    final hdX = _lerp(50, 50, p), hdY = _lerp(24, 20, p);

    // Barbell on back/shoulders
    final barX1 = _lerp(26, 28, p), barX2 = _lerp(70, 72, p), barY = _lerp(34, 30, p);
    _line(canvas, barX1*s, barY*s, barX2*s, barY*s, ac);
    _plate(canvas, barX1*s, barY*s, 4.5*s, 16*s, c);
    _plate(canvas, barX2*s, barY*s, 4.5*s, 16*s, c);

    // Leg chain
    _line(canvas, ankX*s, ankY*s, kneeX*s, kneeY*s, b);
    _line(canvas, kneeX*s, kneeY*s, hipX*s, hipY*s, b);
    // Torso + head
    _line(canvas, hipX*s, hipY*s, shX*s, shY*s, b);
    _head(canvas, hdX*s, hdY*s, 5.5*s, b);

    // Arms on bar
    _line(canvas, shX*s, shY*s, barX1*s, barY*s, _dim(s));
    _line(canvas, shX*s, shY*s, barX2*s, barY*s, _dim(s));
  }

  @override bool shouldRepaint(_SquatPainter o) => o.p != p;
}

// 8. LUNGE — side view, split stance
class _LungePainter extends CustomPainter {
  final double p; final Color c;
  _LungePainter(this.p, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final b = _body(s);

    // Front foot fixed, back foot fixed
    const fFoot = 30.0, bFoot = 72.0, floor = 84.0;
    // Joints: p=0 deep lunge, p=1 standing
    final fKneeX = _lerp(32, 36, p), fKneeY = _lerp(66, 74, p);
    final bKneeX = _lerp(68, 64, p), bKneeY = _lerp(68, 74, p);
    final hipX = _lerp(48, 50, p), hipY = _lerp(54, 62, p);
    final shX = _lerp(46, 48, p), shY = _lerp(34, 38, p);

    // Front leg
    _line(canvas, fFoot*s, floor*s, fKneeX*s, fKneeY*s, b);
    _line(canvas, fKneeX*s, fKneeY*s, hipX*s, hipY*s, b);
    // Back leg
    _line(canvas, bFoot*s, floor*s, bKneeX*s, bKneeY*s, b);
    _line(canvas, bKneeX*s, bKneeY*s, hipX*s, hipY*s, b);
    // Torso + head
    _line(canvas, hipX*s, hipY*s, shX*s, shY*s, b);
    _head(canvas, shX*s, (shY - 9)*s, 5.5*s, b);

    // Dumbbell in hand (side detail, accent)
    final db = _ac(c, s, w: 3.0);
    _line(canvas, (shX - 6)*s, (shY + 4)*s, (shX - 6)*s, (shY + 16)*s, db);
    _plate(canvas, (shX - 6)*s, (shY + 2)*s, 2.5*s, 7*s, c);
    _plate(canvas, (shX - 6)*s, (shY + 18)*s, 2.5*s, 7*s, c);
  }

  @override bool shouldRepaint(_LungePainter o) => o.p != p;
}

// 9. OVERHEAD PRESS — side view, bar shoulder→overhead
class _OHPressPainter extends CustomPainter {
  final double p; final Color c;
  _OHPressPainter(this.p, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final b = _body(s), ac = _ac(c, s, w: 3.0);

    // Standing figure (fixed)
    _head(canvas, 48*s, 22*s, 5.5*s, b);
    _line(canvas, 50*s, 32*s, 52*s, 64*s, b);  // torso
    _line(canvas, 52*s, 64*s, 54*s, 74*s, b);  // thigh
    _line(canvas, 54*s, 74*s, 56*s, 84*s, b);  // shin

    // Bar: shoulder(32) → overhead(10)
    final barY = _lerp(32, 10, p) * s;
    final elbX = _lerp(38, 40, p), elbY = _lerp(44, 22, p);
    final handX = _lerp(40, 40, p);

    _line(canvas, 44*s, 36*s, elbX*s, elbY*s, b);       // upper arm
    _line(canvas, elbX*s, elbY*s, handX*s, barY, b);    // forearm

    _line(canvas, 22*s, barY, 72*s, barY, ac);
    _plate(canvas, 24*s, barY, 4*s, 14*s, c);
    _plate(canvas, 70*s, barY, 4*s, 14*s, c);
  }

  @override bool shouldRepaint(_OHPressPainter o) => o.p != p;
}

// 10. LATERAL RAISE — front view, arms spread
class _LateralRaisePainter extends CustomPainter {
  final double p; final Color c;
  _LateralRaisePainter(this.p, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final b = _body(s);

    // Front view standing figure
    _head(canvas, 50*s, 18*s, 6*s, b);
    _line(canvas, 50*s, 26*s, 50*s, 64*s, b);  // torso
    _line(canvas, 50*s, 64*s, 44*s, 84*s, b);  // left leg
    _line(canvas, 50*s, 64*s, 56*s, 84*s, b);  // right leg

    // Arms: at sides (p=0) → raised to shoulder height (p=1)
    final lArmX = _lerp(34, 14, p), lArmY = _lerp(50, 32, p);
    final rArmX = _lerp(66, 86, p), rArmY = _lerp(50, 32, p);

    _line(canvas, 36*s, 34*s, lArmX*s, lArmY*s, b);
    _line(canvas, 64*s, 34*s, rArmX*s, rArmY*s, b);

    // Dumbbells at hand
    _plate(canvas, lArmX*s, lArmY*s, 5*s, 5*s, c);
    _plate(canvas, rArmX*s, rArmY*s, 5*s, 5*s, c);

    // Motion arc hint (dim, accent)
    if (p > 0.1) {
      final path = Path()
        ..moveTo(34*s, 50*s)
        ..quadraticBezierTo(20*s, 42*s, 14*s, 32*s);
      canvas.drawPath(path, _ac(c, s, w: 1.2)..color = c.withValues(alpha: p * 0.4));
    }
  }

  @override bool shouldRepaint(_LateralRaisePainter o) => o.p != p;
}

// 11. BICEP CURL — side view, forearm swings up
class _BicepCurlPainter extends CustomPainter {
  final double p; final Color c;
  _BicepCurlPainter(this.p, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final b = _body(s), ac = _ac(c, s, w: 3.0);

    // Standing figure
    _head(canvas, 50*s, 22*s, 5.5*s, b);
    _line(canvas, 50*s, 32*s, 52*s, 64*s, b);
    _line(canvas, 52*s, 64*s, 54*s, 74*s, b);
    _line(canvas, 54*s, 74*s, 56*s, 84*s, b);

    // Upper arm hangs (fixed)
    _line(canvas, 42*s, 36*s, 44*s, 58*s, b);

    // Forearm swings: down (p=0) → curled (p=1)
    final handX = _lerp(46, 54, p), handY = _lerp(82, 40, p);
    _line(canvas, 44*s, 58*s, handX*s, handY*s, b);

    // Dumbbell
    _line(canvas, (handX - 5)*s, handY*s, (handX + 5)*s, handY*s, ac);
    _plate(canvas, (handX - 7)*s, handY*s, 2.5*s, 8*s, c);
    _plate(canvas, (handX + 7)*s, handY*s, 2.5*s, 8*s, c);
  }

  @override bool shouldRepaint(_BicepCurlPainter o) => o.p != p;
}

// 12. TRICEP PUSHDOWN — side view, forearm extends down
class _TricepPainter extends CustomPainter {
  final double p; final Color c;
  _TricepPainter(this.p, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final b = _body(s), ac = _ac(c, s, w: 2.8);

    // Standing figure
    _head(canvas, 48*s, 22*s, 5.5*s, b);
    _line(canvas, 50*s, 32*s, 52*s, 64*s, b);
    _line(canvas, 52*s, 64*s, 54*s, 74*s, b);
    _line(canvas, 54*s, 74*s, 56*s, 84*s, b);

    // Upper arm stays back (fixed elbow at side)
    _line(canvas, 44*s, 36*s, 44*s, 54*s, b);

    // Forearm: up(p=0) → down(p=1)
    final handX = _lerp(44, 48, p), handY = _lerp(42, 76, p);
    _line(canvas, 44*s, 54*s, handX*s, handY*s, b);

    // Cable from top (thin accent)
    _line(canvas, handX*s, handY*s, 46*s, 6*s, _ac(c, s, w: 1.2)..color = c.withValues(alpha: 0.45));

    // Handle/bar
    _line(canvas, (handX - 5)*s, handY*s, (handX + 5)*s, handY*s, ac);
  }

  @override bool shouldRepaint(_TricepPainter o) => o.p != p;
}

// 13. PLANK — side view, breathing (slight lift)
class _PlankPainter extends CustomPainter {
  final double p; final Color c;
  _PlankPainter(this.p, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final b = _body(s), ac = _ac(c, s, w: 1.5);

    // Ground
    _line(canvas, 4*s, 84*s, 96*s, 84*s, ac..color = c.withValues(alpha: 0.35));

    // Slight breathe: torso lifts a tiny bit
    final midLift = p * 2.5;
    // Forearms on floor
    _line(canvas, 18*s, 80*s, 22*s, 84*s, b);  // forearm
    _line(canvas, 12*s, 84*s, 26*s, 84*s, b);  // elbow-to-wrist on floor

    // Body line (toes to shoulder) with slight arc up
    _line(canvas, 80*s, 84*s, 20*s, (74 - midLift)*s, b);
    _head(canvas, 11*s, (70 - midLift)*s, 5.5*s, b);

    // Toes
    _line(canvas, 78*s, 84*s, 82*s, 84*s, b);
  }

  @override bool shouldRepaint(_PlankPainter o) => o.p != p;
}

// 14. CRUNCH — side view, upper body curls up
class _CrunchPainter extends CustomPainter {
  final double p; final Color c;
  _CrunchPainter(this.p, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final b = _body(s), ac = _ac(c, s, w: 1.5);

    // Ground
    _line(canvas, 4*s, 84*s, 96*s, 84*s, ac..color = c.withValues(alpha: 0.3));

    // Feet + bent knees (fixed)
    _line(canvas, 72*s, 84*s, 58*s, 68*s, b);  // shin
    _line(canvas, 58*s, 68*s, 42*s, 72*s, b);  // thigh
    // Hip (fixed)
    const hipX = 42.0, hipY = 74.0;

    // Upper body curls up
    final shX = _lerp(14, 34, p), shY = _lerp(72, 58, p);
    final hdX = _lerp(8, 28, p), hdY = _lerp(68, 52, p);

    _line(canvas, hipX*s, hipY*s, shX*s, shY*s, b);
    _head(canvas, hdX*s, hdY*s, 5.5*s, b);
  }

  @override bool shouldRepaint(_CrunchPainter o) => o.p != p;
}

// 15. RUNNING — side view, legs alternate
class _RunningPainter extends CustomPainter {
  final double p; final Color c;
  _RunningPainter(this.p, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final b = _body(s);

    // Body center (slight lean)
    _head(canvas, 47*s, 22*s, 5.5*s, b);
    _line(canvas, 50*s, 32*s, 52*s, 56*s, b);  // torso

    // Legs alternate: p=0 (left forward) ↔ p=1 (right forward)
    final lKneeX = _lerp(56, 44, p), lKneeY = _lerp(64, 68, p);
    final lFootX = _lerp(64, 36, p), lFootY = _lerp(78, 84, p);
    final rKneeX = _lerp(44, 56, p), rKneeY = _lerp(68, 64, p);
    final rFootX = _lerp(36, 64, p), rFootY = _lerp(84, 78, p);

    // Dim back leg, bright front leg
    final front = p < 0.5 ? b : _dim(s);
    final back = p < 0.5 ? _dim(s) : b;

    _line(canvas, 52*s, 56*s, lKneeX*s, lKneeY*s, front);
    _line(canvas, lKneeX*s, lKneeY*s, lFootX*s, lFootY*s, front);
    _line(canvas, 52*s, 56*s, rKneeX*s, rKneeY*s, back);
    _line(canvas, rKneeX*s, rKneeY*s, rFootX*s, rFootY*s, back);

    // Arms opposite
    final lArmX = _lerp(58, 36, p), lArmY = _lerp(46, 44, p);
    final rArmX = _lerp(36, 58, p), rArmY = _lerp(44, 46, p);
    _line(canvas, 48*s, 36*s, lArmX*s, lArmY*s, front);
    _line(canvas, 48*s, 36*s, rArmX*s, rArmY*s, back);
  }

  @override bool shouldRepaint(_RunningPainter o) => o.p != p;
}

// 16. CALF RAISE — side view, heel rises
class _CalfRaisePainter extends CustomPainter {
  final double p; final Color c;
  _CalfRaisePainter(this.p, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final b = _body(s), ac = _ac(c, s, w: 1.5);

    // Ground line
    _line(canvas, 4*s, 84*s, 96*s, 84*s, ac..color = c.withValues(alpha: 0.3));

    // Fixed upper body
    _head(canvas, 48*s, 20*s, 5.5*s, b);
    _line(canvas, 50*s, 30*s, 52*s, 60*s, b);  // torso
    _line(canvas, 52*s, 60*s, 53*s, 72*s, b);  // thigh

    // Ankle rises, heel lifts, toe stays down
    final ankY = _lerp(80, 68, p);
    final heelY = _lerp(84, 62, p);
    _line(canvas, 54*s, 72*s, 53*s, ankY*s, b);  // shin
    // Foot: heel to toe (toe fixed at floor)
    _line(canvas, 42*s, heelY*s, 64*s, 84*s, b);
  }

  @override bool shouldRepaint(_CalfRaisePainter o) => o.p != p;
}

// 17. LEG CURL — side view, prone, leg swings up
class _LegCurlPainter extends CustomPainter {
  final double p; final Color c;
  _LegCurlPainter(this.p, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final b = _body(s), ac = _ac(c, s, w: 2.6);

    // Bench pad
    _line(canvas, 8*s, 58*s, 86*s, 58*s, ac);
    _line(canvas, 16*s, 58*s, 16*s, 76*s, ac);
    _line(canvas, 80*s, 58*s, 80*s, 76*s, ac);

    // Prone figure (face down, facing right)
    _head(canvas, 12*s, 50*s, 5.5*s, b);
    _line(canvas, 18*s, 54*s, 74*s, 54*s, b);  // torso

    // Knee pivot fixed, foot swings up (p=0 straight, p=1 curled)
    const kneeX = 78.0, kneeY = 56.0;
    final footX = _lerp(94, 82, p), footY = _lerp(58, 32, p);
    _line(canvas, kneeX*s, kneeY*s, footX*s, footY*s, b);

    // Arm by side
    _line(canvas, 20*s, 56*s, 28*s, 68*s, b);
  }

  @override bool shouldRepaint(_LegCurlPainter o) => o.p != p;
}

// 18. SHRUG — front view, shoulders rise
class _ShrugPainter extends CustomPainter {
  final double p; final Color c;
  _ShrugPainter(this.p, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final b = _body(s), ac = _ac(c, s, w: 3.0);

    // Head stays, shoulders rise
    _head(canvas, 50*s, 18*s, 6*s, b);
    final shY = _lerp(34, 28, p);  // shoulders rise
    _line(canvas, 26*s, shY*s, 74*s, shY*s, b);  // shoulder line

    // Torso + legs
    _line(canvas, 50*s, shY*s, 50*s, 66*s, b);
    _line(canvas, 50*s, 66*s, 44*s, 84*s, b);
    _line(canvas, 50*s, 66*s, 56*s, 84*s, b);

    // Arms + dumbbells
    final lHandY = _lerp(62, 56, p), rHandY = _lerp(62, 56, p);
    _line(canvas, 26*s, shY*s, 22*s, lHandY*s, b);
    _line(canvas, 74*s, shY*s, 78*s, rHandY*s, b);

    _line(canvas, 14*s, lHandY*s, 26*s, lHandY*s, ac);
    _plate(canvas, 12*s, lHandY*s, 2.5*s, 9*s, c);
    _plate(canvas, 28*s, lHandY*s, 2.5*s, 9*s, c);
    _line(canvas, 72*s, rHandY*s, 86*s, rHandY*s, ac);
    _plate(canvas, 70*s, rHandY*s, 2.5*s, 9*s, c);
    _plate(canvas, 88*s, rHandY*s, 2.5*s, 9*s, c);
  }

  @override bool shouldRepaint(_ShrugPainter o) => o.p != p;
}

// ── Pulsing generic fallback ──────────────────────────────────────────────────

class _PulseIllustration extends StatelessWidget {
  final double progress;
  final Color accent;
  final IconData icon;
  final double size;

  const _PulseIllustration({
    required this.progress,
    required this.accent,
    required this.icon,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final glowR = size * (0.46 + 0.16 * progress);
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: glowR,
          height: glowR,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                accent.withValues(alpha: 0.10 + 0.20 * progress),
                accent.withValues(alpha: 0),
              ],
            ),
          ),
        ),
        Icon(icon, color: Colors.white, size: size * 0.42),
      ],
    );
  }
}
