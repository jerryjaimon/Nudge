// lib/screens/movies/movie_editor_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../storage.dart';
import '../../utils/gemini_service.dart';

class MovieEditorSheet extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const MovieEditorSheet({super.key, required this.initial});

  @override
  State<MovieEditorSheet> createState() => _MovieEditorSheetState();
}

class _MovieEditorSheetState extends State<MovieEditorSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _langCtrl;
  late final TextEditingController _runtimeCtrl;
  late final TextEditingController _yearCtrl;
  late final TextEditingController _seasonCtrl;
  late final TextEditingController _episodeCtrl;
  late final TextEditingController _prevRewatchCtrl;

  String _type = 'Movie';
  bool _rewatch = false;
  DateTime _watchDate = DateTime.now();
  bool _isLoadingAI = false;
  String? _lastQuery;
  String _rawLog = '';

  Future<void> _autoFill() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a title first')));
      return;
    }

    if (AppStorage.activeGeminiKey.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please set Gemini API key in Settings first')));
      return;
    }

    final lang = _langCtrl.text.trim();
    final searchQuery = '$title ${lang.isNotEmpty ? '$lang ' : ''}$_type run time';
    setState(() {
      _isLoadingAI = true;
      _lastQuery = searchQuery;
    });

    try {
      final prompt = '''
Search Query: "$searchQuery"

Run a search using the exact query above.
Find the movie or series based on the search results.
If no movies are found, return exactly this JSON: {"error": "No movies found."}
Otherwise, return its runtime in minutes and release year strictly as JSON.
Format: {"runtimeMin": 120, "releaseYear": 2020, "season": 1, "episode": 5}
If it is a series, estimate average episode length for runtime and try to identify the season/episode if mentioned in the title (e.g. "Series Name S01E05").
''';

      final geminiText = await GeminiService.generate(
        prompt: prompt,
        typeOverride: GeminiGenType.grounded,
      ) ?? '{}';

      debugPrint('Gemini Search Output: $geminiText');

      final start = geminiText.indexOf('{');
      final end = geminiText.lastIndexOf('}');
      if (start != -1 && end != -1) {
        final data = jsonDecode(geminiText.substring(start, end + 1));

        if (data.containsKey('error')) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] as String)));
          return;
        }

        if (mounted) {
          setState(() {
            if (data['runtimeMin'] != null) _runtimeCtrl.text = data['runtimeMin'].toString();
            if (data['releaseYear'] != null) _yearCtrl.text = data['releaseYear'].toString();
            if (data['season'] != null) _seasonCtrl.text = data['season'].toString();
            if (data['episode'] != null) _episodeCtrl.text = data['episode'].toString();
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gemini auto-filled!')));
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to parse Gemini response.')));
      }
    } catch (e) {
      debugPrint('Gemini Error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to auto-fill: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingAI = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final init = widget.initial;

    _titleCtrl = TextEditingController(text: (init?['title'] as String?) ?? '');
    _langCtrl = TextEditingController(text: (init?['language'] as String?) ?? '');

    final rt = init?['runtimeMin'];
    _runtimeCtrl = TextEditingController(text: (rt is num && rt.toInt() > 0) ? rt.toInt().toString() : '');

    final yr = init?['releaseYear'];
    _yearCtrl = TextEditingController(text: (yr is num && yr.toInt() > 0) ? yr.toInt().toString() : '');

    final s = init?['season'];
    _seasonCtrl = TextEditingController(text: (s is num && s.toInt() > 0) ? s.toInt().toString() : '');

    final ep = init?['episode'];
    _episodeCtrl = TextEditingController(text: (ep is num && ep.toInt() > 0) ? ep.toInt().toString() : '');
    
    final pr = init?['previousRewatchCount'];
    _prevRewatchCtrl = TextEditingController(text: (pr is num && pr.toInt() > 0) ? pr.toInt().toString() : '');

    _type = (init?['type'] as String?) ?? 'Movie';
    _rewatch = init?['rewatch'] == true;

    final wd = (init?['watchDay'] as String?) ?? '';
    if (wd.isNotEmpty) {
      try {
        _watchDate = DateTime.parse(wd);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _langCtrl.dispose();
    _runtimeCtrl.dispose();
    _yearCtrl.dispose();
    _seasonCtrl.dispose();
    _episodeCtrl.dispose();
    _prevRewatchCtrl.dispose();
    super.dispose();
  }

  DateTime _onlyDay(DateTime d) => DateTime(d.year, d.month, d.day);

  String _isoDay(DateTime d) {
    final dt = _onlyDay(d);
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$mm-$dd';
  }

  Future<void> _pickWatchDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _onlyDay(_watchDate),
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
    setState(() => _watchDate = _onlyDay(picked));
  }

  void _bumpDate(int d) => setState(() => _watchDate = _onlyDay(_watchDate.add(Duration(days: d))));

  Future<void> _webSearch() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a title first')));
      return;
    }

    final lang = _langCtrl.text.trim();
    final term = lang.isNotEmpty ? '$title $lang' : title;
    final entity = _type == 'Series' ? 'tvSeason' : 'movie';
    final searchQuery = '$term $entity run time';

    setState(() {
      _isLoadingAI = true;
      _lastQuery = searchQuery;
    });
    try {
      final url = Uri.parse('https://itunes.apple.com/search?term=$term&entity=$entity&limit=1');
      final response = await http.get(url);
      
      final raw = response.body;
      final logText = 'Type: Web Search (iTunes)\nQuery: $searchQuery\n\nRaw JSON Output:\n$raw';
      setState(() => _rawLog = logText);
      debugPrint("Web Search Query: $searchQuery");
      debugPrint("Web Search (iTunes) Output: $raw");
      await Clipboard.setData(ClipboardData(text: logText));
      
      if (response.statusCode == 200) {
        final data = json.decode(raw);
        if (data['resultCount'] > 0) {
          final res = data['results'][0];
          
          final millis = res['trackTimeMillis'] as int?;
          if (millis != null && millis > 0) {
            _runtimeCtrl.text = (millis / 60000).round().toString();
          }
          
          final release = res['releaseDate'] as String?;
          if (release != null && release.length >= 4) {
            _yearCtrl.text = release.substring(0, 4);
          }
          
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Web search fetched & raw output copied!')));
        } else {
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No results found on web.')));
        }
      } else {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Web API error: \${response.statusCode}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingAI = false);
    }
  }

  void _done() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    final now = DateTime.now().toIso8601String();
    final runtime = int.tryParse(_runtimeCtrl.text.trim());
    final year = int.tryParse(_yearCtrl.text.trim());
    final season = int.tryParse(_seasonCtrl.text.trim());
    final episode = int.tryParse(_episodeCtrl.text.trim());

    Navigator.of(context).pop(<String, dynamic>{
      '__action': 'save',
      'id': widget.initial?['id'] ?? '${DateTime.now().millisecondsSinceEpoch}',
      'title': title,
      'type': _type,
      'language': _langCtrl.text.trim(),
      'runtimeMin': (runtime == null || runtime <= 0) ? null : runtime,
      'releaseYear': (year == null || year <= 0) ? null : year,
      'season': (season == null || season <= 0) ? null : season,
      'episode': (episode == null || episode <= 0) ? null : episode,
      'watchDay': _isoDay(_watchDate),
      'rewatch': _rewatch,
      'previousRewatchCount': int.tryParse(_prevRewatchCtrl.text.trim()) ?? 0,
      'createdAt': widget.initial?['createdAt'] ?? now,
      'updatedAt': now,
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
                  color: Colors.white.withValues(alpha: 0.20),
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

              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              
              if (_isLoadingAI)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: CircularProgressIndicator(),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _autoFill,
                        icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                        label: const Text('Gemini Search', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _webSearch,
                        icon: const Icon(Icons.travel_explore_rounded, size: 16),
                        label: const Text('Web Search', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              if (_lastQuery != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Last Query: $_lastQuery',
                    style: const TextStyle(fontSize: 10, color: Colors.white54, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _type,
                      items: const [
                        DropdownMenuItem(value: 'Movie', child: Text('Movie')),
                        DropdownMenuItem(value: 'Series', child: Text('Series')),
                      ],
                      onChanged: (v) => setState(() => _type = v ?? 'Movie'),
                      decoration: const InputDecoration(labelText: 'Type'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _langCtrl,
                      decoration: const InputDecoration(labelText: 'Language'),
                    ),
                  ),
                ],
              ),
 
              if (_type == 'Series') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _seasonCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Season'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _episodeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Episode'),
                      ),
                    ),
                  ],
                ),
              ],
 
              const SizedBox(height: 12),

              // Watch date
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withValues(alpha: 0.06),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_rounded, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Watch date: ${_isoDay(_watchDate)}')),
                    IconButton(onPressed: () => _bumpDate(-1), icon: const Icon(Icons.remove_circle_outline_rounded)),
                    IconButton(onPressed: () => _bumpDate(1), icon: const Icon(Icons.add_circle_outline_rounded)),
                    const SizedBox(width: 6),
                    OutlinedButton(onPressed: _pickWatchDate, child: const Text('Pick')),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Runtime + Year
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _runtimeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Runtime (min)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _yearCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Release year'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              SwitchListTile(
                value: _rewatch,
                onChanged: (v) => setState(() => _rewatch = v),
                title: const Text('Rewatch'),
                subtitle: const Text('Is this a rewatch?', style: TextStyle(fontSize: 10)),
                contentPadding: EdgeInsets.zero,
              ),

              if (_rewatch)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    controller: _prevRewatchCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Rewatches before using Nudge',
                      hintText: 'e.g. 2',
                      helperText: 'How many times did you watch this before the first log here?',
                    ),
                  ),
                ),

              const SizedBox(height: 10),

              if (_rawLog.isNotEmpty) ...[
                 SizedBox(
                   width: double.infinity,
                   child: OutlinedButton.icon(
                     onPressed: _showRawLog,
                     icon: const Icon(Icons.code_rounded, size: 18),
                     label: const Text('View Raw Search Log'),
                     style: OutlinedButton.styleFrom(
                       foregroundColor: Colors.white70,
                       side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                     ),
                   ),
                 ),
                 const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showRawLog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2B),
        title: const Text('Raw Search Log'),
        content: SingleChildScrollView(
          child: SelectableText(
            _rawLog,
            style: const TextStyle(fontSize: 12, color: Colors.white70, fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _rawLog));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard!')));
            },
            child: const Text('Copy All'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}
