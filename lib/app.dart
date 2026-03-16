import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/auth/sign_in_screen.dart';
import 'storage.dart';
import 'utils/theme_service.dart';
import 'utils/nudge_theme_extension.dart';

/// Central design tokens — import this anywhere you need raw values.
abstract class NudgeTokens {
  // Background layers
  static const bg       = Color(0xFF050A0D);
  static const surface  = Color(0xFF0C1317);
  static const elevated = Color(0xFF111B20);
  static const card     = Color(0xFF0F1A1F);

  // Accent
  static const purple   = Color(0xFF7C4DFF);
  static const purpleDim= Color(0xFF4A2DCC);

  // Status
  static const green    = Color(0xFF39D98A);
  static const amber    = Color(0xFFFFBF00);
  static const red      = Color(0xFFFF4D6A);
  static const blue     = Color(0xFF5AC8FA);

  // Text
  static const textHigh = Colors.white;
  static const textMid  = Color(0xFFB0C4CF);
  static const textLow  = Color(0xFF5A7582);

  // Border
  static const border   = Color(0x14FFFFFF); // white ~8%
  static const borderHi = Color(0x22FFFFFF); // white ~13%

  // Feature accent colors (start/end gradient)
  static const gymA     = Color(0xFF1C2A17);
  static const gymB     = Color(0xFFB7FF5A);
  static const moviesA  = Color(0xFF2D1938);
  static const moviesB  = Color(0xFFFF2D95);
  static const booksA   = Color(0xFF0E2A1C);
  static const booksB   = Color(0xFF39D98A);
  static const pomA     = Color(0xFF1B1B2F);
  static const pomB     = Color(0xFF7C4DFF);
  static const protA    = Color(0xFF0B1D2A);
  static const protB    = Color(0xFF5AC8FA);
  static const exportA  = Color(0xFF0E1F15);
  static const exportB  = Color(0xFF4CD964);
  static const finA     = Color(0xFF0D141C); // Deep fintech slate blue
  static const finB     = Color(0xFF2990FF); // Crisp Azure
  static const foodA     = Color(0xFF2A1B0D); // Deep cocoa
  static const foodB     = Color(0xFFFF9500); // Vibrant orange
  static const healthA   = Color(0xFF0A1924); // Deep teal-blue
  static const healthB   = Color(0xFF5AC8FA); // Sky blue
}

