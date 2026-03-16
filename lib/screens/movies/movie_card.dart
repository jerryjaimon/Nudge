// lib/screens/movies/movie_card.dart
import 'package:flutter/material.dart';

class MovieCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const MovieCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = (item['title'] as String?) ?? 'Title';
    final type = (item['type'] as String?) ?? 'Movie';
    final lang = (item['language'] as String?) ?? '';
    final watchDay = (item['watchDay'] as String?) ?? '';
    final rewatch = item['rewatch'] == true;
    final runtime = item['runtimeMin'];
    final year = item['releaseYear'];

    String fmtMin(int minutes) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      if (h <= 0) return '${m}m';
      if (m == 0) return '${h}h';
      return '${h}h ${m}m';
    }

    final rtText = (runtime is num && runtime.toInt() > 0) ? fmtMin(runtime.toInt()) : '—';
    final yText = (year is num && year.toInt() > 0) ? '${year.toInt()}' : '—';

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
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white.withOpacity(0.06),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
              ),
              child: const Icon(Icons.local_movies_rounded, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    (() {
                      final parts = <String>[type];
                      if (lang.isNotEmpty) parts.add(lang);
                      if (year is num && year.toInt() > 0) parts.add('${year.toInt()}');
                      
                      final s = item['season'];
                      final e = item['episode'];
                      if (type == 'Series' && (s != null || e != null)) {
                        String epStr = '';
                        if (s != null) epStr += 'S${s.toString().padLeft(2, '0')}';
                        if (e != null) epStr += 'E${e.toString().padLeft(2, '0')}';
                        parts.add(epStr);
                      }
                      
                      if (runtime is num && runtime.toInt() > 0) parts.add(fmtMin(runtime.toInt()));
                      
                      if (rewatch) {
                        final prev = (item['previousRewatchCount'] as num? ?? 0).toInt();
                        if (prev > 0) {
                          parts.add('Rewatch: $prev prev');
                        } else {
                          parts.add('Rewatch');
                        }
                      }
                      
                      return parts.join(' • ');
                    })(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.70)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    watchDay.isEmpty ? '' : watchDay,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withOpacity(0.60)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
