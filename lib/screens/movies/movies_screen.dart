// lib/screens/movies/movies_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../storage.dart';
import '../../widgets/empty_card.dart';
import 'movie_card.dart';
import 'movie_editor_sheet.dart';

class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> with WidgetsBindingObserver {
  Box? _box;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
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

  Future<void> _init() async {
    _box = await AppStorage.getMoviesBox();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _items() {
    final b = _box;
    if (b == null) return [];
    final raw = (b.get('movies', defaultValue: <dynamic>[]) as List);
    final list = raw.map((e) => (e as Map).cast<String, dynamic>()).toList();
    list.sort((a, b) => (b['watchDay'] as String? ?? '').compareTo(a['watchDay'] as String? ?? ''));
    return list;
  }

  int _totalRuntimeMin() {
    int sum = 0;
    for (final m in _items()) {
      final v = m['runtimeMin'];
      if (v is int) sum += v;
      if (v is num) sum += v.toInt();
    }
    return sum;
  }

  Map<String, int> _languageStats() {
    final out = <String, int>{};
    for (final m in _items()) {
      final lang = (m['language'] as String?)?.trim();
      if (lang == null || lang.isEmpty) continue;
      out[lang] = (out[lang] ?? 0) + 1;
    }
    return out;
  }

  Future<void> _openEditor({Map<String, dynamic>? initial}) async {
    if (_box == null) return;

    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1520),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => MovieEditorSheet(initial: initial),
    );
    if (res == null) return;

    final action = (res['__action'] as String?) ?? 'save';
    final list = _items();

    if (action == 'delete') {
      final id = res['id']?.toString();
      if (id == null) return;
      list.removeWhere((m) => m['id']?.toString() == id);
      await _box!.put('movies', list);
      setState(() {});
      return;
    }

    final cleaned = Map<String, dynamic>.from(res)..remove('__action');
    final id = cleaned['id']?.toString();
    if (id == null) return;

    final idx = list.indexWhere((m) => m['id']?.toString() == id);
    if (idx >= 0) list[idx] = cleaned;
    if (idx < 0) list.insert(0, cleaned);

    await _box!.put('movies', list);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final items = _items();
    final totalMin = _totalRuntimeMin();
    final langs = _languageStats()..removeWhere((k, v) => v <= 0);

    // simple “mini bars” for languages
    final topLangs = langs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final shown = topLangs.take(5).toList();
    final maxV = shown.isEmpty ? 1 : shown.first.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Movies')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
        children: [
          // Stats
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2D1938).withOpacity(0.92),
                  const Color(0xFFFF2D95).withOpacity(0.70),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics_rounded, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Stats', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    ),
                    Text(
                      '${items.length} • ${_fmtMin(totalMin)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (shown.isNotEmpty)
                  Column(
                    children: shown.map((e) {
                      final pct = (e.value / maxV).clamp(0.0, 1.0);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 70,
                              child: Text(e.key, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.90))),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: SizedBox(
                                  height: 10,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: pct,
                                      child: Container(color: Colors.white.withOpacity(0.35)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text('${e.value}', style: TextStyle(color: Colors.white.withOpacity(0.90), fontWeight: FontWeight.w900)),
                          ],
                        ),
                      );
                    }).toList(),
                  )
                else
                  Text('No language data yet', style: TextStyle(color: Colors.white.withOpacity(0.75))),
              ],
            ),
          ),

          const SizedBox(height: 12),

          if (items.isEmpty)
            const EmptyCard(title: 'No entries yet', subtitle: 'Tap Add below.')
          else
            ...(() {
              final List<Widget> children = [];
              final Map<String, List<Map<String, dynamic>>> groups = {};
              final Set<String> titlesInOrder = {};

              for (final m in items) {
                final title = (m['title'] as String).trim();
                groups.putIfAbsent(title, () => []).add(m);
                titlesInOrder.add(title);
              }

              final Set<String> processed = {};
              
              for (final m in items) {
                final title = (m['title'] as String).trim();
                if (processed.contains(title)) continue;
                processed.add(title);
                
                final group = groups[title]!;
                final type = group.first['type'];

                if (group.length > 1) {
                  if (type == 'Series') {
                    children.add(Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SeriesGroupCard(
                        title: title,
                        items: group,
                        onTap: () => _openEditor(initial: group.first),
                      ),
                    ));
                  } else {
                    children.add(Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MovieGroupCard(
                        title: title,
                        items: group,
                        onTap: () => _openEditor(initial: group.first),
                      ),
                    ));
                  }
                } else {
                  children.add(Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: MovieCard(
                      item: m,
                      onTap: () => _openEditor(initial: m),
                    ),
                  ));
                }
              }
              return children;
            })(),
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

  String _fmtMin(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h <= 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

class _SeriesGroupCard extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final VoidCallback onTap;

  const _SeriesGroupCard({
    required this.title,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final latest = items.first;
    final lang = (latest['language'] as String?) ?? '';
    final count = items.length;

    // Figure out season/episode range
    final seasons = items.map((i) => i['season'] as int?).whereType<int>().toSet().toList()..sort();
    final episodes = items.map((i) => i['episode'] as int?).whereType<int>().toSet().toList()..sort();

    String rangeStr = '';
    if (seasons.isNotEmpty) {
      if (seasons.length == 1) {
        rangeStr += 'S${seasons.first.toString().padLeft(2, '0')} ';
      } else {
        rangeStr += 'S${seasons.first}-${seasons.last} ';
      }
    }
    if (episodes.isNotEmpty) {
      if (episodes.length == 1) {
        rangeStr += 'E${episodes.first.toString().padLeft(2, '0')}';
      } else if (episodes.length > 1) {
        // simple range if sequential or just first/last
        rangeStr += 'E${episodes.first}-${episodes.last}';
      }
    }

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
            Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white.withOpacity(0.06),
                    border: Border.all(color: Colors.white.withOpacity(0.10)),
                  ),
                  child: const Icon(Icons.library_books_rounded, size: 22, color: Color(0xFFFF2D95)),
                ),
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Color(0xFFFF2D95), shape: BoxShape.circle),
                    child: Text('${items.length}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Series • $lang • $count logs' + (rangeStr.isNotEmpty ? ' • $rangeStr' : ''),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.70)),
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

class _MovieGroupCard extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final VoidCallback onTap;

  const _MovieGroupCard({
    required this.title,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final latest = items.first;
    final lang = (latest['language'] as String?) ?? '';
    final logCount = items.length;
    
    // Total previous count from all logs (usually user sets it once, but let's take latest log's value)
    final prevCount = (latest['previousRewatchCount'] as num? ?? 0).toInt();
    final totalRewatches = (logCount - 1) + prevCount;

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
            Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white.withOpacity(0.06),
                    border: Border.all(color: Colors.white.withOpacity(0.10)),
                  ),
                  child: const Icon(Icons.movie_filter_rounded, size: 22, color: Color(0xFFFF2D95)),
                ),
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Color(0xFFFF2D95), shape: BoxShape.circle),
                    child: Text('$logCount', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Movie • $lang • Rewatch: $totalRewatches ($logCount logs, $prevCount prev)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.70)),
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
