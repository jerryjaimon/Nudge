import 'dart:math' show pow;
import 'package:flutter/material.dart';
import '../utils/gemini_service.dart';
import '../storage.dart';

class PaceZone {
  final String name;
  final int zone;
  final Color color;
  final String description;
  const PaceZone({
    required this.name,
    required this.zone,
    required this.color,
    required this.description,
  });
}

class RunningCoachService {
  /// Scans all cached HC sessions for running sessions (last [days] days).
  static List<Map<String, dynamic>> getRecentRuns({int days = 60}) {
    final stored = (AppStorage.gymBox
            .get('hc_sessions', defaultValue: <dynamic, dynamic>{}) as Map)
        .cast<String, dynamic>();
    final now = DateTime.now();
    final runs = <Map<String, dynamic>>[];

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final iso =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final raw = stored[iso];
      if (raw != null) {
        final daySessions = (raw as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((s) {
              final type = (s['type'] as String? ?? '').toLowerCase();
              if (!type.contains('running')) return false;
              // Filter out short/warmup sessions (< 5 min or < 0.5 km)
              final dur = (s['durationMin'] as num?)?.toDouble() ?? 0.0;
              final dist = (s['distanceKm'] as num?)?.toDouble() ?? 0.0;
              if (dur < 5.0 && dist < 0.5) return false;
              return true;
            })
            .toList();
        runs.addAll(daySessions);
      }
    }

    runs.sort(
        (a, b) => (b['startTime'] as String).compareTo(a['startTime'] as String));
    return runs;
  }

  /// Classify average pace (min/km) into a training zone.
  static PaceZone getPaceZone(double paceMinPerKm) {
    if (paceMinPerKm <= 0 ||
        paceMinPerKm.isInfinite ||
        paceMinPerKm.isNaN) {
      return const PaceZone(
          name: 'Unknown', zone: 0, color: Color(0xFF5A7582), description: 'No pace data');
    }
    if (paceMinPerKm < 4.0) {
      return const PaceZone(
          name: 'Zone 5 · Max Effort',
          zone: 5,
          color: Color(0xFFFF4D6A),
          description: 'VO₂ Max intensity · Race pace · Very hard');
    } else if (paceMinPerKm < 5.0) {
      return const PaceZone(
          name: 'Zone 4 · Threshold',
          zone: 4,
          color: Color(0xFFFF9500),
          description: 'Lactate threshold · Hard sustained effort');
    } else if (paceMinPerKm < 6.0) {
      return const PaceZone(
          name: 'Zone 3 · Tempo',
          zone: 3,
          color: Color(0xFFFFBF00),
          description: 'Comfortably hard · Aerobic power development');
    } else if (paceMinPerKm < 7.0) {
      return const PaceZone(
          name: 'Zone 2 · Aerobic',
          zone: 2,
          color: Color(0xFF39D98A),
          description: 'Conversational pace · Fat oxidation zone');
    } else {
      return const PaceZone(
          name: 'Zone 1 · Recovery',
          zone: 1,
          color: Color(0xFF5AC8FA),
          description: 'Very easy · Active recovery · Restorative');
    }
  }

  /// Compute 7-day training load (AU = arbitrary units based on distance × zone).
  static double computeTrainingLoad(List<Map<String, dynamic>> runs) {
    const multipliers = [0.0, 1.0, 1.5, 2.0, 2.5, 3.0];
    final now = DateTime.now();
    double load = 0;
    for (final run in runs) {
      try {
        final start = DateTime.parse(run['startTime'] as String);
        if (now.difference(start).inDays > 7) continue;
        final dist = (run['distanceKm'] as num?)?.toDouble() ?? 0.0;
        final dur = (run['durationMin'] as num?)?.toDouble() ?? 0.0;
        final pace = dur > 0 && dist > 0 ? dur / dist : 0.0;
        final zone = getPaceZone(pace).zone.clamp(0, 5);
        load += dist * multipliers[zone];
      } catch (_) {}
    }
    return load;
  }

