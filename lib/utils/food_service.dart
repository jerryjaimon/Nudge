import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../storage.dart';
import 'gemini_service.dart';

class FoodService {
  static Future<List<Map<String, dynamic>>?> parseFoodDescription(String text) async {
    final apiKey = AppStorage.activeGeminiKey;
    if (apiKey.isEmpty) return null;

    final prompt = '''
      Extract nutritional information from this food description: "$text".
      If the user logs multiple items (comma-separated or listed), return EACH as a separate object.
      Return a JSON array. Each object must have:
      - name: String (PRESERVE adjectives like "Pan fried", "Grilled", "Homemade")
      - brand: String (empty if unknown)
      - servingUnit: String (e.g. "piece", "cup", "g", "oz", "ml", "bowl", "roti")
      - caloriesPerServing: double
      - proteinPerServing: double (grams)
      - carbsPerServing: double (grams)
      - fatPerServing: double (grams)
      - fiberPerServing: double (grams)
      - servingsConsumed: double

      CRITICAL RULES:
      1. COUNT vs WEIGHT: "4 walnuts" → servingUnit="piece", servingsConsumed=4, caloriesPerServing for ONE walnut.
         NEVER treat piece counts as grams.
      2. WEIGHT inputs: "200g chicken" → servingsConsumed=1.0, caloriesPerServing for the full 200g.
      3. MATH: caloriesPerServing ≈ (protein×4) + (carbs×4) + (fat×9). Check your own math.
      4. REALITY BENCHMARKS (recalculate if >2× off):
         1 egg ≈ 70 kcal | 1 walnut half ≈ 26 kcal | 1 medium banana ≈ 90 kcal
         100g chicken breast ≈ 165 kcal | 1 tbsp olive oil ≈ 120 kcal | 1 slice bread ≈ 80 kcal
         1 chapati/roti ≈ 100 kcal | 1 cup cooked rice ≈ 200 kcal | 1 cup dal ≈ 150 kcal
         100g paneer ≈ 265 kcal | 1 medium apple ≈ 95 kcal | 1 tbsp ghee ≈ 112 kcal
         100g oats ≈ 389 kcal | 1 cup whole milk ≈ 149 kcal | 1 medium potato ≈ 160 kcal
      5. Be CONSERVATIVE — when uncertain, err on the side of slightly lower calories.
      6. For COMPOSITE dishes (biryani, curry, sandwich) estimate ingredients collectively.

      Use USDA or IFCT (Indian Food Composition Tables) data. JSON ONLY. No markdown.
    ''';

    try {
      final raw = await GeminiService.generate(prompt: prompt, jsonMode: true);
      if (raw != null) {
        final decoded = json.decode(raw);
        List<Map<String, dynamic>> items;
        if (decoded is List) {
          items = decoded.cast<Map<String, dynamic>>();
        } else if (decoded is Map<String, dynamic>) {
          items = [decoded];
        } else {
          return null;
        }
        return _reconcileCalories(items);
      }
    } catch (e) {
      debugPrint('Error parsing food description: $e');
    }
    return null;
  }

  /// Recalculates caloriesPerServing from macros whenever Gemini's value
  /// diverges by more than 15% from (P×4 + C×4 + F×9). This ensures the
  /// displayed calorie number is always mathematically consistent with the
  /// displayed macros.
  static List<Map<String, dynamic>> _reconcileCalories(List<Map<String, dynamic>> items) {
    for (final item in items) {
      final p = (item['proteinPerServing'] as num?)?.toDouble() ?? 0.0;
      final c = (item['carbsPerServing'] as num?)?.toDouble() ?? 0.0;
      final f = (item['fatPerServing'] as num?)?.toDouble() ?? 0.0;
      final macroCal = p * 4 + c * 4 + f * 9;
      final geminiCal = (item['caloriesPerServing'] as num?)?.toDouble() ?? 0.0;

      if (macroCal > 0) {
        if (geminiCal <= 0) {
          item['caloriesPerServing'] = macroCal;
        } else {
          final ratio = geminiCal / macroCal;
          if (ratio < 0.85 || ratio > 1.15) {
            // Gemini's calorie total is inconsistent with its own macros — fix it.
            item['caloriesPerServing'] = macroCal;
          }
        }
      }
    }
    return items;
  }

