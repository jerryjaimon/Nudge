// lib/screens/books/book_editor_sheet.dart
import 'package:flutter/material.dart';

class BookEditorSheet extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const BookEditorSheet({super.key, this.initial});

  @override
  State<BookEditorSheet> createState() => _BookEditorSheetState();
}

class _BookEditorSheetState extends State<BookEditorSheet> {
  final _titleCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  final _genreCtrl = TextEditingController();
  final _totalPagesCtrl = TextEditingController();
  final _pagesReadCtrl = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      _titleCtrl.text = (init['title'] as String?) ?? '';
      _authorCtrl.text = (init['author'] as String?) ?? '';
      _genreCtrl.text = (init['genre'] as String?) ?? '';

      final tp = (init['totalPages'] as int?) ?? 0;
      _totalPagesCtrl.text = tp == 0 ? '' : tp.toString();

      final pr = (init['pagesRead'] as int?) ?? 0;
      _pagesReadCtrl.text = pr == 0 ? '' : pr.toString();

      final s = (init['startAt'] as String?) ?? '';
      final e = (init['endAt'] as String?) ?? '';
      _startDate = DateTime.tryParse(s);
      _endDate = DateTime.tryParse(e);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _genreCtrl.dispose();
    _totalPagesCtrl.dispose();
    _pagesReadCtrl.dispose();
    super.dispose();
  }

  DateTime _onlyDay(DateTime d) => DateTime(d.year, d.month, d.day);

  String _isoDay(DateTime d) {
    final dt = _onlyDay(d);
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$mm-$dd';
  }

  Future<DateTime?> _pickDate(DateTime? initial) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? _onlyDay(now),
      firstDate: DateTime(1900, 1, 1),
      lastDate: now.add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(surface: const Color(0xFF101722)), dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF101722)),
          ),
          child: child!,
        );
      },
    );
    return picked == null ? null : _onlyDay(picked);
  }

  void _done() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    final totalPages = int.tryParse(_totalPagesCtrl.text.trim()) ?? 0;
    final pagesRead = int.tryParse(_pagesReadCtrl.text.trim()) ?? 0;
    final now = DateTime.now().toIso8601String();
    final todayIso = now.substring(0, 10);

    // Calculate delta and handle log
    final previousPages = (widget.initial?['pagesRead'] as int?) ?? 0;
    final delta = pagesRead - previousPages;
    
    List<Map<String, dynamic>> logs = (widget.initial?['readingLogs'] as List?)?.map((l) => Map<String, dynamic>.from(l as Map)).toList() ?? [];
    
    if (delta > 0) {
      logs.add({
        'dayIso': todayIso,
        'pages': delta,
        'timestamp': now,
      });
    }

    Navigator.of(context).pop(<String, dynamic>{
      '__action': 'save',
      'id': widget.initial?['id'] ?? '${DateTime.now().millisecondsSinceEpoch}',
      'createdAt': widget.initial?['createdAt'] ?? now,
      'updatedAt': now,
      'title': title,
      'author': _authorCtrl.text.trim(),
      'genre': _genreCtrl.text.trim(),
      'totalPages': totalPages < 0 ? 0 : totalPages,
      'pagesRead': pagesRead < 0 ? 0 : pagesRead,
      'startAt': _startDate == null ? '' : _startDate!.toIso8601String(),
      'endAt': _endDate == null ? '' : _endDate!.toIso8601String(),
      'readingLogs': logs,
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
              TextField(
                controller: _titleCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _authorCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Author (optional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _genreCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Genre (optional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _totalPagesCtrl,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Total pages (optional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pagesReadCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Pages read'),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withOpacity(0.06),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.play_arrow_rounded, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _startDate == null ? 'Start: not set' : 'Start: ${_isoDay(_startDate!)}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.90)),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            final d = await _pickDate(_startDate);
                            if (d == null) return;
                            setState(() => _startDate = d);
                          },
                          child: const Text('Pick'),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Clear',
                          onPressed: () => setState(() => _startDate = null),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.stop_rounded, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _endDate == null ? 'End: not set' : 'End: ${_isoDay(_endDate!)}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.90)),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            final d = await _pickDate(_endDate);
                            if (d == null) return;
                            setState(() => _endDate = d);
                          },
                          child: const Text('Pick'),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Clear',
                          onPressed: () => setState(() => _endDate = null),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
