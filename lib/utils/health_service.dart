import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'dart:math' as math;
import '../storage.dart';

class HealthService {
  static final Health health = Health();

  static const List<HealthDataType> types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.BASAL_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.WATER,
    HealthDataType.HEART_RATE,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.WORKOUT, // exercise session calories ("Other" in HC UI)
  ];

  // kept for backward-compat callers; now merged into types
  static const List<HealthDataType> _workoutTypes = [
    HealthDataType.WORKOUT,
  ];

  static const List<HealthDataType> debugTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.BASAL_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.WATER,
    HealthDataType.WORKOUT,
    HealthDataType.WEIGHT,
    HealthDataType.HEIGHT,
    HealthDataType.BLOOD_GLUCOSE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BODY_FAT_PERCENTAGE,
    HealthDataType.BODY_MASS_INDEX,
    HealthDataType.BODY_TEMPERATURE,
    HealthDataType.HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_SESSION,
  ];

  static Future<bool> isEnabled() async {
    return AppStorage.settingsBox.get('health_connect_enabled', defaultValue: false) as bool;
  }

  static Future<void> setEnabled(bool enabled) async {
    await AppStorage.settingsBox.put('health_connect_enabled', enabled);
  }

  static Future<bool> requestPermissions() async {
    try {
      // Check if Health Connect is available
      final bool isSupported = await health.isHealthConnectAvailable();
      if (isSupported != true) return false;

      // Request permissions
      bool granted = await health.requestAuthorization([...types, HealthDataType.WORKOUT_ROUTE]);
      return granted;
    } catch (e) {
      debugPrint('Health Connect Permission Error: $e');
      return false;
    }
  }

  /// Fetches raw health points for a given day (by default today)
  static Future<List<HealthDataPoint>> fetchRawHealthData({DateTime? start, DateTime? end}) async {
    if (!await isEnabled()) return [];
    try {
      final now = DateTime.now();
      final s = start ?? dayBoundaryStart();
      final e = end ?? now;

      List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
        startTime: s,
        endTime: e,
        types: types,
      );
      return healthData;
    } catch (e) {
      debugPrint('Health Connect fetchRawHealthData Error: $e');
      return [];
    }
  }

  /// Syncs activity for the last [days] and saves to history.
  static Future<void> syncRecentHistory({int days = 7}) async {
    if (!await isEnabled()) return;
    try {
      final now = DateTime.now();
      for (int i = 0; i < days; i++) {
        final date = now.subtract(Duration(days: i));
        final start = DateTime(date.year, date.month, date.day);
        final end = i == 0 ? now : start.add(const Duration(days: 1));
        
        await fetchDailyActivityBySource(start: start, end: end);
      }
    } catch (e) {
      debugPrint('Health Connect syncRecentHistory Error: $e');
    }
  }

  /// Calculates total steps by prioritizing watch over phone data, with
  /// time-based deduplication so Google Fit walk steps (not on watch) are
  /// included while gym-session phone steps are excluded.
  static Future<Map<String, dynamic>> fetchDailyActivityBySource({DateTime? start, DateTime? end}) async {
    if (!await isEnabled()) return {'totals': {'steps': 0.0, 'calories': 0.0, 'distance': 0.0}, 'grouped': {}};

    try {
      final healthData = await fetchRawHealthData(start: start, end: end);
      final grouped = <String, Map<String, double>>{};
      // Collect raw step points per source for time-based deduplication
      final stepPointsBySource = <String, List<HealthDataPoint>>{};

      final now = start ?? DateTime.now();

      // ── FETCH GYM SESSIONS FIRST so they're available for step dedup ──
      final sessions = await syncHCWorkoutSessions(now);

      for (var point in healthData) {
        double val = 0;
        final value = point.value;
        if (value is NumericHealthValue) {
          val = value.numericValue.toDouble();
        } else if (value is WorkoutHealthValue) {
          if (point.type == HealthDataType.WORKOUT) {
            val = (value.totalEnergyBurned ?? 0).toDouble();
          } else {
             val = (value.totalDistance ?? 0).toDouble();
          }
        } else {
          final s = value.toString();
          final match = RegExp(r"(\d+\.?\d*)").firstMatch(s);
          if (match != null) {
            val = double.tryParse(match.group(1)!) ?? 0;
          }
        }

        final source = point.sourceName.trim().isEmpty ? 'Unknown Source' : point.sourceName;
        if (!grouped.containsKey(source)) {
          grouped[source] = {'steps': 0.0, 'active_cal': 0.0, 'basal_cal': 0.0, 'total_cal': 0.0, 'distance': 0.0};
        }

        if (point.type == HealthDataType.STEPS) {
          grouped[source]!['steps'] = (grouped[source]!['steps']! + val);
          stepPointsBySource.putIfAbsent(source, () => []).add(point);
        } else if (point.type == HealthDataType.WATER) {
          if (!grouped[source]!.containsKey('water')) grouped[source]!['water'] = 0.0;
          grouped[source]!['water'] = (grouped[source]!['water']! + val);
        } else if (point.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
          grouped[source]!['active_cal'] = (grouped[source]!['active_cal']! + val);
        } else if (point.type == HealthDataType.BASAL_ENERGY_BURNED) {
          grouped[source]!['basal_cal'] = (grouped[source]!['basal_cal']! + val);
        } else if (point.type == HealthDataType.TOTAL_CALORIES_BURNED) {
          grouped[source]!['total_cal'] = (grouped[source]!['total_cal']! + val);
        } else if (point.type == HealthDataType.DISTANCE_DELTA) {
          grouped[source]!['distance'] = (grouped[source]!['distance']! + val);
        } else if (point.type == HealthDataType.WORKOUT) {
          final workoutValue = point.value;
          if (workoutValue is WorkoutHealthValue && workoutValue.totalEnergyBurned != null) {
            grouped[source]!['total_cal'] = (grouped[source]!['total_cal']! + workoutValue.totalEnergyBurned!);
          }
        }
      }

      // Calculate final merged 'calories' per source safely
      for (var s in grouped.keys) {
        final g = grouped[s]!;
        final active = g['active_cal'] ?? 0.0;
        final basal = g['basal_cal'] ?? 0.0;
        final total = g['total_cal'] ?? 0.0;
        g['calories'] = math.max(total, active + basal);

        // Debug: output points per source
        debugPrint('HealthSource [$s]: steps=${g['steps']}, cal=${g['calories']}, dist=${g['distance']}, water=${g['water'] ?? 0.0}');
      }

      debugPrint('Health Connect: Fetched ${healthData.length} points across ${grouped.length} sources.');

      double finalCal = 0.0;
      double finalDist = 0.0;
      double finalWater = 0.0;

      // ── PRIORITY-BASED BEST SOURCE ──
      final String? bestSource = _findBestSourceByPriority(grouped);

      // ── PRIORITY-BASED STEP DEDUPLICATION ──
      // Sources are processed in user-configured priority order.
      // The highest-priority enabled source is fully trusted; lower-priority
      // sources only fill time windows not already covered.
      final (double dedupSteps, Set<String> countedPointKeys) =
          _computeDeduplicatedStepsByPriority(stepPointsBySource, sessions);
      double finalSteps = dedupSteps;
      debugPrint('Deduplicated steps: $finalSteps (bestSource=$bestSource)');

      // Distance and water from best source (or max fallback)
      if (bestSource != null) {
        finalDist = grouped[bestSource]!['distance']!;
        finalWater = grouped[bestSource]!['water'] ?? 0.0;
      } else {
        for (var data in grouped.values) {
           if (data['steps']! > finalDist) finalDist = data['distance']!;
           if ((data['water'] ?? 0.0) > finalWater) finalWater = data['water']!;
        }
      }

      // ── PRIORITY-BASED CALORIES (not max-across-sources) ──
      // Take calories from the highest-priority enabled source that has data.
      // Fallback to max only if no priority source has calorie data.
      if (bestSource != null && (grouped[bestSource]?['calories'] ?? 0) > 0) {
        finalCal = grouped[bestSource]!['calories']!;
      } else if (grouped.isNotEmpty) {
        finalCal = grouped.values.map((v) => v['calories']!).reduce(math.max);
      }
      if (grouped.isNotEmpty) {
        if (finalDist == 0) {
          finalDist = grouped.values.map((v) => v['distance']!).reduce(math.max);
        }
        finalWater = math.max(finalWater, grouped.values.map((v) => v['water'] ?? 0.0).reduce(math.max));
      }

      // ── CATEGORIZE SESSIONS (Running vs Other Workouts) ──
      double runningCal = 0.0;
      double runningDist = 0.0;
      double workoutCal = 0.0;
      int workoutTime = 0;

      for (var s in sessions) {
        final type = (s['type'] as String).toLowerCase();
        final cal = (s['calories'] as num?)?.toDouble() ?? 0.0;
        final dist = (s['distanceKm'] as num?)?.toDouble() ?? 0.0;
        final dur = (s['durationMin'] as num?)?.toInt() ?? 0;

        if (type.contains('running')) {
          runningCal += cal;
          runningDist += dist;
        } else {
          workoutCal += cal;
          workoutTime += dur;
        }
      }

      // Final Calories: Use session calories if available
      if (runningCal + workoutCal > 0) {
        finalCal = runningCal + workoutCal;
      }

      // Add Local Added Steps
      final localData = await getLocalStepsForToday(date: now);
      finalSteps += localData['steps'] ?? 0.0;

      // Save to Hive with detailed breakdown
      await _saveDetailedTodayStats(
        date: now,
        steps: finalSteps,
        walkingDist: finalDist,
        runningCal: runningCal,
        runningDist: runningDist,
        workoutCal: workoutCal,
        workoutTime: workoutTime,
      );

      final Map<String, Map<String, double>> outGrouped = Map.from(grouped);
      outGrouped['Aggregated'] = {
        'steps': finalSteps,
        'calories': finalCal,
        'distance': finalDist,
        'runningCal': runningCal,
        'workoutCal': workoutCal,
      };

      return {
        'totals': {
           'steps': finalSteps,
           'walkingDist': finalDist,
           'runningCal': runningCal,
           'runningDist': runningDist,
           'workoutCal': workoutCal,
           'workoutTime': workoutTime,
           'calories': finalCal,
           'distance': finalDist,
        },
        'grouped': outGrouped,
        'bestSource': bestSource ?? 'Aggregated',
        'water_today': await getTodayWater(),
        'countedPointKeys': countedPointKeys, // Set<String> for raw-data highlighting
      };
    } catch (e) {
      debugPrint('Health Connect Fetch Error: $e');
      return {'totals': {'steps': 0.0, 'calories': 0.0, 'distance': 0.0}, 'grouped': {}};
    }
  }

  /// Priority-based time-deduplication.
  /// Sources are processed in user-configured priority order.
  /// The highest-priority enabled source's intervals are fully counted and
  /// block lower-priority sources.  Non-cardio gym intervals block all but
  /// the primary source.
  /// Returns (totalSteps, countedPointKeys) where each key is
  /// "${sourceName}_${dateFrom.millisecondsSinceEpoch}".
  static (double, Set<String>) _computeDeduplicatedStepsByPriority(
    Map<String, List<HealthDataPoint>> stepPointsBySource,
    List<Map<String, dynamic>> gymSessions,
  ) {
    if (stepPointsBySource.isEmpty) return (0.0, {});

    final priority = getSourcePriority();
    final disabled = getDisabledSources();
    final countedKeys = <String>{};

    // Sort sources by category priority; skip disabled categories
    final orderedSources = stepPointsBySource.keys
        .where((src) => !disabled.contains(sourceCategory(src)))
        .toList()
      ..sort((a, b) {
          final ia = priority.indexOf(sourceCategory(a));
          final ib = priority.indexOf(sourceCategory(b));
          return (ia < 0 ? 999 : ia).compareTo(ib < 0 ? 999 : ib);
        });

    if (orderedSources.isEmpty) return (0.0, {});

    // Non-cardio gym intervals block all non-primary sources
    final gymIntervals = <(DateTime, DateTime)>[];
    for (final s in gymSessions) {
      final type = (s['type'] as String? ?? '').toLowerCase();
      final isCardio = type.contains('running') || type.contains('walking') ||
          type.contains('cycling') || type.contains('hiking') ||
          type.contains('swimming') || type.contains('rowing');
      if (!isCardio) {
        final startStr = s['startTime'] as String?;
        final endStr = s['endTime'] as String?;
        if (startStr != null && endStr != null) {
          try {
            gymIntervals.add((DateTime.parse(startStr), DateTime.parse(endStr)));
          } catch (_) {}
        }
      }
    }

    double total = 0.0;
    // coveredForLower starts with gym blocks; the primary source ignores these
    final coveredForLower = <(DateTime, DateTime)>[...gymIntervals];
    bool isFirst = true;

    for (final src in orderedSources) {
      final points = stepPointsBySource[src] ?? <HealthDataPoint>[];
      final srcIntervals = <(DateTime, DateTime)>[];

      for (final p in points) {
        final v = p.value;
        if (v is! NumericHealthValue) continue;
        final steps = v.numericValue.toDouble();
        if (steps <= 0) continue;

        final from = p.dateFrom;
        final to = p.dateTo;
        final key = '${p.sourceName}_${from.millisecondsSinceEpoch}';
        final totalSec = to.difference(from).inSeconds;

        if (isFirst) {
          // Highest-priority source: count everything
          total += steps;
          countedKeys.add(key);
          srcIntervals.add(
              (from, totalSec > 0 ? to : from.add(const Duration(seconds: 1))));
        } else {
          if (totalSec <= 0) {
            final blocked = coveredForLower
                .any((iv) => !from.isBefore(iv.$1) && !from.isAfter(iv.$2));
            if (!blocked) {
              total += steps;
              countedKeys.add(key);
            }
          } else {
            final coveredSec = _coveredSeconds(from, to, coveredForLower);
            final uncoveredFraction = (totalSec - coveredSec) / totalSec;
            if (uncoveredFraction > 0.01) {
              total += steps * uncoveredFraction;
              countedKeys.add(key);
              srcIntervals.add((from, to));
            }
          }
        }
      }

      coveredForLower.addAll(srcIntervals);
      isFirst = false;
    }

    return (total, countedKeys);
  }

  /// Returns how many seconds of [from, to] are covered by [intervals].
  /// Clips intervals to [from, to], then merges overlaps before summing.
  static int _coveredSeconds(
      DateTime from, DateTime to, List<(DateTime, DateTime)> intervals) {
    final clipped = <(DateTime, DateTime)>[];
    for (final (s, e) in intervals) {
      final cs = s.isBefore(from) ? from : s;
      final ce = e.isAfter(to) ? to : e;
      if (cs.isBefore(ce)) clipped.add((cs, ce));
    }
    if (clipped.isEmpty) return 0;

    clipped.sort((a, b) => a.$1.compareTo(b.$1));
    var mStart = clipped[0].$1;
    var mEnd = clipped[0].$2;
    int covered = 0;
    for (int i = 1; i < clipped.length; i++) {
      final (s, e) = clipped[i];
      if (!s.isAfter(mEnd)) {
        if (e.isAfter(mEnd)) mEnd = e;
      } else {
        covered += mEnd.difference(mStart).inSeconds;
        mStart = s;
        mEnd = e;
      }
    }
    covered += mEnd.difference(mStart).inSeconds;
    return covered;
  }

  static Future<void> _saveDetailedTodayStats({
    required DateTime date,
    required double steps,
    required double walkingDist,
    required double runningCal,
    required double runningDist,
    required double workoutCal,
    required int workoutTime,
  }) async {
      final box = AppStorage.gymBox;
      final history = (box.get('health_history', defaultValue: <dynamic>[]) as List).cast<Map>();

      final iso = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

      final idx = history.indexWhere((element) => element['dayIso'] == iso);
      final entry = {
        'dayIso': iso,
        'steps': steps,
        'walkingDistKm': walkingDist / 1000,
        'runningCal': runningCal,
        'runningDistKm': runningDist,
        'workoutCal': workoutCal,
        'workoutTimeMin': workoutTime,
        'calories': runningCal + workoutCal,
      };

      if (idx >= 0) {
        history[idx] = entry;
      } else {
        history.add(entry);
      }
      await box.put('health_history', history);
  }

  // ── Source priority settings ──────────────────────────────────────────────

  static const List<String> defaultSourcePriority = [
    'samsung_health',
    'watch',
    'google_fit',
    'other',
  ];

  static const Map<String, String> sourceDisplayNames = {
    'samsung_health': 'Samsung Health',
    'watch': 'Watch / Wearable',
    'google_fit': 'Google Fit',
    'other': 'Other (Android)',
  };

  static const Map<String, String> sourceDescriptions = {
    'samsung_health': 'Samsung Health on your phone',
    'watch': 'Galaxy Watch, Pixel Watch, Garmin, Fitbit, etc.',
    'google_fit': 'Google Fit — may over-count if it aggregates other apps',
    'other': 'Phone step counter & other apps',
  };

  /// Maps a raw sourceName string from Health Connect to a category key.
  static String sourceCategory(String sourceName) {
    final lower = sourceName.toLowerCase();
    if (lower.contains('watch') || lower.contains('wear') ||
        lower.contains('garmin') || lower.contains('fitbit')) return 'watch';
    if (lower.contains('samsung') || lower.contains('shealth')) return 'samsung_health';
    if (lower.contains('google') || lower.contains('fitness')) return 'google_fit';
    return 'other';
  }

  static List<String> getSourcePriority() {
    final raw = AppStorage.settingsBox.get('health_source_priority');
    if (raw is List) {
      final list = raw.cast<String>().toList();
      // Ensure all categories are present
      for (final cat in defaultSourcePriority) {
        if (!list.contains(cat)) list.add(cat);
      }
      return list;
    }
    return List.from(defaultSourcePriority);
  }

  static Future<void> setSourcePriority(List<String> priority) async {
    await AppStorage.settingsBox.put('health_source_priority', priority);
  }

  static Set<String> getDisabledSources() {
    final raw = AppStorage.settingsBox.get('health_source_disabled');
    if (raw is List) return raw.cast<String>().toSet();
    return {};
  }

  static Future<void> setDisabledSources(Set<String> disabled) async {
    await AppStorage.settingsBox.put('health_source_disabled', disabled.toList());
  }

  // ── Day boundary ──────────────────────────────────────────────────────────

  /// Hour (0-23) at which the user considers their day to start.
  /// Default 0 = midnight. Set to e.g. 6 for 6 AM.
  static int getDayStartHour() =>
      (AppStorage.settingsBox.get('day_start_hour') as num?)?.toInt() ?? 0;

  static Future<void> setDayStartHour(int hour) async =>
      AppStorage.settingsBox.put('day_start_hour', hour.clamp(0, 23));

  /// Returns the DateTime representing the start of the current "day"
  /// for a given [reference] time, based on [getDayStartHour()].
  /// If the current hour is before dayStartHour, the day started yesterday.
  static DateTime dayBoundaryStart({DateTime? reference}) {
    final h = getDayStartHour();
    final ref = reference ?? DateTime.now();
    if (h == 0) return DateTime(ref.year, ref.month, ref.day);
    if (ref.hour < h) {
      // Still in yesterday's logical day
      final yest = ref.subtract(const Duration(days: 1));
      return DateTime(yest.year, yest.month, yest.day, h);
    }
    return DateTime(ref.year, ref.month, ref.day, h);
  }

  // ── Raw points for debug ──────────────────────────────────────────────────

  /// Returns individual calorie and distance data points from Health Connect
  /// for [date], grouped by data type key ('active_cal', 'basal_cal',
  /// 'total_cal', 'distance'). Each entry: {source, typeLabel, value, from, to}.
  static Future<Map<String, List<Map<String, dynamic>>>> fetchRawPointsForDebug(DateTime date) async {
    if (!await isEnabled()) return {};
    try {
      final h = getDayStartHour();
      final start = h == 0
          ? DateTime(date.year, date.month, date.day)
          : DateTime(date.year, date.month, date.day, h);
      final end = start.add(const Duration(hours: 24));

      final healthData = await health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: const [
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.BASAL_ENERGY_BURNED,
          HealthDataType.TOTAL_CALORIES_BURNED,
          HealthDataType.DISTANCE_DELTA,
        ],
      );

      final result = <String, List<Map<String, dynamic>>>{};

      for (final point in healthData) {
        if (point.value is! NumericHealthValue) continue;
        final val = (point.value as NumericHealthValue).numericValue.toDouble();
        if (val <= 0) continue;

        final source = point.sourceName.trim().isEmpty ? 'Unknown' : point.sourceName;
        String key;
        String label;
        switch (point.type) {
          case HealthDataType.ACTIVE_ENERGY_BURNED:
            key = 'active_cal'; label = 'Active Cal'; break;
          case HealthDataType.BASAL_ENERGY_BURNED:
            key = 'basal_cal'; label = 'Basal Cal'; break;
          case HealthDataType.TOTAL_CALORIES_BURNED:
            key = 'total_cal'; label = 'Total Cal'; break;
          case HealthDataType.DISTANCE_DELTA:
            key = 'distance'; label = 'Distance'; break;
          default:
            continue;
        }

        result.putIfAbsent(key, () => []).add({
          'source': source,
          'typeLabel': label,
          'value': val,
          'from': point.dateFrom.toIso8601String(),
          'to': point.dateTo.toIso8601String(),
        });
      }

      for (final list in result.values) {
        list.sort((a, b) => (a['from'] as String).compareTo(b['from'] as String));
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  /// Returns the highest-priority enabled source that has step data.
  static String? _findBestSourceByPriority(Map<String, Map<String, double>> grouped) {
    final priority = getSourcePriority();
    final disabled = getDisabledSources();
    for (final cat in priority) {
      if (disabled.contains(cat)) continue;
      for (final src in grouped.keys) {
        if (sourceCategory(src) == cat && (grouped[src]?['steps'] ?? 0) > 0) {
          return src;
        }
      }
    }
    return null;
  }

  static String cleanSource(String source) {
    if (source.contains('shealth')) return 'Samsung Health';
    if (source.contains('google.android.apps.fitness')) return 'Google Fit';
    if (source.contains('hevy')) return 'Hevy';
    if (source.contains('strong')) return 'Strong';
    if (source.contains('healthconnect')) return 'Health Connect';
    if (source.contains('fitbit')) return 'Fitbit';
    if (source.contains('garmin')) return 'Garmin Connect';
    if (source.contains('strava')) return 'Strava';
    if (source.contains('myfitnesspal')) return 'MyFitnessPal';
    if (source.contains('wearos') || source.contains('wear')) return 'Wear OS watch';
    final parts = source.split('.');
    if (parts.length > 1) {
      final name = parts.last;
      return name[0].toUpperCase() + name.substring(1);
    }
    return source;
  }


  // --- Local Manual Steps Logic ---
  static Future<void> addLocalSteps(double steps, double calories) async {
      final box = AppStorage.gymBox;
      final localLogs = (box.get('local_health_logs', defaultValue: <dynamic>[]) as List).cast<Map>();
      
      final now = DateTime.now();
      final iso = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      localLogs.add({
        'dayIso': iso,
        'timestamp': now.toIso8601String(),
        'steps': steps,
        'calories': calories,
      });

      await box.put('local_health_logs', localLogs);
  }

  static Future<Map<String, double>> getLocalStepsForToday({DateTime? date}) async {
      final box = AppStorage.gymBox;
      final localLogs = (box.get('local_health_logs', defaultValue: <dynamic>[]) as List).cast<Map>();
      
      final now = date ?? DateTime.now();
      final iso = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      double totalSteps = 0.0;
      double totalCal = 0.0;

      for (var log in localLogs) {
        if (log['dayIso'] == iso) {
          totalSteps += (log['steps'] as num?)?.toDouble() ?? 0.0;
          totalCal += (log['calories'] as num?)?.toDouble() ?? 0.0;
        }
      }

      return {'steps': totalSteps, 'calories': totalCal};
  }

  static Future<void> deleteLocalLog(String timestamp) async {
       final box = AppStorage.gymBox;
       final localLogs = (box.get('local_health_logs', defaultValue: <dynamic>[]) as List).cast<Map>();
       localLogs.removeWhere((log) => log['timestamp'] == timestamp);
       await box.put('local_health_logs', localLogs);
  }

  // --- Water Sync Logic ---
  static Future<void> syncWaterIntake(double healthConnectMl) async {
      final box = AppStorage.gymBox;
      final now = DateTime.now();
      final iso = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final List<Map<String, dynamic>> logs = (box.get('water_logs', defaultValue: <dynamic>[]) as List)
          .map((l) => Map<String, dynamic>.from(l as Map))
          .toList();
      final idx = logs.indexWhere((l) => l['dayIso'] == iso);

      double currentLocal = 0.0;
      if (idx >= 0) {
        currentLocal = (logs[idx]['localAmount'] as num?)?.toDouble() ?? 0.0;
      }

      final Map<String, dynamic> entry = {
        'dayIso': iso,
        'localAmount': currentLocal,
        'healthConnectAmount': healthConnectMl,
        'totalAmount': currentLocal + healthConnectMl,
      };

      if (idx >= 0) {
        logs[idx] = entry;
      } else {
        logs.add(entry);
      }
      await box.put('water_logs', logs);
  }

  static Future<void> addLocalWater(double ml, {DateTime? date}) async {
      final box = AppStorage.gymBox;
      final d = date ?? DateTime.now();
      final iso = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

      final List<Map<String, dynamic>> logs = (box.get('water_logs', defaultValue: <dynamic>[]) as List)
          .map((l) => Map<String, dynamic>.from(l as Map))
          .toList();
      final idx = logs.indexWhere((l) => l['dayIso'] == iso);

      if (idx >= 0) {
        final currentLocal = (logs[idx]['localAmount'] as num?)?.toDouble() ?? 0.0;
        final healthConnect = (logs[idx]['healthConnectAmount'] as num?)?.toDouble() ?? 0.0;
        logs[idx]['localAmount'] = (currentLocal + ml).clamp(0.0, 10000.0);
        logs[idx]['totalAmount'] = (currentLocal + ml + healthConnect).clamp(0.0, 10000.0);
      } else {
        logs.add(<String, dynamic>{
          'dayIso': iso,
          'localAmount': ml.clamp(0.0, 10000.0),
          'healthConnectAmount': 0.0,
          'totalAmount': ml.clamp(0.0, 10000.0),
        });
      }
      await box.put('water_logs', logs);
  }

  // ── All-types raw fetch (for debug / inspection) ──────────────────────────

  /// Returns every HealthDataPoint for all known types in [start, end].
  /// Sorted newest-first by the caller. Includes workouts.
  static Future<List<HealthDataPoint>> fetchAllRawData({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!await isEnabled()) return [];
    try {
      final all = [...types, ..._workoutTypes];
      final points = await health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: all,
      );
      return points;
    } catch (e) {
      debugPrint('Health Connect fetchAllRawData Error: $e');
      return [];
    }
  }

  /// Fetches GPS route coordinates for a specific workout period.
  static Future<List<Map<String, double>>> fetchRunningRoute({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!await isEnabled()) return [];
    try {
      /*
      final points = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.WORKOUT_ROUTE],
      );
      */
      final points = [];
      
      final route = <Map<String, double>>[];
      for (final _ in points) {
        /*
        final val = p.value;
        if (val is WorkoutRouteHealthValue) {
          for (var loc in val.routePoints) {
            route.add({
              'lat': loc.latitude,
              'lng': loc.longitude,
            });
          }
        }
        */
      }
      return route;
    } catch (e) {
      debugPrint('Health Connect fetchRunningRoute Error: $e');
      return [];
    }
  }

  // ── Workout Session Fetch ──────────────────────────────────────────────────

  /// Reads ExerciseSession records written by Hevy (or any app) for a given day.
  /// Returns session-level metadata only — Health Connect does not expose
  /// individual exercises/sets.
  static Future<List<Map<String, dynamic>>> fetchWorkoutSessionsForDay(DateTime day) async {
    if (!await isEnabled()) return [];
    try {
      final start = DateTime(day.year, day.month, day.day);
      final end = start.add(const Duration(days: 1));

      final points = await health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: _workoutTypes,
      );

      final sessions = points.map((point) {
        int calories = 0;
        double distanceKm = 0.0;
        int? totalSteps;
        String distanceUnit = 'METER';
        String activityType = 'Workout';
        final v = point.value;
        if (v is WorkoutHealthValue) {
          calories = v.totalEnergyBurned ?? 0;
          final rawDist = (v.totalDistance ?? 0).toDouble();
          final unitName = v.totalDistanceUnit?.name ?? 'METER';
          if (unitName.contains('KILOMETER')) {
            distanceKm = rawDist;
          } else if (unitName.contains('MILE')) {
            distanceKm = rawDist * 1.60934;
          } else {
            // Default to meter
            distanceKm = rawDist / 1000.0;
          }
          totalSteps = v.totalSteps;
          activityType = _workoutTypeName(v.workoutActivityType);
        }
        return {
          'startTime': point.dateFrom.toIso8601String(),
          'endTime': point.dateTo.toIso8601String(),
          'durationMin': point.dateTo.difference(point.dateFrom).inSeconds / 60.0,
          'type': activityType,
          'calories': calories,
          'distanceKm': distanceKm,
          'distanceUnit': distanceUnit,
          if (totalSteps != null) 'sessionSteps': totalSteps,
          'sourceName': point.sourceName,
        };
      }).toList();

      // Deduplicate sessions: overlapping times or same start + same type.
      // Samsung Health writes duplicate sessions from both phone and watch —
      // use wider tolerance (10 min) and keep the one with more data.
      bool isSamsungSource(String src) {
        final s = src.toLowerCase();
        return s.contains('shealth') || s.contains('samsung');
      }

      final uniqueSessions = <Map<String, dynamic>>[];
      for (final s in sessions) {
        final start = DateTime.parse(s['startTime'] as String);
        final end = DateTime.parse(s['endTime'] as String);
        final type = (s['type'] as String? ?? '').toLowerCase();
        final src = (s['sourceName'] as String? ?? '').toLowerCase();
        final isSamsung = isSamsungSource(src);

        final matchIdx = uniqueSessions.indexWhere((existing) {
          final eStart = DateTime.parse(existing['startTime'] as String);
          final eEnd = DateTime.parse(existing['endTime'] as String);
          final eType = (existing['type'] as String? ?? '').toLowerCase();
          final eSrc = (existing['sourceName'] as String? ?? '').toLowerCase();

          // Overlapping time windows
          final overlap = start.isBefore(eEnd) && end.isAfter(eStart);
          if (overlap) return true;

          // Same start within 60 s
          if (start.difference(eStart).inSeconds.abs() < 60) return true;

          // Samsung Health phone+watch: same type within 10 min window
          if (isSamsung && isSamsungSource(eSrc) && eType == type) {
            final startDiff = start.difference(eStart).inMinutes.abs();
            final endDiff = end.difference(eEnd).inMinutes.abs();
            if (startDiff <= 10 && endDiff <= 10) return true;
          }

          return false;
        });

        if (matchIdx < 0) {
          uniqueSessions.add(s);
        } else {
          // Keep the entry with more complete data (prefer longer duration or more distance)
          final existing = uniqueSessions[matchIdx];
          final dist = (s['distanceKm'] as num?)?.toDouble() ?? 0.0;
          final eDist = (existing['distanceKm'] as num?)?.toDouble() ?? 0.0;
          final dur = (s['durationMin'] as num?)?.toDouble() ?? 0.0;
          final eDur = (existing['durationMin'] as num?)?.toDouble() ?? 0.0;
          if (dist > eDist || (dist == eDist && dur > eDur)) {
            uniqueSessions[matchIdx] = s;
          }
        }
      }
      return uniqueSessions;
    } catch (e) {
      debugPrint('Health Connect fetchWorkoutSessions Error: $e');
      return [];
    }
  }

  static String _workoutTypeName(HealthWorkoutActivityType type) {
    return type.name
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0]}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  static Future<Map<String, double>> getTodayWater({DateTime? date}) async {
      final box = AppStorage.gymBox;
      final d = date ?? DateTime.now();
      final iso = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

      final List<Map<String, dynamic>> logs = (box.get('water_logs', defaultValue: <dynamic>[]) as List)
          .map((l) => Map<String, dynamic>.from(l as Map))
          .toList();
      final Map<String, dynamic> entry = logs.firstWhere((l) => l['dayIso'] == iso, orElse: () => <String, dynamic>{});
      
      return {
        'total': (entry['totalAmount'] as num?)?.toDouble() ?? 0.0,
        'local': (entry['localAmount'] as num?)?.toDouble() ?? 0.0,
        'health': (entry['healthConnectAmount'] as num?)?.toDouble() ?? 0.0,
      };
  }
  /// Fetches Health Connect WORKOUT sessions for [day] and caches them in
  /// gym_box['hc_sessions'][isoDate]. Returns the session list.
  static Future<List<Map<String, dynamic>>> syncHCWorkoutSessions(DateTime day) async {
    final sessions = await fetchWorkoutSessionsForDay(day);
    if (sessions.isEmpty) return sessions;
    final box = AppStorage.gymBox;
    final iso = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
    final stored = (box.get('hc_sessions', defaultValue: <dynamic, dynamic>{}) as Map)
        .cast<String, dynamic>();
    stored[iso] = sessions;
    await box.put('hc_sessions', stored);
    return sessions;
  }

  /// Returns cached HC workout sessions for a given ISO date.
  static List<Map<String, dynamic>> getCachedHCSessionsForDay(String isoDate) {
    final stored = (AppStorage.gymBox.get('hc_sessions', defaultValue: <dynamic, dynamic>{}) as Map)
        .cast<String, dynamic>();
    final raw = stored[isoDate];
    if (raw == null) return [];
    return (raw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Running threshold: speeds below this are classified as walking (< ~8 min/km).
  static const double _runningThresholdMps = 2.1;

  /// Fetches biometric + GPS route data during a run window.
  ///
  /// Returns:
  ///   avgHrBpm, peakHrBpm, minHrBpm, hrTimeline (List<Map>)
  ///   totalSteps, estimatedCadenceSpm, strideLengthM,
  ///   avgSpeedMps, peakSpeedMps,
  ///   runningDistanceKm (GPS-filtered), runningDurationMin,
  ///   walkingDistanceKm, hasMixedActivity (bool), walkingFraction,
  ///   avgRunningPaceMinKm, avgRunningSpeedMps,
  ///   gpsRoute (List<Map> with lat/lng/speed/alt/t), speedTimeline (List<Map>)
  static Future<Map<String, dynamic>> fetchRunMetrics({
    required DateTime start,
    required DateTime end,
    required double distanceKm,
    required double durationMin,
    int? sessionSteps,
    List<HealthDataPoint>? healthData,
  }) async {
    final result = <String, dynamic>{};
    if (!await isEnabled()) return result;
    try {
      /*
      print('[HEALTH_DEBUG] Fetching metrics for $startTime to $endTime');
      final routePoints = await Health().getHealthDataFromTypes(
        startTime,
        endTime,
        [HealthDataType.WORKOUT_ROUTE],
      );
      print('[HEALTH_DEBUG] Found ${routePoints.length} route points (raw)');
      */
      final data = healthData ?? await health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.HEART_RATE, HealthDataType.STEPS, HealthDataType.WORKOUT_ROUTE],
      );
      
      print('[HEALTH_DEBUG] Raw data points for metrics: ${data.length}');
      for (final p in data) {
        if (p.type == HealthDataType.WORKOUT_ROUTE) {
           print('[HEALTH_DEBUG] Found ROUTE point from ${p.sourceName}');
        }
      }

      // ── Heart rate ─────────────────────────────────────────────────────────
      final hrValues = <double>[];
      final hrTimeline = <Map<String, double>>[];
      for (final p in data) {
        if (p.type == HealthDataType.HEART_RATE) {
          final v = p.value;
          if (v is NumericHealthValue && v.numericValue > 0) {
            final bpm = v.numericValue.toDouble();
            hrValues.add(bpm);
            final tMin = p.dateFrom.difference(start).inSeconds / 60.0;
            hrTimeline.add({'t': tMin, 'bpm': bpm});
          }
        }
      }
      hrTimeline.sort((a, b) => a['t']!.compareTo(b['t']!));
      if (hrValues.isNotEmpty) {
        result['avgHrBpm'] = hrValues.reduce((a, b) => a + b) / hrValues.length;
        result['peakHrBpm'] = hrValues.reduce((a, b) => a > b ? a : b);
        result['minHrBpm'] = hrValues.reduce((a, b) => a < b ? a : b);
        result['hrTimeline'] = hrTimeline;
      }

      // ── GPS Route (WORKOUT_ROUTE) → real speed per point ───────────────────
      final gpsPoints = <({DateTime ts, double lat, double lng, double? speed, double? alt})>[];
      final seenTs = <int>{};
      for (final p in data) {
        if (p.type == HealthDataType.WORKOUT_ROUTE) {
          final v = p.value;
          print('[HEALTH_DEBUG] Found WORKOUT_ROUTE point. Value type: ${v.runtimeType}');
          if (v is WorkoutRouteHealthValue) {
            print('[HEALTH_DEBUG] WorkoutRouteHealthValue has ${v.locations.length} locations');
            for (final loc in v.locations) {
              final ms = loc.timestamp.millisecondsSinceEpoch;
              if (seenTs.contains(ms)) continue;
              seenTs.add(ms);
              gpsPoints.add((
                ts: loc.timestamp,
                lat: loc.latitude,
                lng: loc.longitude,
                speed: loc.speed,
                alt: loc.altitude,
              ));
            }
          } else {
            print('[HEALTH_DEBUG] Expected WorkoutRouteHealthValue but got ${v.runtimeType}. Value string: $v');
          }
        }
      }
      gpsPoints.sort((a, b) => a.ts.compareTo(b.ts));
      print('[HEALTH_DEBUG] Unique GPS points after deduplication: ${gpsPoints.length}');

      if (gpsPoints.isNotEmpty) {
        // Build route list for map rendering
        result['gpsRoute'] = gpsPoints.map((p) => {
          't': p.ts.millisecondsSinceEpoch,
          'lat': p.lat,
          'lng': p.lng,
          if (p.speed != null) 'speed': p.speed,
          if (p.alt != null) 'alt': p.alt,
        }).toList();

        // Build speed timeline (minutes from start → m/s)
        final speedTimeline = <Map<String, double>>[];
        for (final p in gpsPoints) {
          if (p.speed != null && p.speed! > 0) {
            final tMin = p.ts.difference(start).inSeconds / 60.0;
            final paceMinKm = 1000.0 / (p.speed! * 60.0);
            speedTimeline.add({'t': tMin, 'mps': p.speed!, 'pace': paceMinKm});
          }
        }
        if (speedTimeline.isNotEmpty) result['speedTimeline'] = speedTimeline;

        // Aggregate stats from GPS points
        final allSpeeds = gpsPoints
            .where((p) => p.speed != null && p.speed! > 0)
            .map((p) => p.speed!)
            .toList();
        if (allSpeeds.isNotEmpty) {
          result['avgSpeedMps'] = allSpeeds.reduce((a, b) => a + b) / allSpeeds.length;
          result['peakSpeedMps'] = allSpeeds.reduce((a, b) => a > b ? a : b);
        }

        // Haversine-based run/walk split using GPS speed per segment
        double totalDistM = 0;
        double runningDistM = 0;
        double walkingDistM = 0;
        double runningDurSec = 0;
        double walkingDurSec = 0;
        
        print('[HEALTH_DEBUG] First point: ${gpsPoints.first.ts}');
        print('[HEALTH_DEBUG] Last point: ${gpsPoints.last.ts}');
        int skipCount = 0;
        for (int i = 0; i < gpsPoints.length - 1; i++) {
          final curr = gpsPoints[i];
          final next = gpsPoints[i + 1];
          final durSec = next.ts.difference(curr.ts).inMilliseconds / 1000.0;
          if (durSec <= 0) {
            skipCount++;
            continue;
          }
          
          final distM = _haversineM(curr.lat, curr.lng, next.lat, next.lng);
          totalDistM += distM;

          // Use provided speed if available, otherwise compute it
          final speedMps = curr.speed ?? (distM / durSec);
          
          if (speedMps >= _runningThresholdMps) {
            runningDistM += distM;
            runningDurSec += durSec;
          } else {
            walkingDistM += distM;
            walkingDurSec += durSec;
          }
        }
        if (skipCount > 0) print('[HEALTH_DEBUG] Skipped $skipCount points due to zero duration');

        print('[HEALTH_DEBUG] Computed Total Dist: ${totalDistM / 1000.0} km');
        print('[HEALTH_DEBUG] Computed Running Dist: ${runningDistM / 1000.0} km');
        print('[HEALTH_DEBUG] Computed Walking Dist: ${walkingDistM / 1000.0} km');

        if (runningDistM > 0) {
          result['runningDistanceKm'] = runningDistM / 1000.0;
          result['runningDurationMin'] = runningDurSec / 60.0;
        }
        if (walkingDistM > 0) {
          result['walkingDistanceKm'] = walkingDistM / 1000.0;
        }
        final totalTrackedM = runningDistM + walkingDistM;
        if (totalTrackedM > 0 && walkingDistM / totalTrackedM > 0.15) {
          result['hasMixedActivity'] = true;
          result['walkingFraction'] = walkingDistM / totalTrackedM;
        }

        // Running-only average pace
        final runningDistKm = runningDistM / 1000.0;
        final runningDurMin = runningDurSec / 60.0;

        if (runningDistKm > 0 && runningDurMin > 0) {
           result['avgRunningSpeedMps'] = (runningDistM / runningDurSec);
           result['avgRunningPaceMinKm'] = runningDurMin / runningDistKm;
        }
      }

      // ── Steps → cadence + stride ────────────────────────────────────────────
      // sessionSteps comes directly from the HC workout record (most accurate).
      // Fallback: collect per-source step totals and take the MAX single source
      // to avoid double-counting when phone + watch both record the same session.
      int totalSteps = sessionSteps ?? 0;
      if (totalSteps == 0) {
        final stepsBySource = <String, int>{};
        for (final p in data) {
          if (p.type == HealthDataType.STEPS) {
            final v = p.value;
            if (v is NumericHealthValue) {
              final src = p.sourceName.trim().isEmpty ? '_unknown' : p.sourceName;
              stepsBySource[src] = (stepsBySource[src] ?? 0) + v.numericValue.toInt();
            }
          }
        }
        if (stepsBySource.isNotEmpty) {
          totalSteps = stepsBySource.values.reduce((a, b) => a > b ? a : b);
        }
      }
      final strideDist = (result['runningDistanceKm'] as double?) ?? distanceKm;
      final strideDur = (result['runningDurationMin'] as double?) ?? durationMin;
      if (totalSteps > 0) {
        result['totalSteps'] = totalSteps;
        if (strideDur > 0) result['estimatedCadenceSpm'] = (totalSteps / strideDur).round();
        if (strideDist > 0) result['strideLengthM'] = (strideDist * 1000) / (totalSteps / 2.0);
      }
    } catch (e) {
      debugPrint('fetchRunMetrics error: $e');
    }
    return result;
  }

  static double _haversineM(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final p1 = lat1 * math.pi / 180, p2 = lat2 * math.pi / 180;
    final dp = (lat2 - lat1) * math.pi / 180;
    final dl = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dp / 2) * math.sin(dp / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static Future<List<String>> fetchDeepDump({required DateTime start, required DateTime end}) async {
    if (!await isEnabled()) return ["Health Connect not enabled."];
    try {
      final points = await health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: debugTypes,
      );
      if (points.isEmpty) return ["No data found for the selected range across ${debugTypes.length} types."];
      
      final result = <String>[];
      result.add("HEALTH CONNECT DEEP DUMP (${points.length} points)\nRange: ${start.toIso8601String()} to ${end.toIso8601String()}");
      
      for (var p in points) {
        final sb = StringBuffer();
        sb.writeln("[${p.type.name}] ${p.dateFrom} | ${p.sourceName}");
        sb.writeln("  Value: ${p.value}");
        sb.writeln("  Unit: ${p.unitString}");
        result.add(sb.toString());
      }
      return result;
    } catch (e) {
      return ["Deep Dump Error: $e"];
    }
  }
}
