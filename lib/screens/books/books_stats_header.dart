// lib/screens/books/books_stats_header.dart
import 'package:flutter/material.dart';

class BooksStatsHeader extends StatelessWidget {
  final int count;
  final int pagesRead;

  const BooksStatsHeader({super.key, required this.count, required this.pagesRead});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2633),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF39D98A).withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.menu_book_rounded, color: Color(0xFF39D98A), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Read', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54, fontWeight: FontWeight.bold)),
                Text('$count books', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: Colors.white)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Pages Read', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54, fontWeight: FontWeight.bold)),
              Text('$pagesRead', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF39D98A))),
            ],
          ),
        ],
      ),
    );
  }
}