  /// Analyze the run with AI, pulling run history and biometric context.
  static Future<String?> analyzeRun({
    required Map<String, dynamic> session,
    Map<String, dynamic>? runMetrics,
  }) async {
    final sessionDist = (session['distanceKm'] as num?)?.toDouble() ?? 0.0;
    final dur = (session['durationMin'] as num?)?.toInt() ?? 0;
    final calories = (session['calories'] as num?)?.toInt() ?? 0;

    // Use speed-filtered running-only distance when available (excludes warm-up walking)
    final runningDistKm =
        (runMetrics?['runningDistanceKm'] as double?) ?? sessionDist;
    final hasMixed = runMetrics?['hasMixedActivity'] == true;
    final dist = runningDistKm; // effective distance for analysis

    // Use running-only pace from speed data when available
    final rawPace = dur > 0 && sessionDist > 0 ? dur / sessionDist : 0.0;
    final pace = (runMetrics?['avgRunningPaceMinKm'] as double?) ?? rawPace;
    final zone = getPaceZone(pace);

    // Build pace string as MM:SS
    final paceStr = pace > 0
        ? '${pace.floor()}:${((pace % 1) * 60).round().toString().padLeft(2, '0')}'
        : 'N/A';

    // Tag context — filter history to same-tag runs when tagged
    final runTag = getRunTag(session['startTime'] as String? ?? '');
    final allRuns = getRecentRuns(days: 60);
    final validatedPool = getValidatedOrAllRuns(days: 60);
    final historyPool = runTag != null
        ? validatedPool.where((r) => getRunTag(r['startTime'] as String? ?? '') == runTag).toList()
        : validatedPool;
    // Fall back to all validated if same-tag history is too small
    final effectivePool = historyPool.length >= 2 ? historyPool : validatedPool;
    final otherRuns = effectivePool
        .where((r) => r['startTime'] != session['startTime'])
        .take(10)
        .toList();

    // Personal best for similar distance (±30%)
    double? pbPace;
    for (final r in otherRuns) {
      final d = (r['distanceKm'] as num?)?.toDouble() ?? 0.0;
      final m = (r['durationMin'] as num?)?.toDouble() ?? 0.0;
      if (d > 0 && m > 0 && dist > 0 && (d - dist).abs() / dist < 0.3) {
        final p = m / d;
        if (pbPace == null || p < pbPace) pbPace = p;
      }
    }

    // Weekly mileage
    final now = DateTime.now();
    double weeklyKm = dist;
    double monthlyKm = dist;
    for (final r in otherRuns) {
      try {
        final start = DateTime.parse(r['startTime'] as String);
        final d = (r['distanceKm'] as num?)?.toDouble() ?? 0.0;
        if (now.difference(start).inDays <= 7) weeklyKm += d;
        if (now.difference(start).inDays <= 30) monthlyKm += d;
      } catch (_) {}
    }

    final trainingLoad = computeTrainingLoad([session, ...otherRuns]);

    // Format history section
    final historyLines = <String>[];
    for (int i = 0; i < otherRuns.length.clamp(0, 6); i++) {
      final r = otherRuns[i];
      final d = (r['distanceKm'] as num?)?.toDouble() ?? 0.0;
      final m = (r['durationMin'] as num?)?.toDouble() ?? 0.0;
      final p = d > 0 && m > 0 ? m / d : 0.0;
      final pStr = p > 0
          ? '${p.floor()}:${((p % 1) * 60).round().toString().padLeft(2, '0')}'
          : '?';
      final cal = (r['calories'] as num?)?.toInt() ?? 0;
      try {
        final date = DateTime.parse(r['startTime'] as String);
        historyLines.add(
            '  ${i + 1}. ${date.day}/${date.month}: ${d.toStringAsFixed(2)}km @ $pStr/km${cal > 0 ? ' · ${cal}kcal' : ''} [${getPaceZone(p).name.split('·')[0].trim()}]');
      } catch (_) {}
    }

    // Biometrics section
    final bioParts = <String>[];
    if (runMetrics != null) {
      if (runMetrics['avgHrBpm'] != null) {
        final avgHr = (runMetrics['avgHrBpm'] as double).round();
        final peakHr = runMetrics['peakHrBpm'] != null
            ? (runMetrics['peakHrBpm'] as double).round()
            : null;
        bioParts
            .add('- Heart Rate: avg ${avgHr}bpm${peakHr != null ? ' · peak ${peakHr}bpm' : ''}');
      }
      if (runMetrics['estimatedCadenceSpm'] != null) {
        bioParts.add(
            '- Cadence: ${runMetrics['estimatedCadenceSpm']} SPM (optimal 160-180 SPM)');
      }
      if (runMetrics['strideLengthM'] != null) {
        bioParts.add(
            '- Stride Length: ${(runMetrics['strideLengthM'] as double).toStringAsFixed(2)}m');
      }
      if (runMetrics['totalSteps'] != null) {
        bioParts.add('- Total Steps: ${runMetrics['totalSteps']}');
      }
    }

    final efficiencyKcalKm =
        dist > 0 && calories > 0 ? (calories / dist).round() : 0;
    final isPb = pbPace != null && pace > 0 && pace <= pbPace * 1.02;

    final tagLine = runTag != null ? '\n- Activity Type: $runTag' : '';
    final tagHistoryNote = runTag != null && historyPool.length >= 2
        ? 'Comparison pool: ${historyPool.length} "$runTag" sessions (same-category only).'
        : otherRuns.isNotEmpty
            ? 'Comparison pool: all recent runs (no tag set — tag this run to enable category-specific analysis).'
            : '';

    final prompt = """You are an elite athletics coach delivering a precision running performance report. Be surgical, data-driven, and actionable.

THIS SESSION:
- Distance: ${dist.toStringAsFixed(2)} km (running only${hasMixed ? '; session total was ${sessionDist.toStringAsFixed(2)} km incl. walking' : ''})
- Duration: $dur min
- Average Pace: $paceStr /km (running segments only)
- Pace Zone: ${zone.name}
- Zone Context: ${zone.description}
- Calories: ${calories > 0 ? '$calories kcal' : 'N/A'}${efficiencyKcalKm > 0 ? ' ($efficiencyKcalKm kcal/km)' : ''}
- Source: ${session['sourceName'] ?? 'Health Connect'}$tagLine${isPb ? '\n⭐ PERSONAL BEST for this distance range!' : ''}

${bioParts.isNotEmpty ? 'BIOMETRIC DATA:\n${bioParts.join('\n')}' : ''}

TRAINING HISTORY (last 60 days):
- Total sessions: ${allRuns.length}
- Weekly distance: ${weeklyKm.toStringAsFixed(1)} km
- Monthly distance: ${monthlyKm.toStringAsFixed(1)} km
- 7-day training load: ${trainingLoad.toStringAsFixed(0)} AU
${pbPace != null ? '- Personal best pace (similar distance): ${pbPace.floor()}:${((pbPace % 1) * 60).round().toString().padLeft(2, '0')}/km' : '- Personal best: No comparable sessions yet'}
${tagHistoryNote.isNotEmpty ? tagHistoryNote : ''}
${historyLines.isNotEmpty ? 'Last ${historyLines.length} runs:\n${historyLines.join('\n')}' : 'No prior sessions found — first run recorded!'}

COACHING REPORT (markdown format, ## headers, use bullets freely):

## 🏁 Performance Verdict
Sharp 2-3 sentence verdict. Was the effort appropriate for the zone? How does it rank in their history? Is there improvement?

## 📊 Training Analysis
${otherRuns.isNotEmpty ? 'Analyze load trend: is the weekly mileage safe? Are they building aerobic base, peaking, or recovering? Flag any overtraining/undertraining signals.' : 'Baseline session — lay out an 8-week progressive training framework.'}
${bioParts.isNotEmpty ? 'Analyze the biometric data. For cadence: is it in the optimal 160-180 SPM range? Give specific correction.' : ''}

## ⚡ 3 High-Performance Power Moves
Exactly 3 specific, technical cues for THIS runner's data profile:
- **Power Move 1 — Form & Cadence**: [based on their actual SPM and zone]
- **Power Move 2 — Energy Systems**: [fueling strategy, threshold work, or aerobic development for their current load]
- **Power Move 3 — Mental / Tactical**: [pacing strategy or psychological cue for their next key session]

## 🧬 Recovery Protocol
Load score: ${trainingLoad.toStringAsFixed(0)} AU
- 0-2h post-run: [specific immediate action]
- Evening: [specific recovery action]
- Next session: [exact timing + type, e.g. "easy Z2 5km in 48h" or "rest day + mobility"]
${isPb ? '\n⭐ PB Management: Special note on recovery and avoiding back-to-back hard efforts after a personal best.' : ''}

Keep every sentence high-signal. No filler. Short paragraphs. This is elite coaching, not generic advice.
""";

    final response = await GeminiService.generate(prompt: prompt);
    if (response != null) {
      await _saveRunAnalysis(session['startTime'], response);
    }
    return response;
  }

