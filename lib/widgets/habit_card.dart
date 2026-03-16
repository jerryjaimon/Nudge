import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/card_model.dart';
import '../providers/app_state.dart';
import '../models/card_type.dart';
import '../app.dart' show NudgeTokens;
import '../utils/nudge_theme_extension.dart';

class HabitCard extends StatefulWidget {
  final TrackerCard card;
  final VoidCallback? onConfetti;

  const HabitCard({super.key, required this.card, this.onConfetti});

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<NudgeThemeExtension>()!;
    final appState = Provider.of<AppState>(context, listen: false);
    final status = appState.statusFor(widget.card);
    final done = widget.card.isCompletedToday;

    Color accentColor;
    switch (status) {
      case CardStatus.completed: accentColor = NudgeTokens.green; break;
      case CardStatus.critical:  accentColor = NudgeTokens.amber; break;
      case CardStatus.due:       accentColor = NudgeTokens.red; break;
      default:                  accentColor = theme.accentColor ?? NudgeTokens.textLow;
    }

    // Aesthetic adjustments per theme
    BoxDecoration decoration = theme.cardDecoration(context);
    
    // In Brutal mode, use status color for the thick border
    if (theme.cardBorderWidth != null && theme.cardBorderWidth! > 2) {
       decoration = decoration.copyWith(
         border: Border.all(color: status == CardStatus.completed ? NudgeTokens.green : (status == CardStatus.due ? NudgeTokens.red : (status == CardStatus.critical ? NudgeTokens.amber : Colors.black)), width: theme.cardBorderWidth!),
       );
    } 
    // In default mode, use the status background tint
    else if (theme.cardShadow == null && theme.cardBorderWidth == 1 && theme.cardRadius == 20) {
       decoration = decoration.copyWith(
         color: accentColor.withValues(alpha: 0.07),
         border: status == CardStatus.completed ? Border.all(color: NudgeTokens.green.withValues(alpha: 0.28)) : null,
       );
    }

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(14),
        decoration: decoration,
        child: Column(
          children: [
            Row(
              children: [
                // Status dot + icon
                Stack(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(theme.cardRadius != null ? (theme.cardRadius! / 2).clamp(0, 12) : 11),
                        color: accentColor.withValues(alpha: 0.10),
                        border: Border.all(color: accentColor.withValues(alpha: 0.20)),
                      ),
                      child: widget.card.iconCodePoint != null
                          ? Icon(
                              IconData(widget.card.iconCodePoint!, fontFamily: 'MaterialIcons'),
                              size: 18,
                              color: accentColor,
                            )
                          : Center(
                              child: Text(widget.card.emoji, style: const TextStyle(fontSize: 18)),
                            ),
                    ),
                    // Status dot
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor,
                          border: Border.all(color: theme.cardBg ?? Colors.black, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.card.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: (theme.cardBg == Colors.white) ? Colors.black : Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _getProgressText(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: accentColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                // Streak badge
                if (widget.card.currentStreak > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(theme.cardRadius != null ? (theme.cardRadius! / 3).clamp(0, 8) : 7),
                      color: NudgeTokens.amber.withValues(alpha: 0.12),
                      border: Border.all(color: NudgeTokens.amber.withValues(alpha: 0.22)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 11)),
                        const SizedBox(width: 3),
                        Text(
                          '${widget.card.currentStreak}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: NudgeTokens.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Check button
                GestureDetector(
                  onTap: () {
                    if (!done) widget.onConfetti?.call();
                    appState.toggleHabit(widget.card);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(theme.cardRadius != null ? (theme.cardRadius! / 3).clamp(0, 10) : 10),
                      color: done
                          ? NudgeTokens.green
                          : (theme.accentColor ?? NudgeTokens.purple).withValues(alpha: 0.12),
                      border: Border.all(
                        color: done ? NudgeTokens.green : (theme.accentColor ?? NudgeTokens.purple).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      done ? Icons.check_rounded : Icons.circle_outlined,
                      color: done ? Colors.white : (theme.accentColor ?? NudgeTokens.purple),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 12),
              Container(height: 1, color: (theme.cardBg == Colors.white ? Colors.black12 : NudgeTokens.border)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   _InfoChip(label: 'Best streak', value: '${widget.card.bestStreak}', theme: theme),
                   _InfoChip(
                    label: 'Target',
                    value: '${widget.card.target}/${widget.card.frequency.name}',
                    theme: theme,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => appState.deleteCard(widget.card.id),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Delete habit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NudgeTokens.red,
                    side: BorderSide(color: NudgeTokens.red.withValues(alpha: 0.35)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.cardRadius != null ? (theme.cardRadius! / 3).clamp(0, 10) : 10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getProgressText() {
    final appState = Provider.of<AppState>(context, listen: false);
    if (widget.card.frequency == Frequency.daily) {
      final s = appState.statusFor(widget.card);
      return s == CardStatus.completed ? 'Done today' : 'Due today';
    }
    final progress = appState.weeklyProgress(widget.card);
    return '$progress / ${widget.card.target} this week';
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final NudgeThemeExtension theme;

  const _InfoChip({required this.label, required this.value, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: (theme.cardBg == Colors.white ? Colors.black54 : Colors.grey))),
        const SizedBox(height: 2),
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.bold, color: (theme.cardBg == Colors.white ? Colors.black : Colors.white))),
      ],
    );
  }
}
