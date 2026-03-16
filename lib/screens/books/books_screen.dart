// lib/screens/books/books_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../storage.dart';
import '../../widgets/empty_card.dart';
import 'book_card.dart';
import 'book_editor_sheet.dart';
import 'books_stats_header.dart';

class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> with WidgetsBindingObserver {
  Box? _box;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initBox();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _initBox() async {
    final b = await AppStorage.getBooksBox();
    if (!mounted) return;
    setState(() {
      _box = b;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> _books() {
    final b = _box;
    if (b == null) return [];
    final raw = (b.get('books', defaultValue: <dynamic>[]) as List);
    final list = raw.map((e) => (e as Map).cast<String, dynamic>()).toList();
    list.sort((a, b) => (b['createdAt'] as String? ?? '').compareTo(a['createdAt'] as String? ?? ''));
    return list;
  }

  Future<void> _save(List<Map<String, dynamic>> list) async {
    final b = _box;
    if (b == null) return;
    await b.put('books', list);
  }

  int _sumPagesRead(List<Map<String, dynamic>> list) {
    int sum = 0;
    for (final b in list) {
      final p = (b['pagesRead'] as int?) ?? 0;
      if (p > 0) sum += p;
    }
    return sum;
  }

  Future<void> _openEditor({Map<String, dynamic>? initial}) async {
    if (_box == null) return;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1520),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => BookEditorSheet(initial: initial),
    );

    if (result == null) return;

    final action = (result['__action'] as String?) ?? 'save';
    final list = _books();

    if (action == 'delete') {
      final id = result['id']?.toString();
      if (id == null) return;
      list.removeWhere((e) => e['id']?.toString() == id);
      await _save(list);
      setState(() {});
      return;
    }

    final id = result['id']?.toString();
    if (id == null) return;

    final idx = list.indexWhere((e) => e['id']?.toString() == id);
    if (idx >= 0) {
      list[idx] = result..remove('__action');
    } else {
      list.insert(0, result..remove('__action'));
    }

    await _save(list);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final list = _books();
    final pagesRead = _sumPagesRead(list);

    return Scaffold(
      appBar: AppBar(title: const Text('Books')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
        children: [
          BooksStatsHeader(count: list.length, pagesRead: pagesRead),
          const SizedBox(height: 12),
          if (list.isEmpty)
            const EmptyCard(title: 'No books yet', subtitle: 'Tap “Add” below.')
          else
            ...list.map((bk) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: BookCard(
                  book: bk,
                  onTap: () => _openEditor(initial: bk),
                ),
              );
            }),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add'),
          ),
        ),
      ),
    );
  }
}
