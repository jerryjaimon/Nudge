// lib/screens/books/book_card.dart
import 'package:flutter/material.dart';
import '../../widgets/pill.dart';

class BookCard extends StatelessWidget {
  final Map<String, dynamic> book;
  final VoidCallback onTap;

  const BookCard({super.key, required this.book, required this.onTap});

  String _fmtDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$mm-$dd';
  }

  double _progress() {
    final total = (book['totalPages'] as int?) ?? 0;
    final read = (book['pagesRead'] as int?) ?? 0;
    if (total <= 0) return 0;
    return (read / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final title = (book['title'] as String?) ?? 'Untitled';
    final author = ((book['author'] as String?) ?? '').trim();
    final genre = ((book['genre'] as String?) ?? '').trim();

    final totalPages = (book['totalPages'] as int?) ?? 0;
    final read = (book['pagesRead'] as int?) ?? 0;

    final startAt = ((book['startAt'] as String?) ?? '').trim();
    final endAt = ((book['endAt'] as String?) ?? '').trim();

    final subtitleBits = <String>[];
    if (author.isNotEmpty) subtitleBits.add(author);
    if (genre.isNotEmpty) subtitleBits.add(genre);
    final subtitle = subtitleBits.isEmpty ? '—' : subtitleBits.join(' • ');

    final pagesText = totalPages > 0 ? '$read / $totalPages' : '$read pages';
    final prog = _progress();

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
                  child: const Icon(Icons.menu_book_rounded, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.70)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: prog,
                      minHeight: 8,
                      backgroundColor: Colors.white.withOpacity(0.12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  pagesText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (startAt.isNotEmpty) Pill(text: 'Start: ${_fmtDate(startAt)}'),
                if (endAt.isNotEmpty) Pill(text: 'End: ${_fmtDate(endAt)}'),
                if (totalPages > 0 && read >= totalPages) const Pill(text: 'Completed'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