  static Future<List<Map<String, dynamic>>?> parseFoodImage(Uint8List imageBytes) async {
    final apiKey = AppStorage.activeGeminiKey;
    if (apiKey.isEmpty) return null;

    const prompt = '''
      Analyze this food image carefully.
      If it shows a nutrition facts label or food packaging: read the EXACT values from the label.
      If it shows actual food (plated meal, ingredients): estimate based on visual portion sizes.

      Return a JSON array. Each object must have:
      - name: String (specific name, e.g. "Oat Upma" not just "Food")
      - brand: String (if visible on packaging, else empty)
      - servingUnit: String (e.g. "serving", "piece", "g", "bowl")
      - caloriesPerServing: double (READ from label if visible, else estimate)
      - proteinPerServing: double (grams)
      - carbsPerServing: double (grams)
      - fatPerServing: double (grams)
      - fiberPerServing: double (grams)
      - servingsConsumed: double (default 1.0)

      IMPORTANT: If nutrition label is visible, use THOSE exact numbers — do not estimate.
      JSON ONLY. No markdown.
    ''';

    try {
      final raw = await GeminiService.generate(
        prompt: prompt,
        images: [(mimeType: 'image/jpeg', bytes: imageBytes)],
        jsonMode: true,
      );
      if (raw != null) {
        final decoded = json.decode(raw);
        List<Map<String, dynamic>> items;
        if (decoded is List) {
          items = decoded.cast<Map<String, dynamic>>();
        } else if (decoded is Map<String, dynamic>) {
          items = [decoded];
        } else {
          return null;
        }
        return _reconcileCalories(items);
      }
    } catch (e) {
      debugPrint('Error parsing food image: $e');
    }
    return null;
  }

  // --- BARCODE LOOKUP (OpenFoodFacts) ---

  /// Looks up a barcode via the OpenFoodFacts API and returns nutrition data.
  /// Returns null if not found or on error.
  static Future<Map<String, dynamic>?> lookupBarcode(String barcode) async {
    debugPrint('[Barcode] Looking up: $barcode');
    try {
      final uri = Uri.parse(
          'https://world.openfoodfacts.org/api/v2/product/$barcode?fields=product_name,brands,nutriments,serving_size,serving_quantity');
      debugPrint('[Barcode] GET $uri');
      final response = await http.get(uri, headers: {'User-Agent': 'Nudge/1.0'})
          .timeout(const Duration(seconds: 20));
      debugPrint('[Barcode] HTTP ${response.statusCode} (${response.body.length} bytes)');
      if (response.statusCode != 200) {
        debugPrint('[Barcode] Non-200 response: ${response.body.substring(0, response.body.length.clamp(0, 300))}');
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final status = json['status'];
      debugPrint('[Barcode] status=$status status_verbose=${json['status_verbose']}');
      if (status != 1) return null;

      final product = json['product'] as Map<String, dynamic>? ?? {};
      final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};

      final name = (product['product_name'] as String?)?.trim() ?? '';
      debugPrint('[Barcode] product_name="$name" brands="${product['brands']}" serving_quantity=${product['serving_quantity']}');
      debugPrint('[Barcode] nutriments keys: ${nutriments.keys.where((k) => k.contains('100g')).join(', ')}');
      if (name.isEmpty) {
        debugPrint('[Barcode] Empty product name — returning null');
        return null;
      }

      // OpenFoodFacts uses _100g suffix for per-100g values
      final cal100 = (nutriments['energy-kcal_100g'] as num?)?.toDouble() ?? 0.0;
      final prot100 = (nutriments['proteins_100g'] as num?)?.toDouble() ?? 0.0;
      final carb100 = (nutriments['carbohydrates_100g'] as num?)?.toDouble() ?? 0.0;
      final fat100 = (nutriments['fat_100g'] as num?)?.toDouble() ?? 0.0;
      final fiber100 = (nutriments['fiber_100g'] as num?)?.toDouble() ?? 0.0;

      // Determine serving size (default 100g if not specified)
      final servingQty = (product['serving_quantity'] as num?)?.toDouble() ?? 100.0;
      final factor = servingQty / 100.0;
      debugPrint('[Barcode] cal100=$cal100 prot100=$prot100 carb100=$carb100 fat100=$fat100 servingQty=${servingQty}g factor=$factor');

      final result = {
        'name': name,
        'brand': (product['brands'] as String?)?.split(',').first.trim() ?? '',
        'servingUnit': 'serving',
        'caloriesPerServing': cal100 * factor,
        'proteinPerServing': prot100 * factor,
        'carbsPerServing': carb100 * factor,
        'fatPerServing': fat100 * factor,
        'fiberPerServing': fiber100 * factor,
        'servingsConsumed': 1.0,
      };
      debugPrint('[Barcode] Success: $result');
      return result;
    } on TimeoutException catch (e) {
      debugPrint('[Barcode] Timeout: $e');
      rethrow;
    } catch (e, stack) {
      debugPrint('[Barcode] Exception: $e');
      debugPrint('[Barcode] Stack: $stack');
      return null;
    }
  }

