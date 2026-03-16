import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app.dart' show NudgeTokens;
import '../../utils/food_service.dart';
import 'package:nudge/utils/nudge_theme_extension.dart';
import 'meal_selector.dart';

class EditFoodSheet extends StatefulWidget {
  final Map<String, dynamic> entry;

  const EditFoodSheet({super.key, required this.entry});

  @override
  State<EditFoodSheet> createState() => _EditFoodSheetState();
}

class _EditFoodSheetState extends State<EditFoodSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _caloriesCtrl;
  late TextEditingController _proteinCtrl;
  late TextEditingController _carbsCtrl;
  late TextEditingController _fatCtrl;
  late double _servings;
  late String _mealType;

  @override
  void initState() {
    super.initState();
    final d = widget.entry;
    _nameCtrl = TextEditingController(text: d['name'] ?? 'Unknown');

    // Use per-serving if available, else fallback
    final cals = (d['caloriesPerServing'] ?? d['calories'] ?? 0).toString();
    final p = (d['proteinPerServing'] ?? d['protein'] ?? 0).toString();
    final c = (d['carbsPerServing'] ?? d['carbs'] ?? 0).toString();
    final f = (d['fatPerServing'] ?? d['fat'] ?? 0).toString();

    _caloriesCtrl = TextEditingController(text: cals);
    _proteinCtrl = TextEditingController(text: p);
    _carbsCtrl = TextEditingController(text: c);
    _fatCtrl = TextEditingController(text: f);
    
    _servings = (d['servingsConsumed'] as num?)?.toDouble() ?? 1.0;
    _mealType = d['mealType']?.toString() ?? 'Snack';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _caloriesCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final updated = {
      ...widget.entry,
      'name': _nameCtrl.text,
      'servingsConsumed': _servings,
      'caloriesPerServing': double.tryParse(_caloriesCtrl.text) ?? 0.0,
      'proteinPerServing': double.tryParse(_proteinCtrl.text) ?? 0.0,
      'carbsPerServing': double.tryParse(_carbsCtrl.text) ?? 0.0,
      'fatPerServing': double.tryParse(_fatCtrl.text) ?? 0.0,
      'mealType': _mealType,
    };
    
    // Convert back to legacy flat properties for backward compatibility
    updated['calories'] = updated['caloriesPerServing'];
    updated['protein'] = updated['proteinPerServing'];
    updated['carbs'] = updated['carbsPerServing'];
    updated['fat'] = updated['fatPerServing'];

    await FoodService.editEntry(widget.entry['id'], updated);
    // Also update library so future autocompletes are fixed
    await FoodService.saveToLibrary(updated);
    
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: NudgeTokens.elevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Nutrition Info',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh)),
              ),
            ),
            const SizedBox(height: 20),
            
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Food Name'),
            ),
            const SizedBox(height: 16),

            Center(child: MealSelector(selected: _mealType, onSelected: (v) => setState(() => _mealType = v))),
            const SizedBox(height: 16),
            
            // Servings Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Servings Consumed', style: TextStyle(fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: NudgeTokens.textLow),
                      onPressed: _servings > 0.5 ? () => setState(() => _servings -= 0.5) : null,
                    ),
                    Text(
                      '${_servings == _servings.toInt() ? _servings.toInt() : _servings}x',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: NudgeTokens.textLow),
                      onPressed: () => setState(() => _servings += 0.5),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Text('Per Serving', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: NudgeTokens.foodB)),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _caloriesCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Calories (kcal)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _proteinCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Protein (g)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _carbsCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Carbs (g)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _fatCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Fat (g)'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(backgroundColor: NudgeTokens.foodB),
                child: const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
