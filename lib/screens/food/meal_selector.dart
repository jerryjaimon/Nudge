import 'package:flutter/material.dart';
import '../../app.dart' show NudgeTokens;
import '../../utils/nudge_theme_extension.dart';

class MealSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const MealSelector({super.key, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<NudgeThemeExtension>();
    final types = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme?.cardBg ?? NudgeTokens.card,
        borderRadius: BorderRadius.circular(12),
        border: theme?.cardDecoration(context).border ?? Border.all(color: NudgeTokens.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: types.map((t) {
          final isSel = selected == t;
          return GestureDetector(
            onTap: () => onSelected(t),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSel ? NudgeTokens.foodB : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                t,
                style: TextStyle(
                  color: isSel ? Colors.white : (theme?.textColor?.withValues(alpha: 0.6) ?? NudgeTokens.textLow),
                  fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
