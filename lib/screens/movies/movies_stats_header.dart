// lib/screens/movies/movies_stats_header.dart
import 'package:flutter/material.dart';

class MoviesStatsHeader extends StatelessWidget {
  final int count;
  final String watchTimeText;
  final Map<String, int> languageCounts;

  const MoviesStatsHeader({
    super.key,
    required this.count,
    required this.watchTimeText,
    required this.languageCounts,
  });

  @override
  Widget build(BuildContext context) {
    final topLangs = languageCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final max = topLangs.isEmpty ? 1 : topLangs.first.value;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2633),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2D95).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.movie_filter_rounded, color: Color(0xFFFF2D95), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Watched', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54, fontWeight: FontWeight.bold)),
                    Text('$count titles', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: Colors.white)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Watch Time', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54, fontWeight: FontWeight.bold)),
                  Text(watchTimeText, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFFFF2D95))),
                ],
              ),
            ],
          ),
          if (topLangs.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Language Breakdown', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 12),
            Column(
              children: topLangs.take(4).map((e) {
                final ratio = (e.value / max).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          e.key.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900, color: Colors.white70),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: ratio,
                              child: Container(
                                height: 14,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF2D95),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 30,
                        child: Text(
                          '${e.value}',
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
