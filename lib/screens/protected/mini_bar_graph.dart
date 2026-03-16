// lib/screens/protected/mini_bar_graph.dart
import 'package:flutter/material.dart';

class MiniBarGraph extends StatelessWidget {
  final Map<String, int> valuesByDay; // dayIso -> count
  const MiniBarGraph({super.key, required this.valuesByDay});

  @override
  Widget build(BuildContext context) {
    final entries = valuesByDay.entries.toList(); // already in order from caller
    int maxVal = 1;
    for (final e in entries) {
      if (e.value > maxVal) maxVal = e.value;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last 14 days',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.80),
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 46,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(entries.length, (i) {
                final v = entries[i].value;
                final h = (v / maxVal).clamp(0.0, 1.0);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        alignment: Alignment.bottomCenter,
                        color: Colors.white.withOpacity(0.06),
                        child: FractionallySizedBox(
                          heightFactor: h,
                          widthFactor: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Min',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withOpacity(0.60)),
                ),
              ),
              Text(
                'Max $maxVal',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withOpacity(0.60)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
