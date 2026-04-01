// lib/utils/ai_analysis_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/health_center_service.dart';
import 'gemini_service.dart';
import '../storage.dart';

class AiAnalysisService {
  static Future<String?> generateWeeklyReport({String? userNotes}) async {
    final history = await HealthCenterService.getHistoryStats(7);
    final goals = HealthCenterService.getActiveGoals();
    final profile = HealthCenterService.profile;

    final prompt = _buildPrompt(history, goals, profile, userNotes);
    
    final response = await GeminiService.generate(prompt: prompt);
    if (response != null) {
      await _saveReport(response);
    }
    return response;
  }

  static String _buildPrompt(List<Map<String, dynamic>> history, List<dynamic> goals, Map<String, dynamic> profile, String? userNotes) {
    final bmi = HealthCenterService.computeBMI();
    final goalsJson = jsonEncode(goals.map((g) => {
      'title': g.title,
      'description': g.description,
      'target': '${g.targetValue} ${g.unit}',
      'current': '${g.currentValue} ${g.unit}',
      'targetDate': g.targetDate.toIso8601String(),
    }).toList());

    final historyJson = jsonEncode(history);

    return """
You are a premium, high-performance health and fitness AI coach. Analyze the user's performance over the last 7 days with a focus on high-fidelity data points.

Structure your report into these specific sections:
1. 🚶 WALKING: Analyze their daily steps and walking distance.
2. 🏃 RUNNING: Analyze their running performance.
3. 🏋️ GYM & WORKOUTS: Deep dive into their workout volume and consistency.
4. 🥗 NUTRITION & HYDRATION: Analyze their food (calories) and water intake. Are they fueling correctly for their activity level?
5. 📈 EXECUTIVE SUMMARY: A high-level overview of their week.
6. 🎯 RECOMMENDATIONS: 3 specific, actionable "power moves" for next week.

User Profile:
- Name: ${profile['name'] ?? 'User'}
- Goal: ${profile['goal'] ?? 'Maintain'}
- BMI: ${bmi?.toStringAsFixed(1) ?? 'Unknown'}
- Primary Focus: ${profile['goal'] ?? 'General Fitness'}

Active Goals:
$goalsJson

Last 7 Days Detailed Stats (including activity, food calories, and water):
$historyJson

Tone: Professional, motivating, but CRITICAL and FUN. Use emojis. Avoid generic advice.
""";
  }

  static Future<void> _saveReport(String content) async {
    final box = await AppStorage.getGymBox();
    final List<dynamic> reports = box.get('ai_reports', defaultValue: []);
    reports.insert(0, {
      'timestamp': DateTime.now().toIso8601String(),
      'content': content,
    });
    // Keep only last 10 reports
    if (reports.length > 10) reports.removeLast();
    await box.put('ai_reports', reports);
  }

  static List<Map<String, dynamic>> getSavedReports() {
    final raw = AppStorage.gymBox.get('ai_reports', defaultValue: []);
    return (raw as List).map((r) => Map<String, dynamic>.from(r)).toList();
  }

  /// Generates a short (2–3 sentence) post-workout summary with progress highlights.
  static Future<String?> generateWorkoutSummary({
    required Map<String, dynamic> workout,
    required Map<String, dynamic> lastByExercise,
  }) async {
    try {
      final exercises = ((workout['exercises'] as List?) ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

      final durationSec = (workout['durationSeconds'] as num?)?.toInt() ?? 0;
      final durationMin = durationSec ~/ 60;

      final lines = <String>[];
      int prsHit = 0;
      double totalVol = 0;

      for (final ex in exercises) {
        final name = (ex['name'] as String?) ?? '';
        final sets = ((ex['sets'] as List?) ?? [])
            .map((s) => (s as Map).cast<String, dynamic>())
            .toList();
        double bestW = 0;
        int maxR = 0;
        for (final s in sets) {
          final w = (s['weight'] as num?)?.toDouble() ?? 0.0;
          final r = (s['reps'] as num?)?.toInt() ?? 0;
          if (w > bestW) bestW = w;
          if (r > maxR) maxR = r;
          totalVol += w * r;
        }
        final last = lastByExercise[name] as Map?;
        final prevBest = (last?['bestWeight'] as num?)?.toDouble() ?? 0.0;
        final isPR = bestW > 0 && prevBest > 0 && bestW > prevBest;
        if (isPR) prsHit++;
        final wStr = bestW > 0 ? '${bestW % 1 == 0 ? bestW.toStringAsFixed(0) : bestW.toStringAsFixed(1)}kg' : 'BW';
        final prTag = isPR ? ' ★ NEW PR' : '';
        lines.add('• $name: ${sets.length} sets, peak $wStr$prTag');
      }

      final prompt = '''
You are a fired-up, no-nonsense gym coach for the Nudge app. Write a post-workout summary in EXACTLY 2-3 sentences.

Session details:
- Duration: ${durationMin > 0 ? '${durationMin}min' : 'not tracked'}
- Exercises (${exercises.length}):
${lines.join('\n')}
- PRs smashed: $prsHit
- Total volume: ${totalVol > 0 ? '${totalVol.toStringAsFixed(0)}kg' : 'N/A'}

Rules:
1. Mention specific exercises and weights (not generic praise).
2. If PRs were hit, celebrate them by name.
3. Close with ONE precise tip for the next session (target a specific lift or muscle group).
4. Energy: direct and motivating. No filler.
Max 3 sentences.''';

      return await GeminiService.generate(prompt: prompt);
    } catch (e) {
      debugPrint('AiAnalysisService.generateWorkoutSummary error: $e');
      return null;
    }
  }
}
