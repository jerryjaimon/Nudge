import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../storage.dart';
import '../../utils/health_service.dart';
import '../../app.dart' show NudgeTokens;
import 'workout_editor.dart';
import 'profile_sheet.dart';
import 'gym_settings_screen.dart';
import 'gym_chat_screen.dart';
import 'gym_progress_charts.dart';
import 'gym_routines_screen.dart';
import 'exercise_db.dart';
import 'exercise_thumbnail.dart';
import 'muscle_mannequin.dart';
import '../../utils/ai_analysis_service.dart';
import '../../utils/ai_routine_generator.dart';
import '../../utils/pdf_export_service.dart';
import '../health/analysis_report_screen.dart';
import 'package:nudge/utils/nudge_theme_extension.dart';
class GymScreen extends StatefulWidget {
  const GymScreen({super.key});

  @override
  State<GymScreen> createState() => _GymScreenState();
}

class _GymScreenState extends State<GymScreen> with WidgetsBindingObserver {
  Box? _box;
  bool _loading = true;
  double _bodyWeight = 0.0;

  DateTime _day = DateTime.now();
  Map<String, Map<String, double>> _healthDataAll = {};
  Map<String, double> _manualHealthData = {'steps': 0, 'calories': 0, 'distance': 0};
  
  Map<String, double> _healthTotals = {'steps': 0, 'calories': 0, 'distance': 0};

  Map<String, double> get _healthData {
    if (_healthSource == 'manual') return _manualHealthData;
    final sourceData = _healthDataAll[_healthSource] ?? {'steps': 0, 'calories': 0, 'distance': 0};
    // Always use the merged totals for calories, as it includes local Gym workouts not yet sent to Health Connect
    return {
      'steps': sourceData['steps'] ?? 0.0,
      'calories': _healthTotals['calories'] ?? sourceData['calories'] ?? 0.0,
      'distance': sourceData['distance'] ?? 0.0,
    };
  }

  bool _healthLoading = false;

  // Health source: 'health_connect' | 'manual' | 'Aggregated'
  String _healthSource = 'Aggregated';

  // Health Connect workout sessions for the selected day
  List<Map<String, dynamic>> _hcWorkouts = [];
  bool _hcWorkoutsLoading = false;
  bool _generatingRoutine = false;

