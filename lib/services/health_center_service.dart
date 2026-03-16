// lib/services/health_center_service.dart
//
// Central data aggregation service — single source of truth for all
// health & body metrics. Reads from existing Hive boxes; no new box needed.
//
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import '../storage.dart';
import '../utils/food_service.dart';
import '../utils/health_service.dart';
import '../utils/usage_service.dart';
import '../models/health_goal.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:hive/hive.dart';

class HealthCenterService {
  // ── Profile ──────────────────────────────────────────────────────────────
  // Stored in gym_box['profile']. Extends the existing {weightKg, heightCm}
  // with age, gender, goal, activityLevel, targetWeightKg, name.

  static Map<String, dynamic> get profile {
    final raw = AppStorage.gymBox.get('profile', defaultValue: <String, dynamic>{});
    return (raw as Map).cast<String, dynamic>();
  }

  static Future<void> saveProfile(Map<String, dynamic> data) async {
    final box = await AppStorage.getGymBox();
    await box.put('profile', Map<String, dynamic>.from(data));
    _recalcMacros(data);
  }

  static double? get heightCm {
    final v = profile['heightCm'];
    return v is num ? v.toDouble() : null;
  }

  static double? get weightKg {
    final v = profile['weightKg'];
    return v is num ? v.toDouble() : null;
  }

  static int? get age {
    final v = profile['age'];
    return v is int ? v : (v is num ? v.toInt() : null);
  }

  /// 'male' | 'female' | 'other'
  static String? get gender => profile['gender'] as String?;

  /// 'lose' | 'maintain' | 'gain'
  static String get goal => (profile['goal'] as String?) ?? 'maintain';

  /// 'sedentary' | 'light' | 'moderate' | 'active' | 'very_active'
  static String get activityLevel =>
      (profile['activityLevel'] as String?) ?? 'moderate';

  static double? get targetWeightKg {
    final v = profile['targetWeightKg'];
    return v is num ? v.toDouble() : null;
  }

  static DateTime? get targetWeightDate {
    final v = profile['targetWeightDate'];
    return v != null ? DateTime.tryParse(v as String) : null;
  }

  static String get displayName => (profile['name'] as String?) ?? '';

  // ── Computed health metrics ───────────────────────────────────────────────

  /// Mifflin-St Jeor BMR — null if height or weight unknown.
  static double? computeBMR() {
    final h = heightCm;
    final w = weightKg;
    if (h == null || w == null) return null;
    final a = (age ?? 30).toDouble();
    if (gender == 'female') {
      return (10 * w) + (6.25 * h) - (5 * a) - 161;
    }
    return (10 * w) + (6.25 * h) - (5 * a) + 5;
  }

  static int? computeTDEE() {
    final bmr = computeBMR();
    if (bmr == null) return null;
    const m = {
      'sedentary': 1.2,
      'light': 1.375,
      'moderate': 1.55,
      'active': 1.725,
      'very_active': 1.9,
    };
    return (bmr * (m[activityLevel] ?? 1.55)).round();
  }

  static double? computeBMI() {
    final h = heightCm;
    final w = weightKg;
    if (h == null || w == null || h == 0) return null;
    return w / ((h / 100) * (h / 100));
  }

  /// Returns the stored calorie target (from macro settings), falling back to
  /// computed TDEE, then 2000 kcal.
  static int get dailyCalorieTarget {
    final v = AppStorage.settingsBox.get('macro_cals');
    if (v is num) return v.toInt();
    return computeTDEE() ?? 2000;
  }

  // ── Cardio / activity goals ───────────────────────────────────────────────
  // Stored in settings_box with 'goal_*' keys.

  static int get stepsGoal =>
      (AppStorage.settingsBox.get('goal_steps') as num?)?.toInt() ?? 10000;

  static int get caloriesBurnedGoal =>
      (AppStorage.settingsBox.get('goal_cal_burned') as num?)?.toInt() ?? 500;

