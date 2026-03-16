// lib/screens/movies/watch_editor_sheet.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

enum WatchType { movie, series }

class WatchEditorSheet extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const WatchEditorSheet({super.key, this.initial});

  @override
  State<WatchEditorSheet> createState() => _WatchEditorSheetState();
}

class _WatchEditorSheetState extends State<WatchEditorSheet> {
  final _nameCtrl = TextEditingController();
  final _runtimeCtrl = TextEditingController();
  final _languageCtrl = TextEditingController();

  WatchType _type = WatchType.movie;
  bool _rewatch = false;

  DateTime _viewDate = DateTime.now();
  String _releaseYear = '';

  bool _fetchingRuntime = false;
  bool _fetchingYear = false;
  String? _hint;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      _nameCtrl.text = (init['name'] as String?) ?? '';
      final rt = (init['runtimeMin'] as int?) ?? 0;
      _runtimeCtrl.text = rt == 0 ? '' : rt.toString();
      _languageCtrl.text = (init['language'] as String?) ?? '';
      _rewatch = (init['rewatch'] as bool?) ?? false;

      final t = (init['type'] as String?) ?? 'movie';
      _type = t == 'series' ? WatchType.series : WatchType.movie;

      final viewedAt = (init['viewedAt'] as String?) ?? '';
      if (viewedAt.isNotEmpty) {
        final dt = DateTime.tryParse(viewedAt);
        if (dt != null) _viewDate = dt;
      }
      _releaseYear = (init['releaseYear'] as String?) ?? '';
    } else {
      _viewDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _runtimeCtrl.dispose();
    _languageCtrl.dispose();
    super.dispose();
  }

  DateTime _onlyDay(DateTime d) => DateTime(d.year, d.month, d.day);

  String _isoDay(DateTime d) {
    final dt = _onlyDay(d);
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$mm-$dd';
  }

  String _googleUrl(String q) => Uri.https('www.google.com', '/search', {'q': q}).toString();

  // Runtime query: separate; series includes EXACT.
  String _runtimeQuery() {
    final name = _nameCtrl.text.trim();
    final lang = _languageCtrl.text.trim();
    final suffix = lang.isEmpty ? '' : ' $lang';
    if (_type == WatchType.series) return 'runtime exact $name series$suffix';
    return 'runtime $name movie$suffix';
  }

  // Release year query: separate.
  String _releaseYearQuery() {
    final name = _nameCtrl.text.trim();
    final lang = _languageCtrl.text.trim();
    final suffix = lang.isEmpty ? '' : ' $lang';
    if (_type == WatchType.series) return '$name series release year$suffix';
    return '$name movie release year$suffix';
  }

  Future<void> _copy(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    setState(() => _hint = 'Copied Google link.');
  }

  Future<String?> _fetchGoogleHtml(String query) async {
    try {
      final uri = Uri.https('www.google.com', '/search', {'q': query});
      final resp = await http.get(uri, headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 12; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Accept-Language': 'en-US,en;q=0.9',
      });
      if (resp.statusCode != 200) return null;
      return utf8.decode(resp.bodyBytes);
    } catch (_) {
      return null;
    }
  }

  int? _parseRuntimeMinutes(String html) {
    final hM = RegExp(r'(\d{1,2})\s*h(?:our)?s?\s*(\d{1,2})\s*m', caseSensitive: false).firstMatch(html);
    if (hM != null) {
      final h = int.tryParse(hM.group(1) ?? '');
      final m = int.tryParse(hM.group(2) ?? '');
      if (h != null && m != null) return h * 60 + m;
    }

    final hrMin = RegExp(
      r'(\d{1,2})\s*(?:hr|hour)s?\s*(\d{1,2})\s*(?:min|minute)s?',
      caseSensitive: false,
    ).firstMatch(html);
    if (hrMin != null) {
      final h = int.tryParse(hrMin.group(1) ?? '');
      final m = int.tryParse(hrMin.group(2) ?? '');
      if (h != null && m != null) return h * 60 + m;
    }

    final onlyMin = RegExp(r'(\d{2,3})\s*(?:min|minute)s', caseSensitive: false).firstMatch(html);
    if (onlyMin != null) {
      final m = int.tryParse(onlyMin.group(1) ?? '');
      if (m != null) return m;
    }
    return null;
  }

  String? _parseYearOnly(String html) {
    final year = RegExp(r'\b(19|20)\d{2}\b').firstMatch(html);
    return year?.group(0);
  }

  Future<void> _fetchRuntime() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _fetchingRuntime = true;
      _hint = null;
    });

    final html = await _fetchGoogleHtml(_runtimeQuery());
    if (!mounted) return;

    if (html == null) {
      setState(() {
        _fetchingRuntime = false;
        _hint = 'Runtime fetch failed. Copy link and check manually.';
      });
      return;
    }

    final min = _parseRuntimeMinutes(html);
    setState(() {
      _fetchingRuntime = false;
      if (min != null && min > 0) {
        _runtimeCtrl.text = min.toString();
        _hint = 'Runtime: $min min';
      } else {
        _hint = 'Could not detect runtime. Copy link and check manually.';
      }
    });
  }

  Future<void> _fetchYear() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _fetchingYear = true;
      _hint = null;
    });

    final html = await _fetchGoogleHtml(_releaseYearQuery());
    if (!mounted) return;

    if (html == null) {
      setState(() {
        _fetchingYear = false;
        _hint = 'Release-year fetch failed. Copy link and check manually.';
      });
      return;
    }

    final y = _parseYearOnly(html);
    setState(() {
      _fetchingYear = false;
      if (y != null && y.trim().isNotEmpty) {
        _releaseYear = y.trim();
        _hint = 'Release year: $_releaseYear';
      } else {
        _hint = 'Could not detect release year. Copy link and check manually.';
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _onlyDay(_viewDate),
      firstDate: DateTime(1970, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(surface: const Color(0xFF101722)), dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF101722)),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() => _viewDate = _onlyDay(picked));
  }

  void _bumpDate(int deltaDays) {
    setState(() => _viewDate = _onlyDay(_viewDate.add(Duration(days: deltaDays))));
  }

  void _done() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final runtime = int.tryParse(_runtimeCtrl.text.trim()) ?? 0;
    final language = _languageCtrl.text.trim();
    final now = DateTime.now().toIso8601String();

    Navigator.of(context).pop(<String, dynamic>{
      '__action': 'save',
      'id': widget.initial?['id'] ?? '${DateTime.now().millisecondsSinceEpoch}',
      'createdAt': widget.initial?['createdAt'] ?? now,
      'updatedAt': now,
      'name': name,
      'type': _type == WatchType.series ? 'series' : 'movie',
      'language': language,
      'rewatch': _rewatch,
      'viewedAt': _onlyDay(_viewDate).toIso8601String(),
      'releaseYear': _releaseYear.trim(),
      'runtimeMin': runtime < 0 ? 0 : runtime,
    });
  }

  void _delete() {
    final id = widget.initial?['id'];
    if (id == null) return;
    Navigator.of(context).pop(<String, dynamic>{'__action': 'delete', 'id': id});
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final name = _nameCtrl.text.trim();
    final runtimeLink = name.isEmpty ? null : _googleUrl(_runtimeQuery());
    final yearLink = name.isEmpty ? null : _googleUrl(_releaseYearQuery());

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 14 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (widget.initial != null)
                    TextButton.icon(
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Delete'),
                    )
                  else
                    const SizedBox.shrink(),
                  const Spacer(),
                  TextButton(onPressed: _done, child: const Text('Done')),
                ],
              ),
              const SizedBox(height: 6),

              // Movie/Series toggle
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _SegButton(
                        selected: _type == WatchType.movie,
                        text: 'Movie',
                        icon: Icons.local_movies_rounded,
                        onTap: () => setState(() => _type = WatchType.movie),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SegButton(
                        selected: _type == WatchType.series,
                        text: 'Series',
                        icon: Icons.tv_rounded,
                        onTap: () => setState(() => _type = WatchType.series),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: _type == WatchType.series ? 'Series name' : 'Movie name'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _languageCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Language (optional)'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),

              // View date row
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withOpacity(0.06),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_rounded, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Viewed: ${_isoDay(_viewDate)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.90)),
                      ),
                    ),
                    IconButton(
                      tooltip: '-1 day',
                      onPressed: () => _bumpDate(-1),
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                    IconButton(
                      tooltip: '+1 day',
                      onPressed: () => _bumpDate(1),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                    const SizedBox(width: 4),
                    OutlinedButton(
                      onPressed: _pickDate,
                      child: const Text('Pick'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                value: _rewatch,
                onChanged: (v) => setState(() => _rewatch = v),
                contentPadding: EdgeInsets.zero,
                title: const Text('Rewatch'),
              ),

              const SizedBox(height: 10),

              // Runtime
              TextField(
                controller: _runtimeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Runtime (minutes)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _fetchingRuntime ? null : _fetchRuntime,
                      icon: _fetchingRuntime
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.search_rounded),
                      label: const Text('Fetch runtime'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: runtimeLink == null ? null : () => _copy(runtimeLink),
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy runtime link'),
                    ),
                  ),
                ],
              ),
              if (runtimeLink != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    runtimeLink,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.65),
                          decoration: TextDecoration.underline,
                        ),
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Release year
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withOpacity(0.06),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range_rounded, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _releaseYear.trim().isEmpty ? 'Release year: not set' : 'Release year: $_releaseYear',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.90)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _fetchingYear ? null : _fetchYear,
                      icon: _fetchingYear
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.search_rounded, size: 18),
                      label: const Text('Fetch'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: yearLink == null ? null : () => _copy(yearLink),
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy year link'),
                    ),
                  ),
                ],
              ),
              if (yearLink != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    yearLink,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.65),
                          decoration: TextDecoration.underline,
                        ),
                  ),
                ),
              ],

              if (_hint != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _hint!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.75)),
                  ),
                ),
              ],
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegButton extends StatelessWidget {
  final bool selected;
  final String text;
  final IconData icon;
  final VoidCallback onTap;

  const _SegButton({
    required this.selected,
    required this.text,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? Colors.white.withOpacity(0.14) : Colors.transparent;
    final bd = selected ? Colors.white.withOpacity(0.18) : Colors.white.withOpacity(0.08);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: bg,
          border: Border.all(color: bd),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
