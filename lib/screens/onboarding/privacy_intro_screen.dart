import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app.dart' show NudgeTokens;
import '../../widgets/orbit_animation.dart';

class PrivacyIntroScreen extends StatelessWidget {
  final VoidCallback onContinue;

  const PrivacyIntroScreen({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NudgeTokens.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.2,
                  colors: [
                    NudgeTokens.purple.withValues(alpha: 0.14),
                    NudgeTokens.bg,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const _OrbitIconSystem(size: 320),
                        const SizedBox(height: 34),
                        Text(
                          'Nudge',
                          style: GoogleFonts.outfit(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'A privacy-first life improvement app.\nHealth, finance, and discipline in one offline vault.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            height: 1.5,
                            color: NudgeTokens.textMid,
                          ),
                        ),
                        const SizedBox(height: 22),
                        const _FeatureRow(
                          icon: Icons.lock_rounded,
                          title: 'Local by default',
                          subtitle: 'Everything is stored on your device.',
                          color: NudgeTokens.green,
                        ),
                        const SizedBox(height: 12),
                        const _FeatureRow(
                          icon: Icons.visibility_off_rounded,
                          title: 'Private cloud backup',
                          subtitle: 'Encrypted before upload. Only you can decrypt.',
                          color: NudgeTokens.blue,
                        ),
                        const SizedBox(height: 12),
                        const _FeatureRow(
                          icon: Icons.bolt_rounded,
                          title: 'Built for momentum',
                          subtitle: 'Small daily inputs. Clear, compounding wins.',
                          color: NudgeTokens.amber,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: onContinue,
                      style: FilledButton.styleFrom(
                        backgroundColor: NudgeTokens.purple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Enter Nudge',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No account required. Sign in only if you want backups.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: NudgeTokens.textLow,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: NudgeTokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    height: 1.35,
                    color: NudgeTokens.textMid,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbitIconSystem extends StatefulWidget {
  final double size;
  const _OrbitIconSystem({required this.size});

  @override
  State<_OrbitIconSystem> createState() => _OrbitIconSystemState();
}

class _OrbitIconSystemState extends State<_OrbitIconSystem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final items = const [
      _OrbitIconSpec(
        icon: Icons.favorite_rounded,
        color: NudgeTokens.healthB,
        radius: 0.35,
        speed: 1.00,
        phase: 0.0,
        label: 'Health',
      ),
      _OrbitIconSpec(
        icon: Icons.account_balance_wallet_rounded,
        color: NudgeTokens.finB,
        radius: 0.40,
        speed: 0.82,
        phase: math.pi * 2 / 3,
        label: 'Finance',
      ),
      _OrbitIconSpec(
        icon: Icons.fitness_center_rounded,
        color: NudgeTokens.amber,
        radius: 0.38,
        speed: 1.18,
        phase: math.pi * 4 / 3,
        label: 'Discipline',
      ),
    ];

    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value * 2 * math.pi;
          final center = Offset(s / 2, s / 2);

          final positioned = <_OrbitPlaced>[];
          for (final it in items) {
            final a = t * it.speed + it.phase;
            final rx = (s * it.radius);
            final ry = (s * 0.14);

            final lx = rx * math.cos(a);
            final ly = ry * math.sin(a);
            final tilt = (it.phase - math.pi) * 0.25;
            final x = lx * math.cos(tilt) - ly * math.sin(tilt);
            final y = lx * math.sin(tilt) + ly * math.cos(tilt);

            final z = (math.sin(a) + 1) / 2; // 0..1
            final scale = 0.78 + (z * 0.32);
            final opacity = 0.55 + (z * 0.45);

            final pos = center + Offset(x, y);
            positioned.add(_OrbitPlaced(
              depth: opacity,
              widget: Positioned(
                left: pos.dx - 22,
                top: pos.dy - 22,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: _OrbitIconBubble(icon: it.icon, color: it.color),
                  ),
                ),
              ),
            ));
          }

          // Simple z-sort: back-to-front.
          positioned.sort((a, b) => a.depth.compareTo(b.depth));

          return Stack(
            alignment: Alignment.center,
            children: [
              OrbitAnimation(size: s),
              ...positioned.map((p) => p.widget),
            ],
          );
        },
      ),
    );
  }
}

class _OrbitPlaced {
  final double depth;
  final Widget widget;
  const _OrbitPlaced({required this.depth, required this.widget});
}

class _OrbitIconBubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _OrbitIconBubble({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.22),
            color.withValues(alpha: 0.16),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Icon(icon, size: 22, color: Colors.white),
    );
  }
}

class _OrbitIconSpec {
  final IconData icon;
  final Color color;
  final double radius;
  final double speed;
  final double phase;
  final String label;

  const _OrbitIconSpec({
    required this.icon,
    required this.color,
    required this.radius,
    required this.speed,
    required this.phase,
    required this.label,
  });
}
