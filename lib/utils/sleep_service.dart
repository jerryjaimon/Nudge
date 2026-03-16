import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'health_service.dart';
import '../storage.dart';
import 'package:usage_stats/usage_stats.dart';
import 'dart:io';

class SleepSession {
  final DateTime bedTime;
  final DateTime wakeTime;
  final Duration duration;
  final int quality; // 0-100 score
  final String source; // 'inferred' or 'health_connect'
  final List<DateTime> interruptions; // Timestamps of phone usage during sleep
  final double reliabilityScore; // 0.0 - 1.0
  final bool? userValidated; // null = pending, true = confirmed, false = rejected

  SleepSession({
    required this.bedTime,
    required this.wakeTime,
    required this.duration,
    required this.quality,
    this.source = 'inferred',
    this.interruptions = const [],
    this.reliabilityScore = 1.0,
    this.userValidated,
  });

  Map<String, dynamic> toJson() => {
    'bedTime': bedTime.toIso8601String(),
    'wakeTime': wakeTime.toIso8601String(),
    'durationSec': duration.inSeconds,
    'quality': quality,
    'source': source,
    'interruptions': interruptions.map((i) => i.toIso8601String()).toList(),
    'reliabilityScore': reliabilityScore,
    'userValidated': userValidated,
  };

  factory SleepSession.fromJson(Map<String, dynamic> json) => SleepSession(
    bedTime: DateTime.parse(json['bedTime']),
    wakeTime: DateTime.parse(json['wakeTime']),
    duration: Duration(seconds: json['durationSec']),
    quality: json['quality'] ?? 70,
    source: json['source'] ?? 'inferred',
    interruptions: (json['interruptions'] as List? ?? []).map((i) => DateTime.parse(i)).toList(),
    reliabilityScore: (json['reliabilityScore'] as num? ?? 1.0).toDouble(),
    userValidated: json['userValidated'] as bool?,
  );
}

class SleepService {
  static const MethodChannel _channel = MethodChannel('com.example.nudge/pomodoro');

  static Future<int> getNextAlarm() async {
    try {
      final int timestamp = await _channel.invokeMethod('getNextAlarm') ?? 0;
      return timestamp;
    } catch (_) {
      return 0;
    }
  }

  /// Detects periods of phone activity (app opens) during a timeframe.
  static Future<List<DateTime>> detectInterruptions(DateTime start, DateTime end) async {
    if (!Platform.isAndroid) return [];
    try {
      final events = await UsageStats.queryEvents(start, end);
      final interruptions = <DateTime>[];
      DateTime? lastInt;

      for (var event in events) {
        // eventType '1' = MOVE_TO_FOREGROUND
        if (event.eventType != '1') continue;

        final ts = int.tryParse(event.timeStamp ?? '0') ?? 0;
        if (ts == 0) continue;
        final time = DateTime.fromMillisecondsSinceEpoch(ts);

        // Group activity within 5 mins as a single interruption event
        if (lastInt == null || time.difference(lastInt).inMinutes > 5) {
          interruptions.add(time);
          lastInt = time;
        }
      }
      return interruptions;
    } catch (e) {
      print('Interruption detection error: $e');
      return [];
    }
  }

