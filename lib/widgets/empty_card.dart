// lib/widgets/empty_card.dart
import 'package:flutter/material.dart';
import '../app.dart' show NudgeTokens;

class EmptyCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData? icon;

  const EmptyCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: NudgeTokens.card,
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: NudgeTokens.elevated,
              border: Border.all(color: NudgeTokens.border),
            ),
            child: Icon(
              icon ?? Icons.inbox_rounded,
              size: 22,
              color: NudgeTokens.textLow,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: NudgeTokens.textMid,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: NudgeTokens.textLow,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
