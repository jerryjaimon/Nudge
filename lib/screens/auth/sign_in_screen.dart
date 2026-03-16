// lib/screens/auth/sign_in_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app.dart' show NudgeTokens;
import '../../services/auth_service.dart';

class SignInScreen extends StatefulWidget {
  /// Called when the user successfully signs in OR chooses to continue offline.
  final VoidCallback onDone;

  const SignInScreen({super.key, required this.onDone});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      final user = await AuthService.signInWithGoogle();
      if (!mounted) return;
      if (user != null) {
        widget.onDone();
      } else {
        setState(() { _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NudgeTokens.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Logo / icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      NudgeTokens.purple.withValues(alpha: 0.8),
                      NudgeTokens.blue.withValues(alpha: 0.6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 40),
              ),

              const SizedBox(height: 28),

              Text('Nudge',
                  style: GoogleFonts.outfit(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1)),

              const SizedBox(height: 10),

              Text(
                'Sign in to sync your data securely across devices.\nAll backups are end-to-end encrypted.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: NudgeTokens.textMid,
                    height: 1.5),
              ),

              const Spacer(flex: 2),

              // Privacy note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: NudgeTokens.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: NudgeTokens.border),
                ),
                child: Column(
                  children: [
                    _PrivacyRow(
                      icon: Icons.lock_rounded,
                      color: NudgeTokens.green,
                      text: 'Your data is encrypted with your passphrase before upload',
                    ),
                    const SizedBox(height: 10),
                    _PrivacyRow(
                      icon: Icons.visibility_off_rounded,
                      color: NudgeTokens.blue,
                      text: 'Google only provides your account ID — no content is shared',
                    ),
                    const SizedBox(height: 10),
                    _PrivacyRow(
                      icon: Icons.smartphone_rounded,
                      color: NudgeTokens.amber,
                      text: 'Data lives on your device. Signing out does not delete it',
                    ),
                  ],
                ),
              ),

              const Spacer(),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: NudgeTokens.red, fontSize: 13)),
                ),

              // Google sign-in button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: NudgeTokens.purple))
                    : ElevatedButton(
                        onPressed: _signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1F1F1F),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Google "G" logo
                            _GoogleLogo(),
                            const SizedBox(width: 12),
                            Text('Continue with Google',
                                style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1F1F1F))),
                          ],
                        ),
                      ),
              ),

              const SizedBox(height: 14),

              // Skip option
              TextButton(
                onPressed: widget.onDone,
                child: Text(
                  'Use without account',
                  style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: NudgeTokens.textLow,
                      fontWeight: FontWeight.w600),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _PrivacyRow({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 12,
                  color: NudgeTokens.textMid,
                  height: 1.4)),
        ),
      ],
    );
  }
}

/// Paints a minimal Google "G" using a Canvas, avoiding any SVG/image dependency.
class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Draw coloured arc segments (simplified)
    final segments = [
      (const Color(0xFF4285F4), -10.0, 100.0),  // blue
      (const Color(0xFF34A853),  90.0,  90.0),  // green
      (const Color(0xFFFBBC05), 180.0,  80.0),  // yellow
      (const Color(0xFFEA4335), 260.0, 110.0),  // red
    ];
    for (final seg in segments) {
      final paint = Paint()
        ..color = seg.$1
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.22;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * 0.7),
        seg.$2 * 3.14159 / 180,
        seg.$3 * 3.14159 / 180,
        false,
        paint,
      );
    }

    // White horizontal bar (the middle of the G)
    canvas.drawRect(
      Rect.fromLTWH(c.dx - r * 0.05, c.dy - r * 0.18, r * 0.9, r * 0.36),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
