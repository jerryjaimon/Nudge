import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../storage.dart';
import '../../utils/pomodoro_service.dart';

enum PomoPhase { work, rest }

class PomodoroState {
  final bool running;
  final bool paused;
  final PomoPhase phase;
  final int workMin;
  final int breakMin;
  final int remainingSec;
  final int totalSec;
  final String projectId;
  final bool sound;

  const PomodoroState({
    required this.running,
    required this.paused,
    required this.phase,
    required this.workMin,
    required this.breakMin,
    required this.remainingSec,
    required this.totalSec,
    required this.projectId,
    required this.sound,
  });

  static PomodoroState initial() => const PomodoroState(
        running: false,
        paused: false,
        phase: PomoPhase.work,
        workMin: 50,
        breakMin: 17,
        remainingSec: 0,
        totalSec: 0,
        projectId: '',
        sound: true,
      );

  PomodoroState copyWith({
    bool? running,
    bool? paused,
    PomoPhase? phase,
    int? workMin,
    int? breakMin,
    int? remainingSec,
    int? totalSec,
    String? projectId,
    bool? sound,
  }) {
    return PomodoroState(
      running: running ?? this.running,
      paused: paused ?? this.paused,
      phase: phase ?? this.phase,
      workMin: workMin ?? this.workMin,
      breakMin: breakMin ?? this.breakMin,
      remainingSec: remainingSec ?? this.remainingSec,
      totalSec: totalSec ?? this.totalSec,
      projectId: projectId ?? this.projectId,
      sound: sound ?? this.sound,
    );
  }
}

class PomodoroEngine {
  PomodoroEngine._();
  static final PomodoroEngine instance = PomodoroEngine._();

  final ValueNotifier<PomodoroState> notifier = ValueNotifier<PomodoroState>(PomodoroState.initial());

  Box? _box;
  bool _loaded = false;
  Timer? _ticker;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _box = await AppStorage.getPomodoroBox();
    _loaded = true;

    final b = _box!;
    final workMin = (b.get('timer_work_min', defaultValue: 50) as int);
    final breakMin = (b.get('timer_break_min', defaultValue: 17) as int);
    final sound = (b.get('timer_sound', defaultValue: true) as bool);
    final pid = (b.get('active_project_id', defaultValue: '') as String);

    notifier.value = notifier.value.copyWith(
      workMin: workMin,
      breakMin: breakMin,
      sound: sound,
      projectId: pid,
    );

