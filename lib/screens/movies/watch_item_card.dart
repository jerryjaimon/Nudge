// lib/screens/movies/watch_item_card.dart
import 'package:flutter/material.dart';
import '../../widgets/pill.dart';

class WatchItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const WatchItemCard({super.key, required this.item, required this.onTap});

  String _titleCase(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final name = (item['name'] as String?) ?? 'Title';
    final type = (item['type'] as String?) ?? 'movie';
    final runtimeMin = (item['runtimeMin'] as int?) ?? 0;
    final runtimeText = runtimeMin > 0 ? '$runtimeMin min' : 'runtime ?';

    final language = ((item['language'] as String?) ?? '').trim();
    final langText = language.isEmpty ? 'Unknown' : _titleCase(language);

    final viewedAt = (item['viewedAt'] as String?) ?? '';
    final releaseYear = ((item['releaseYear'] as String?) ?? '').trim();
    final rewatch = (item['rewatch'] as bool?) ?? false;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xFF101722),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white.withOpacity(0.06),
                    border: Border.all(color: Colors.white.withOpacity(0.10)),
                  ),
                  child: Icon(
                    type == 'series' ? Icons.tv_rounded : Icons.local_movies_rounded,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        '$runtimeText • $langText',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withOpacity(0.70),
                            ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Pill(text: type == 'series' ? 'Series' : 'Movie'),
                if (viewedAt.isNotEmpty) Pill(text: 'Viewed: ${viewedAt.substring(0, 10)}'),
                if (releaseYear.isNotEmpty) Pill(text: 'Release: $releaseYear'),
                if (rewatch) const Pill(text: 'Rewatch'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