  // Manual input controllers
  final _stepsCtrl = TextEditingController();
  final _calCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stepsCtrl.dispose();
    _calCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchHealth();
    }
  }

  Future<void> _init() async {
    _box = await AppStorage.getGymBox();
    final savedSource = AppStorage.settingsBox.get('gym_health_source') as String?;
    if (savedSource != null) {
      _healthSource = savedSource;
    } else {
      _healthSource = 'manual';
    }
    _loadWeight();
    await _cleanupWorkouts();
    setState(() => _loading = false);
    _fetchHealth();
    _fetchHcWorkouts();
  }

  Future<void> _cleanupWorkouts() async {
    if (_box == null) return;
    final List<dynamic> raw = _box!.get('workouts', defaultValue: <dynamic>[]);
    if (raw.isEmpty) return;

    final List<Map<String, dynamic>> list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var w in list) {
      final iso = w['dayIso'] as String? ?? 'unknown';
      if (!grouped.containsKey(iso)) grouped[iso] = [];
      grouped[iso]!.add(w);
    }

    bool changed = false;
    final List<Map<String, dynamic>> consolidated = [];

    final keys = grouped.keys.toList();
    for (var iso in keys) {
      final entries = grouped[iso]!;
      if (entries.length > 1 && iso != 'unknown') {
        changed = true;
        // Merge them. Use the newest one (highest updatedAt) as base.
        entries.sort((a, b) => (b['updatedAt'] ?? '').toString().compareTo((a['updatedAt'] ?? '').toString()));
        final base = Map<String, dynamic>.from(entries.first);
        final List<dynamic> mergedExercises = (base['exercises'] as List?)?.toList() ?? [];
        final List<dynamic> mergedCardio = (base['cardio'] as List?)?.toList() ?? [];

        for (int i = 1; i < entries.length; i++) {
          final other = entries[i];
          final otherExercises = other['exercises'] as List? ?? [];
          final otherCardio = other['cardio'] as List? ?? [];
          mergedExercises.addAll(otherExercises);
          mergedCardio.addAll(otherCardio);
        }
        base['exercises'] = mergedExercises;
        base['cardio'] = mergedCardio;
        consolidated.add(base);
      } else {
        consolidated.add(entries.first);
      }
    }

    if (changed) {
      consolidated.sort((a, b) => (b['dayIso'] as String? ?? '').compareTo(a['dayIso'] as String? ?? ''));
      await _box!.put('workouts', consolidated);
    }
  }

  void _loadWeight() {
    final dayIso = _isoDay(_day);
    final weights =
        (_box?.get('daily_weights', defaultValue: <dynamic, dynamic>{}) as Map);
    final entry = weights[dayIso];
    setState(() {
      if (entry is num) {
        _bodyWeight = entry.toDouble();
      } else if (entry is Map) {
        _bodyWeight = (entry['kg'] as num?)?.toDouble() ?? 0.0;
      } else {
        _bodyWeight = 0.0;
      }
    });
  }

  Future<void> _saveWeight(double v) async {
    final dayIso = _isoDay(_day);
    final weights = Map<String, dynamic>.from(
        _box?.get('daily_weights', defaultValue: <dynamic, dynamic>{}) as Map);
    weights[dayIso] = {
      'kg': v,
      'source': 'manual',
      'ts': DateTime.now().toIso8601String(),
    };
    await _box?.put('daily_weights', weights);
    setState(() => _bodyWeight = v);
  }

  DateTime _onlyDay(DateTime d) => DateTime(d.year, d.month, d.day);

  String _isoDay(DateTime d) {
    final dt = _onlyDay(d);
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$mm-$dd';
  }

  bool get _isToday => _isoDay(_day) == _isoDay(DateTime.now());

  Map<String, dynamic> _profile() {
    final b = _box;
    if (b == null) return {'weightKg': 70.0, 'heightCm': 170.0};
    final raw = b.get('profile', defaultValue: <String, dynamic>{});
    return (raw as Map).cast<String, dynamic>();
  }

  int _targetDaysPerWeek() {
    final b = _box;
    if (b == null) return 3;
    final s = b.get('streak_settings');
    if (s is Map) {
      final t = s['targetDaysPerWeek'];
      if (t is int) return t.clamp(1, 7);
      if (t is num) return t.toInt().clamp(1, 7);
    }
    return 3;
  }

  Future<void> _setTargetDaysPerWeek(int v) async {
    final b = _box;
    if (b == null) return;
    final curr = b.get('streak_settings');
    final map = (curr is Map)
        ? Map<String, dynamic>.from(curr.cast<String, dynamic>())
        : <String, dynamic>{};
    map['targetDaysPerWeek'] = v.clamp(1, 7);
    await b.put('streak_settings', map);
  }

  List<Map<String, dynamic>> _workouts() {
    final b = _box;
    if (b == null) return [];
    final raw = (b.get('workouts', defaultValue: <dynamic>[]) as List);
    final list = raw.map((e) => (e as Map).cast<String, dynamic>()).toList();
    list.sort((a, b) =>
        (b['dayIso'] as String? ?? '').compareTo(a['dayIso'] as String? ?? ''));
    return list;
  }

  List<Map<String, dynamic>> _getMergedLogbookEntries() {
    final workoutsList = _workouts();
    final healthHistory = (AppStorage.gymBox
            .get('health_history', defaultValue: <dynamic>[]) as List)
        .cast<Map>();

    final allDays = (healthHistory.map((e) => e['dayIso'] as String).toList() + 
                     workoutsList.map((e) => e['dayIso'] as String).toList()).toSet().toList();
    
    final List<Map<String, dynamic>> merged = [];
    for (var iso in allDays) {
      final h = healthHistory.firstWhere((element) => element['dayIso'] == iso, orElse: () => {});
      final w = workoutsList.firstWhere((element) => element['dayIso'] == iso, orElse: () => {});
      merged.add({
        'dayIso': iso,
        'health': h.isNotEmpty ? h : null,
        'workout': w.isNotEmpty ? w : null,
      });
    }

    merged.sort((a, b) => (b['dayIso'] as String).compareTo(a['dayIso'] as String));
    return merged;
  }

  Map<String, dynamic>? _workoutForDay(String dayIso) {
    for (final w in _workouts()) {
      if ((w['dayIso'] as String?) == dayIso) return w;
    }
    return null;
  }

  Map<String, dynamic> _lastByExercise({required String excludeDayIso}) {
    final list = _workouts();
    final out = <String, dynamic>{};
    for (final w in list) {
      final dayIso = (w['dayIso'] as String?) ?? '';
      if (dayIso.isEmpty || dayIso == excludeDayIso) continue;
      final exercises = ((w['exercises'] as List?) ?? <dynamic>[]);
      for (final exAny in exercises) {
        final ex = (exAny as Map).cast<String, dynamic>();
        final name = (ex['name'] as String?) ?? '';
        if (name.isEmpty || out.containsKey(name)) continue;
        final sets = ((ex['sets'] as List?) ?? <dynamic>[]);
        double best = 0;
        double prevVol = 0;
        int maxR = 0;
        int totalR = 0;
        for (final s in sets) {
          final m = (s as Map);
          final w2 = m['weight'];
          final ww = (w2 is num) ? w2.toDouble() : 0.0;
          if (ww > best) best = ww;
          final rr = m['reps'];
          final repCount = (rr is int) ? rr : (rr is num) ? rr.toInt() : int.tryParse(rr?.toString() ?? '') ?? 0;
          if (repCount > maxR) maxR = repCount;
          totalR += repCount;
          prevVol += repCount * ww;
        }
        out[name] = {
          'dayIso': dayIso,
          'setsText': _setsToText(sets),
          'bestWeight': best,
          'prevVolume': prevVol,
          'maxReps': maxR,
          'totalReps': totalR,
          'sets': sets, // raw list for per-row previous display
        };
      }
      if (out.length > 200) break;
    }
    return out;
  }

  String _setsToText(List sets) {
    final parts = <String>[];
    for (final s in sets) {
      final m = (s as Map).cast<String, dynamic>();
      final reps = (m['reps'] as int?) ?? 0;
      final w = (m['weight'] as num?)?.toDouble() ?? 0.0;
      final wText = w % 1 == 0 ? w.toStringAsFixed(0) : w.toStringAsFixed(1);
      parts.add('${reps}x$wText');
    }
    return parts.join(', ');
  }

  Future<void> _saveWorkouts(List<Map<String, dynamic>> list) async {
    await _box?.put('workouts', list);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _onlyDay(_day),
      firstDate: DateTime(1970, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: const DialogThemeData(
              backgroundColor: NudgeTokens.elevated,
            ),
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  surface: NudgeTokens.elevated,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _day = _onlyDay(picked);
      _hcWorkouts = [];
    });
    _loadWeight();
    _fetchHealth();
    _fetchHcWorkouts();
  }

  Future<void> _fetchHcWorkouts() async {
    final enabled = await HealthService.isEnabled();
    if (!enabled) return;
    if (mounted) setState(() => _hcWorkoutsLoading = true);
    final sessions = await HealthService.fetchWorkoutSessionsForDay(_day);
    if (mounted) {
      setState(() {
        _hcWorkouts = sessions;
        _hcWorkoutsLoading = false;
      });
    }
  }

  Future<void> _fetchHealth() async {
    if (!_isToday) return;
    final enabled = await HealthService.isEnabled();
    if (!enabled) return;
    setState(() => _healthLoading = true);
    
    // Sync recent history first (last 3 days should be enough for quick refresh)
    await HealthService.syncRecentHistory(days: 3);
    
    final data = await HealthService.fetchDailyActivityBySource();
    if (mounted) {
      setState(() {
        _healthDataAll = data['grouped'] as Map<String, Map<String, double>>;
        _healthTotals = (data['totals'] as Map).cast<String, double>();
        _healthLoading = false;
        
        // Auto-select source if manual isn't preferred and we have data
        if (_healthSource != 'manual' && !_healthDataAll.containsKey(_healthSource)) {
           if (_healthDataAll.containsKey('Aggregated')) {
             _healthSource = 'Aggregated';
           } else if (_healthDataAll.isNotEmpty) {
             _healthSource = _healthDataAll.keys.first;
           }
        }
      });
    }
  }

  void _bumpDay(int delta) {
    setState(() {
      _day = _day.add(Duration(days: delta));
      _manualHealthData = {'steps': 0.0, 'calories': 0.0, 'distance': 0.0};
      _healthDataAll = {};
      _hcWorkouts = [];
    });
    _loadWeight();
    _fetchHealth();
    _fetchHcWorkouts();
  }

  Future<void> _setHealthSource(String source) async {
    await AppStorage.settingsBox.put('gym_health_source', source);
    setState(() => _healthSource = source);
    if (source == 'health_connect') _fetchHealth();
  }

  Future<void> _openProfile() async {
    if (_box == null) return;
    final p = _profile();
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NudgeTokens.elevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ProfileSheet(
        weightKg:
            (p['weightKg'] is num) ? (p['weightKg'] as num).toDouble() : 70.0,
        heightCm:
            (p['heightCm'] is num) ? (p['heightCm'] as num).toDouble() : 170.0,
      ),
    );
    if (res == null) return;
    await _box!.put('profile', res);
    setState(() {});
  }

  Future<void> _openSettings() async {
    final target = _targetDaysPerWeek();
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NudgeTokens.elevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => GymSettingsSheet(targetDaysPerWeek: target),
    );
    if (res == null) return;
    final t = res['targetDaysPerWeek'];
    if (t is int) await _setTargetDaysPerWeek(t);
    if (t is num) await _setTargetDaysPerWeek(t.toInt());
    setState(() {});
  }

  int _currentWeeklyStreak() {
    final target = _targetDaysPerWeek();
    final workouts = _workouts();
    final days = <String>{};
    for (final w in workouts) {
      final d = (w['dayIso'] as String?) ?? '';
      if (d.isNotEmpty) days.add(d);
    }

    DateTime startOfWeek(DateTime d) {
      final dt = _onlyDay(d);
      return dt.subtract(Duration(days: dt.weekday - 1));
    }

    bool weekIsComplete(DateTime weekStart) {
      int count = 0;
      for (int i = 0; i < 7; i++) {
        if (days.contains(_isoDay(weekStart.add(Duration(days: i))))) count++;
      }
      return count >= target;
    }

    int streak = 0;
    DateTime cursor = startOfWeek(DateTime.now());
    while (weekIsComplete(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 7));
    }
    return streak;
  }

  List<String> _currentWeekDays() {
    final today = _onlyDay(DateTime.now());
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return List.generate(7, (i) => _isoDay(monday.add(Duration(days: i))));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final dayIso = _isoDay(_day);
    final workout = _workoutForDay(dayIso);
    final streak = _currentWeeklyStreak();
    final target = _targetDaysPerWeek();
    final weekDays = _currentWeekDays();
    final workedDays = _workouts()
        .where((w) => (w['exercises'] as List?)?.isNotEmpty == true)
        .map((w) => w['dayIso'] as String?)
        .toSet();

    // Streak Risk Calculation
    final workedThisWeek = workedDays.where((d) => weekDays.contains(d)).length;
    final neededDays = target - workedThisWeek;
    final availableDays = 8 - DateTime.now().weekday;
    Color riskColor = NudgeTokens.gymB;
    if (neededDays > availableDays) {
      riskColor = const Color(0xFFFF5252); // Red
    } else if (neededDays > 0 && neededDays == availableDays) {
      riskColor = const Color(0xFFFFB74D); // Orange/Yellow
    }

    final hasApiKey = AppStorage.activeGeminiKey.isNotEmpty;
    final lastBy = _lastByExercise(excludeDayIso: dayIso);

    final importedStartTimes = ((workout?['hcSessions'] as List?) ?? [])
        .map((s) => (s as Map)['startTime']?.toString() ?? '')
        .where((t) => t.isNotEmpty)
        .toSet();
    final unimportedHcWorkouts = _hcWorkouts.where((session) {
      final startTime = (session['startTime'] as String?) ?? '';
      if (startTime.isEmpty) return true;
      return !importedStartTimes.contains(startTime);
    }).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          title: Row(
            children: [
              Container(
                width: 3,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: NudgeTokens.gymB,
                ),
              ),
              const SizedBox(width: 10),
              const Text('Gym'),
            ],
          ),
          bottom: const TabBar(
            indicatorColor: NudgeTokens.gymB,
            labelColor: Colors.white,
            unselectedLabelColor: NudgeTokens.textLow,
            tabs: [
              Tab(text: 'Today'),
              Tab(text: 'Weekly'),
              Tab(text: 'Logbook'),
            ],
          ),
          actions: [
            IconButton(
                onPressed: _openSettings,
                icon: const Icon(Icons.tune_rounded)),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                  onPressed: _openProfile,
                  icon: const Icon(Icons.person_outline_rounded)),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
          // Date nav
          _DateNav(
            dayIso: dayIso,
            isToday: _isToday,
            onPrev: () => _bumpDay(-1),
            onNext: () => _bumpDay(1),
            onPick: _pickDate,
          ),
          const SizedBox(height: 12),

          // Compact stats strip (streak + target + week dots + body weight)
          _StatsStrip(
            streak: streak,
            target: target,
            weekDays: weekDays,
            workedDays: workedDays,
            bodyWeight: _bodyWeight,
            riskColor: riskColor,
            onWeightTap: () async {
              final res = await showDialog<String>(
                context: context,
                builder: (ctx) {
                  final ctrl = TextEditingController(
                      text: _bodyWeight > 0 ? _bodyWeight.toString() : '');
                  return AlertDialog(
                    title: const Text('Log Weight'),
                    content: TextField(
                      controller: ctrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: const InputDecoration(suffixText: 'kg'),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, ctrl.text),
                          child: const Text('Save')),
                    ],
                  );
                },
              );
              if (res != null) {
                final v = double.tryParse(res) ?? 0.0;
                _saveWeight(v);
              }
            },
          ),
          const SizedBox(height: 12),

          // Activity card (health source selector + data)
          if (_isToday) ...[
            const _LogbookHeader(title: 'DAILY ACTIVITY', icon: Icons.directions_run_rounded),
            const SizedBox(height: 12),
            _ActivityCard(
              source: _healthSource,
              availableSources: _healthDataAll.keys.toList(),
              healthLoading: _healthLoading,
              healthData: _healthData,
              stepsCtrl: _stepsCtrl,
              calCtrl: _calCtrl,
              onSourceChanged: _setHealthSource,
              onManualSave: () {
                final s = int.tryParse(_stepsCtrl.text) ?? 0;
                final c = int.tryParse(_calCtrl.text) ?? 0;
                setState(() {
                  _manualHealthData = {
                    'steps': s.toDouble(),
                    'calories': c.toDouble(),
                    'distance': 0.0,
                  };
                });
              },
            ),
            const SizedBox(height: 12),
          ],

          // Quick actions row (Gemini + Routines + Progression)
          Row(
            children: [
              Expanded(
                child: _AIChatCard(
                  hasApiKey: hasApiKey,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => GymChatScreen(
                                dayIso: dayIso,
                                onSaved: (res) async {
                                  final workouts = _workouts();
                                  final existingIdx =
                                      workouts.indexWhere((w) => w['dayIso'] == dayIso);

                                  if (existingIdx >= 0) {
                                    final ext = Map<String, dynamic>.from(workouts[existingIdx]);
                                    final exExercises = (ext['exercises'] as List?)?.toList() ?? [];
                                    final exCardio = (ext['cardio'] as List?)?.toList() ?? [];
                                    if (res['exercises'] != null) {
                                      exExercises.addAll((res['exercises'] as List).map((e) => (e as Map).cast<String, dynamic>()).toList());
                                    }
                                    if (res['cardio'] != null) {
                                      exCardio.addAll((res['cardio'] as List).map((e) => (e as Map).cast<String, dynamic>()).toList());
                                    }
                                    ext['exercises'] = exExercises;
                                    ext['cardio'] = exCardio;
                                    ext['updatedAt'] = DateTime.now().toIso8601String();
                                    if (res['note'] != null && res['note'].toString().isNotEmpty) {
                                       final oldNote = (ext['note']?.toString()) ?? '';
                                       ext['note'] = oldNote.isEmpty ? res['note'] : '$oldNote\n${res['note']}';
                                    }
                                    workouts[existingIdx] = ext;
                                  } else {
                                    workouts.insert(0, {
                                      'id': '${DateTime.now().millisecondsSinceEpoch}',
                                      'dayIso': dayIso,
                                      'createdAt': DateTime.now().toIso8601String(),
                                      'updatedAt': DateTime.now().toIso8601String(),
                                      ...res,
                                    });
                                  }
                                  await _saveWorkouts(workouts);
                                  if (mounted) setState(() {});
                                },
                          )),
                    );
                    if (mounted) setState(() {});
                  },
                  onSetupSettings: _openSettings,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionTile(
                  label: 'Routines',
                  icon: Icons.auto_awesome_motion_rounded,
                  onTap: () async {
                    final res = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const GymRoutinesScreen()));
                    if (res is Map<String, dynamic>) {
                      final routineExercises =
                          (res['exercises'] as List).map((e) => {
                                'name': e,
                                'sets': [
                                  {'reps': 8, 'weight': 0.0}
                                ]
                              }).toList();
                      final workouts = _workouts();
                      final idx = workouts.indexWhere((w) => w['dayIso'] == dayIso);
                      if (idx >= 0) {
                        final existing = Map<String, dynamic>.from(workouts[idx]);
                        final exList = (existing['exercises'] as List?)?.toList() ?? [];
                        exList.addAll(routineExercises);
                        existing['exercises'] = exList;
                        existing['updatedAt'] = DateTime.now().toIso8601String();
                        workouts[idx] = existing;
                      } else {
                        workouts.insert(0, {
                          'id': '${DateTime.now().millisecondsSinceEpoch}',
                          'dayIso': dayIso,
                          'exercises': routineExercises,
                          'cardio': [],
                          'createdAt': DateTime.now().toIso8601String(),
                          'updatedAt': DateTime.now().toIso8601String(),
                        });
                      }
                      await _saveWorkouts(workouts);
                      setState(() {});
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionTile(
                  label: 'Progression',
                  icon: Icons.trending_up_rounded,
                  onTap: () {
                    final exerciseList = <String>{};
                    for (final w in _workouts()) {
                      for (final ex in (w['exercises'] as List? ?? [])) {
                        exerciseList.add(ex['name'] as String);
                      }
                    }
                    if (exerciseList.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('No exercises logged yet.')));
                      return;
                    }
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: NudgeTokens.card,
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(28))),
                      builder: (ctx) => ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          Text('Choose Exercise',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 16),
                          ...exerciseList.map((name) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: NudgeTokens.textLow),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: NudgeTokens.card,
                                    shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(28))),
                                    builder: (_) => GymProgressCharts(
                                        workouts: _workouts(),
                                        exerciseName: name),
                                  );
                                },
                              )),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Health Connect sessions for this day
          if (_hcWorkoutsLoading || unimportedHcWorkouts.isNotEmpty) ...[
            _HCWorkoutsSection(
              sessions: unimportedHcWorkouts,
              loading: _hcWorkoutsLoading,
              onImport: (session) => _showHcImportDialog(session, dayIso),
            ),
            const SizedBox(height: 20),
          ],

          // Muscle group weekly summary
          _MuscleGroupWeeklySummary(workouts: _workouts(), weekDays: weekDays),
          const SizedBox(height: 20),

          // Logbook
          Row(
            children: [
              const Icon(Icons.fitness_center_rounded, size: 14, color: NudgeTokens.textLow),
              const SizedBox(width: 8),
              const Text(
                'GYM SESSIONS',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  color: NudgeTokens.textLow,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (workout != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: NudgeTokens.gymB.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_dayCalories(workout).toStringAsFixed(0)} kcal',
                    style: const TextStyle(
                      color: NudgeTokens.gymB,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (workout == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: NudgeTokens.gymB.withValues(alpha: 0.08),
                      ),
                      child: const Icon(Icons.fitness_center_rounded, size: 28, color: NudgeTokens.gymB),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No workout logged',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: NudgeTokens.textMid),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap Log Workout, chat with Gemini, or Auto-Generate.',
                      style: TextStyle(fontSize: 12, color: NudgeTokens.textLow),
                    ),
                    const SizedBox(height: 24),
                    if (hasApiKey)
                      _generatingRoutine
                          ? const CircularProgressIndicator(color: NudgeTokens.purple)
                          : FilledButton.icon(
                              onPressed: () => _generateDailyRoutine(dayIso, lastBy),
                              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                              label: const Text('Generate Routine', style: TextStyle(fontWeight: FontWeight.w800)),
                              style: FilledButton.styleFrom(
                                backgroundColor: NudgeTokens.purple.withValues(alpha: 0.2),
                                foregroundColor: NudgeTokens.purple,
                              ),
                            ),
                  ],
                ),
              ),
            )
          else
            _WorkoutPreview(
              workout: workout,
              lastByExercise: lastBy,
              onEditHcSession: (hcIdx, updated) => _saveHcSessionEdit(dayIso, hcIdx, updated),
            ),
        ],
      ),
      _buildWeeklyInsights(weekDays, streak, target),
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        child: _buildLogbookList(),
      ),
    ],
  ),
  floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20, right: 4),
        child: FloatingActionButton.extended(
          backgroundColor: NudgeTokens.gymB,
          foregroundColor: const Color(0xFF0A1500),
          onPressed: () async {
            if (_box == null) return;
            final existing = _workoutForDay(dayIso);
            final res = await Navigator.of(context)
                .push<Map<String, dynamic>>(MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => WorkoutEditorPage(
                dayIso: dayIso,
                initialWorkout: existing,
                lastByExercise: lastBy,
              ),
            ));
            if (res == null) return;
            await _handleEditorResult(res);
          },
          label: Text(
            workout == null ? 'Log Workout' : 'Edit Workout',
            style: const TextStyle(
                fontWeight: FontWeight.w800, letterSpacing: 0.3),
          ),
          icon: Icon(
              workout == null ? Icons.add_rounded : Icons.edit_rounded,
              size: 20),
        ),
      ),
    ),
  );
}

  // ── AI Generate Routine Handler ──────────────────────────────────────────
  Future<void> _generateDailyRoutine(String dayIso, Map<String, dynamic> lastBy) async {
    setState(() => _generatingRoutine = true);
    final data = await AiRoutineGenerator.generateDailyRoutine(dayIso);
    setState(() => _generatingRoutine = false);
    
    if (data != null && mounted) {
      final newWorkout = {
        'id': '${DateTime.now().millisecondsSinceEpoch}',
        'dayIso': dayIso,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        ...data,
      };

      final res = await Navigator.of(context).push<Map<String, dynamic>>(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => WorkoutEditorPage(
          dayIso: dayIso,
          initialWorkout: newWorkout,
          lastByExercise: lastBy,
        ),
      ));
      if (res != null) {
        await _handleEditorResult(res);
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate routine. Check your AI key or try again.')),
      );
    }
  }

  // ── Shared workout editor result handler ─────────────────────────────────
  Future<void> _handleEditorResult(Map<String, dynamic> res) async {
    final action = (res['__action'] as String?) ?? 'save';
    final list = _workouts();

    if (action == 'delete') {
      final id = res['id']?.toString();
      if (id == null) return;
      list.removeWhere((w) => w['id']?.toString() == id);
      await _saveWorkouts(list);
      if (mounted) setState(() {});
      return;
    }

    final cleaned = Map<String, dynamic>.from(res)..remove('__action');
    final id = cleaned['id']?.toString();
    if (id == null) return;

    final idx = list.indexWhere((w) => w['id']?.toString() == id);
    if (idx >= 0) {
      list[idx] = cleaned;
    } else {
      list.insert(0, cleaned);
    }
    await _saveWorkouts(list);
    if (mounted) setState(() {});
  }

  // ── HC Session Edit ───────────────────────────────────────────────────────
  Future<void> _saveHcSessionEdit(String dayIso, int hcIdx, Map<String, dynamic> updated) async {
    final workouts = _workouts();
    final idx = workouts.indexWhere((w) => w['dayIso'] == dayIso);
    if (idx < 0) return;
    final w = Map<String, dynamic>.from(workouts[idx]);
    final sessions = (w['hcSessions'] as List?)?.toList() ?? [];
    if (hcIdx >= sessions.length) return;
    sessions[hcIdx] = updated;
    // Recalculate total calories from all hcSessions
    w['hcSessions'] = sessions;
    w['calories'] = sessions.fold<int>(0, (sum, s) => sum + ((s as Map)['calories'] as num? ?? 0).toInt());
    w['updatedAt'] = DateTime.now().toIso8601String();
    workouts[idx] = w;
    await _saveWorkouts(workouts);
    if (mounted) setState(() {});
  }

  // ── HC Import Dialog ─────────────────────────────────────────────────────
  Future<void> _showHcImportDialog(Map<String, dynamic> session, String dayIso) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NudgeTokens.elevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _HcImportChoiceSheet(session: session),
    );
    if (chosen == null || !mounted) return;

    final hcPayload = _buildHcInitialWorkout(dayIso, session, chosenType: chosen);
    final existing = _workoutForDay(dayIso);

    Map<String, dynamic> finalWorkout;
    if (existing != null) {
      finalWorkout = Map<String, dynamic>.from(existing);

      final exCardio = (finalWorkout['cardio'] as List?)?.toList() ?? [];
      if ((hcPayload['cardio'] as List?)?.isNotEmpty == true) {
        exCardio.addAll(hcPayload['cardio'] as List);
      }
      finalWorkout['cardio'] = exCardio;

      final exHcSessions = (finalWorkout['hcSessions'] as List?)?.toList() ?? [];
      if ((hcPayload['hcSessions'] as List?)?.isNotEmpty == true) {
        exHcSessions.addAll(hcPayload['hcSessions'] as List);
      }
      finalWorkout['hcSessions'] = exHcSessions;

      final isWalking = chosen.toLowerCase().contains('walk');
      final oldCal = (finalWorkout['calories'] as num?)?.toInt() ?? 0;
      final newCal = isWalking ? 0 : ((hcPayload['calories'] as num?)?.toInt() ?? 0);
      finalWorkout['calories'] = oldCal + newCal;
      finalWorkout['updatedAt'] = DateTime.now().toIso8601String();
    } else {
      finalWorkout = hcPayload;
      if (chosen.toLowerCase().contains('walk')) finalWorkout['calories'] = 0;
    }

    await _handleEditorResult({'__action': 'save', ...finalWorkout});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$chosen session imported.')),
      );
    }
  }

  // ── HC session helpers ────────────────────────────────────────────────────
  String _cleanHealthConnectSource(String source) {
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

  Map<String, dynamic> _buildHcInitialWorkout(String dayIso, Map<String, dynamic> session, {String? chosenType}) {
    final type = chosenType ?? (session['type'] as String?) ?? 'Workout';
    final durationMin = (session['durationMin'] as int?) ?? 0;
    final calories = (session['calories'] as int?) ?? 0;
    final distanceKm = (session['distanceKm'] as double?) ?? 0.0;
    final source = _cleanHealthConnectSource((session['sourceName'] as String?) ?? 'Health Connect');

    final hcSession = <String, dynamic>{
      'type': type,
      'durationMin': durationMin,
      'calories': calories,
      'distanceKm': distanceKm,
      'source': source,
      'startTime': session['startTime'] as String? ?? '',
    };

    return {
      'id': '${DateTime.now().millisecondsSinceEpoch}',
      'dayIso': dayIso,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'exercises': <dynamic>[],
      'cardio': <dynamic>[],
      'hcSessions': [hcSession],
      'calories': calories,
      'source': 'health_connect',
    };
  }

  double _dayCalories(Map<String, dynamic>? workout) {
    if (workout == null) return 0;
    final c = workout['calories'];
    return (c is num) ? c.toDouble() : 0;
  }

  Widget _buildWeeklyInsights(List<String> weekDays, int streak, int target) {

    // We'll calculate total workouts and sets for this week
    final allWorkouts = _workouts();
    final thisWeekWorkouts = allWorkouts.where((w) => weekDays.contains(w['dayIso'])).toList();
    
    int totalSetsThisWeek = 0;
    final muscleGroups = <String>{};

    for (var w in thisWeekWorkouts) {
      List exercises = (w['exercises'] as List?) ?? [];
      for (var ex in exercises) {
        totalSetsThisWeek += ((ex['sets'] as List?) ?? []).length;
        
        final name = (ex['name'] as String?) ?? '';
        for (final entry in ExerciseDB.categories.entries) {
          if (entry.value.contains(name)) {
            muscleGroups.add(entry.key);
            break;
          }
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildWeeklyAiHero(),
        const SizedBox(height: 16),
        if (muscleGroups.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MuscleMapDuo(activeMuscles: muscleGroups, height: 160),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: muscleGroups.map((g) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: NudgeTokens.gymB.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: NudgeTokens.gymB.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        g.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: NudgeTokens.gymB,
                          letterSpacing: 1.2,
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: NudgeTokens.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: NudgeTokens.border),
          ),
          child: Column(
            children: [
              Text(
                'This Week',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn('Workouts', '${thisWeekWorkouts.length}', NudgeTokens.gymB),
                  _buildStatColumn('Sets', '$totalSetsThisWeek', NudgeTokens.amber),
                  _buildStatColumn('Streak', '$streak wks', NudgeTokens.green),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: NudgeTokens.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: NudgeTokens.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Activity Volume',

                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: weekDays.map((iso) {
                  final dayName = _getDayName(iso);
                  final w = thisWeekWorkouts.firstWhere((element) => element['dayIso'] == iso, orElse: () => {});
                  int sets = 0;
                  if (w.isNotEmpty) {
                    List exList = (w['exercises'] as List?) ?? [];
                    sets = exList.fold(0, (sum, ex) => sum + ((ex['sets'] as List?) ?? []).length);
                  }
                  
                  // Max height 100
                  double height = sets.toDouble() * 3.0; // scale factor
                  if (height > 100) height = 100;
                  if (height < 4) height = 4; // minimum height
                  
                  final isToday = iso == _isoDay(DateTime.now());

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sets > 0)
                        Text('$sets', style: const TextStyle(fontSize: 10, color: NudgeTokens.textLow)),
                      const SizedBox(height: 4),
                      Container(
                        width: 20,
                        height: height,
                        decoration: BoxDecoration(
                          color: sets > 0 ? NudgeTokens.gymB : NudgeTokens.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                          color: isToday ? NudgeTokens.gymB : NudgeTokens.textLow,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogbookList() {
    final entries = _getMergedLogbookEntries();
    if (entries.isEmpty) return const SizedBox();

    final sessions = entries.where((e) => e['workout'] != null).toList();
    final daily = entries.where((e) => e['health'] != null).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Row(
          children: [
            Text(
              'Logbook',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh),
              ),
            ),
            const Spacer(),
            _ExportButton(onTap: () => PdfExportService.exportProgress()),
          ],
        ),
        
        if (sessions.isNotEmpty) ...[
          const SizedBox(height: 24),
          _LogbookHeader(title: 'GYM SESSIONS', icon: Icons.fitness_center_rounded),
          const SizedBox(height: 12),
          ...sessions.map((e) => _LogbookCard(entry: e, isWorkout: true, onTap: (d) => setState(() { _day = d; DefaultTabController.of(context).animateTo(0); }))),
        ],

        if (daily.isNotEmpty) ...[
          const SizedBox(height: 32),
          _LogbookHeader(title: 'DAILY ACTIVITY', icon: Icons.bolt_rounded),
          const SizedBox(height: 12),
          ...daily.map((e) => _LogbookCard(entry: e, isWorkout: false, onTap: (d) => setState(() { _day = d; DefaultTabController.of(context).animateTo(0); }))),
        ],
        const SizedBox(height: 40),
      ],
    );
  }


  String _getDayName(String iso) {
    try {
      final str = DateTime.parse(iso);
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return names[str.weekday - 1];
    } catch(e) {
      return '?';
    }
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: NudgeTokens.textLow, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildWeeklyAiHero() {
    final reports = AiAnalysisService.getSavedReports();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [NudgeTokens.purple.withValues(alpha: 0.2), NudgeTokens.purple.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NudgeTokens.purple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: NudgeTokens.purple, size: 20),
              const SizedBox(width: 10),
              Text('AI Health Coach', style: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh), fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Get a detailed analysis of your weekly performance compared to your goals.', style: TextStyle(color: NudgeTokens.textMid, fontSize: 12, height: 1.4)),
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton(
                onPressed: () async {
                  final notes = await showDialog<String>(
                    context: context,
                    builder: (ctx) {
                      final ctrl = TextEditingController();
                      return AlertDialog(
                        backgroundColor: NudgeTokens.card,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        title: Text('Add Weekly Notes', style: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh), fontSize: 18, fontWeight: FontWeight.w800)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Is there anything specific you need the AI to note for this report?', style: TextStyle(color: NudgeTokens.textMid, fontSize: 13, height: 1.4)),
                            const SizedBox(height: 16),
                            TextField(
                              controller: ctrl,
                              maxLines: 4,
                              style: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh), fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'e.g. Had a minor injury, felt very energetic, etc.',
                                hintStyle: const TextStyle(color: NudgeTokens.textLow, fontSize: 14),
                                filled: true,
                                fillColor: NudgeTokens.elevated,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, ""), child: const Text('Skip', style: TextStyle(color: NudgeTokens.textLow))),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, ctrl.text),
                            style: FilledButton.styleFrom(backgroundColor: NudgeTokens.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: const Text('Generate'),
                          ),
                        ],
                      );
                    }
                  );

                  if (notes == null) return;
                  if (!mounted) return;

                  final nav = Navigator.of(context);
                  showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: NudgeTokens.purple)));
                  try {
                    final report = await AiAnalysisService.generateWeeklyReport(userNotes: notes.isEmpty ? null : notes);
                    nav.pop(); // Close loading
                    if (report != null) {
                      nav.push(MaterialPageRoute(builder: (_) => AnalysisReportScreen(content: report, timestamp: DateTime.now().toIso8601String())));
                    }
                  } catch (e) {
                    if (mounted) nav.pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: NudgeTokens.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Generate Report', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
              const SizedBox(width: 12),
              if (reports.isNotEmpty)
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => AnalysisReportScreen(content: reports.first['content'], timestamp: reports.first['timestamp'])));
                  },
                  child: const Text('View Last Report', style: TextStyle(color: NudgeTokens.purple, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date Nav
// ─────────────────────────────────────────────────────────────────────────────

class _DateNav extends StatelessWidget {
  final String dayIso;
  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;

  const _DateNav({
    required this.dayIso,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(dayIso);
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final label = '${dayNames[date.weekday - 1]}, ${monthNames[date.month - 1]} ${date.day}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: NudgeTokens.card,
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Row(
        children: [
          _NavBtn(icon: Icons.chevron_left_rounded, onTap: onPrev),
          Expanded(
            child: GestureDetector(
              onTap: onPick,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh),
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: NudgeTokens.gymB.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: NudgeTokens.gymB.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        'TODAY',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: NudgeTokens.gymB,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          _NavBtn(icon: Icons.chevron_right_rounded, onTap: onNext),
        ],
      ),
    );
  }
}


class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Icon(icon, size: 22, color: NudgeTokens.textMid),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats Strip (replaces two separate metric cards)
// ─────────────────────────────────────────────────────────────────────────────

class _StatsStrip extends StatelessWidget {
  final int streak;
  final int target;
  final List<String> weekDays;
  final Set<String?> workedDays;
  final double bodyWeight;
  final Color riskColor;
  final VoidCallback onWeightTap;

  const _StatsStrip({
    required this.streak,
    required this.target,
    required this.weekDays,
    required this.workedDays,
    required this.bodyWeight,
    required this.riskColor,
    required this.onWeightTap,
  });

  @override
  Widget build(BuildContext context) {
    const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final todayIso = () {
      final d = DateTime.now();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }();

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: NudgeTokens.card,
              border: Border.all(color: NudgeTokens.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (i) {
                final iso = weekDays[i];
                final isToday = iso == todayIso;
                final isWorked = workedDays.contains(iso);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dayLetters[i],
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: NudgeTokens.textLow,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isWorked
                            ? riskColor
                            : (isToday ? riskColor.withValues(alpha: 0.1) : Colors.transparent),
                        border: Border.all(
                          color: isToday && !isWorked ? riskColor.withValues(alpha: 0.3) : Colors.transparent,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: isWorked ? Colors.white : Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onWeightTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: NudgeTokens.card,
              border: Border.all(color: NudgeTokens.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(Icons.scale_rounded, size: 14, color: NudgeTokens.textMid),
                    SizedBox(width: 4),
                    Text(
                      'Weight',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: NudgeTokens.textMid,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  bodyWeight > 0
                      ? '${bodyWeight % 1 == 0 ? bodyWeight.toStringAsFixed(0) : bodyWeight.toStringAsFixed(1)} kg'
                      : '--',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh),
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity Card
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  final String source;
  final List<String> availableSources;
  final bool healthLoading;
  final Map<String, double> healthData;
  final TextEditingController stepsCtrl;
  final TextEditingController calCtrl;
  final ValueChanged<String> onSourceChanged;
  final VoidCallback onManualSave;

  const _ActivityCard({
    required this.source,
    required this.availableSources,
    required this.healthLoading,
    required this.healthData,
    required this.stepsCtrl,
    required this.calCtrl,
    required this.onSourceChanged,
    required this.onManualSave,
  });

  @override
  Widget build(BuildContext context) {
    final steps = healthData['steps']?.toInt() ?? 0;
    final calories = healthData['calories']?.toInt() ?? 0;
    final hasData = steps > 0 || calories > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: NudgeTokens.card,
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'ACTIVITY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: NudgeTokens.textLow,
                  letterSpacing: 1.5,
                ),
              ),
              if (healthLoading) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: NudgeTokens.textLow),
                ),
              ],
              const Spacer(),
              _SourceToggle(
                value: source, 
                sources: availableSources,
                onChanged: onSourceChanged
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (source != 'manual') ...[
            if (!hasData && !healthLoading)
               Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No data received today.\nCheck Health Connect settings.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: NudgeTokens.textLow),
                    ),
                  ),
               )
            else
              Row(
                children: [
                  Expanded(
                    child: _MiniMetric(
                      icon: Icons.directions_walk_rounded,
                      color: NudgeTokens.green,
                      value: steps.toString(),
                      label: 'Walking',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniMetric(
                      icon: Icons.local_fire_department_rounded,
                      color: NudgeTokens.amber,
                      value: calories.toString(),
                      label: 'Calories',
                    ),
                  ),
                ],
              ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: stepsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Steps', isDense: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: calCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Calories', isDense: true),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: onManualSave,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Set'),
                ),
              ],
            ),
            if (hasData) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  _MiniMetric(
                    icon: Icons.directions_walk_rounded,
                    color: NudgeTokens.green,
                    value: steps.toString(),
                    label: 'Steps',
                  ),
                  const SizedBox(width: 12),
                  _MiniMetric(
                    icon: Icons.local_fire_department_rounded,
                    color: NudgeTokens.amber,
                    value: calories.toString(),
                    label: 'Calories',
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SourceToggle extends StatelessWidget {
  final String value;
  final List<String> sources;
  final ValueChanged<String> onChanged;
  const _SourceToggle({required this.value, required this.sources, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      color: NudgeTokens.elevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (ctx) => [
        PopupMenuItem(value: 'manual', child: Text('Manual Input', style: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh)))),
        ...sources.map((s) => PopupMenuItem(value: s, child: Text(s == 'Aggregated' ? 'All Health Connect' : HealthService.cleanSource(s), style: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh))))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: value != 'manual' ? NudgeTokens.gymB.withValues(alpha: 0.15) : NudgeTokens.elevated,
          border: Border.all(color: NudgeTokens.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value == 'manual' ? 'Manual' : (value == 'Aggregated' ? 'Aggregated' : (value.length > 12 ? '${value.substring(0, 10)}...' : value)),
              style: TextStyle(
                fontSize: 11, 
                fontWeight: FontWeight.w700, 
                color: value != 'manual' ? NudgeTokens.gymB : NudgeTokens.textMid,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded, size: 14, color: value != 'manual' ? NudgeTokens.gymB : NudgeTokens.textMid),
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _MiniMetric(
      {required this.icon,
      required this.color,
      required this.value,
      required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            color: color.withValues(alpha: 0.1),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh)),
            ),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: NudgeTokens.textLow),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Chat Card
// ─────────────────────────────────────────────────────────────────────────────

class _AIChatCard extends StatelessWidget {
  final bool hasApiKey;
  final VoidCallback onTap;
  final VoidCallback onSetupSettings;

  const _AIChatCard(
      {required this.hasApiKey,
      required this.onTap,
      required this.onSetupSettings});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: hasApiKey ? onTap : onSetupSettings,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFF7C4DFF), Color(0xFF5C6BC0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  hasApiKey ? Icons.auto_awesome_rounded : Icons.settings_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hasApiKey ? 'Gemini' : 'Setup AI',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action Tile
// ─────────────────────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionTile(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NudgeTokens.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: NudgeTokens.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: NudgeTokens.gymB.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: NudgeTokens.gymB),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: NudgeTokens.textMid,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Workout Preview (Bevel-like per-exercise cards with trend)
// ─────────────────────────────────────────────────────────────────────────────

class _WorkoutPreview extends StatelessWidget {
  final Map<String, dynamic> workout;
  final Map<String, dynamic> lastByExercise;
  final void Function(int hcIdx, Map<String, dynamic> updated)? onEditHcSession;

  const _WorkoutPreview({
    required this.workout,
    required this.lastByExercise,
    this.onEditHcSession,
  });

  double _bestWeight(List sets) {
    double best = 0;
    for (final s in sets) {
      final w = (s as Map)['weight'];
      final ww = (w is num) ? w.toDouble() : 0.0;
      if (ww > best) best = ww;
    }
    return best;
  }

  double _totalVolume(List sets) {
    double vol = 0;
    for (final s in sets) {
      final m = s as Map;
      final rr = m['reps'];
      final reps = (rr is int) ? rr : (rr is num) ? rr.toInt() : int.tryParse(rr?.toString() ?? '') ?? 0;
      final w = (m['weight'] is num) ? (m['weight'] as num).toDouble() : 0.0;
      vol += reps * w;
    }
    return vol;
  }

  int _maxReps(List sets) {
    int max = 0;
    for (final s in sets) {
      final m = s as Map;
      final rr = m['reps'];
      final reps = (rr is int) ? rr : (rr is num) ? rr.toInt() : int.tryParse(rr?.toString() ?? '') ?? 0;
      if (reps > max) max = reps;
    }
    return max;
  }

  int _totalReps(List sets) {
    int total = 0;
    for (final s in sets) {
      final m = s as Map;
      final rr = m['reps'];
      final reps = (rr is int) ? rr : (rr is num) ? rr.toInt() : int.tryParse(rr?.toString() ?? '') ?? 0;
      total += reps;
    }
    return total;
  }

  String _setsShort(List sets) {
    final parts = <String>[];
    for (final s in sets) {
      final m = (s as Map).cast<String, dynamic>();
      final reps = (m['reps'] as int?) ?? 0;
      final w = (m['weight'] as num?)?.toDouble() ?? 0.0;
      final wText =
          w % 1 == 0 ? w.toStringAsFixed(0) : w.toStringAsFixed(1);
      parts.add('${reps}x$wText');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ((workout['exercises'] as List?) ?? <dynamic>[])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();

    final cardio = ((workout['cardio'] as List?) ?? <dynamic>[])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();

    final note = ((workout['note'] as String?) ?? '').trim();

    final muscleGroups = <String>{};
    for (final ex in exercises) {
      final name = (ex['name'] as String?) ?? '';
      for (final entry in ExerciseDB.categories.entries) {
        if (entry.value.contains(name)) {
          muscleGroups.add(entry.key);
          break;
        }
      }
    }

    final hcSessionsRaw = ((workout['hcSessions'] as List?) ?? <dynamic>[])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    // Indexed for edit callbacks
    final hcEntries = hcSessionsRaw.asMap().entries.toList();
    final workoutCalEntries = hcEntries.where((e) => (e.value['type'] as String?) == 'Workout Calories').toList();
    final cardioEntries = hcEntries.where((e) => (e.value['type'] as String?) != 'Workout Calories').toList();

    String hcDur(num min) {
      if (min <= 0) return '';
      final h = min ~/ 60;
      final m = min % 60;
      if (h == 0) return '${m}m';
      return m == 0 ? '${h}h' : '${h}h ${m}m';
    }

    Future<void> editSession(int originalIdx, Map<String, dynamic> s) async {
      final updated = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: NudgeTokens.elevated,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => _HcSessionEditSheet(session: s),
      );
      if (updated != null) onEditHcSession?.call(originalIdx, updated);
    }

    Widget hcCard({
      required int originalIdx,
      required Map<String, dynamic> s,
      required bool isWorkoutCal,
    }) {
      final type = (s['type'] as String?) ?? 'Workout';
      final durationMin = (s['durationMin'] as num?)?.toInt() ?? 0;
      final calories = (s['calories'] as num?)?.toInt() ?? 0;
      final dist = (s['distanceKm'] as num?)?.toDouble() ?? 0.0;
      final source = (s['source'] as String?) ?? '';
      final durLabel = hcDur(durationMin);
      final color = isWorkoutCal ? NudgeTokens.gymB : NudgeTokens.blue;
      final icon = isWorkoutCal ? Icons.local_fire_department_rounded : Icons.directions_run_rounded;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: () => editSession(originalIdx, s),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: NudgeTokens.card,
              border: Border.all(color: color.withValues(alpha: 0.28)),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(icon, size: 14, color: color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(type,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700, fontSize: 13, color: NudgeTokens.textHigh)),
                                if (source.isNotEmpty)
                                  Text(source,
                                      style: const TextStyle(fontSize: 11, color: NudgeTokens.textLow)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (calories > 0)
                                Text('$calories kcal',
                                    style: TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (durLabel.isNotEmpty)
                                    Text(durLabel,
                                        style: const TextStyle(fontSize: 11, color: NudgeTokens.textLow)),
                                  if (durLabel.isNotEmpty && dist > 0)
                                    const Text('  ·  ', style: TextStyle(fontSize: 11, color: NudgeTokens.textLow)),
                                  if (dist > 0)
                                    Text('${dist.toStringAsFixed(1)} km',
                                        style: const TextStyle(fontSize: 11, color: NudgeTokens.textLow)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.edit_rounded, size: 13, color: NudgeTokens.textLow.withValues(alpha: 0.5)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (muscleGroups.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MuscleMapDuo(activeMuscles: muscleGroups, height: 156),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: muscleGroups.map((g) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: NudgeTokens.gymB.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: NudgeTokens.gymB.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        g.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: NudgeTokens.gymB,
                          letterSpacing: 1.2,
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ),
        ...exercises.map((ex) {
          final name = (ex['name'] as String?) ?? 'Exercise';
          final sets = (ex['sets'] as List?) ?? [];
          final best = _bestWeight(sets);
          final bestReps = _maxReps(sets);
          final volume = _totalVolume(sets);
          final totalReps = _totalReps(sets);
          final setsText = _setsShort(sets);
          final last = lastByExercise[name] as Map?;
          final lastBest = last?['bestWeight'];
          final lastBestW = (lastBest is num) ? lastBest.toDouble() : null;
          final diff =
              (lastBestW != null && best > 0) ? best - lastBestW : null;
          final lastVol = last != null ? (last['prevVolume'] as num?)?.toDouble() : null;
          final volDiff = (lastVol != null && volume > 0) ? volume - lastVol : null;

          final isBodyweight = best == 0 && bestReps > 0;
          final lastBestReps = last?['maxReps'] as int?;
          final repsDiff = (lastBestReps != null && bestReps > 0) ? bestReps - lastBestReps : null;
          final lastTotalReps = last?['totalReps'] as int?;
          final totalRepsDiff = (lastTotalReps != null && totalReps > 0) ? totalReps - lastTotalReps : null;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  color: NudgeTokens.card,
                  border: Border.all(color: NudgeTokens.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 3, color: NudgeTokens.gymB),
                      const SizedBox(width: 12),
                      Center(
                        child: ExerciseThumbnail(exerciseName: name, size: 38, iconSize: 19),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh),
                                      ),
                                    ),
                                  ),
                                  if (isBodyweight) ...[
                                    if (repsDiff != null)
                                      _TrendBadge(diff: repsDiff.toDouble(), isReps: true)
                                    else if (bestReps > 0)
                                      Text(
                                        '$bestReps max reps',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: NudgeTokens.textMid,
                                        ),
                                      ),
                                  ] else ...[
                                    if (diff != null)
                                      _TrendBadge(diff: diff)
                                    else if (best > 0)
                                      Text(
                                        '${best % 1 == 0 ? best.toStringAsFixed(0) : best.toStringAsFixed(1)} kg',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: NudgeTokens.textMid,
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                              if (setsText.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  setsText,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: NudgeTokens.textMid,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  if (last != null && last['dayIso'] != null)
                                    Expanded(
                                      child: Text(
                                        'Last ${last['dayIso']}: ${last['setsText']}',
                                        style: const TextStyle(
                                            fontSize: 11, color: NudgeTokens.textLow),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                  else
                                    const Expanded(child: SizedBox()),
                                  if (isBodyweight && totalReps > 0)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '$totalReps total reps',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: NudgeTokens.textLow,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (totalRepsDiff != null && totalRepsDiff != 0) ...[
                                          const SizedBox(width: 4),
                                          _VolDeltaBadge(delta: totalRepsDiff.toDouble(), isReps: true),
                                        ],
                                      ],
                                    )
                                  else if (volume > 0)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${volume.toStringAsFixed(0)} kg vol',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: NudgeTokens.textLow,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (volDiff != null && volDiff != 0) ...[
                                          const SizedBox(width: 4),
                                          _VolDeltaBadge(delta: volDiff),
                                        ],
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              const Divider(height: 1, thickness: 1, color: Color(0x14FFFFFF)),
                              const SizedBox(height: 6),
                              // AI Coach stub — targets & rank (future feature)
                              Row(
                                children: [
                                  Icon(Icons.auto_awesome_rounded, size: 10,
                                      color: NudgeTokens.purple.withValues(alpha: 0.55)),
                                  const SizedBox(width: 5),
                                  Text('AI Target',
                                      style: TextStyle(fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: NudgeTokens.purple.withValues(alpha: 0.55))),
                                  const SizedBox(width: 6),
                                  Text('—',
                                      style: TextStyle(fontSize: 10,
                                          color: NudgeTokens.textLow.withValues(alpha: 0.6))),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(5),
                                      color: NudgeTokens.textLow.withValues(alpha: 0.07),
                                      border: Border.all(color: NudgeTokens.textLow.withValues(alpha: 0.12)),
                                    ),
                                    child: const Text('UNRANKED',
                                        style: TextStyle(fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: NudgeTokens.textLow,
                                            letterSpacing: 0.5)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        // ── Workout Calories (with gym log) ────────────────────────────
        if (workoutCalEntries.isNotEmpty) ...[
          const SizedBox(height: 4),
          for (final entry in workoutCalEntries)
            hcCard(originalIdx: entry.key, s: entry.value, isWorkoutCal: true),
        ],
        // ── Health Connect Cardio Activities ────────────────────────────
        if (cardioEntries.isNotEmpty) ...[
          if (exercises.isNotEmpty || workoutCalEntries.isNotEmpty) const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Row(
              children: [
                Container(
                  width: 3, height: 12,
                  decoration: BoxDecoration(color: NudgeTokens.blue, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 8),
                const Text('HEALTH CONNECT',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: NudgeTokens.textLow, letterSpacing: 1.3)),
              ],
            ),
          ),
          for (final entry in cardioEntries)
            hcCard(originalIdx: entry.key, s: entry.value, isWorkoutCal: false),
          const SizedBox(height: 4),
        ],
        // ── Legacy cardio items (only when no hcSessions — backward compat) ──
        if (hcSessionsRaw.isEmpty)
          for (final c in cardio)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: NudgeTokens.card,
                  border: Border.all(color: NudgeTokens.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        color: NudgeTokens.gymB.withValues(alpha: 0.1),
                      ),
                      child: const Icon(Icons.directions_run_rounded,
                          size: 14, color: NudgeTokens.gymB),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                          (c['activity'] as String?) ?? 'Cardio',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    Text('${(c['minutes'] as num?)?.toInt() ?? 0} min',
                        style: const TextStyle(
                            color: NudgeTokens.textMid, fontSize: 12)),
                    if (((c['distanceKm'] as num?)?.toDouble() ?? 0.0) > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                          '${((c['distanceKm'] as num?)!.toDouble()).toStringAsFixed(1)} km',
                          style: const TextStyle(
                              color: NudgeTokens.textLow, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
        if (note.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: NudgeTokens.elevated,
              border: Border.all(color: NudgeTokens.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes_rounded,
                    size: 14, color: NudgeTokens.textLow),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    note,
                    style: const TextStyle(
                        color: NudgeTokens.textMid,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trend Badge
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Health Connect Workout Sessions
// ─────────────────────────────────────────────────────────────────────────────

class _HCWorkoutsSection extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  final bool loading;
  final void Function(Map<String, dynamic> session) onImport;

  const _HCWorkoutsSection({
    required this.sessions,
    required this.loading,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: NudgeTokens.blue,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'HEALTH CONNECT',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11,
                color: NudgeTokens.textMid,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            if (loading)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: NudgeTokens.textLow),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (sessions.isEmpty && loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text('Fetching sessions…', style: TextStyle(fontSize: 12, color: NudgeTokens.textLow)),
            ),
          ),
        ...sessions.map((session) {
          final type = (session['type'] as String?) ?? 'Workout';
          final durationMin = (session['durationMin'] as num?)?.toInt() ?? 0;
          final calories = (session['calories'] as num?)?.toInt() ?? 0;
          final source = HealthService.cleanSource((session['sourceName'] as String?) ?? 'Health Connect');
          final startIso = session['startTime'] as String?;
          final start = startIso != null ? DateTime.tryParse(startIso) : null;
          final timeLabel = start != null
              ? '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}'
              : '';

          final h = durationMin ~/ 60;
          final m = durationMin % 60;
          final dur = h > 0 ? (m > 0 ? '${h}h ${m}m' : '${h}h') : '${m}m';

          final meta = [
            if (timeLabel.isNotEmpty) timeLabel,
            if (durationMin > 0) dur,
            if (calories > 0) '$calories kcal',
            source,
          ].join(' · ');

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: NudgeTokens.card,
                border: Border.all(color: NudgeTokens.blue.withValues(alpha: 0.3)),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 3,
                      decoration: const BoxDecoration(
                        color: NudgeTokens.blue,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: NudgeTokens.blue.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.fitness_center_rounded, size: 16, color: NudgeTokens.blue),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(type,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700, fontSize: 13, color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh))),
                                  const SizedBox(height: 2),
                                  Text(meta,
                                      style: const TextStyle(fontSize: 11, color: NudgeTokens.textLow)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () => onImport(session),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: NudgeTokens.blue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(color: NudgeTokens.blue.withValues(alpha: 0.35)),
                                ),
                                child: const Text(
                                  'Import',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: NudgeTokens.blue),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HC Import Choice Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _HcImportChoiceSheet extends StatelessWidget {
  final Map<String, dynamic> session;
  const _HcImportChoiceSheet({required this.session});

  static const _options = [
    ('Workout Calories', Icons.fitness_center_rounded, 'Gym workout — calories logged'),
    ('Running',         Icons.directions_run_rounded,  'Cardio run'),
    ('Walking',         Icons.directions_walk_rounded, 'Walk — shown in activity'),
    ('Cycling',         Icons.directions_bike_rounded, 'Cycling session'),
    ('Swimming',        Icons.pool_rounded,             'Swimming session'),
    ('Hiking',          Icons.terrain_rounded,          'Hiking session'),
    ('Rowing',          Icons.rowing_rounded,           'Rowing session'),
  ];

  @override
  Widget build(BuildContext context) {
    final type = (session['type'] as String?) ?? 'Workout';
    final durationMin = (session['durationMin'] as num?)?.toInt() ?? 0;
    final calories = (session['calories'] as num?)?.toInt() ?? 0;
    final dist = (session['distanceKm'] as num?)?.toDouble() ?? 0.0;
    final source = HealthService.cleanSource((session['sourceName'] as String?) ?? '');
    final h = durationMin ~/ 60;
    final m = durationMin % 60;
    final durLabel = durationMin <= 0 ? '' : (h > 0 ? (m > 0 ? '${h}h ${m}m' : '${h}h') : '${m}m');
    final meta = [
      if (durLabel.isNotEmpty) durLabel,
      if (calories > 0) '$calories kcal',
      if (dist > 0) '${dist.toStringAsFixed(1)} km',
      if (source.isNotEmpty) source,
    ].join('  ·  ');

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: NudgeTokens.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Session info header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: NudgeTokens.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.health_and_safety_rounded, size: 18, color: NudgeTokens.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Import: $type',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      if (meta.isNotEmpty)
                        Text(meta, style: const TextStyle(fontSize: 12, color: NudgeTokens.textLow)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: NudgeTokens.border, height: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'IMPORT AS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: NudgeTokens.textLow,
                  letterSpacing: 1.3,
                ),
              ),
            ),
          ),
          ..._options.map((opt) {
            final isMatch = type.toLowerCase().contains(opt.$1.toLowerCase()) ||
                opt.$1.toLowerCase().contains(type.toLowerCase());
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: NudgeTokens.blue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(opt.$2, size: 16, color: NudgeTokens.blue),
              ),
              title: Text(opt.$1,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              subtitle: Text(opt.$3,
                  style: const TextStyle(fontSize: 11, color: NudgeTokens.textLow)),
              trailing: isMatch
                  ? const Icon(Icons.check_circle_rounded, color: NudgeTokens.green, size: 18)
                  : null,
              onTap: () => Navigator.pop(context, opt.$1),
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HC Session Edit Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _HcSessionEditSheet extends StatefulWidget {
  final Map<String, dynamic> session;
  const _HcSessionEditSheet({required this.session});

  @override
  State<_HcSessionEditSheet> createState() => _HcSessionEditSheetState();
}

class _HcSessionEditSheetState extends State<_HcSessionEditSheet> {
  static const _typeOptions = [
    ('Workout Calories', Icons.local_fire_department_rounded),
    ('Running',         Icons.directions_run_rounded),
    ('Treadmill',       Icons.directions_run_rounded),
    ('Walking',         Icons.directions_walk_rounded),
    ('Cycling',         Icons.directions_bike_rounded),
    ('Swimming',        Icons.pool_rounded),
    ('Hiking',          Icons.terrain_rounded),
    ('Rowing',          Icons.rowing_rounded),
  ];

  // Distance unit options
  static const _distUnits = ['km', 'miles', 'steps'];

  late String _type;
  late TextEditingController _durationCtrl;
  late TextEditingController _caloriesCtrl;
  late TextEditingController _distanceCtrl;
  late TextEditingController _stepsCtrl;
  String _distUnit = 'km';

  @override
  void initState() {
    super.initState();
    _type = (widget.session['type'] as String?) ?? 'Workout Calories';
    _durationCtrl = TextEditingController(
        text: '${(widget.session['durationMin'] as num?)?.toInt() ?? 0}');
    _caloriesCtrl = TextEditingController(
        text: '${(widget.session['calories'] as num?)?.toInt() ?? 0}');
    final dist = (widget.session['distanceKm'] as num?)?.toDouble() ?? 0.0;
    _distanceCtrl = TextEditingController(
        text: dist > 0 ? dist.toStringAsFixed(2) : '');
    final steps = (widget.session['steps'] as num?)?.toInt() ?? 0;
    _stepsCtrl = TextEditingController(text: steps > 0 ? '$steps' : '');
    _distUnit = (widget.session['distUnit'] as String?) ?? 'km';
    if (!_distUnits.contains(_distUnit)) _distUnit = 'km';
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    _caloriesCtrl.dispose();
    _distanceCtrl.dispose();
    _stepsCtrl.dispose();
    super.dispose();
  }

  double _distToKm() {
    final raw = double.tryParse(_distanceCtrl.text.trim()) ?? 0.0;
    if (_distUnit == 'miles') return raw * 1.60934;
    if (_distUnit == 'steps') return raw * 0.000762; // avg step ~0.762 m
    return raw;
  }

  void _save() {
    final updated = Map<String, dynamic>.from(widget.session);
    updated['type'] = _type;
    updated['durationMin'] = int.tryParse(_durationCtrl.text.trim()) ?? 0;
    updated['calories'] = int.tryParse(_caloriesCtrl.text.trim()) ?? 0;
    updated['distanceKm'] = _distToKm();
    updated['distUnit'] = _distUnit;
    final rawDist = double.tryParse(_distanceCtrl.text.trim()) ?? 0.0;
    updated['distanceDisplay'] = rawDist; // raw user value before conversion
    final steps = int.tryParse(_stepsCtrl.text.trim()) ?? 0;
    if (steps > 0) updated['steps'] = steps;
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final isCardio = _type != 'Workout Calories';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              decoration: BoxDecoration(color: NudgeTokens.border, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Edit Activity',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: NudgeTokens.gymB,
                      foregroundColor: NudgeTokens.gymA,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
            const Divider(color: NudgeTokens.border, height: 1),
            // Type picker
            SizedBox(
              height: 72,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: _typeOptions.map((opt) {
                  final selected = _type == opt.$1;
                  return GestureDetector(
                    onTap: () => setState(() => _type = opt.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? NudgeTokens.gymB.withValues(alpha: 0.15) : NudgeTokens.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? NudgeTokens.gymB : NudgeTokens.border,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(opt.$2, size: 14,
                              color: selected ? NudgeTokens.gymB : NudgeTokens.textLow),
                          const SizedBox(width: 6),
                          Text(opt.$1,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: selected ? NudgeTokens.gymB : NudgeTokens.textMid,
                              )),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(color: NudgeTokens.border, height: 1),
            // Numeric fields
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _EditField(label: 'Duration', suffix: 'min', controller: _durationCtrl, isInt: true),
                      const SizedBox(width: 12),
                      _EditField(label: 'Calories', suffix: 'kcal', controller: _caloriesCtrl, isInt: true),
                    ],
                  ),
                  if (isCardio) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('DISTANCE',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                          color: NudgeTokens.textLow, letterSpacing: 1.1)),
                                  const SizedBox(width: 8),
                                  // Unit toggle chips
                                  Expanded(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: _distUnits.map((u) => GestureDetector(
                                          onTap: () => setState(() => _distUnit = u),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 150),
                                            margin: const EdgeInsets.only(right: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _distUnit == u ? NudgeTokens.gymB.withValues(alpha: 0.15) : Colors.transparent,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: _distUnit == u ? NudgeTokens.gymB : NudgeTokens.border,
                                              ),
                                            ),
                                            child: Text(u,
                                              style: TextStyle(
                                                fontSize: 10, fontWeight: FontWeight.w700,
                                                color: _distUnit == u ? NudgeTokens.gymB : NudgeTokens.textLow,
                                              )),
                                          ),
                                        )).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _distanceCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                decoration: InputDecoration(
                                  suffixText: _distUnit,
                                  suffixStyle: const TextStyle(fontSize: 12, color: NudgeTokens.textLow),
                                  filled: true,
                                  fillColor: NudgeTokens.card,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: NudgeTokens.border)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: NudgeTokens.border)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _EditField(label: 'Steps', suffix: '', controller: _stepsCtrl, isInt: true),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final String suffix;
  final TextEditingController controller;
  final bool isInt;
  const _EditField({required this.label, required this.suffix, required this.controller, required this.isInt});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: NudgeTokens.textLow, letterSpacing: 1.1)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: isInt
                ? TextInputType.number
                : const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              suffixText: suffix,
              suffixStyle: const TextStyle(fontSize: 12, color: NudgeTokens.textLow),
              filled: true,
              fillColor: NudgeTokens.card,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: NudgeTokens.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: NudgeTokens.border),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Small inline badge showing volume change vs last session
class _VolDeltaBadge extends StatelessWidget {
  final double delta;
  final bool isReps;
  const _VolDeltaBadge({required this.delta, this.isReps = false});

  @override
  Widget build(BuildContext context) {
    final isUp = delta > 0;
    final color = isUp ? NudgeTokens.green : NudgeTokens.red;
    final sign = isUp ? '+' : '';
    final abs = delta.abs();
    final numStr = abs >= 1000
        ? '${(abs / 1000).toStringAsFixed(1)}k'
        : '${abs.toStringAsFixed(0)}';
    final label = isReps ? '$sign$numStr reps' : '$sign$numStr';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          size: 11,
          color: color,
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }
}

class _TrendBadge extends StatelessWidget {
  final double diff;
  final bool isReps;
  const _TrendBadge({required this.diff, this.isReps = false});

  @override
  Widget build(BuildContext context) {
    final double diffVal = diff;
    final isUp = diffVal > 0;
    final isDown = diffVal < 0;
    final color = isUp
        ? NudgeTokens.green
        : isDown
            ? NudgeTokens.red
            : NudgeTokens.textLow;
    final icon = isUp
        ? Icons.arrow_upward_rounded
        : isDown
            ? Icons.arrow_downward_rounded
            : Icons.remove_rounded;
    final text = diffVal == 0
        ? 'Same'
        : '${isUp ? '+' : ''}${diffVal % 1 == 0 ? diffVal.toStringAsFixed(0) : diffVal.toStringAsFixed(1)} ${isReps ? 'reps' : 'kg'}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: 0.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

Widget _LogMetricItem({required IconData icon, required String value, required String label}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: NudgeTokens.textLow),
      const SizedBox(width: 4),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NudgeTokens.textMid)),
      const SizedBox(width: 2),
      Text(label, style: const TextStyle(fontSize: 10, color: NudgeTokens.textLow)),
    ],
  );
}

class _LogbookHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _LogbookHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: NudgeTokens.textLow),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: NudgeTokens.textLow,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _LogbookCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final bool isWorkout;
  final Function(DateTime) onTap;
  const _LogbookCard({required this.entry, required this.isWorkout, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final workout = entry['workout'] as Map?;
    final health = entry['health'] as Map?;
    final iso = entry['dayIso'] as String;
    final date = DateTime.tryParse(iso) ?? DateTime.now();
    final dayName = DateFormat('EEE').format(date).toUpperCase();

    return GestureDetector(
      onTap: () => onTap(date),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NudgeTokens.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: NudgeTokens.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  Text(dayName, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: NudgeTokens.textLow)),
                  Text('${date.day}', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isWorkout && workout != null) ...[
                     Text(
                        (workout['exercises'] as List?)?.isNotEmpty == true
                            ? '${(workout['exercises'] as List).length} exercises'
                            : 'Cardio session',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white),
                      ),
                      if (workout['note'] != null && workout['note'].toString().isNotEmpty)
                        Text(
                          workout['note'], 
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: NudgeTokens.textLow)
                        ),
                  ] else if (health != null) ...[
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _LogMetricItem(icon: Icons.directions_walk_rounded, value: '${(health['steps'] as num?)?.toInt() ?? 0}', label: 'steps'),
                        if ((health['runningCal'] as num? ?? 0) > 0)
                          _LogMetricItem(icon: Icons.directions_run_rounded, value: '${(health['runningCal'] as num?)?.toInt() ?? 0}', label: 'kcal'),
                        if ((health['foodCalories'] as num? ?? 0) > 0)
                          _LogMetricItem(icon: Icons.restaurant_rounded, value: '${(health['foodCalories'] as num?)?.toInt() ?? 0}', label: 'in'),
                        if ((health['waterMl'] as num? ?? 0) > 0)
                          _LogMetricItem(icon: Icons.water_drop_rounded, value: '${(health['waterMl'] as num?)?.toInt() ?? 0}', label: 'ml'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ExportButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: NudgeTokens.gymB.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NudgeTokens.gymB.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf_rounded, size: 14, color: NudgeTokens.gymB),
            const SizedBox(width: 6),
            Text(
              'EXPORT PDF',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: NudgeTokens.gymB,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Muscle Group Weekly Summary ──────────────────────────────────────────────

class _MuscleGroupWeeklySummary extends StatelessWidget {
  final List<Map<String, dynamic>> workouts;
  final List<String> weekDays;

  const _MuscleGroupWeeklySummary({required this.workouts, required this.weekDays});

  static const Map<String, String> _muscleMap = {
    'chest': 'Chest', 'pec': 'Chest', 'fly': 'Chest',
    'lat': 'Back', 'row': 'Back', 'deadlift': 'Back', 'pulldown': 'Back', 'pull-up': 'Back', 'pullup': 'Back',
    'shoulder': 'Shoulders', 'delt': 'Shoulders', 'overhead': 'Shoulders', 'lateral raise': 'Shoulders',
    'bicep': 'Biceps', 'curl': 'Biceps',
    'tricep': 'Triceps', 'pushdown': 'Triceps', 'extension': 'Triceps', 'dip': 'Triceps',
    'squat': 'Legs', 'leg press': 'Legs', 'lunge': 'Legs', 'hamstring': 'Legs',
    'glute': 'Legs', 'calf': 'Legs', 'quad': 'Legs', 'rdl': 'Legs',
    'ab': 'Core', 'core': 'Core', 'plank': 'Core', 'crunch': 'Core', 'sit-up': 'Core',
  };

  static const Map<String, Color> _groupColor = {
    'Chest':     Color(0xFFFF4D6A),
    'Back':      Color(0xFF5AC8FA),
    'Shoulders': Color(0xFFFF9500),
    'Biceps':    Color(0xFF39D98A),
    'Triceps':   Color(0xFF7C4DFF),
    'Legs':      Color(0xFFFFBF00),
    'Core':      Color(0xFFFF2D95),
  };

  static const List<String> _groupOrder = [
    'Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps', 'Legs', 'Core',
  ];

  String? _classify(String name) {
    final lower = name.toLowerCase();
    // Check multi-word keys first (longer keys have priority)
    final sorted = _muscleMap.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final key in sorted) {
      if (lower.contains(key)) return _muscleMap[key];
    }
    // Default: back classification for generic "press" moves if no other match
    if (lower.contains('press') && !lower.contains('leg')) return 'Chest';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, int> groupSets = {};
    for (final w in workouts) {
      if (!weekDays.contains(w['dayIso'] as String?)) continue;
      for (final ex in ((w['exercises'] as List?) ?? [])) {
        final name = (ex as Map)['name'] as String? ?? '';
        final group = _classify(name);
        if (group == null) continue;
        final sets = ((ex['sets'] as List?) ?? []).length;
        groupSets[group] = (groupSets[group] ?? 0) + sets;
      }
    }

    if (groupSets.isEmpty) return const SizedBox.shrink();

    final maxSets = groupSets.values.reduce((a, b) => a > b ? a : b).toDouble();
    final totalSets = groupSets.values.fold(0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.accessibility_new_rounded, color: NudgeTokens.gymB, size: 14),
              const SizedBox(width: 6),
              const Text('MUSCLE GROUPS THIS WEEK',
                  style: TextStyle(color: NudgeTokens.textLow, fontSize: 10,
                      fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              const Spacer(),
              Text('$totalSets sets total',
                  style: const TextStyle(color: NudgeTokens.textLow, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          ...(_groupOrder.where((g) => groupSets.containsKey(g)).map((group) {
            final sets = groupSets[group]!;
            final bar = sets / maxSets;
            final color = _groupColor[group] ?? NudgeTokens.gymB;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 76,
                    child: Text(group,
                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: bar,
                        backgroundColor: color.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 28,
                    child: Text('$sets',
                        textAlign: TextAlign.right,
                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            );
          })),
        ],
      ),
    );
  }
}
