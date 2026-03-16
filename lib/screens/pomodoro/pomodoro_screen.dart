// lib/screens/pomodoro/pomodoro_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../storage.dart';
import '../../widgets/empty_card.dart';
import '../../app.dart' show NudgeTokens;
import 'pomodoro_engine.dart';
import 'project_editor_sheet.dart';
import 'manual_log_sheet.dart';
import 'pomodoro_stats_screen.dart';

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final IconData icon;
  final Color color;

  const _Stepper({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: NudgeTokens.card,
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontSize: 13),
            ),
          ),
          _StepBtn(icon: Icons.remove_rounded, onTap: onMinus, color: NudgeTokens.textLow),
          const SizedBox(width: 10),
          SizedBox(
            width: 32,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _StepBtn(icon: Icons.add_rounded, onTap: onPlus, color: color),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _StepBtn({required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: color.withValues(alpha: 0.10),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  Box? _box;
  bool _loading = true;

  final PomodoroEngine _engine = PomodoroEngine.instance;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _engine.ensureLoaded();
    final b = await AppStorage.getPomodoroBox();
    if (!mounted) return;
    setState(() {
      _box = b;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> _projects() {
    final b = _box;
    if (b == null) return [];
    final raw = (b.get('projects', defaultValue: <dynamic>[]) as List);
    final list = raw.map((e) => (e as Map).cast<String, dynamic>()).toList();
    list.sort((a, b) =>
        (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));
    return list;
  }

  List<Map<String, dynamic>> _logs() {
    final b = _box;
    if (b == null) return [];
    final raw = (b.get('logs', defaultValue: <dynamic>[]) as List);
    final list = raw.map((e) => (e as Map).cast<String, dynamic>()).toList();
    list.sort((a, b) =>
        (b['at'] as String? ?? '').compareTo(a['at'] as String? ?? ''));
    return list;
  }

  Map<String, int> _minutesByProject() {
    final out = <String, int>{};
    for (final l in _logs()) {
      final pid = (l['projectId'] as String?) ?? '';
      if (pid.isEmpty) continue;
      final kind = (l['kind'] as String?) ?? '';
      if (kind != 'work' && kind != 'manual') continue;
      final min = (l['minutes'] is int) ? (l['minutes'] as int) : 0;
      out[pid] = (out[pid] ?? 0) + min;
    }
    return out;
  }

  String _fmtHours(int minutes) {
    if (minutes <= 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h <= 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  String _fmtClock(int seconds) {
    if (seconds < 0) seconds = 0;
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _openProjectEditor({Map<String, dynamic>? initial}) async {
    if (_box == null) return;
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NudgeTokens.elevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ProjectEditorSheet(initial: initial),
    );
    if (res == null) return;

    final action = (res['__action'] as String?) ?? 'save';
    final list = _projects();

    if (action == 'delete') {
      final id = res['id']?.toString();
      if (id == null) return;
      list.removeWhere((p) => p['id']?.toString() == id);
      await _box!.put('projects', list);
      if (_engine.notifier.value.projectId == id) {
        await _engine.setProject('');
      }
      setState(() {});
      return;
    }

    final id = res['id']?.toString();
    if (id == null) return;
    final cleaned = Map<String, dynamic>.from(res)..remove('__action');
    final idx = list.indexWhere((p) => p['id']?.toString() == id);
    if (idx >= 0) {
      list[idx] = cleaned;
    } else {
      list.add(cleaned);
    }
    await _box!.put('projects', list);
    setState(() {});
  }

  Future<void> _openManualLog() async {
    if (_box == null) return;
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NudgeTokens.elevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ManualLogSheet(
        projects: _projects(),
        initialProjectId: _engine.notifier.value.projectId,
      ),
    );
    if (res == null) return;
    final raw = (_box!.get('logs', defaultValue: <dynamic>[]) as List);
    final logs = raw.map((e) => (e as Map).cast<String, dynamic>()).toList();
    logs.insert(0, res);
    await _box!.put('logs', logs);
    setState(() {});
  }

  Future<void> _handleStop() async {
    final minutes = await _engine.stop();
    if (!mounted) return;

    if (minutes < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Session too short ($minutes mins). Minimum 5 mins.'),
          backgroundColor: NudgeTokens.amber,
        ),
      );
      return;
    }

    final projects = _projects();
    String? selectedProjectId = _engine.notifier.value.projectId;
    if (selectedProjectId.isEmpty && projects.isNotEmpty) {
      selectedProjectId = projects.first['id']?.toString();
    }

    final bool? shouldLog = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Session Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You focused for $minutes minutes.'),
            const SizedBox(height: 16),
            const Text('Log this to a project?'),
            const SizedBox(height: 8),
            if (projects.isEmpty)
              const Text(
                'No projects yet — create one first.',
                style: TextStyle(color: NudgeTokens.red, fontSize: 13),
              )
            else
              DropdownButtonFormField<String>(
                value: selectedProjectId,
                items: projects
                    .map((p) => DropdownMenuItem<String>(
                          value: p['id']?.toString() ?? '',
                          child: Text((p['name'] as String?) ?? 'Project'),
                        ))
                    .toList(),
                onChanged: (v) => selectedProjectId = v,
                decoration: const InputDecoration(labelText: 'Project'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Discard'),
          ),
          if (projects.isNotEmpty)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log time'),
            ),
        ],
      ),
    );

    if (shouldLog == true && selectedProjectId != null) {
      await _engine.logWorkMinutes(
        selectedProjectId!,
        workMinSetting: _engine.notifier.value.workMin,
        breakMinSetting: _engine.notifier.value.breakMin,
        minutes: minutes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session logged!')),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final projects = _projects();
    final byProject = _minutesByProject();

    return ValueListenableBuilder<PomodoroState>(
      valueListenable: _engine.notifier,
      builder: (context, s, _) {
        final isWork = s.phase == PomoPhase.work;
        final phaseColor = isWork ? const Color(0xFFFF4D6A) : NudgeTokens.blue;
        final progress = s.totalSec <= 0
            ? 0.0
            : (1.0 - (s.remainingSec / s.totalSec)).clamp(0.0, 1.0);

        return Scaffold(
          appBar: AppBar(
            surfaceTintColor: Colors.transparent,
            title: Row(
              children: [
                Container(
                  width: 3,
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: NudgeTokens.pomB,
                  ),
                ),
                const SizedBox(width: 10),
                const Text('Pomodoro'),
              ],
            ),
            actions: [
              IconButton(
                onPressed: _openManualLog,
                icon: const Icon(Icons.edit_calendar_rounded),
                tooltip: 'Manual log',
              ),
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PomodoroStatsScreen()),
                ),
                icon: const Icon(Icons.analytics_rounded),
                tooltip: 'Stats',
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: NudgeTokens.border),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            children: [
              // Timer ring
              _TimerRing(
                progress: progress,
                phaseColor: phaseColor,
                label: s.running
                    ? _fmtClock(s.remainingSec)
                    : '${s.workMin.toString().padLeft(2, '0')}:00',
                sublabel: s.running
                    ? (isWork ? 'FOCUS' : 'BREAK')
                    : 'READY',
                running: s.running,
                paused: s.paused,
              ),

              const SizedBox(height: 28),

              // Controls
              if (!s.running) ...[
                // Presets
                Row(
                  children: [
                    Expanded(
                      child: _PresetBtn(
                        label: '25 / 5',
                        sublabel: 'Classic',
                        active: s.workMin == 25 && s.breakMin == 5,
                        onTap: () => _engine.setPreset(25, 5),
                        color: phaseColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PresetBtn(
                        label: '50 / 10',
                        sublabel: 'Deep work',
                        active: s.workMin == 50 && s.breakMin == 10,
                        onTap: () => _engine.setPreset(50, 10),
                        color: phaseColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _Stepper(
                  label: 'Focus duration (min)',
                  value: s.workMin,
                  onMinus: () =>
                      _engine.setPreset((s.workMin - 5).clamp(5, 120), s.breakMin),
                  onPlus: () => _engine.setPreset(s.workMin + 5, s.breakMin),
                  icon: Icons.work_outline_rounded,
                  color: const Color(0xFFFF4D6A),
                ),
                const SizedBox(height: 8),
                _Stepper(
                  label: 'Break duration (min)',
                  value: s.breakMin,
                  onMinus: () =>
                      _engine.setPreset(s.workMin, (s.breakMin - 1).clamp(1, 30)),
                  onPlus: () => _engine.setPreset(s.workMin, s.breakMin + 1),
                  icon: Icons.coffee_rounded,
                  color: NudgeTokens.blue,
                ),
                const SizedBox(height: 12),
                // Project selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: NudgeTokens.card,
                    border: Border.all(color: NudgeTokens.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: s.projectId.isEmpty ? null : s.projectId,
                      hint: const Text(
                        'Assign to project',
                        style: TextStyle(
                          fontSize: 13,
                          color: NudgeTokens.textLow,
                        ),
                      ),
                      isExpanded: true,
                      dropdownColor: NudgeTokens.elevated,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: NudgeTokens.textMid,
                      ),
                      items: projects
                          .map((p) => DropdownMenuItem<String>(
                                value: p['id']?.toString() ?? '',
                                child: Text((p['name'] as String?) ?? 'Project'),
                              ))
                          .toList(),
                      onChanged: (v) => _engine.setProject(v ?? ''),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _engine.start,
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text('Start session'),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _handleStop,
                        icon: const Icon(Icons.stop_rounded, size: 18),
                        label: const Text('Stop'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _engine.pauseResume,
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              s.paused ? NudgeTokens.green : NudgeTokens.pomB,
                          foregroundColor: Colors.white,
                        ),
                        icon: Icon(
                          s.paused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          size: 18,
                        ),
                        label: Text(s.paused ? 'Resume' : 'Pause'),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 32),

              // Projects section
              Row(
                children: [
                  Text(
                    'PROJECTS',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _openProjectEditor(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: NudgeTokens.pomB.withValues(alpha: 0.10),
                        border: Border.all(
                            color: NudgeTokens.pomB.withValues(alpha: 0.20)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded,
                              size: 13, color: NudgeTokens.pomB),
                          SizedBox(width: 4),
                          Text(
                            'New',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: NudgeTokens.pomB,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (projects.isEmpty)
                const EmptyCard(
                  title: 'No projects yet',
                  subtitle: 'Create one to track your focus time',
                  icon: Icons.folder_outlined,
                )
              else
                ...projects.map((p) {
                  final id = p['id']?.toString() ?? '';
                  final min = byProject[id] ?? 0;
                  final isActive = s.projectId == id;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: isActive
                          ? NudgeTokens.pomB.withValues(alpha: 0.08)
                          : NudgeTokens.card,
                      border: Border.all(
                        color: isActive
                            ? NudgeTokens.pomB.withValues(alpha: 0.25)
                            : NudgeTokens.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9),
                            color: isActive
                                ? NudgeTokens.pomB.withValues(alpha: 0.15)
                                : NudgeTokens.elevated,
                          ),
                          child: Icon(
                            Icons.folder_rounded,
                            size: 16,
                            color: isActive ? NudgeTokens.pomB : NudgeTokens.textLow,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            (p['name'] as String?) ?? 'Project',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        // Time badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7),
                            color: NudgeTokens.green.withValues(alpha: 0.10),
                            border: Border.all(
                                color: NudgeTokens.green.withValues(alpha: 0.18)),
                          ),
                          child: Text(
                            _fmtHours(min),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: NudgeTokens.green,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded,
                              color: NudgeTokens.textLow, size: 18),
                          onPressed: () => _openProjectEditor(initial: p),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}


class _TimerRing extends StatelessWidget {
  final double progress;
  final Color phaseColor;
  final String label;
  final String sublabel;
  final bool running;
  final bool paused;

  const _TimerRing({
    required this.progress,
    required this.phaseColor,
    required this.label,
    required this.sublabel,
    required this.running,
    required this.paused,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 240,
        height: 240,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow ring
            Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: running && !paused
                    ? [
                        BoxShadow(
                          color: phaseColor.withValues(alpha: 0.12),
                          blurRadius: 32,
                          spreadRadius: 4,
                        ),
                      ]
                    : null,
              ),
            ),
            // Progress ring
            SizedBox(
              width: 220,
              height: 220,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 8,
                strokeCap: StrokeCap.round,
                backgroundColor: NudgeTokens.elevated,
                color: phaseColor,
              ),
            ),
            // Inner content
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    color: phaseColor.withValues(alpha: 0.12),
                  ),
                  child: Text(
                    sublabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: phaseColor,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetBtn extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool active;
  final VoidCallback onTap;
  final Color color;

  const _PresetBtn({
    required this.label,
    required this.sublabel,
    required this.active,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: active ? color.withValues(alpha: 0.12) : NudgeTokens.card,
          border: Border.all(
            color: active ? color.withValues(alpha: 0.35) : NudgeTokens.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: active ? color : NudgeTokens.textMid,
              ),
            ),
            Text(
              sublabel,
              style: const TextStyle(fontSize: 10, color: NudgeTokens.textLow),
            ),
          ],
        ),
      ),
    );
  }
}

