import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../storage.dart';
import '../screens/gym/exercise_db.dart';
import 'gemini_service.dart';

class AiRoutineGenerator {
  /// Analyzes the user's progression plan and recent workout history
  /// to generate today's routine formatted as JSON.
  static Future<Map<String, dynamic>?> generateDailyRoutine(String dayIso) async {
    try {
      final settings = AppStorage.settingsBox;
      final aiPlan = settings.get('ai_progression_plan', defaultValue: 'No formal plan set.') as String;
      
      final gymBox = await AppStorage.getGymBox();
      final workoutsRaw = gymBox.get('workouts', defaultValue: <dynamic>[]) as List;
      
      // Get the last 7 days of workouts to inform the AI of recent volume
      final recentWorkouts = workoutsRaw
          .map((e) => (e as Map).cast<String, dynamic>())
          .where((w) => w['dayIso'] != null && w['dayIso'] != dayIso)
          .toList();
          
      recentWorkouts.sort((a, b) => (b['dayIso'] as String).compareTo(a['dayIso'] as String));
      final last7Days = recentWorkouts.take(7).toList();

      final prompt = '''
You are an expert personal trainer and periodisation coach for the "Nudge" app.

The user is requesting a daily workout routine tailored to their overarching 8-week progressive plan.
Generate today's workout based on the plan and their recent workout history.

### User's Overarching Plan
$aiPlan

### User's Recent Workout History (Last 7 Sessions)
${jsonEncode(last7Days)}

### Known Exercises Reference:
${ExerciseDB.allExercises.join(', ')}

### Task & Rules:
1. Review the overarching plan to determine which phase and split day the user should be doing today.
2. Review the recent workout history to avoid overtraining muscle groups they just hit yesterday.
3. Suggest 4 to 8 exercises for today's session based on the plan.
4. Provide realistic set, rep, and target weight goals (in kg) based on their history. If you don't know their strength level for a lift, set the weight to 0.0.
5. All exercise names MUST exactly match one of the Known Exercises Reference if possible.
6. Return the routine strictly as a JSON object, with no markdown formatting or extra raw text.

### Output JSON Format Specification:
{
  "exercises": [
    {
      "name": "Barbell Squat",
      "sets": [
        {"reps": 8, "weight": 60.0},
        {"reps": 8, "weight": 60.0},
        {"reps": 8, "weight": 60.0}
      ]
    }
  ],
  "note": "Today is Leg Day from Phase 1. Focus on depth and explosive power on the way up."
}
''';

      final rawOutput = await GeminiService.generate(prompt: prompt);
      if (rawOutput == null) return null;

      String cleanedJson = rawOutput;
      final start = rawOutput.indexOf('{');
      final end = rawOutput.lastIndexOf('}');
      if (start != -1 && end != -1) {
        cleanedJson = rawOutput.substring(start, end + 1);
      }

      final data = jsonDecode(cleanedJson) as Map<String, dynamic>;
      return data;
    } catch (e) {
      debugPrint('AiRoutineGenerator error: $e');
      return null;
    }
  }
}
