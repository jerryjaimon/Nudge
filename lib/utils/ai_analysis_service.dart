// lib/utils/ai_analysis_service.dart

import 'dart:convert';
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
}
