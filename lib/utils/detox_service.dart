import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import '../storage.dart';
import 'pomodoro_service.dart';

class DetoxSchedule {
  final String id;
  final String name;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final List<int> days; // 1 = Monday, 7 = Sunday
  final List<String> blockedApps;
  final bool enabled;

  DetoxSchedule({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.days,
    required this.blockedApps,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startHour': startTime.hour,
    'startMinute': startTime.minute,
    'endHour': endTime.hour,
    'endMinute': endTime.minute,
    'days': days,
    'blockedApps': blockedApps,
    'enabled': enabled,
  };

  factory DetoxSchedule.fromJson(Map<String, dynamic> json) => DetoxSchedule(
    id: json['id'],
    name: json['name'],
    startTime: TimeOfDay(hour: json['startHour'], minute: json['startMinute']),
    endTime: TimeOfDay(hour: json['endHour'], minute: json['endMinute']),
    days: List<int>.from(json['days']),
    blockedApps: List<String>.from(json['blockedApps']),
    enabled: json['enabled'] ?? true,
  );
}

class DetoxService {
  DetoxService._();
  static final DetoxService instance = DetoxService._();

  Timer? _scheduleTimer;
  bool _isCurrentlyBlocking = false;

  Future<void> init() async {
    _startScheduleChecker();
  }

  void _startScheduleChecker() {
    _scheduleTimer?.cancel();
    _scheduleTimer = Timer.periodic(const Duration(seconds: 30), (_) => checkSchedules());
    checkSchedules();
  }

  Future<void> checkSchedules() async {
    final box = AppStorage.settingsBox;
    final List<dynamic> rawSchedules = box.get('detox_schedules', defaultValue: []);
    final schedules = rawSchedules.map((s) => DetoxSchedule.fromJson(Map<String, dynamic>.from(s))).toList();

    final now = DateTime.now();
    final currentDay = now.weekday;
    final currentTime = TimeOfDay.fromDateTime(now);

    List<String> appsToBlock = [];
    bool shouldBlock = false;

    for (var schedule in schedules) {
      if (!schedule.enabled) continue;
      if (!schedule.days.contains(currentDay)) continue;

      if (_isTimeInRange(currentTime, schedule.startTime, schedule.endTime)) {
        shouldBlock = true;
        appsToBlock.addAll(schedule.blockedApps);
      }
    }

    if (shouldBlock) {
      if (!_isCurrentlyBlocking || !listEquals(appsToBlock, _lastBlockedApps)) {
        final tone = box.get('blocker_tone', defaultValue: 'motivating') as String;
        await PomodoroService.startBlocker(appsToBlock.toSet().toList(), tone: tone);
        _isCurrentlyBlocking = true;
        _lastBlockedApps = appsToBlock.toSet().toList();
      }
    } else {
      if (_isCurrentlyBlocking) {
        await PomodoroService.stopBlocker();
        _isCurrentlyBlocking = false;
        _lastBlockedApps = [];
      }
    }
  }

  List<String> _lastBlockedApps = [];

  bool _isTimeInRange(TimeOfDay current, TimeOfDay start, TimeOfDay end) {
    final now = current.hour * 60 + current.minute;
    final s = start.hour * 60 + start.minute;
    final e = end.hour * 60 + end.minute;

    if (s <= e) {
      return now >= s && now <= e;
    } else {
      // Overnight schedule (e.g., 22:00 to 06:00)
      return now >= s || now <= e;
    }
  }

  Future<void> saveSchedule(DetoxSchedule schedule) async {
    final box = AppStorage.settingsBox;
    final List<dynamic> rawSchedules = box.get('detox_schedules', defaultValue: []);
    final schedules = rawSchedules.map((s) => Map<String, dynamic>.from(s)).toList();

    final idx = schedules.indexWhere((s) => s['id'] == schedule.id);
    if (idx >= 0) {
      schedules[idx] = schedule.toJson();
    } else {
      schedules.add(schedule.toJson());
    }

    await box.put('detox_schedules', schedules);
    checkSchedules();
  }

  Future<void> deleteSchedule(String id) async {
    final box = AppStorage.settingsBox;
    final List<dynamic> rawSchedules = box.get('detox_schedules', defaultValue: []);
    final schedules = rawSchedules.where((s) => s['id'] != id).toList();
    await box.put('detox_schedules', schedules);
    checkSchedules();
  }
}

