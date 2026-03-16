import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/card_model.dart';
import '../providers/app_state.dart';
import '../services/runtime_fetcher.dart';
import '../app.dart' show NudgeTokens;
import '../utils/nudge_theme_extension.dart';

class CounterCard extends StatelessWidget {
  final TrackerCard card;

  const CounterCard({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<NudgeThemeExtension>()!;
    final appState = Provider.of<AppState>(context, listen: false);
    final hasTime = card.totalMinutes > 0;
    final hrs = (card.totalMinutes / 60).toStringAsFixed(1);
    
    final accent = theme.accentColor ?? NudgeTokens.purple;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: theme.cardDecoration(context),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(theme.cardRadius != null ? (theme.cardRadius! / 2).clamp(0, 12) : 11),
              color: accent.withValues(alpha: 0.10),
              border: Border.all(color: accent.withValues(alpha: 0.20)),
            ),
            child: card.iconCodePoint != null
                ? Icon(
                    IconData(card.iconCodePoint!, fontFamily: 'MaterialIcons'),
                    size: 18,
                    color: accent,
                  )
                : Center(
                    child: Text(card.emoji, style: const TextStyle(fontSize: 18)),
                  ),
          ),
          const SizedBox(width: 12),
          // Labels
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: (theme.cardBg == Colors.white) ? Colors.black : Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _StatPill(label: '${card.count}×', color: accent),
                    if (hasTime) ...[
                      const SizedBox(width: 6),
                      _StatPill(label: '${hrs}h', color: NudgeTokens.blue),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // +1 button
          GestureDetector(
            onTap: () => _handleIncrement(context, appState),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(theme.cardRadius != null ? (theme.cardRadius! / 2.5).clamp(0, 12) : 11),
                color: accent,
                border: theme.cardBorder != null ? Border.all(color: theme.cardBorder!, width: 1) : null,
              ),
              child: Icon(Icons.add_rounded, color: (theme.cardBg == Colors.white && theme.accentColor == null) ? Colors.white : (theme.cardBg == Colors.white ? Colors.white : Colors.black), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _handleIncrement(BuildContext context, AppState appState) async {
    final isMedia = card.title.toLowerCase().contains('movie') ||
        card.title.toLowerCase().contains('series');

    if (isMedia) {
      final controller = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('What did you watch?'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Title'),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final title = controller.text;
                if (title.isNotEmpty) {
                  final mins = await RuntimeFetcher.fetchRuntime(title);
                  appState.incrementCounter(card, minutes: mins);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      );
    } else {
      appState.incrementCounter(card);
    }
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
