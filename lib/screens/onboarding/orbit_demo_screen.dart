import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app.dart' show NudgeTokens;
import '../../widgets/orbit_animation.dart';

class OrbitDemoScreen extends StatelessWidget {
  const OrbitDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NudgeTokens.bg,
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [
                    NudgeTokens.purple.withOpacity(0.05),
                    NudgeTokens.bg,
                  ],
                ),
              ),
            ),
          ),
          
          // Center Animation
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const OrbitAnimation(size: 320),
                const SizedBox(height: 60),
                
                // Text content
                Text(
                  'INITIALISING SYSTEM',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4.0,
                    color: NudgeTokens.textLow,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Establishing Orbit',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    'Syncing Health, Finance, and Discipline into your private Data Vault.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: NudgeTokens.textMid,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom subtle indicator
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