  static double get distanceGoalKm =>
      (AppStorage.settingsBox.get('goal_distance_km') as num?)?.toDouble() ?? 5.0;

  /// Target number of workout sessions per week.
  static int get weeklyWorkoutsGoal =>
      (AppStorage.settingsBox.get('goal_workouts_week') as num?)?.toInt() ?? 3;

  static Future<void> saveCardioGoals({
    int? steps,
    int? caloriesBurned,
    double? distanceKm,
    int? weeklyWorkouts,
  }) async {
    final box = AppStorage.settingsBox;
    if (steps != null) box.put('goal_steps', steps);
    if (caloriesBurned != null) box.put('goal_cal_burned', caloriesBurned);
    if (distanceKm != null) box.put('goal_distance_km', distanceKm);
    if (weeklyWorkouts != null) box.put('goal_workouts_week', weeklyWorkouts);
  }

  /// Count of gym workout sessions in the current ISO week (Mon–Sun).
  /// Running/walking/HC sessions are NOT counted here — those belong to Activity Coach.
  static Future<int> getWeeklyWorkoutCount() async {
    final now = DateTime.now();
    // ISO week starts Monday
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final gymBox = await AppStorage.getGymBox();
    final workouts = (gymBox.get('workouts', defaultValue: []) as List).cast<Map>();

    int count = 0;
    for (var w in workouts) {
      final iso = w['dayIso'] as String?;
      if (iso == null) continue;
      final d = DateTime.tryParse(iso);
      if (d != null &&
          !d.isBefore(DateTime(weekStart.year, weekStart.month, weekStart.day)) &&
          d.isBefore(now.add(const Duration(days: 1)))) {
        count++;
      }
    }

    return count;
  }