  static Future<SleepSession?> getHealthConnectSleep() async {
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 1));
      
      final List<dynamic> points = await HealthService.fetchRawHealthData(start: start, end: now);
      final sleepPoints = points.where((p) => p.type == HealthDataType.SLEEP_SESSION).toList();

      if (sleepPoints.isEmpty) return null;

      // Take the most recent session
      final last = sleepPoints.last;
      final duration = last.dateTo.difference(last.dateFrom);
      
      // Cross-reference with phone activity
      final interruptions = await detectInterruptions(last.dateFrom, last.dateTo);
      
      // Calculate reliability: deduct for interruptions
      double reliability = 1.0;
      if (interruptions.isNotEmpty) {
        reliability = (1.0 - (interruptions.length * 0.15)).clamp(0.4, 1.0);
      }

      // Calculate scientific score
      int quality = calculateScientificScore(
        duration: duration,
        interruptionsCount: interruptions.length,
      );
      
      // Bonus for HC reliability if no interruptions
      if (interruptions.isEmpty) quality = (quality + 10).clamp(0, 100);

      return SleepSession(
        bedTime: last.dateFrom,
        wakeTime: last.dateTo,
        duration: duration,
        quality: quality,
        source: 'health_connect',
        interruptions: interruptions,
        reliabilityScore: reliability,
      );
    } catch (e) {
      print('HC Sleep Error: $e');
      return null;
    }
  }

  static int calculateScientificScore({required Duration duration, required int interruptionsCount}) {
    int durationScore = 0;
    final hours = duration.inMinutes / 60.0;
    
    // Duration Points (Max 50)
    if (hours >= 7 && hours <= 9) {
      durationScore = 50;
    } else if (hours >= 6 && hours < 7 || hours > 9 && hours <= 10) {
      durationScore = 40;
    } else if (hours >= 5 && hours < 6 || hours > 10 && hours <= 11) {
      durationScore = 25;
    } else {
      durationScore = 10;
    }

    // Continuity Points (Max 50)
    int continuityScore = (50 - (interruptionsCount * 15)).clamp(10, 50);

    return durationScore + continuityScore;
  }

  static Future<SleepSession?> inferLastNightSleep() async {
    if (!Platform.isAndroid) return null;

    final now = DateTime.now();
    final yesterdayEvening = DateTime(now.year, now.month, now.day - 1, 18, 0);
    final todayMorning = DateTime(now.year, now.month, now.day, 12, 0);

    try {
      final events = await UsageStats.queryEvents(yesterdayEvening, todayMorning);
      if (events.isEmpty) return null;

      DateTime? lastUsageBeforeSleep;
      DateTime? firstUsageAfterSleep;

      for (var event in events) {
        final ts = int.tryParse(event.timeStamp ?? '0') ?? 0;
        if (ts == 0) continue;
        final time = DateTime.fromMillisecondsSinceEpoch(ts);

        // Bedtime: Latest event between 6 PM and 4 AM
        if (time.isAfter(yesterdayEvening) && time.isBefore(DateTime(now.year, now.month, now.day, 4, 0))) {
          if (lastUsageBeforeSleep == null || time.isAfter(lastUsageBeforeSleep)) {
            lastUsageBeforeSleep = time;
          }
        }

        // Wake time: Earliest event between 4 AM and 12 PM
        if (time.isAfter(DateTime(now.year, now.month, now.day, 4, 0)) && time.isBefore(todayMorning)) {
          if (firstUsageAfterSleep == null || time.isBefore(firstUsageAfterSleep)) {
            firstUsageAfterSleep = time;
          }
        }
      }

      if (lastUsageBeforeSleep == null || firstUsageAfterSleep == null) return null;
      
      final duration = firstUsageAfterSleep.difference(lastUsageBeforeSleep);
      if (duration.inHours < 2) return null; // Filter out naps

      final interruptions = await detectInterruptions(lastUsageBeforeSleep, firstUsageAfterSleep);
      
      final score = calculateScientificScore(
        duration: duration,
        interruptionsCount: interruptions.length,
      );

      return SleepSession(
        bedTime: lastUsageBeforeSleep,
        wakeTime: firstUsageAfterSleep,
        duration: duration,
        quality: score,
        source: 'inferred',
        interruptions: interruptions,
        reliabilityScore: 0.8, // Inferred is never 1.0
      );
    } catch (e) {
      print('Sleep inference error: $e');
      return null;
    }
  }

  static Future<void> updateSleepWindow(String dayIso, DateTime bed, DateTime wake) async {
    final box = AppStorage.gymBox;
    final List<dynamic> rawHistory = box.get('sleep_history', defaultValue: []);
    final history = rawHistory.map((s) => Map<String, dynamic>.from(s)).toList();

    final idx = history.indexWhere((s) => s['dayIso'] == dayIso);
    if (idx >= 0) {
      final duration = wake.difference(bed);
      final interruptions = await detectInterruptions(bed, wake);
      final score = calculateScientificScore(duration: duration, interruptionsCount: interruptions.length);

      history[idx]['bedTime'] = bed.toIso8601String();
      history[idx]['wakeTime'] = wake.toIso8601String();
      history[idx]['durationSec'] = duration.inSeconds;
      history[idx]['quality'] = score;
      history[idx]['interruptions'] = interruptions.map((i) => i.toIso8601String()).toList();
      history[idx]['userValidated'] = true; // Manual edit counts as validation
      history[idx]['reliabilityScore'] = 1.0;

      await box.put('sleep_history', history);
    }
  }

  static Future<void> syncSleep() async {
    // Priority: Health Connect > Inferred
    SleepSession? session = await getHealthConnectSleep();
    session ??= await inferLastNightSleep();
    
    if (session == null) return;

    final box = AppStorage.gymBox;
    final List<dynamic> rawHistory = box.get('sleep_history', defaultValue: []);
    final history = rawHistory.map((s) => Map<String, dynamic>.from(s)).toList();

    final dayIso = "${session.wakeTime.year}-${session.wakeTime.month.toString().padLeft(2, '0')}-${session.wakeTime.day.toString().padLeft(2, '0')}";
    
    final idx = history.indexWhere((s) => s['dayIso'] == dayIso);
    if (idx >= 0) {
      final existingSource = history[idx]['source'] ?? 'inferred';
      final existingValidated = history[idx]['userValidated'] != null;
      
      // If user already validated, don't overwrite with auto-sync unless it's a major source upgrade
      if (existingValidated && session.source == 'inferred') return;

      if (existingSource == 'inferred' || session.source == 'health_connect') {
        final existingValidated = history[idx]['userValidated'];
        history[idx] = {
          'dayIso': dayIso,
          ...session.toJson(),
        };
        // Preserve user's validation — never overwrite with null from live fetch
        if (existingValidated != null) {
          history[idx]['userValidated'] = existingValidated;
        }
      }
    } else {
      history.add({
        'dayIso': dayIso,
        ...session.toJson(),
      });
    }

    await box.put('sleep_history', history);
  }

  static Future<SleepSession?> getStoredSleep() async {
    final box = AppStorage.gymBox;
    final List<dynamic> rawHistory = box.get('sleep_history', defaultValue: []);
    final history = rawHistory.map((s) => Map<String, dynamic>.from(s)).toList();
    if (history.isEmpty) return null;
    // Most recent entry (last by wakeTime)
    history.sort((a, b) => (a['wakeTime'] as String).compareTo(b['wakeTime'] as String));
    return SleepSession.fromJson(history.last);
  }

  static Future<void> validateSleep(String dayIso, bool confirmed) async {
    final box = AppStorage.gymBox;
    final List<dynamic> rawHistory = box.get('sleep_history', defaultValue: []);
    final history = rawHistory.map((s) => Map<String, dynamic>.from(s)).toList();

    final idx = history.indexWhere((s) => s['dayIso'] == dayIso);
    if (idx >= 0) {
      history[idx]['userValidated'] = confirmed;
      // If rejected, we might want to lower the quality or mark it as unreliable
      if (!confirmed) {
        history[idx]['quality'] = ((history[idx]['quality'] as int? ?? 50) * 0.5).toInt();
        history[idx]['reliabilityScore'] = 0.2;
      } else {
        history[idx]['reliabilityScore'] = 1.0;
      }
      await box.put('sleep_history', history);
    }
  }
}
