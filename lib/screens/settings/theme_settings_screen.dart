import 'package:flutter/material.dart';
import '../../utils/theme_service.dart';
import '../../utils/nudge_theme_extension.dart';
import '../../app.dart' show NudgeTokens;

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<NudgeThemeExtension>()!;
    return Scaffold(
      backgroundColor: theme.scaffoldBg ?? NudgeTokens.bg,
      appBar: AppBar(
        title: const Text('Appearance'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'SELECT A THEME',
            style: theme.labelStyle?.copyWith(fontSize: 11, letterSpacing: 1.5) ?? const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 20),
          const _ThemeCard(
            mode: NudgeThemeMode.dark,
            name: 'Default Dark',
            description: 'The classic Nudge look. Deep charcoal and soft edges.',
          ),
          const SizedBox(height: 16),
          const _ThemeCard(
            mode: NudgeThemeMode.brutal,
            name: 'Brutal Neo',
            description: 'High contrast, monospace, and thick borders. Bold.',
          ),
          const SizedBox(height: 16),
          const _ThemeCard(
            mode: NudgeThemeMode.neumorphic,
            name: 'Soft UI',
            description: 'Minimalist shadow-based design. Clean and modern.',
          ),
          const SizedBox(height: 16),
          const _ThemeCard(
            mode: NudgeThemeMode.cute,
            name: 'Bubbly',
            description: 'Rounded, pastel, and fun. Like a digital sticker book.',
          ),
          const SizedBox(height: 16),
          const _ThemeCard(
            mode: NudgeThemeMode.terminal,
            name: 'Terminal',
            description: 'Retro green on black with CRT scanlines.',
          ),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final NudgeThemeMode mode;
  final String name;
  final String description;

  const _ThemeCard({
    required this.mode,
    required this.name,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<NudgeThemeExtension>()!;
    final currentMode = ThemeService().mode;
    final isSelected = currentMode == mode;
    final accent = theme.accentColor ?? NudgeTokens.purple;

    return GestureDetector(
      onTap: () => ThemeService().setTheme(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: theme.cardDecoration(context).copyWith(
          color: isSelected 
              ? accent.withValues(alpha: 0.1) 
              : (theme.cardBg == Colors.white ? Colors.white : Colors.white.withValues(alpha: 0.03)),
          border: isSelected 
              ? Border.all(color: accent, width: theme.cardBorderWidth ?? 2) 
              : theme.cardDecoration(context).border,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? accent : (theme.cardBg == Colors.white ? Colors.black : Colors.white),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: (theme.cardBg == Colors.white ? Colors.black54 : Colors.grey)),
                  ),
                ],
              ),
            ),
            if (isSelected)
               Icon(Icons.check_circle_rounded, color: accent)
            else
               Icon(Icons.circle_outlined, color: (theme.cardBg == Colors.white ? Colors.black26 : Colors.grey)),
          ],
        ),
      ),
    );
  }
}