  static Future<void> _saveRunAnalysis(
      String? startTime, String content) async {
    if (startTime == null) return;
    final box = await AppStorage.getGymBox();
    final Map<String, dynamic> analyses =
        (box.get('run_analyses', defaultValue: <String, dynamic>{}) as Map)
            .cast<String, dynamic>();
    analyses[startTime] = {
      'timestamp': DateTime.now().toIso8601String(),
      'content': content,
    };
    await box.put('run_analyses', analyses);
  }

  static String? getSavedAnalysis(String startTime) {
    final Map<String, dynamic> analyses =
        (AppStorage.gymBox.get('run_analyses', defaultValue: <String, dynamic>{}) as Map)
            .cast<String, dynamic>();
    return (analyses[startTime] as Map?)?['content'] as String?;
  }

  // ── Manual distance correction ────────────────────────────────────────────
  static double? getManualDistance(String startTime) {
    final Map<String, dynamic> overrides =
        (AppStorage.gymBox.get('run_distance_overrides', defaultValue: <String, dynamic>{}) as Map)
            .cast<String, dynamic>();
    return (overrides[startTime] as num?)?.toDouble();
  }

  static Future<void> setManualDistance(String startTime, double km) async {
    final box = await AppStorage.getGymBox();
    final Map<String, dynamic> overrides =
        (box.get('run_distance_overrides', defaultValue: <String, dynamic>{}) as Map)
            .cast<String, dynamic>();
    overrides[startTime] = km;
    await box.put('run_distance_overrides', overrides);
  }

