// lib/screens/pomodoro/manual_log_sheet.dart
import 'package:flutter/material.dart';

class ManualLogSheet extends StatefulWidget {
  final List<Map<String, dynamic>> projects;
  final String initialProjectId;

  const ManualLogSheet({
    super.key,
    required this.projects,
    required this.initialProjectId,
  });

  @override
  State<ManualLogSheet> createState() => _ManualLogSheetState();
}

class _ManualLogSheetState extends State<ManualLogSheet> {
  String _projectId = '';
  final _minutesCtrl = TextEditingController(text: '30');
  final _noteCtrl = TextEditingController();

  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _projectId = widget.initialProjectId;
  }

  @override
  void dispose() {
    _minutesCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  DateTime _onlyDay(DateTime d) => DateTime(d.year, d.month, d.day);

  String _isoDay(DateTime d) {
    final dt = _onlyDay(d);
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$mm-$dd';
  }

  void _bump(int days) => setState(() => _date = _onlyDay(_date.add(Duration(days: days))));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _onlyDay(_date),
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
    setState(() => _date = _onlyDay(picked));
  }

  void _done() {
    final min = int.tryParse(_minutesCtrl.text.trim()) ?? 0;
    if (min <= 0) return;
    if (_projectId.trim().isEmpty) return;

    final now = DateTime.now().toIso8601String();

    Navigator.of(context).pop(<String, dynamic>{
      'id': '${DateTime.now().millisecondsSinceEpoch}',
      'at': now,
      'kind': 'manual',
      'projectId': _projectId,
      'minutes': min,
      'meta': {
        'note': _noteCtrl.text.trim(),
        'day': _isoDay(_date),
      },
    });
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
                  const Spacer(),
                  TextButton(onPressed: _done, child: const Text('Done')),
                ],
              ),
              const SizedBox(height: 6),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withOpacity(0.06),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _projectId.isEmpty ? null : _projectId,
                    hint: const Text('Select project'),
                    isExpanded: true,
                    items: widget.projects
                        .map((p) => DropdownMenuItem<String>(
                              value: p['id']?.toString() ?? '',
                              child: Text((p['name'] as String?) ?? 'Project'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _projectId = v ?? ''),
                  ),
                ),
              ),

              const SizedBox(height: 12),

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
                        'Date: ${_isoDay(_date)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.90)),
                      ),
                    ),
                    IconButton(onPressed: () => _bump(-1), icon: const Icon(Icons.remove_circle_outline_rounded)),
                    IconButton(onPressed: () => _bump(1), icon: const Icon(Icons.add_circle_outline_rounded)),
                    const SizedBox(width: 4),
                    OutlinedButton(onPressed: _pickDate, child: const Text('Pick')),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _minutesCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Minutes'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
