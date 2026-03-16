// lib/screens/gym/gym_routines_screen.dart
import 'package:flutter/material.dart';
import '../../storage.dart';
import 'exercise_picker_sheet.dart';
import 'exercise_thumbnail.dart';

class GymRoutinesScreen extends StatefulWidget {
  const GymRoutinesScreen({super.key});

  @override
  State<GymRoutinesScreen> createState() => _GymRoutinesScreenState();
}

class _GymRoutinesScreenState extends State<GymRoutinesScreen> {
  List<Map<String, dynamic>> _routines = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final raw = AppStorage.gymBox.get('routines', defaultValue: <dynamic>[]) as List;
    setState(() {
      _routines = raw.map((e) => (e as Map).cast<String, dynamic>()).toList();
    });
  }

  Future<void> _addOrEditRoutine({Map<String, dynamic>? initial}) async {
    final nameCtrl = TextEditingController(text: initial?['name'] ?? '');
    List<String> exercises = (initial?['exercises'] as List?)?.cast<String>() ?? [];

    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          title: Text(initial == null ? 'New Routine' : 'Edit Routine'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Routine Name'),
              ),
              const SizedBox(height: 16),
              const Text('Exercises:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...exercises.map((e) => ListTile(
                    leading: ExerciseThumbnail(exerciseName: e, size: 36, iconSize: 18),
                    title: Text(e),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => setDialogState(() => exercises.remove(e)),
                    ),
                  )),
              TextButton.icon(
                onPressed: () async {
                  final picked = await showModalBottomSheet<String>(
                    context: context,
                    builder: (_) => const ExercisePickerSheet(),
                  );
                  if (picked != null) setDialogState(() => exercises.add(picked));
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Exercise'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.isEmpty) return;
                Navigator.pop(ctx, {
                  'id': initial?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  'name': nameCtrl.text.trim(),
                  'exercises': exercises,
                });
              },
              child: const Text('Save'),
            ),
          ],
        );
      }),
    );

    if (res != null) {
      if (initial != null) {
        final idx = _routines.indexWhere((r) => r['id'] == initial['id']);
        _routines[idx] = res;
      } else {
        _routines.add(res);
      }
      await AppStorage.gymBox.put('routines', _routines);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workout Routines')),
      body: _routines.isEmpty
          ? const Center(child: Text('No routines yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _routines.length,
              itemBuilder: (context, i) {
                final r = _routines[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(r['name']),
                    subtitle: Text('${(r['exercises'] as List).length} exercises'),
                    onTap: () => _addOrEditRoutine(initial: r),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_arrow_rounded, color: Colors.greenAccent),
                      onPressed: () => Navigator.pop(context, r),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditRoutine(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