  static Future<void> clearManualDistance(String startTime) async {
    final box = await AppStorage.getGymBox();
    final Map<String, dynamic> overrides =
        (box.get('run_distance_overrides', defaultValue: <String, dynamic>{}) as Map)
            .cast<String, dynamic>();
    overrides.remove(startTime);
    await box.put('run_distance_overrides', overrides);
  }

  // ── Manual calorie override ───────────────────────────────────────────────

  static double? getManualCalories(String startTime) {
    final Map<String, dynamic> overrides =
        (AppStorage.gymBox.get('run_calorie_overrides', defaultValue: <String, dynamic>{}) as Map)
            .cast<String, dynamic>();
    return (overrides[startTime] as num?)?.toDouble();
  }

  static Future<void> setManualCalories(String startTime, double kcal) async {
    final box = await AppStorage.getGymBox();
    final Map<String, dynamic> overrides =
        (box.get('run_calorie_overrides', defaultValue: <String, dynamic>{}) as Map)
            .cast<String, dynamic>();
    overrides[startTime] = kcal;
    await box.put('run_calorie_overrides', overrides);
  }

  static Future<void> clearManualCalories(String startTime) async {
    final box = await AppStorage.getGymBox();
    final Map<String, dynamic> overrides =
        (box.get('run_calorie_overrides', defaultValue: <String, dynamic>{}) as Map)
            .cast<String, dynamic>();
    overrides.remove(startTime);
    await box.put('run_calorie_overrides', overrides);
  }

  // ── Run validation (user marks correct runs for AI analysis) ─────────────

  static bool isRunValidated(String startTime) {
    final Map<String, dynamic> flags =
        (AppStorage.gymBox.get('run_validations', defaultValue: <String, dynamic>{}) as Map)
            .cast<String, dynamic>();
    return flags[startTime] == true;
  }

  static Future<void> setRunValidated(String startTime, bool validated) async {
    final box = await AppStorage.getGymBox();
    final Map<String, dynamic> flags =
        (box.get('run_validations', defaultValue: <String, dynamic>{}) as Map)
            .cast<String, dynamic>();
    if (validated) {
      flags[startTime] = true;
    } else {
      flags.remove(startTime);
    }
    await box.put('run_validations', flags);
  }

  /// Returns validated runs, or all runs if none are validated yet (backward compat).
  static List<Map<String, dynamic>> getValidatedOrAllRuns({int days = 60}) {
    final all = getRecentRuns(days: days);
    final validated = all.where((r) => isRunValidated(r['startTime'] as String? ?? '')).toList();
    return validated.isNotEmpty ? validated : all;
  }

  // ── Activity tags ─────────────────────────────────────────────────────────

