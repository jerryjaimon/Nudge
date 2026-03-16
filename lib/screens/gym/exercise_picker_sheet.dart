// lib/screens/gym/exercise_picker_sheet.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../storage.dart';
import '../../utils/gemini_service.dart';
import 'exercise_db.dart';
import 'exercise_thumbnail.dart';
import 'exercise_detail_sheet.dart';

class ExercisePickerSheet extends StatefulWidget {
  const ExercisePickerSheet({super.key});

  @override
  State<ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<ExercisePickerSheet> {
  final _qCtrl = TextEditingController();
  Box? _box;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _box = await AppStorage.getGymBox();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  List<String> _customExercises() {
    final b = _box;
    if (b == null) return [];
    final raw = (b.get('custom_exercises', defaultValue: <dynamic>[]) as List);
    return raw.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
  }

  Map<String, List<String>> _categorized() {
    final q = _qCtrl.text.trim().toLowerCase();
    final custom = _customExercises();
    
    final result = <String, List<String>>{};
    
    // Custom category mappings
    final catMap = (_box?.get('custom_categories', defaultValue: <dynamic, dynamic>{}) ?? <dynamic, dynamic>{}) as Map;
    final catMapString = catMap.cast<String, String>();

    for (final e in custom) {
      if (e.toLowerCase().contains(q)) {
        final cat = catMapString[e] ?? 'Custom';
        if (!result.containsKey(cat)) result[cat] = [];
        result[cat]!.add(e);
      }
    }

    ExerciseDB.categories.forEach((cat, list) {
      final filtered = list.where((e) => e.toLowerCase().contains(q)).toList();
      if (filtered.isNotEmpty) {
        if (!result.containsKey(cat)) result[cat] = [];
        result[cat]!.addAll(filtered);
      }
    });

    return result;
  }

  Future<void> _addCustom() async {
    final name = _qCtrl.text.trim();
    if (name.isEmpty) return;

    final b = _box;
    if (b == null) return;

    final list = _customExercises();
    final exists = list.any((e) => e.toLowerCase() == name.toLowerCase()) || 
                   ExerciseDB.allExercises.any((e) => e.toLowerCase() == name.toLowerCase());
    
    if (!exists) {
      setState(() => _loading = true);
      String cat = 'Custom';
      // Try to categorize the new exercise using Gemini
      final apiKey = AppStorage.activeGeminiKey;

      if (apiKey.isNotEmpty) {
        try {
          final prompt = 'You are a fitness categorization engine. '
              'Classify the following exercise: "${name.trim()}" into exactly one of these: '
              '${ExerciseDB.categories.keys.join(", ")}. '
              'Reply with JUST the category name, or "Custom" if it does not fit any.';
          final text = (await GeminiService.generate(
            prompt: prompt,
            typeOverride: GeminiGenType.standard,
          ))?.trim() ?? 'Custom';
          if (ExerciseDB.categories.keys.contains(text)) {
            cat = text;
          }
        } catch (e) {
          debugPrint('Gemini categorization failed: $e');
        }
      }

      final customCats = Map<String, dynamic>.from(_box?.get('custom_categories', defaultValue: <dynamic, dynamic>{}) as Map);
      customCats[name] = cat;
      await b.put('custom_categories', customCats);

      list.insert(0, name);
      await b.put('custom_exercises', list);
    }

    if (!mounted) return;
    Navigator.of(context).pop<String>(name);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final catMap = _categorized();
    final sortedCats = catMap.keys.toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 14 + bottomInset),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Search exercise',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'Add as custom',
                onPressed: _loading ? null : _addCustom,
                icon: const Icon(Icons.add_rounded),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: sortedCats.length,
                    itemBuilder: (_, catIdx) {
                      final cat = sortedCats[catIdx];
                      final list = catMap[cat]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            child: Text(
                              cat.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.white38,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          ...list.map((name) => ListTile(
                                leading: ExerciseThumbnail(exerciseName: name, size: 36, iconSize: 18),
                                title: Text(name),
                                trailing: const Icon(Icons.chevron_right_rounded, size: 16),
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => ExerciseDetailSheet(
                                      exerciseName: name,
                                      onSelect: () {
                                        Navigator.of(context).pop(); // Close detail sheet
                                        Navigator.of(context).pop<String>(name); // Close picker with name
                                      },
                                    ),
                                  );
                                },
                              )),
                          const Divider(color: Colors.white10),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