  // --- MEAL TEMPLATES ---

  static Future<List<Map<String, dynamic>>> getMealTemplates() async {
    final box = await AppStorage.getFoodLibraryBox();
    final raw = (box.get('meal_templates', defaultValue: <dynamic>[]) as List);
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> saveMealTemplate(String name, String mealType, List<Map<String, dynamic>> items) async {
    final box = await AppStorage.getFoodLibraryBox();
    final templates = (box.get('meal_templates', defaultValue: <dynamic>[]) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    // Replace existing template with same name
    templates.removeWhere((t) => (t['name'] as String?)?.toLowerCase() == name.toLowerCase());
    templates.add({
      'name': name,
      'mealType': mealType,
      'items': items,
      'savedAt': DateTime.now().toIso8601String(),
    });
    await box.put('meal_templates', templates);
  }

  static Future<void> deleteMealTemplate(String name) async {
    final box = await AppStorage.getFoodLibraryBox();
    final templates = (box.get('meal_templates', defaultValue: <dynamic>[]) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    templates.removeWhere((t) => (t['name'] as String?)?.toLowerCase() == name.toLowerCase());
    await box.put('meal_templates', templates);
  }

  // --- LOCAL LIBRARY ---
  
  static Future<void> saveToLibrary(Map<String, dynamic> item) async {
    final box = await AppStorage.getFoodLibraryBox();
    final String name = item['name']?.toString() ?? 'Unknown Food';
    final key = name.toLowerCase().trim();
    
    // Only save to library if it has valid nutritional data
    final double calories = (item['caloriesPerServing'] ?? item['calories'] ?? 0).toDouble();
    if (calories > 0 || item['name'] != null) {
      await box.put(key, {
        'name': name,
        'brand': item['brand'] ?? '',
        'caloriesPerServing': calories,
        'proteinPerServing': (item['proteinPerServing'] ?? item['protein'] ?? 0).toDouble(),
        'carbsPerServing': (item['carbsPerServing'] ?? item['carbs'] ?? 0).toDouble(),
        'fatPerServing': (item['fatPerServing'] ?? item['fat'] ?? 0).toDouble(),
        'fiberPerServing': (item['fiberPerServing'] ?? item['fiber'] ?? 0).toDouble(),
        // Also save flat keys for backward compatibility/simpler UI access
        'calories': calories,
        'protein': (item['proteinPerServing'] ?? item['protein'] ?? 0).toDouble(),
        'carbs': (item['carbsPerServing'] ?? item['carbs'] ?? 0).toDouble(),
        'fat': (item['fatPerServing'] ?? item['fat'] ?? 0).toDouble(),
        'mealType': item['mealType'],
      });
    }
  }

  static Future<List<Map<String, dynamic>>> searchLibrary(String query) async {
    final box = await AppStorage.getFoodLibraryBox();
    final q = query.toLowerCase().trim();
    final all = box.values
        .where((e) => e is Map && e.containsKey('name'))
        .map((e) => (e as Map).cast<String, dynamic>())
        .where((e) => e['name'] != null && !(e['name'] as String).startsWith('meal_template_'))
        .toList();
    if (q.isEmpty) {
      // Return most recently logged items
      all.sort((a, b) {
        final at = (a['savedAt'] ?? '') as String;
        final bt = (b['savedAt'] ?? '') as String;
        return bt.compareTo(at);
      });
      return all.take(10).toList();
    }
    return all
        .where((e) => (e['name'] as String).toLowerCase().contains(q))
        .take(10)
        .toList();
  }

  // --- DAILY LOGS ---

  static Future<List<Map<String, dynamic>>> getTodayEntries({DateTime? date}) async {
    final box = await AppStorage.getFoodBox();
    final all = (box.get('food', defaultValue: <dynamic>[]) as List).cast<Map>();
    final d = date ?? DateTime.now();
    final iso = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

    return all
        .where((e) => (e['timestamp'] as String? ?? '').startsWith(iso))
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  static Future<void> saveEntry(Map<String, dynamic> entry) async {
    final box = await AppStorage.getFoodBox();
    final all = (box.get('food', defaultValue: <dynamic>[]) as List).toList();

    // Ensure it's saved to the library for future autocomplete
    await saveToLibrary(entry);

    final newEntry = {
      ...entry,
      'timestamp': entry['timestamp'] ?? DateTime.now().toIso8601String(),
      'id': entry['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      // Ensure flat keys exist for legacy UI
      'calories': (entry['calories'] ?? entry['caloriesPerServing'] ?? 0).toDouble(),
      'protein': (entry['protein'] ?? entry['proteinPerServing'] ?? 0).toDouble(),
      'carbs': (entry['carbs'] ?? entry['carbsPerServing'] ?? 0).toDouble(),
      'fat': (entry['fat'] ?? entry['fatPerServing'] ?? 0).toDouble(),
    };

    all.add(newEntry);
    await box.put('food', all);
  }

  static Future<void> editEntry(String id, Map<String, dynamic> updatedData) async {
     final box = await AppStorage.getFoodBox();
     final all = (box.get('food', defaultValue: <dynamic>[]) as List).toList();
     final index = all.indexWhere((e) => (e as Map)['id'] == id);
     if (index != -1) {
       final existing = all[index] as Map;
       all[index] = {
         ...existing,
         ...updatedData,
       };
       await box.put('food', all);
     }
  }

  static Future<void> deleteEntry(String id) async {
    final box = await AppStorage.getFoodBox();
    final all = (box.get('food', defaultValue: <dynamic>[]) as List).toList();
    all.removeWhere((e) => (e as Map)['id'] == id);
    await box.put('food', all);
  }

  static Future<double> getTodayCalories({DateTime? date}) async {
    final today = await getTodayEntries(date: date);
    return today.fold<double>(0.0, (sum, e) {
      final servings = (e['servingsConsumed'] as num?)?.toDouble() ?? 1.0;
      final cals = (e['calories'] ?? e['caloriesPerServing'] ?? 0 as num).toDouble();
      return sum + (cals * servings);
    });
  }

  // ── Macro Calculations ──────────────────────────────────────────────────
  
  static void calculateAndSaveMacros(double heightCm, double weightKg, String activity, String goal) {
    // 1. Basal Metabolic Rate (Mifflin-St Jeor equation - male avg approx, or blended)
    // using a rough blended average since gender isn't requested to keep it simple:
    double bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * 30) + 5; // Assumed age 30, leaning male/average

    // 2. Activity Multiplier
    double multiplier = 1.2;
    switch (activity) {
      case 'Sedentary': multiplier = 1.2; break;
      case 'Light': multiplier = 1.375; break;
      case 'Moderate': multiplier = 1.55; break;
      case 'Active': multiplier = 1.725; break;
      case 'Very Active': multiplier = 1.9; break;
    }

    double tdee = bmr * multiplier;

    // 3. Goal Adjustment
    double targetCals = tdee;
    double proteinPerKg = 1.8; // default

    switch (goal) {
      case 'Weight Loss':
        targetCals -= 500;
        proteinPerKg = 2.2; // Higher protein to preserve muscle in deficit
        break;
      case 'Muscle Gain':
        targetCals += 300;
        proteinPerKg = 2.0;
        break;
      case 'Maintenance':
      default:
        proteinPerKg = 1.8;
        break;
    }

    // Ensure calories don't go disastrously low
    if (targetCals < 1200) targetCals = 1200;

    // 4. Calculate Macros
    double protein = weightKg * proteinPerKg;
    double fat = (targetCals * 0.25) / 9.0; // 25% of calories from fat, 9 cals per g
    double fibre = (targetCals / 1000) * 14.0; // 14g per 1000 cals

    // Remainder in Carbs (4 cals per g)
    double remainingCals = targetCals - (protein * 4) - (fat * 9);
    double carbs = remainingCals / 4.0;
    if (carbs < 0) carbs = 0;

    final box = AppStorage.settingsBox;
    box.put('macro_cals', targetCals);
    box.put('macro_protein', protein);
    box.put('macro_fat', fat);
    box.put('macro_fibre', fibre);
    box.put('macro_carbs', carbs);
  }

  static Map<String, double> getMacroGoals() {
    final box = AppStorage.settingsBox;
    // Default to 2000 cal diet if nothing set
    return {
      'calories': box.get('macro_cals', defaultValue: 2000.0) as double,
      'protein': box.get('macro_protein', defaultValue: 150.0) as double,
      'fat': box.get('macro_fat', defaultValue: 65.0) as double,
      'carbs': box.get('macro_carbs', defaultValue: 200.0) as double,
      'fibre': box.get('macro_fibre', defaultValue: 30.0) as double,
    };
  }
}