  /// Predefined activity tags the user can apply to any run.
  static const List<({String label, String emoji, Color color})> activityTags = [
    (label: 'Easy Run',   emoji: '🟢', color: Color(0xFF39D98A)),
    (label: 'Tempo Run',  emoji: '🟡', color: Color(0xFFFFBF00)),
    (label: 'Threshold',  emoji: '🟠', color: Color(0xFFFF9500)),
    (label: 'Intervals',  emoji: '🔴', color: Color(0xFFFF4D6A)),
    (label: 'Long Run',   emoji: '🔵', color: Color(0xFF5AC8FA)),
    (label: 'Race',       emoji: '🏆', color: Color(0xFFFF2D95)),
    (label: 'Trail Run',  emoji: '🌿', color: Color(0xFF6BCB77)),
    (label: 'Walk',       emoji: '🚶', color: Color(0xFF8E8E8E)),
    (label: 'Treadmill',  emoji: '🏃', color: Color(0xFF5AC8FA)),
    (label: 'Recovery',   emoji: '💤', color: Color(0xFF7C4DFF)),
  ];

  static String? getRunTag(String startTime) {
    final Map<String, dynamic> tags =
        (AppStorage.gymBox.get('run_tags', defaultValue: <String, dynamic>{}) as Map)
            .cast<String, dynamic>();
    return tags[startTime] as String?;
  }

  static Future<void> setRunTag(String startTime, String tag) async {
    final box = await AppStorage.getGymBox();
    final Map<String, dynamic> tags =
        (box.get('run_tags', defaultValue: <String, dynamic>{}) as Map)
            .cast<String, dynamic>();
    tags[startTime] = tag;
    await box.put('run_tags', tags);
  }

  static Future<void> clearRunTag(String startTime) async {
    final box = await AppStorage.getGymBox();
    final Map<String, dynamic> tags =
        (box.get('run_tags', defaultValue: <String, dynamic>{}) as Map)
            .cast<String, dynamic>();
    tags.remove(startTime);
    await box.put('run_tags', tags);
  }

  /// Returns runs with the given tag, most-recent first.
  static List<Map<String, dynamic>> getRunsByTag(String tag, {int days = 90}) {
    return getRecentRuns(days: days)
        .where((r) => getRunTag(r['startTime'] as String? ?? '') == tag)
        .toList();
  }

  // ── GPS-tracked sessions ──────────────────────────────────────────────────