    await refreshFromStorage();
    _startTicker();
  }

  void _startTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) async {
      await refreshFromStorage();
    });
  }

  Future<void> setProject(String projectId) async {
    await ensureLoaded();
    notifier.value = notifier.value.copyWith(projectId: projectId);
    await _box!.put('active_project_id', projectId);
  }

  Future<void> setPreset(int work, int rest) async {
    await ensureLoaded();
    if (notifier.value.running) return;
    await _box!.put('timer_work_min', work);
    await _box!.put('timer_break_min', rest);
    notifier.value = notifier.value.copyWith(workMin: work, breakMin: rest);
  }

  Future<void> setSound(bool enabled) async {
    await ensureLoaded();
    if (notifier.value.running) return;
    await _box!.put('timer_sound', enabled);
    notifier.value = notifier.value.copyWith(sound: enabled);
  }

  Future<void> start() async {
    await ensureLoaded();
    final s = notifier.value;
    if (s.running) return;
    if (s.projectId.trim().isEmpty) return;

    final total = s.workMin * 60;
    final endAt = DateTime.now().add(Duration(seconds: total)).toIso8601String();
    final startedAt = DateTime.now().toIso8601String();

    notifier.value = s.copyWith(
      running: true,
      paused: false,
      phase: PomoPhase.work,
      totalSec: total,
      remainingSec: total,
    );

    // Get tracked apps and start blocker
    final tracked = AppStorage.settingsBox.get('tracked_apps', defaultValue: <dynamic>[]) as List;
    final apps = tracked.map((e) => e.toString()).toList();
    if (apps.isNotEmpty) {
      final tone = AppStorage.settingsBox.get('blocker_tone', defaultValue: 'motivating') as String;
      await PomodoroService.startBlocker(apps, tone: tone);
    }

    WakelockPlus.enable();

    await _box!.put('active_session', <String, dynamic>{
      'running': true,
      'paused': false,
      'phase': 'work',
      'workMin': s.workMin,
      'breakMin': s.breakMin,
      'projectId': s.projectId,
      'phaseEndAt': endAt,
      'pausedRemainingSec': null,
      'startedAt': startedAt,
    });
  }

  Future<void> pauseResume() async {
    await ensureLoaded();
    final s = notifier.value;
    if (!s.running) return;

    final session = _box!.get('active_session');
    if (session is! Map) return;
    final m = Map<String, dynamic>.from(session.cast<String, dynamic>());

    if (!s.paused) {
      await refreshFromStorage();
      final fresh = notifier.value;
      notifier.value = fresh.copyWith(paused: true);
      m['paused'] = true;
      m['pausedRemainingSec'] = fresh.remainingSec;
      await _box!.put('active_session', m);
      
      await PomodoroService.stopBlocker();
      WakelockPlus.disable();
      return;
    }

    // resume
    final remaining = s.remainingSec;
    final endAt = DateTime.now().add(Duration(seconds: remaining)).toIso8601String();
    notifier.value = s.copyWith(paused: false);
    m['paused'] = false;
    m['pausedRemainingSec'] = null;
    m['phaseEndAt'] = endAt;
    await _box!.put('active_session', m);

    final tracked = AppStorage.settingsBox.get('tracked_apps', defaultValue: <dynamic>[]) as List;
    final apps = tracked.map((e) => e.toString()).toList();
    if (apps.isNotEmpty) {
      final tone = AppStorage.settingsBox.get('blocker_tone', defaultValue: 'motivating') as String;
      await PomodoroService.startBlocker(apps, tone: tone);
    }
    WakelockPlus.enable();
  }

  Future<int> stop() async {
    await ensureLoaded();
    final s = notifier.value;
    int elapsedMinutes = 0;

    if (s.running && s.phase == PomoPhase.work) {
      final session = _box!.get('active_session');
      if (session is Map) {
        final startedAtStr = session['startedAt'] as String?;
        if (startedAtStr != null) {
          final startedAt = DateTime.parse(startedAtStr);
          final now = DateTime.now();
          // Total seconds since start, minus any time already logged if we implement that, 
          // but here we just take the current session's duration.
          final diff = now.difference(startedAt).inSeconds;
          elapsedMinutes = diff ~/ 60;
        }
      }
    }

    notifier.value = notifier.value.copyWith(
      running: false,
      paused: false,
      phase: PomoPhase.work,
      totalSec: 0,
      remainingSec: 0,
    );
    await _box!.put('active_session', null);
    await PomodoroService.stopBlocker();
    WakelockPlus.disable();
    return elapsedMinutes;
  }

  Future<void> refreshFromStorage() async {
    if (!_loaded) return;

    final session = _box!.get('active_session');
    if (session == null) {
      if (notifier.value.running) {
        notifier.value = notifier.value.copyWith(running: false, paused: false, totalSec: 0, remainingSec: 0);
      }
      return;
    }
    if (session is! Map) return;

    final m = session.cast<String, dynamic>();
    final running = m['running'] == true;
    if (!running) return;

    final paused = m['paused'] == true;
    final phaseStr = (m['phase'] as String?) ?? 'work';
    final phase = (phaseStr == 'rest') ? PomoPhase.rest : PomoPhase.work;

    final workMin = (m['workMin'] is int) ? m['workMin'] as int : notifier.value.workMin;
    final breakMin = (m['breakMin'] is int) ? m['breakMin'] as int : notifier.value.breakMin;
    final projectId = (m['projectId'] as String?) ?? notifier.value.projectId;

    if (paused) {
      final rem = (m['pausedRemainingSec'] is int) ? m['pausedRemainingSec'] as int : notifier.value.remainingSec;
      final total = (phase == PomoPhase.work ? workMin : breakMin) * 60;
      notifier.value = notifier.value.copyWith(
        running: true,
        paused: true,
        phase: phase,
        workMin: workMin,
        breakMin: breakMin,
        projectId: projectId,
        totalSec: total,
        remainingSec: rem.clamp(0, total),
      );
      return;
    }

    // not paused
    final endAtStr = (m['phaseEndAt'] as String?) ?? '';
    if (endAtStr.isEmpty) return;

    DateTime endAt;
    try {
      endAt = DateTime.parse(endAtStr);
    } catch (_) {
      return;
    }

    DateTime now = DateTime.now();
    String phaseMut = phaseStr;
    int completedWorkBlocks = 0;

    // catch up if app was backgrounded
    while (now.isAfter(endAt) || now.isAtSameMomentAs(endAt)) {
      if (phaseMut == 'work') completedWorkBlocks++;

      phaseMut = (phaseMut == 'work') ? 'rest' : 'work';
      final nextSec = ((phaseMut == 'work') ? workMin : breakMin) * 60;
      endAt = endAt.add(Duration(seconds: nextSec));

      if (completedWorkBlocks > 30) break;
    }

    if (completedWorkBlocks > 0) {
      for (int i = 0; i < completedWorkBlocks; i++) {
        await logWorkMinutes(projectId, workMinSetting: workMin, breakMinSetting: breakMin, minutes: workMin);
      }
      if (notifier.value.sound) {
        SystemSound.play(SystemSoundType.alert);
      }
    }

    final newPhase = (phaseMut == 'rest') ? PomoPhase.rest : PomoPhase.work;
    final total = (newPhase == PomoPhase.work ? workMin : breakMin) * 60;
    final remaining = endAt.difference(now).inSeconds.clamp(0, total);

    notifier.value = notifier.value.copyWith(
      running: true,
      paused: false,
      phase: newPhase,
      workMin: workMin,
      breakMin: breakMin,
      projectId: projectId,
      totalSec: total,
      remainingSec: remaining,
    );

    // persist updated phase + endAt (only if changed)
    final newPhaseStr = (phaseMut == 'rest') ? 'rest' : 'work';
    if (newPhaseStr != phaseStr) {
      final patched = Map<String, dynamic>.from(m);
      patched['phase'] = newPhaseStr;
      patched['phaseEndAt'] = endAt.toIso8601String();
      await _box!.put('active_session', patched);
    }
  }

  Future<void> logWorkMinutes(
    String projectId, {
    required int workMinSetting,
    required int breakMinSetting,
    required int minutes,
  }) async {
    final raw = (_box!.get('logs', defaultValue: <dynamic>[]) as List);
    final logs = raw.map((e) => (e as Map).cast<String, dynamic>()).toList();

    logs.insert(0, <String, dynamic>{
      'id': '${DateTime.now().millisecondsSinceEpoch}-${logs.length}',
      'at': DateTime.now().toIso8601String(),
      'kind': 'work',
      'projectId': projectId,
      'minutes': minutes,
      'meta': {
        'workMinSetting': workMinSetting,
        'breakMinSetting': breakMinSetting,
      }
    });

    await _box!.put('logs', logs);
  }
}
