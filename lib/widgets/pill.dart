// lib/widgets/pill.dart
import 'package:flutter/material.dart';
import '../app.dart' show NudgeTokens;

class Pill extends StatelessWidget {
  final String text;
  final Color? color;
  final IconData? icon;

  const Pill({super.key, required this.text, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = color ?? NudgeTokens.textLow;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: icon != null ? 8 : 9,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: c.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: c),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}