  /// Returns gym workout sessions for the current ISO week (Mon–Sun).
  /// Running/walking/HC sessions are excluded — those belong to Activity Coach.
  static Future<List<Map<String, dynamic>>> getWeeklyWorkoutDetails() async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final gymBox = await AppStorage.getGymBox();
    final workouts = (gymBox.get('workouts', defaultValue: []) as List).cast<Map>();
    final result = <Map<String, dynamic>>[];
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (int i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      if (day.isAfter(now)) break;
      final iso = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final dayLabel = dayNames[day.weekday - 1];

      for (final w in workouts.where((w) => w['dayIso'] == iso)) {
        final exercises = (w['exercises'] as List?) ?? [];
        int totalSets = 0;
        for (final ex in exercises) {
          totalSets += ((ex as Map)['sets'] as List? ?? []).length;
        }
        result.add({
          'date': iso,
          'day': dayLabel,
          'type': 'gym',
          'name': (w['name'] as String?) ?? 'Workout',
          'exercises': exercises.length,
          'sets': totalSets,
        });
      }
    }
    return result;
  }

  /// Returns the first-ever logged weight (earliest date in the weight log).
  static double? getStartWeight() {
    final log = getWeightLog();
    if (log.isEmpty) return null;
    final sorted = log.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final v = sorted.first.value['kg'];
    return v is num ? v.toDouble() : null;
  }

  // ── Internal macro recalculation ─────────────────────────────────────────

  static void _recalcMacros(Map<String, dynamic> p) {
    final h = (p['heightCm'] as num?)?.toDouble();
    final w = (p['weightKg'] as num?)?.toDouble();
    if (h == null || w == null) return;

    final a = (p['age'] as num?)?.toDouble() ?? 30;
    final g = p['gender'] as String?;
    final act = p['activityLevel'] as String? ?? 'moderate';
    final goalStr = p['goal'] as String? ?? 'maintain';

    final double bmr = g == 'female'
        ? (10 * w) + (6.25 * h) - (5 * a) - 161
        : (10 * w) + (6.25 * h) - (5 * a) + 5;

    const multipliers = {
      'sedentary': 1.2,
      'light': 1.375,
      'moderate': 1.55,
      'active': 1.725,
      'very_active': 1.9,
    };
    final tdee = bmr * (multipliers[act] ?? 1.55);

    double targetCals;
    double proteinPerKg;
    switch (goalStr) {
      case 'lose':
        targetCals = tdee - 500;
        proteinPerKg = 2.2;
        break;
      case 'gain':
        targetCals = tdee + 300;
        proteinPerKg = 2.0;
        break;
      default:
        targetCals = tdee;
        proteinPerKg = 1.8;
    }
    if (targetCals < 1200) targetCals = 1200;

    final protein = w * proteinPerKg;
    final fat = (targetCals * 0.25) / 9.0;
    final fibre = (targetCals / 1000) * 14.0;
    final carbs = ((targetCals - (protein * 4) - (fat * 9)) / 4.0)
        .clamp(0.0, double.infinity);

    final box = AppStorage.settingsBox;
    box.put('macro_cals', targetCals);
    box.put('macro_protein', protein);
    box.put('macro_fat', fat);
    box.put('macro_fibre', fibre);
    box.put('macro_carbs', carbs);
  }

  // ── Weight log ────────────────────────────────────────────────────────────
  // gym_box['daily_weights'] — new entries: {kg, source, ts}
  // Old entries were plain doubles — read both formats.

  static Map<String, Map<String, dynamic>> getWeightLog() {
    final raw = AppStorage.gymBox
        .get('daily_weights', defaultValue: <dynamic, dynamic>{}) as Map;
    final result = <String, Map<String, dynamic>>{};
    for (final e in raw.entries) {
      final key = e.key.toString();
      final val = e.value;
      if (val is Map) {
        result[key] = val.cast<String, dynamic>();
      } else if (val is num) {
        // backward compat: old format was a bare double
        result[key] = {'kg': val.toDouble(), 'source': 'manual', 'ts': key};
      }
    }
    return result;
  }

  static Future<void> logWeight(double kg) async {
    final box = await AppStorage.getGymBox();
    final raw =
        (box.get('daily_weights', defaultValue: <dynamic, dynamic>{}) as Map)
            .cast<String, dynamic>();
    raw[_isoToday()] = {
      'kg': kg,
      'source': 'manual',
      'ts': DateTime.now().toIso8601String(),
    };
    await box.put('daily_weights', raw);
  }

  /// Attempts to pull today's body weight from Health Connect.
  /// Only writes if no manual entry exists for today.
  static Future<void> tryAutoLogWeight() async {
    final today = _isoToday();
    if (getWeightLog()[today]?['source'] == 'manual') return;
    try {
      final health = Health();
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final granted = await health.requestAuthorization(
        [HealthDataType.WEIGHT],
        permissions: [HealthDataAccess.READ],
      );
      if (!granted) return;
      final data = await health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: [HealthDataType.WEIGHT],
      );
      if (data.isEmpty) return;
      final kg = (data.last.value as NumericHealthValue).numericValue.toDouble();
      final box = await AppStorage.getGymBox();
      final raw =
          (box.get('daily_weights', defaultValue: <dynamic, dynamic>{}) as Map)
              .cast<String, dynamic>();
      // Only write if still no manual entry
      if ((raw[today] as Map?)?['source'] != 'manual') {
        raw[today] = {
          'kg': kg,
          'source': 'auto',
          'ts': data.last.dateFrom.toIso8601String(),
        };
        await box.put('daily_weights', raw);
      }
    } catch (e) {
      debugPrint('HealthCenter: auto weight fetch failed: $e');
    }
  }

  static double? getTodayWeight() {
    final v = getWeightLog()[_isoToday()]?['kg'];
    return v is num ? v.toDouble() : null;
  }

  static String? getTodayWeightSource() =>
      getWeightLog()[_isoToday()]?['source'] as String?;

  static double? getLatestWeight() {
    final log = getWeightLog();
    if (log.isEmpty) return null;
    final sorted = log.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final v = sorted.first.value['kg'];
    return v is num ? v.toDouble() : null;
  }

  // ── Aggregated today stats ────────────────────────────────────────────────

  /// Returns stats for [date]. Today → live fetch; past → cached history.
  static Future<Map<String, dynamic>> getStatsForDate(DateTime date) async {
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    if (isToday) return getTodayStats();

    final iso =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final gymBox = await AppStorage.getGymBox();
    final history =
        (gymBox.get('health_history', defaultValue: []) as List).cast<Map>();
    final workouts =
        (gymBox.get('workouts', defaultValue: []) as List).cast<Map>();

    final entry =
        history.firstWhere((e) => e['dayIso'] == iso, orElse: () => {});
    final workoutEntry =
        workouts.firstWhere((w) => w['dayIso'] == iso, orElse: () => {});

    final dayCalories = await FoodService.getTodayCalories(date: date);
    final waterData = await HealthService.getTodayWater(date: date);
    final waterMl = ((waterData['total'] ?? 0) as num).toDouble();

    final macroGoals = FoodService.getMacroGoals();
    final steps = (entry['steps'] as num?)?.toDouble() ?? 0.0;
    final caloriesBurned = (entry['calories'] as num?)?.toDouble() ?? 0.0;
    final walkingDistKm =
        (entry['walkingDistKm'] as num?)?.toDouble() ?? 0.0;
    final runningDistKm =
        (entry['runningDistKm'] as num?)?.toDouble() ?? 0.0;
    final runningCal = (entry['runningCal'] as num?)?.toDouble() ?? 0.0;
    final workoutCal = (entry['workoutCal'] as num?)?.toDouble() ?? 0.0;

    return {
      'caloriesIn': dayCalories,
      'caloriesTarget': macroGoals['calories']?.toInt() ?? dailyCalorieTarget,
      'protein': 0.0, 'carbs': 0.0, 'fat': 0.0, 'fibre': 0.0,
      'proteinTarget': macroGoals['protein']?.toInt() ?? 150,
      'carbsTarget':   macroGoals['carbs']?.toInt()   ?? 200,
      'fatTarget':     macroGoals['fat']?.toInt()     ?? 65,
      'fibreTarget':   macroGoals['fibre']?.toInt()   ?? 30,
      'steps': steps,
      'caloriesBurned': caloriesBurned,
      'distanceKm': walkingDistKm + runningDistKm,
      'distance':    walkingDistKm + runningDistKm,
      'waterMl': waterMl,
      'workoutsToday': workoutEntry.isNotEmpty ? 1 : 0,
      'gymSetsToday': 0,
      'hcSessionsToday': 0,
      'latestRun': null,
      'weeklyWorkouts': 0,
      'stepsGoal': stepsGoal,
      'caloriesBurnedGoal': caloriesBurnedGoal,
      'distanceGoalKm': distanceGoalKm,
      'weeklyWorkoutsGoal': weeklyWorkoutsGoal,
      'runningCal':    runningCal,
      'workoutCal':    workoutCal,
      'walkingDistKm': walkingDistKm,
      'runningDistKm': runningDistKm,
      'stepsGrouped':  <String, int>{},
      'weeklyDetails': <Map<String, dynamic>>[],
      'moviesCount': 0, 'booksCount': 0,
      'pomMinutes': 0, 'habitStreak': 0,
      'habitProgress': {'done': 0, 'total': 0},
      'totalScreentimeMs': 0, 'usage': [], 'monthlyUsage': [],
    };
  }

  static Future<Map<String, dynamic>> getTodayStats() async {
    final macroGoals = FoodService.getMacroGoals();
    final caloriesTarget =
        macroGoals['calories']?.toInt() ?? dailyCalorieTarget;

    // Food
    final entries = await FoodService.getTodayEntries();
    double caloriesIn = 0, protein = 0, carbs = 0, fat = 0, fibre = 0;
    for (final e in entries) {
      final s = (e['servingsConsumed'] as num?)?.toDouble() ?? 1.0;
      caloriesIn +=
          ((e['caloriesPerServing'] ?? e['calories'] ?? 0) as num).toDouble() *
              s;
      protein +=
          ((e['proteinPerServing'] ?? e['protein'] ?? 0) as num).toDouble() *
              s;
      carbs +=
          ((e['carbsPerServing'] ?? e['carbs'] ?? 0) as num).toDouble() * s;
      fat +=
          ((e['fatPerServing'] ?? e['fat'] ?? 0) as num).toDouble() * s;
      fibre +=
          ((e['fiberPerServing'] ?? e['fiber'] ?? 0) as num).toDouble() * s;
    }

    // Health Connect — fetch activity + sync workout sessions
    double steps = 0, caloriesBurned = 0, waterMl = 0, distanceKm = 0;
    double runningCal = 0, workoutCal = 0, walkingDistKm = 0, runningDistKm = 0;
    Map<String, int> stepsGrouped = {};
    try {
      final now = DateTime.now();
      // Sync HC workout sessions so calorie totals include them
      await HealthService.syncHCWorkoutSessions(now);

      final h = await HealthService.fetchDailyActivityBySource();
      final totals = (h['totals'] as Map?)?.cast<String, double>() ?? {};
      steps = totals['steps'] ?? 0;
      caloriesBurned = totals['calories'] ?? 0;
      // distance stored in km by _saveTodayStats; raw totals are in metres
      distanceKm = (totals['distance'] ?? 0) / 1000;
      runningCal = totals['runningCal'] ?? 0;
      workoutCal = totals['workoutCal'] ?? 0;
      walkingDistKm = (totals['walkingDist'] ?? 0) / 1000;
      runningDistKm = (totals['runningDist'] ?? 0) / 1000;
      final waterData = h['water_today'] as Map? ?? {};
      waterMl = ((waterData['total'] ?? 0) as num).toDouble();
      // Per-source step counts (for raw data view)
      final grouped = h['grouped'] as Map? ?? {};
      for (final entry in grouped.entries) {
        if (entry.key != 'Aggregated') {
          final v = (entry.value as Map)['steps'];
          stepsGrouped[entry.key as String] = (v as num?)?.round() ?? 0;
        }
      }
    } catch (_) {}

    // Gym workouts today
    final gymBox = await AppStorage.getGymBox();
    final iso = _isoToday();
    final workouts =
        (gymBox.get('workouts', defaultValue: []) as List).cast<Map>();
    final workoutsToday = workouts.where((w) => w['dayIso'] == iso).length;

    int gymSetsToday = 0;
    for (var w in workouts.where((w) => w['dayIso'] == iso)) {
      final exercises = (w['exercises'] as List?) ?? [];
      for (var ex in exercises) {
        final setsList = ((ex as Map)['sets'] as List?) ?? [];
        gymSetsToday += setsList.length;
      }
    }

    // HC sessions today
    final hcSessions = HealthService.getCachedHCSessionsForDay(iso);

    // Latest run across all history (so card is always present if data exists)
    final allSessions = gymBox.get('hc_sessions', defaultValue: <dynamic, dynamic>{}) as Map;
    final allRuns = <Map<String, dynamic>>[];
    for (final sList in allSessions.values) {
      if (sList is List) {
        for (final s in sList) {
          if (s is Map && (s['type'] as String? ?? '').toLowerCase().contains('running')) {
            allRuns.add(Map<String, dynamic>.from(s));
          }
        }
      }
    }
    allRuns.sort((a, b) => (b['startTime'] as String).compareTo(a['startTime'] as String));
    
    // Deduplicate runs
    final uniqueRuns = <Map<String, dynamic>>[];
    for (final r in allRuns) {
      final start = DateTime.parse(r['startTime'] as String);
      final found = uniqueRuns.any((existing) {
        final eStart = DateTime.parse(existing['startTime'] as String);
        final sameType = existing['type'] == r['type'];
        return sameType && start.difference(eStart).inSeconds.abs() < 60;
      });
      if (!found) uniqueRuns.add(r);
    }
    final latestRun = uniqueRuns.isNotEmpty ? uniqueRuns.first : null;

    // Weekly workout count
    final weeklyWorkouts = await getWeeklyWorkoutCount();

    return {
      'caloriesIn': caloriesIn,
      'caloriesTarget': caloriesTarget,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fibre': fibre,
      'proteinTarget': macroGoals['protein']?.toInt() ?? 150,
      'carbsTarget': macroGoals['carbs']?.toInt() ?? 200,
      'fatTarget': macroGoals['fat']?.toInt() ?? 65,
      'fibreTarget': macroGoals['fibre']?.toInt() ?? 30,
      'steps': steps,
      'caloriesBurned': caloriesBurned,
      'distanceKm': distanceKm,
      'distance': distanceKm,
      'waterMl': waterMl,
      'workoutsToday': workoutsToday,
      'gymSetsToday': gymSetsToday,
      'hcSessionsToday': hcSessions.length,
      'latestRun': latestRun,
      'weeklyWorkouts': weeklyWorkouts,
      // goals for display
      'stepsGoal': stepsGoal,
      'caloriesBurnedGoal': caloriesBurnedGoal,
      'distanceGoalKm': distanceGoalKm,
      'weeklyWorkoutsGoal': weeklyWorkoutsGoal,
      // Breakdown data for raw data view
      'runningCal': runningCal,
      'workoutCal': workoutCal,
      'walkingDistKm': walkingDistKm,
      'runningDistKm': runningDistKm,
      'stepsGrouped': stepsGrouped,
      'weeklyDetails': await getWeeklyWorkoutDetails(),
      
      // Expanded stats for Home Dashboard
      'moviesCount': await _getMoviesCount(),
      'booksCount': await _getBooksCount(),
      'pomMinutes': await _getTodayPomMinutes(),
      'habitStreak': await _getHabitStreak(),
      'habitProgress': await _getHabitProgress(),
      'totalScreentimeMs': await _getTotalScreentimeMs(),
      'usage': await _getTopUsage(),
      'monthlyUsage': await _getMonthlyUsage(),
    };
  }

  static Future<Map<String, int>> _getHabitProgress() async {
    final habitBox = await AppStorage.getProtectedBox();
    final rawHabits = (habitBox.get('habits', defaultValue: <dynamic>[]) as List);
    final habits = rawHabits.map((e) => (e as Map).cast<String, dynamic>()).toList();
    
    final now = DateTime.now();
    final iso = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    final rawLogs = habitBox.get('habit_logs', defaultValue: <String, dynamic>{});
    final logs = (rawLogs as Map).cast<String, dynamic>();

    int doneCount = 0;
    for (final h in habits) {
      final id = h['id']?.toString() ?? '';
      final per = logs[id];
      int current = 0;
      if (per is Map) {
        final v = per[iso];
        if (v is int) current = v;
        else if (v is num) current = v.toInt();
      }
      
      final type = (h['type'] as String?) ?? 'build';
      final target = (h['target'] as int?) ?? 1;
      
      if (type == 'quit') {
        if (current <= target) doneCount++;
      } else {
        if (current >= target) doneCount++;
      }
    }

    return {
      'done': doneCount,
      'total': habits.length,
    };
  }

  static Future<List<Map<String, dynamic>>> getHistoryStats(int days) async {
    final List<Map<String, dynamic>> result = [];
    final now = DateTime.now();
    
    final gymBox = await AppStorage.getGymBox();
    final history = (gymBox.get('health_history', defaultValue: []) as List).cast<Map>();
    final workouts = (gymBox.get('workouts', defaultValue: []) as List).cast<Map>();

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final iso = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      final entry = history.firstWhere((e) => e['dayIso'] == iso, orElse: () => {});
      final workoutEntry = workouts.firstWhere((e) => e['dayIso'] == iso, orElse: () => {});
      
      // Fetch food and water for this specific day
      final dayCalories = await FoodService.getTodayCalories(date: date);
      final waterData = await HealthService.getTodayWater(date: date);
      final waterMl = (waterData['total'] ?? 0.0);

      result.add({
        'date': iso,
        'steps': (entry['steps'] as num?)?.toDouble() ?? 0.0,
        'walkingDistKm': (entry['walkingDistKm'] as num?)?.toDouble() ?? 0.0,
        'runningCal': (entry['runningCal'] as num?)?.toDouble() ?? 0.0,
        'runningDistKm': (entry['runningDistKm'] as num?)?.toDouble() ?? 0.0,
        'workoutCal': (entry['workoutCal'] as num?)?.toDouble() ?? 0.0,
        'workoutTimeMin': (entry['workoutTimeMin'] as num?)?.toInt() ?? 0,
        'caloriesBurned': (entry['calories'] as num?)?.toDouble() ?? 0.0,
        'foodCalories': dayCalories,
        'waterMl': waterMl,
        'hasLocalWorkout': workoutEntry.isNotEmpty,
        'workoutNotes': (workoutEntry['note'] as String?) ?? '',
      });
    }
    return result;
  }

  static Future<int> _getMoviesCount() async {
    final box = await AppStorage.getMoviesBox();
    return (box.get('movies', defaultValue: []) as List).length;
  }

  static Future<int> _getBooksCount() async {
    final box = await AppStorage.getBooksBox();
    return (box.get('books', defaultValue: []) as List).length;
  }

  static Future<double> _getTodayPomMinutes() async {
    final box = await AppStorage.getPomodoroBox();
    final now = DateTime.now();
    final iso = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final rawLogs = box.get('logs', defaultValue: []) as List;
    final logs = rawLogs.cast<Map>();
    return logs.where((l) => l['startTime'].toString().startsWith(iso))
        .fold<double>(0.0, (sum, l) => sum + ((l['durationMin'] as num?)?.toDouble() ?? 0.0));
  }

  static Future<int> _getHabitStreak() async {
    final habitBox = await AppStorage.getProtectedBox();
    final habits = habitBox.values.toList();
    int maxStreak = 0;
    for (final h in habits) {
      if (h is Map && (h['streak'] ?? 0) > maxStreak) {
        maxStreak = h['streak'];
      }
    }
    return maxStreak;
  }

  static Future<int> _getTotalScreentimeMs() async {
    bool hasPermission = await UsageService.checkPermission();
    if (!hasPermission) return 0;
    final trackedList = (AppStorage.settingsBox.get('tracked_apps', defaultValue: <String>[]) as List).cast<String>();
    final usage = await UsageService.fetchUsageStats(trackedApps: trackedList);
    return usage.fold<int>(0, (sum, info) {
      final val = int.tryParse(info.totalTimeInForeground ?? '0') ?? 0;
      return sum + val;
    });
  }

  static Future<List<UsageInfo>> _getTopUsage() async {
    bool hasPermission = await UsageService.checkPermission();
    if (!hasPermission) return [];
    final trackedList = (AppStorage.settingsBox.get('tracked_apps', defaultValue: <String>[]) as List).cast<String>();
    final usage = await UsageService.fetchUsageStats(trackedApps: trackedList);
    return usage.take(3).toList();
  }

  static Future<List<UsageInfo>> _getMonthlyUsage() async {
    bool hasPermission = await UsageService.checkPermission();
    if (!hasPermission) return [];
    final trackedList = (AppStorage.settingsBox.get('tracked_apps', defaultValue: <String>[]) as List).cast<String>();
    final usage = await UsageService.fetchUsageStats(monthly: true, trackedApps: trackedList);
    return usage.take(3).toList();
  }

  // ── Health Goals ──────────────────────────────────────────────────────────

  static List<HealthGoal> getActiveGoals() {
    final raw = AppStorage.gymBox.get('health_goals', defaultValue: []);
    return (raw as List).map((g) => HealthGoal.fromJson(Map<String, dynamic>.from(g))).toList();
  }

  static Future<void> saveGoal(HealthGoal goal) async {
    final goals = getActiveGoals();
    final idx = goals.indexWhere((g) => g.id == goal.id);
    if (idx >= 0) {
      goals[idx] = goal;
    } else {
      goals.add(goal);
    }
    await AppStorage.gymBox.put('health_goals', goals.map((g) => g.toJson()).toList());
  }

  static Future<void> deleteGoal(String id) async {
    final goals = getActiveGoals();
    goals.removeWhere((g) => g.id == id);
    await AppStorage.gymBox.put('health_goals', goals.map((g) => g.toJson()).toList());
  }

  // ── Recovery stats (HRV + Resting HR) ────────────────────────────────────

  /// Fetches resting HR and HRV from Health Connect for the past [days] days
  /// and returns a composite recovery score (0–100).
  static Future<Map<String, dynamic>> getRecoveryStats({int days = 7}) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    final List<double> rhrList = [];
    final List<double> hrvList = [];

    try {
      final health = Health();
      final granted = await health.requestAuthorization(
        [HealthDataType.RESTING_HEART_RATE, HealthDataType.HEART_RATE_VARIABILITY_RMSSD],
        permissions: [HealthDataAccess.READ, HealthDataAccess.READ],
      );
      if (granted) {
        final data = await health.getHealthDataFromTypes(
          startTime: start,
          endTime: now,
          types: [HealthDataType.RESTING_HEART_RATE, HealthDataType.HEART_RATE_VARIABILITY_RMSSD],
        );
        for (final p in data) {
          if (p.value is! NumericHealthValue) continue;
          final v = (p.value as NumericHealthValue).numericValue.toDouble();
          if (p.type == HealthDataType.RESTING_HEART_RATE && v > 20 && v < 200) {
            rhrList.add(v);
          } else if (p.type == HealthDataType.HEART_RATE_VARIABILITY_RMSSD && v > 0) {
            hrvList.add(v);
          }
        }
      }
    } catch (e) {
      debugPrint('Recovery stats error: $e');
    }

    final latestRhr = rhrList.isNotEmpty ? rhrList.last : null;
    final latestHrv = hrvList.isNotEmpty ? hrvList.last : null;
    final avgHrv = hrvList.isNotEmpty
        ? hrvList.reduce((a, b) => a + b) / hrvList.length
        : null;

    // Recovery score 0-100:
    // HRV component (60%): typical adult 20–100 ms; higher = better
    // RHR component (40%): 40-80 bpm; lower = better
    int? score;
    if (latestHrv != null && latestRhr != null) {
      final hrvScore = ((latestHrv - 20) / 80 * 60).clamp(0.0, 60.0);
      final rhrScore = ((80 - latestRhr) / 40 * 40).clamp(0.0, 40.0);
      score = (hrvScore + rhrScore).round().clamp(0, 100);
    } else if (latestHrv != null) {
      score = ((latestHrv - 20) / 80 * 100).round().clamp(0, 100);
    } else if (latestRhr != null) {
      score = ((80 - latestRhr) / 40 * 100).round().clamp(0, 100);
    }

    return {
      'restingHrBpm': latestRhr,
      'hrvMs': latestHrv,
      'avgHrv7d': avgHrv,
      'recoveryScore': score,
      'rhrHistory': rhrList,
      'hrvHistory': hrvList,
    };
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _isoToday() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }
}
