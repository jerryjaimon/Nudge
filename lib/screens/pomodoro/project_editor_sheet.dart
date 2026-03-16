// lib/screens/pomodoro/project_editor_sheet.dart
import 'package:flutter/material.dart';

class ProjectEditorSheet extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const ProjectEditorSheet({super.key, this.initial});

  @override
  State<ProjectEditorSheet> createState() => _ProjectEditorSheetState();
}

class _ProjectEditorSheetState extends State<ProjectEditorSheet> {
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      _nameCtrl.text = (init['name'] as String?) ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _done() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final now = DateTime.now().toIso8601String();
    Navigator.of(context).pop(<String, dynamic>{
      '__action': 'save',
      'id': widget.initial?['id'] ?? '${DateTime.now().millisecondsSinceEpoch}',
      'createdAt': widget.initial?['createdAt'] ?? now,
      'updatedAt': now,
      'name': name,
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
                controller: _nameCtrl,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Project name'),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
