import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app.dart' show NudgeTokens;
import '../../utils/gemini_service.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: NudgeTokens.textLow,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? color;

  const SettingTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? NudgeTokens.purple;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: c, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: NudgeTokens.textLow)),
        trailing: trailing,
      ),
    );
  }
}

class ValidateButton extends StatefulWidget {
  final String apiKey;
  final String model;
  const ValidateButton({super.key, required this.apiKey, required this.model});

  @override
  State<ValidateButton> createState() => _ValidateButtonState();
}

class _ValidateButtonState extends State<ValidateButton> {
  bool _validating = false;
  bool? _isValid;

  @override
  Widget build(BuildContext context) {
    if (_validating) {
      return const SizedBox(
        width: 24, height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: NudgeTokens.purple),
      );
    }
    if (_isValid == true) return const Icon(Icons.check_circle_rounded, color: NudgeTokens.green, size: 20);
    if (_isValid == false) return const Icon(Icons.error_outline_rounded, color: NudgeTokens.red, size: 20);

    return TextButton(
      onPressed: widget.apiKey.isEmpty ? null : () async {
        setState(() => _validating = true);
        final ok = await GeminiService.validateKey(widget.apiKey, widget.model);
        if (mounted) setState(() { _validating = false; _isValid = ok; });
        if (ok && mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API Key is valid!')));
        } else if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid API Key.')));
        }
      },
      child: const Text('Test', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: NudgeTokens.purple)),
    );
  }
}