class NudgeApp extends StatelessWidget {
  const NudgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService(),
      builder: (context, _) {
        final mode = ThemeService().mode;
        final themeData = _createThemeData(mode);

        return MaterialApp(
          title: 'Nudge',
          debugShowCheckedModeBanner: false,
          theme: themeData,
          builder: (context, child) {
            if (mode == NudgeThemeMode.terminal) {
              return Stack(
                children: [
                  child!,
                  const _TerminalOverlay(),
                ],
              );
            }
            return child!;
          },
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (ctx, _) {
              // 1. Show sign-in prompt on first launch
              // User can skip — app works fully offline without an account.
              final shownSignIn = AppStorage.settingsBox
                  .get('has_shown_sign_in', defaultValue: false) as bool;
              if (!shownSignIn && FirebaseAuth.instance.currentUser == null) {
                return SignInScreen(onDone: () {
                  AppStorage.settingsBox.put('has_shown_sign_in', true);
                  // Explicit Navigation since StreamBuilder doesn't listen to Hive
                  Navigator.of(ctx).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => AppStorage.hasSeenOnboarding 
                          ? const HomeScreen() 
                          : const OnboardingScreen(),
                    ),
                  );
                });
              }

              // 2. Show onboarding if not seen yet
              if (!AppStorage.hasSeenOnboarding) {
                return const OnboardingScreen();
              }

              // 3. Main app flow
              return const HomeScreen();
            },
          ),
        );
      },
    );
  }

  ThemeData _createThemeData(NudgeThemeMode mode) {
    final baseTheme = ThemeData.dark();
    
    // Choose font
    TextTheme textTheme;
    switch (mode) {
      case NudgeThemeMode.brutal:
      case NudgeThemeMode.terminal:
        textTheme = GoogleFonts.robotoMonoTextTheme(baseTheme.textTheme);
        break;
      case NudgeThemeMode.cute:
        textTheme = GoogleFonts.fredokaTextTheme(baseTheme.textTheme);
        break;
      default:
        textTheme = GoogleFonts.outfitTextTheme(baseTheme.textTheme);
    }

    // Base colors
    Color bg = NudgeTokens.bg;
    Color surface = NudgeTokens.surface;
    Color elevated = NudgeTokens.elevated;
    Color accent = NudgeTokens.purple;

    if (mode == NudgeThemeMode.terminal) {
      bg = Colors.black;
      surface = const Color(0xFF001100);
      elevated = const Color(0xFF002200);
      accent = const Color(0xFF00FF00);
    } else if (mode == NudgeThemeMode.cute) {
      bg = const Color(0xFFFFF9FA);
      surface = Colors.white;
      elevated = const Color(0xFFFDE8ED);
      accent = const Color(0xFFFF52AF);
    } else if (mode == NudgeThemeMode.neumorphic) {
      bg = const Color(0xFFE0E5EC);
      surface = const Color(0xFFE0E5EC);
      elevated = const Color(0xFFF0F5FC);
      accent = const Color(0xFF2D62ED);
    } else if (mode == NudgeThemeMode.brutal) {
      bg = Colors.white;
      surface = Colors.white;
      elevated = Colors.white;
      accent = NudgeTokens.purple;
    }

    // Explicit Icon Theme per aesthetic
    IconThemeData iconTheme;
    if (mode == NudgeThemeMode.brutal) {
      iconTheme = const IconThemeData(color: Colors.black, weight: 700, fill: 1, size: 28);
    } else if (mode == NudgeThemeMode.terminal) {
      iconTheme = const IconThemeData(color: Color(0xFF00FF00), weight: 300, fill: 0, shadows: [
        Shadow(color: Color(0xFF00FF00), blurRadius: 10, offset: Offset(0, 0))
      ]);
    } else if (mode == NudgeThemeMode.cute) {
      iconTheme = const IconThemeData(color: Color(0xFFFF52AF), weight: 600, fill: 1, size: 26);
    } else if (mode == NudgeThemeMode.neumorphic) {
      iconTheme = const IconThemeData(color: Color(0xFF2D62ED), weight: 400, fill: 0);
    } else {
      iconTheme = const IconThemeData(color: NudgeTokens.textHigh, weight: 400, fill: 0);
    }

    // Extension tokens
    final extension = _createExtension(mode, accent, surface, bg);

    return ThemeData(
      useMaterial3: true,
      brightness: (mode == NudgeThemeMode.cute || mode == NudgeThemeMode.neumorphic || mode == NudgeThemeMode.brutal) 
          ? Brightness.light : Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: (mode == NudgeThemeMode.cute || mode == NudgeThemeMode.neumorphic || mode == NudgeThemeMode.brutal) 
            ? Brightness.light : Brightness.dark,
        surface: surface,
      ),
      textTheme: textTheme,
      iconTheme: iconTheme,
      extensions: [extension],
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: (mode == NudgeThemeMode.terminal || mode == NudgeThemeMode.brutal)
            ? GoogleFonts.robotoMono(fontSize: 20, fontWeight: FontWeight.w900, color: (mode == NudgeThemeMode.terminal) ? Colors.green : Colors.black)
            : GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: (mode == NudgeThemeMode.cute) ? Colors.black : Colors.white),
        iconTheme: iconTheme,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(extension.cardRadius ?? 12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      cardTheme: CardThemeData(
        color: mode == NudgeThemeMode.cute ? Colors.white : (mode == NudgeThemeMode.terminal ? Colors.black : (mode == NudgeThemeMode.brutal ? Colors.white : NudgeTokens.card)),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(extension.cardRadius ?? 20),
          side: mode == NudgeThemeMode.brutal 
              ? const BorderSide(color: Colors.black, width: 3) 
              : (mode == NudgeThemeMode.terminal ? const BorderSide(color: Colors.green, width: 1) : BorderSide(color: (mode == NudgeThemeMode.cute || mode == NudgeThemeMode.neumorphic) ? Colors.transparent : NudgeTokens.border)),
        ),
      ),
    );
  }

  NudgeThemeExtension _createExtension(NudgeThemeMode mode, Color accent, Color surface, Color bg) {
    switch (mode) {
      case NudgeThemeMode.brutal:
        return NudgeThemeExtension(
          cardBg: Colors.white,
          cardBorder: Colors.black,
          cardRadius: 0,
          cardBorderWidth: 4,
          cardShadow: [
            const BoxShadow(color: Colors.black, offset: Offset(8, 8)),
          ],
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.black),
          valueStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Colors.black),
          accentColor: accent,
          scaffoldBg: bg,
          textColor: Colors.black,
          textDim: Colors.black54,
        );
      case NudgeThemeMode.neumorphic:
        return NudgeThemeExtension(
          cardBg: surface,
          cardRadius: 30,
          cardShadow: [
            const BoxShadow(color: Colors.white, offset: Offset(-8, -8), blurRadius: 16),
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), offset: const Offset(8, 8), blurRadius: 16),
          ],
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: Colors.grey),
          valueStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: accent),
          accentColor: accent,
          scaffoldBg: bg,
          textColor: accent,
          textDim: Colors.grey,
        );
      case NudgeThemeMode.cute:
        return NudgeThemeExtension(
          cardBg: Colors.white,
          cardRadius: 32,
          cardBorder: const Color(0xFFFFD6E0),
          cardBorderWidth: 4,
          cardShadow: [
            BoxShadow(color: accent.withValues(alpha: 0.1), offset: const Offset(0, 10), blurRadius: 20),
          ],
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFFF8BBE)),
          valueStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: Color(0xFFFF52AF)),
          accentColor: accent,
          scaffoldBg: bg,
          textColor: const Color(0xFFFF52AF),
          textDim: const Color(0xFFFF8BBE),
        );
      case NudgeThemeMode.terminal:
        return const NudgeThemeExtension(
          cardBg: Colors.black,
          cardBorder: Colors.green,
          cardRadius: 2,
          cardBorderWidth: 1,
          showScanlines: true,
          labelStyle: TextStyle(color: Colors.green, fontWeight: FontWeight.normal),
          valueStyle: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 20),
          accentColor: Colors.green,
          scaffoldBg: Colors.black,
          textColor: Colors.greenAccent,
          textDim: Colors.green,
        );
      default:
        return const NudgeThemeExtension(
          cardBg: NudgeTokens.card,
          cardBorder: NudgeTokens.border,
          cardRadius: 20,
          cardBorderWidth: 1,
          labelStyle: TextStyle(color: NudgeTokens.textLow, fontWeight: FontWeight.w600),
          valueStyle: TextStyle(color: NudgeTokens.textHigh, fontWeight: FontWeight.w800, fontSize: 20),
          accentColor: NudgeTokens.purple,
          scaffoldBg: NudgeTokens.bg,
          textColor: NudgeTokens.textHigh,
          textDim: NudgeTokens.textLow,
        );
    }
  }
}

class _TerminalOverlay extends StatelessWidget {
  const _TerminalOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green.withValues(alpha: 0.05),
              Colors.transparent,
              Colors.green.withValues(alpha: 0.05),
            ],
            stops: const [0, 0.5, 1],
          ),
        ),
        child: CustomPaint(
          painter: _ScanlinePainter(),
          child: Container(),
        ),
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    for (double i = 0; i < size.height; i += 4) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
