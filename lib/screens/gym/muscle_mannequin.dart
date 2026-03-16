import 'package:flutter/material.dart';
import '../../app.dart' show NudgeTokens;

enum MannequinView { front, back }

// ─────────────────────────────────────────────────────────────────────────────
class MuscleMapDuo extends StatelessWidget {
  final Set<String> activeMuscles;
  final double height;

  const MuscleMapDuo({
    super.key,
    required this.activeMuscles,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LabelledView(activeMuscles: activeMuscles, height: height, view: MannequinView.front),
        SizedBox(width: height * 0.14),
        _LabelledView(activeMuscles: activeMuscles, height: height, view: MannequinView.back),
      ],
    );
  }
}

class _LabelledView extends StatelessWidget {
  final Set<String> activeMuscles;
  final double height;
  final MannequinView view;

  const _LabelledView({
    required this.activeMuscles,
    required this.height,
    required this.view,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MuscleMannequin(activeMuscles: activeMuscles, height: height, view: view),
        const SizedBox(height: 6),
        Text(
          view == MannequinView.front ? 'FRONT' : 'BACK',
          style: const TextStyle(
            fontSize: 9,
            color: NudgeTokens.textLow,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class MuscleMannequin extends StatelessWidget {
  final Set<String> activeMuscles;
  final double height;
  final MannequinView view;

  const MuscleMannequin({
    super.key,
    required this.activeMuscles,
    this.height = 160,
    this.view = MannequinView.front,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: height * 0.52,
      child: CustomPaint(painter: _BodyPainter(activeMuscles, view)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Virtual 100×200 coordinate grid. All x1<x2, y1<y2 — no inversion possible.
// ─────────────────────────────────────────────────────────────────────────────
class _BodyPainter extends CustomPainter {
  final Set<String> muscles;
  final MannequinView view;

  const _BodyPainter(this.muscles, this.view);

  static const _inactive = Color(0xFF141C24);
  static const _border   = Color(0xFF263342);

  bool _on(List<String> keys) => keys.any(
        (k) => muscles.any((m) => m.toLowerCase().contains(k.toLowerCase())),
      );

  Path _circle(double cx, double cy, double r, double w, double h) =>
      Path()..addOval(Rect.fromCircle(
          center: Offset((cx / 100) * w, (cy / 200) * h),
          radius: (r / 100) * w));

  Path _oval(double cx, double cy, double wPct, double hPct, double w, double h) {
    return Path()
      ..addOval(Rect.fromCenter(
        center: Offset((cx / 100) * w, (cy / 200) * h),
        width: (wPct / 100) * w,
        height: (hPct / 200) * h,
      ));
  }

  Path _merge(List<Path> paths) {
    if (paths.isEmpty) return Path();
    Path result = paths.first;
    for (int i = 1; i < paths.length; i++) {
        result = Path.combine(PathOperation.union, result, paths[i]);
    }
    return result;
  }
  
  void _draw(Canvas canvas, Path p, bool active) {
    if (active) {
      // Outer neon glow
      canvas.drawPath(p, Paint()
        ..color = NudgeTokens.gymB.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..style = PaintingStyle.fill);

      // Solid color fill
      canvas.drawPath(p, Paint()
        ..color = NudgeTokens.gymB
        ..style = PaintingStyle.fill);

      // Bright inner rim
      canvas.drawPath(p, Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 1.2);
    } else {
      // Soft dark base
      canvas.drawPath(p, Paint()
        ..color = _inactive
        ..style = PaintingStyle.fill);

      // Crisp border
      canvas.drawPath(p, Paint()
        ..color = _border
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 1.0);
    }
  }

  void _dim(Canvas canvas, Path p) => _draw(canvas, p, false);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Head + neck
    _dim(canvas, _merge([
      _oval(50, 14, 16, 22, w, h),
      _circle(50, 26, 6, w, h)
    ]));

    if (view == MannequinView.front) {
      _paintFront(canvas, w, h);
    } else {
      _paintBack(canvas, w, h);
    }
  }

  void _paintFront(Canvas canvas, double w, double h) {
    final chest  = _on(['Chest', 'Pec']);
    final delt   = _on(['Shoulder', 'Delt', 'Full Body']);
    final arms   = _on(['Bicep', 'Arm', 'Forearm', 'Full Body']);
    final core   = _on(['Core', 'Ab', 'Oblique', 'Full Body']);
    final legs   = _on(['Leg', 'Quad', 'Hip', 'Full Body']);
    final calves = _on(['Calf', 'Leg', 'Full Body']);

    // Shoulders
    _draw(canvas, _merge([
        _circle(25, 34, 13, w, h),
        _circle(21, 43, 11, w, h),
    ]), delt);
    _draw(canvas, _merge([
        _circle(75, 34, 13, w, h),
        _circle(79, 43, 11, w, h),
    ]), delt);

    // Chest (Pecs pushed wider and joined seamlessly into delts)
    _draw(canvas, _merge([
        _oval(32, 40, 26, 22, w, h),
        _oval(68, 40, 26, 22, w, h),
        _oval(50, 41, 30, 18, w, h)
    ]), chest);

    // Arms
    _draw(canvas, _merge([
        _oval(14, 54, 13, 24, w, h),
        _oval(11, 75, 11, 28, w, h),
        _circle(13, 65, 7, w, h)
    ]), arms);
    _draw(canvas, _merge([
        _oval(86, 54, 13, 24, w, h),
        _oval(89, 75, 11, 28, w, h),
        _circle(87, 65, 7, w, h)
    ]), arms);

    // Abs/Core (Contiguous block overlapping lower chest AND hips so stomach has no gap)
    Path corePath = Path();
    for (int i=0; i<4; i++) {
        corePath = Path.combine(PathOperation.union, corePath, _circle(41, 52 + (i*9.0), 9, w, h));
        corePath = Path.combine(PathOperation.union, corePath, _circle(59, 52 + (i*9.0), 9, w, h));
    }
    // Deeply overlapping gap filler for stomach to hips
    corePath = Path.combine(PathOperation.union, corePath, _oval(50, 68, 28, 42, w, h));
    _draw(canvas, corePath, core);

    // Quads (Joined up into the core/stomach base)
    _draw(canvas, _merge([
        _oval(34, 110, 26, 60, w, h),
        _oval(66, 110, 26, 60, w, h),
        _oval(50, 94, 28, 30, w, h) // thick groin joiner linking up into core
    ]), legs);

    // Calves
    _draw(canvas, _merge([
        _oval(34, 166, 17, 42, w, h),
        _circle(34, 149, 9, w, h)
    ]), calves);
    _draw(canvas, _merge([
        _oval(66, 166, 17, 42, w, h),
        _circle(66, 149, 9, w, h)
    ]), calves);
  }

  void _paintBack(Canvas canvas, double w, double h) {
    final traps  = _on(['Back', 'Trap', 'Full Body']);
    final lats   = _on(['Back', 'Lat', 'Full Body']);
    final delt   = _on(['Shoulder', 'Delt', 'Full Body']);
    final arms   = _on(['Tricep', 'Arm', 'Forearm', 'Full Body']);
    final lower  = _on(['Back', 'Core', 'Lower Back', 'Erector', 'Full Body']);
    final glutes = _on(['Glute', 'Leg', 'Full Body']);
    final hams   = _on(['Hamstring', 'Leg', 'Full Body']);
    final calves = _on(['Calf', 'Leg', 'Full Body']);

    // Shoulders
    _draw(canvas, _merge([
        _circle(28, 34, 11, w, h),
        _circle(24, 42, 9, w, h),
    ]), delt);
    _draw(canvas, _merge([
        _circle(72, 34, 11, w, h),
        _circle(76, 42, 9, w, h),
    ]), delt);

    // Traps (Narrowed and tapered up)
    _draw(canvas, _merge([
       _oval(50, 31, 28, 16, w, h),
       _oval(50, 40, 16, 20, w, h)
    ]), traps);

    // Lats (Slimmer V-Taper, pulled in tighter to the spine)
    _draw(canvas, _merge([
        _oval(35, 54, 16, 36, w, h),
        _oval(65, 54, 16, 36, w, h),
        _oval(50, 52, 22, 20, w, h) // Central upper-back bridge
    ]), lats);

    // Lower Back (Slimmer erectors)
    _draw(canvas, _merge([
        _oval(45, 74, 10, 26, w, h),
        _oval(55, 74, 10, 26, w, h),
        _oval(50, 74, 12, 26, w, h)
    ]), lower);

    // Triceps & Forearms (Adjusted position slightly inwards)
    _draw(canvas, _merge([
        _oval(17, 54, 11, 24, w, h),
        _oval(14, 75, 9, 28, w, h),
        _circle(16, 65, 6, w, h)
    ]), arms);
    _draw(canvas, _merge([
        _oval(83, 54, 11, 24, w, h),
        _oval(86, 75, 9, 28, w, h),
        _circle(84, 65, 6, w, h)
    ]), arms);

    // Glutes (Contiguous mass filling lower pelvic gap up into lower back)
    _draw(canvas, _merge([
       _oval(38, 96, 24, 24, w, h),
       _oval(62, 96, 24, 24, w, h),
       _oval(50, 93, 22, 20, w, h)
    ]), glutes);

    // Hamstrings
    _draw(canvas, _merge([
       _oval(36, 124, 24, 50, w, h),
       _oval(64, 124, 24, 50, w, h),
       _oval(50, 110, 20, 24, w, h) // gap fill
    ]), hams);

    // Calves
    _draw(canvas, _merge([
        _oval(34, 168, 15, 42, w, h),
        _circle(34, 149, 8, w, h)
    ]), calves);
    _draw(canvas, _merge([
        _oval(66, 168, 15, 42, w, h),
        _circle(66, 149, 8, w, h)
    ]), calves);
  }

  @override
  bool shouldRepaint(covariant _BodyPainter old) =>
      old.muscles != muscles || old.view != view;
}