  /// Returns all GPS-tracked sessions from Hive, most-recent first.
  static List<Map<String, dynamic>> getGpsSessions({int days = 90}) {
    final raw = (AppStorage.gymBox
            .get('gps_sessions', defaultValue: <dynamic>[]) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (days <= 0) return raw;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return raw.where((s) {
      try {
        return DateTime.parse(s['startTime'] as String).isAfter(cutoff);
      } catch (_) {
        return false;
      }
    }).toList();
  }

  /// Returns a merged list of HC running sessions AND GPS-tracked sessions,
  /// sorted most-recent first. Each entry has a `_source` key: 'HC' or 'GPS'.
  /// GPS entries are normalised to the HC field schema so callers can use them
  /// interchangeably (distanceKm, durationMin, calories, startTime, endTime).
  static List<Map<String, dynamic>> getMergedSessions({int days = 90}) {
    final merged = <Map<String, dynamic>>[];

    // HC sessions
    for (final r in getRecentRuns(days: days)) {
      merged.add({...r, '_source': 'HC'});
    }

    // GPS sessions — normalise fields
    for (final s in getGpsSessions(days: days)) {
      final distM = (s['distanceMeters'] as num?)?.toDouble() ?? 0.0;
      final durSec = (s['durationSeconds'] as num?)?.toInt() ?? 0;
      final startStr = s['startTime'] as String? ?? '';
      // Build endTime if absent
      String endStr = s['endTime'] as String? ?? '';
      if (endStr.isEmpty && startStr.isNotEmpty) {
        try {
          final end = DateTime.parse(startStr).add(Duration(seconds: durSec));
          endStr = end.toIso8601String();
        } catch (_) {}
      }
      merged.add({
        ...s,
        '_source': 'GPS',
        'distanceKm': distM / 1000,
        'durationMin': durSec / 60,
        'startTime': startStr,
        'endTime': endStr,
        'type': 'Running',
        'sourceName': 'GPS Tracker',
      });
    }

    // Deduplicate: remove HC sessions that overlap with a GPS session (±2 min)
    final gpsEntries = merged.where((e) => e['_source'] == 'GPS').toList();
    merged.removeWhere((e) {
      if (e['_source'] != 'HC') return false;
      try {
        final hcStart = DateTime.parse(e['startTime'] as String);
        return gpsEntries.any((g) {
          try {
            final gStart = DateTime.parse(g['startTime'] as String);
            return hcStart.difference(gStart).inMinutes.abs() <= 2;
          } catch (_) {
            return false;
          }
        });
      } catch (_) {
        return false;
      }
    });

    merged.sort((a, b) =>
        (b['startTime'] as String).compareTo(a['startTime'] as String));
    return merged;
  }

  /// Analyze a GPS-tracked activity session with AI coaching.
  static Future<String?> analyzeGpsActivity(
      Map<String, dynamic> session) async {
    final activityLabel = session['activityLabel'] as String? ?? 'Activity';
    final distM = (session['distanceMeters'] as num?)?.toDouble() ?? 0.0;
    final distKm = distM / 1000;
    final durSec = (session['durationSeconds'] as num?)?.toInt() ?? 0;
    final durMin = durSec / 60;
    final avgPace =
        (session['avgPaceMinPerKm'] as num?)?.toDouble() ?? 0.0;
    final avgSpeed = (session['avgSpeedKmh'] as num?)?.toDouble() ?? 0.0;
    final maxSpeed = (session['maxSpeedKmh'] as num?)?.toDouble() ?? 0.0;
    final elevGain = (session['elevationGain'] as num?)?.toDouble() ?? 0.0;
    final calories = (session['calories'] as num?)?.toInt() ?? 0;
    final avgHr = (session['avgHrBpm'] as num?)?.toInt();
    final maxHr = (session['maxHrBpm'] as num?)?.toInt();
    final note = session['note'] as String? ?? '';

    String paceStr = '--';
    if (avgPace > 0 && !avgPace.isInfinite) {
      final min = avgPace.floor();
      final sec = ((avgPace % 1) * 60).round();
      paceStr = "$min'${sec.toString().padLeft(2, '0')}\"";
    }

    // Recent history for context
    final recent = getGpsSessions(days: 60)
        .where((s) =>
            s['startTime'] != session['startTime'] &&
            s['activityType'] == session['activityType'])
        .take(8)
        .toList();

    double weeklyKm = distKm, monthlyKm = distKm;
    final now = DateTime.now();
    for (final s in recent) {
      try {
        final start = DateTime.parse(s['startTime'] as String);
        final d = ((s['distanceMeters'] as num?)?.toDouble() ?? 0.0) / 1000;
        if (now.difference(start).inDays <= 7) weeklyKm += d;
        if (now.difference(start).inDays <= 30) monthlyKm += d;
      } catch (_) {}
    }

    final historyLines = <String>[];
    for (int i = 0; i < recent.length.clamp(0, 6); i++) {
      final s = recent[i];
      final d = ((s['distanceMeters'] as num?)?.toDouble() ?? 0.0) / 1000;
      final sec2 = (s['durationSeconds'] as num?)?.toInt() ?? 0;
      final p = sec2 > 0 && d > 0 ? (sec2 / 60) / d : 0.0;
      final pStr = p > 0
          ? "${p.floor()}'${((p % 1) * 60).round().toString().padLeft(2, '0')}\""
          : '?';
      try {
        final date = DateTime.parse(s['startTime'] as String);
        historyLines.add(
            '  ${i + 1}. ${date.day}/${date.month}: ${d.toStringAsFixed(2)}km @ $pStr/km');
      } catch (_) {}
    }

    final bioParts = <String>[];
    if (avgHr != null) bioParts.add('- Heart Rate: avg ${avgHr}bpm${maxHr != null ? ' · peak ${maxHr}bpm' : ''}');
    if (elevGain > 5) bioParts.add('- Elevation Gain: +${elevGain.toInt()}m');
    if (maxSpeed > 0) bioParts.add('- Max Speed: ${maxSpeed.toStringAsFixed(1)} km/h');

    final prompt = """You are an elite endurance coach. Deliver a precision coaching report for this GPS-tracked activity.

ACTIVITY: $activityLabel
SESSION DATA:
- Distance: ${distKm.toStringAsFixed(2)} km
- Duration: ${durMin.toStringAsFixed(0)} min
- Average Pace: $paceStr /km
- Average Speed: ${avgSpeed.toStringAsFixed(1)} km/h
- Calories: ${calories > 0 ? '$calories kcal' : 'N/A'}
${bioParts.isNotEmpty ? '\nBIOMETRICS:\n${bioParts.join('\n')}' : ''}
${note.isNotEmpty ? '\nATHLETE NOTE: "$note"' : ''}

TRAINING CONTEXT:
- Weekly ${activityLabel.toLowerCase()} distance: ${weeklyKm.toStringAsFixed(1)} km
- Monthly ${activityLabel.toLowerCase()} distance: ${monthlyKm.toStringAsFixed(1)} km
${historyLines.isNotEmpty ? 'Recent sessions:\n${historyLines.join('\n')}' : 'This is their first recorded session.'}

COACHING REPORT (markdown, ## headers):

## Performance Verdict
2-3 sentence assessment. How does this session compare to their history? Was the effort appropriate?

## Training Analysis
${recent.isNotEmpty ? 'Analyze their load trend. Is the weekly volume building safely? Any overtraining or undertraining signals?' : 'First session — lay out a 6-week progressive base-building plan suited to $activityLabel.'}
${bioParts.any((l) => l.contains('Heart Rate')) ? 'Analyze the HR data in context of the pace and distance.' : ''}

## 3 Power Moves
Exactly 3 specific, actionable improvements tailored to this athlete's data:
- **Move 1 — Technique**: [specific form cue for $activityLabel at their current fitness level]
- **Move 2 — Training**: [next session type and target metrics]
- **Move 3 — Recovery**: [specific recovery action with timing]

Keep every sentence high-signal. No filler. Elite coaching only.
""";

    final response = await GeminiService.generate(prompt: prompt);
    if (response != null) {
      await _saveRunAnalysis(session['startTime'] as String?, response);
    }
    return response;
  }

  // ── Personal Records ──────────────────────────────────────────────────────

  /// Returns the effective distance for a session, respecting manual overrides.
  static double _effectiveDist(Map<String, dynamic> s) {
    final override = getManualDistance(s['startTime'] as String? ?? '');
    return override ?? (s['distanceKm'] as num?)?.toDouble() ?? 0.0;
  }

  /// Scans all sessions (up to 365 days) and returns personal bests.
  /// Keys: fastestKmPace, fastest5kPace, fastest10kPace, longestRunKm,
  ///       mostElevationM, sessionCount.
  static Map<String, dynamic> getPersonalRecords() {
    final sessions = getMergedSessions(days: 365);
    double? fastestKmPace;
    double? fastest5kPace;
    double? fastest10kPace;
    double? longestRunKm;
    double? mostElevationM;

    for (final s in sessions) {
      final dist = _effectiveDist(s);
      final dur = (s['durationMin'] as num?)?.toDouble() ?? 0.0;
      if (dist <= 0 || dur <= 0) continue;
      final pace = dur / dist; // min/km — lower = faster

      if (dist >= 1.0 && (fastestKmPace == null || pace < fastestKmPace)) {
        fastestKmPace = pace;
      }
      // 5K window: 4.5–6.5 km
      if (dist >= 4.5 && dist <= 6.5) {
        if (fastest5kPace == null || pace < fastest5kPace) fastest5kPace = pace;
      }
      // 10K window: 9–11.5 km
      if (dist >= 9.0 && dist <= 11.5) {
        if (fastest10kPace == null || pace < fastest10kPace) fastest10kPace = pace;
      }
      if (longestRunKm == null || dist > longestRunKm) longestRunKm = dist;

      // Elevation from GPS sessions
      final elev = (s['elevationGain'] as num?)?.toDouble()
          ?? (s['elevationGainM'] as num?)?.toDouble();
      if (elev != null && (mostElevationM == null || elev > mostElevationM)) {
        mostElevationM = elev;
      }
    }

    return {
      'fastestKmPace': fastestKmPace,
      'fastest5kPace': fastest5kPace,
      'fastest10kPace': fastest10kPace,
      'longestRunKm': longestRunKm,
      'mostElevationM': mostElevationM,
      'sessionCount': sessions.length,
    };
  }

  // ── Weekly distance goal ──────────────────────────────────────────────────

  static double getWeeklyKmGoal() =>
      (AppStorage.settingsBox.get('weekly_km_goal') as num?)?.toDouble() ?? 30.0;

  static void setWeeklyKmGoal(double km) =>
      AppStorage.settingsBox.put('weekly_km_goal', km);

  /// Total km run in the current ISO week (Mon–Sun).
  static double getThisWeekKm() {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    double km = 0;
    for (final s in getMergedSessions(days: 8)) {
      try {
        if (DateTime.parse(s['startTime'] as String).isAfter(weekStart)) {
          km += _effectiveDist(s);
        }
      } catch (_) {}
    }
    return km;
  }

  // ── Running streak ────────────────────────────────────────────────────────

  /// Consecutive days (ending today) with at least one session.
  static int getRunStreak() {
    final sessions = getMergedSessions(days: 365);
    final Set<String> runDays = {};
    for (final s in sessions) {
      try {
        final d = DateTime.parse(s['startTime'] as String);
        runDays.add('${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}');
      } catch (_) {}
    }
    int streak = 0;
    final now = DateTime.now();
    for (int i = 0; i < 365; i++) {
      final d = now.subtract(Duration(days: i));
      final iso = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
      if (runDays.contains(iso)) {
        streak++;
      } else if (i > 0) {
        break; // allow today to be rest day without breaking streak
      }
    }
    return streak;
  }

  // ── Training load trend (ATL / CTL) ──────────────────────────────────────

  /// Returns 7-day acute load, 4-week chronic load (normalised to 7-day), and
  /// the ATL/CTL ratio (>1.3 = overreaching risk, <0.8 = detraining).
  static Map<String, double> getTrainingLoadTrend() {
    final sessions = getMergedSessions(days: 28);
    const multipliers = [0.0, 1.0, 1.5, 2.0, 2.5, 3.0];
    final now = DateTime.now();
    double acute = 0; // 7-day
    double chronic = 0; // 28-day
    for (final s in sessions) {
      try {
        final daysAgo = now.difference(DateTime.parse(s['startTime'] as String)).inDays;
        final dist = _effectiveDist(s);
        final dur = (s['durationMin'] as num?)?.toDouble() ?? 0.0;
        final pace = dist > 0 && dur > 0 ? dur / dist : 0.0;
        final zone = getPaceZone(pace).zone.clamp(0, 5);
        final au = dist * multipliers[zone];
        if (daysAgo < 7) acute += au;
        chronic += au;
      } catch (_) {}
    }
    final chronicNorm = chronic / 28 * 7; // scale to same 7-day window
    return {
      'acute': acute,
      'chronic': chronicNorm,
      'ratio': chronicNorm > 0 ? acute / chronicNorm : 1.0,
    };
  }

  // ── Race predictor (Riegel formula) ──────────────────────────────────────

  static String _fmtMin(double minutes) {
    final h = minutes ~/ 60;
    final m = (minutes % 60).floor();
    final s = ((minutes % 1) * 60).round();
    if (h > 0) return '${h}h ${m}m';
    return '${m}m ${s.toString().padLeft(2,'0')}s';
  }

  /// Given the user's best effort ≥ 3 km, predict race times via T2 = T1 × (d2/d1)^1.06.
  static Map<String, dynamic>? getRacePredictions() {
    double? bestPace;
    Map<String, dynamic>? bestSession;
    for (final s in getMergedSessions(days: 365)) {
      final dist = _effectiveDist(s);
      final dur = (s['durationMin'] as num?)?.toDouble() ?? 0.0;
      if (dist < 3.0 || dur <= 0) continue;
      final pace = dur / dist;
      if (bestPace == null || pace < bestPace) {
        bestPace = pace;
        bestSession = s;
      }
    }
    if (bestSession == null || bestPace == null) return null;
    final baseDist = _effectiveDist(bestSession);
    final baseDur = (bestSession['durationMin'] as num?)?.toDouble() ?? 1.0;

    double predict(double d) => baseDur * pow(d / baseDist, 1.06).toDouble();

    return {
      'baseDist': baseDist,
      'baseDur': baseDur,
      '5k': predict(5.0),
      '10k': predict(10.0),
      'half': predict(21.0975),
      'marathon': predict(42.195),
      '5k_str': _fmtMin(predict(5.0)),
      '10k_str': _fmtMin(predict(10.0)),
      'half_str': _fmtMin(predict(21.0975)),
      'marathon_str': _fmtMin(predict(42.195)),
    };
  }
}
