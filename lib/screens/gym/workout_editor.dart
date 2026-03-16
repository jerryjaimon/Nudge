// lib/screens/gym/workout_editor.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../app.dart' show NudgeTokens;
import 'exercise_picker_sheet.dart';
import 'exercise_thumbnail.dart';
import 'exercise_detail_sheet.dart';
import 'package:nudge/utils/nudge_theme_extension.dart';

// ─── Public entry-point ───────────────────────────────────────────────────────
class WorkoutEditorPage extends StatefulWidget {
  final String dayIso;
  final Map<String, dynamic>? initialWorkout;
  final Map<String, dynamic>? lastByExercise;

  const WorkoutEditorPage({
    super.key,
    required this.dayIso,
    required this.initialWorkout,
    required this.lastByExercise,
  });

  @override
  State<WorkoutEditorPage> createState() => _WorkoutEditorPageState();
}

// ─── Page state ───────────────────────────────────────────────────────────────
class _WorkoutEditorPageState extends State<WorkoutEditorPage> {
  late List<Map<String, dynamic>> _exercises;
  late List<Map<String, dynamic>> _cardio;
  final _noteCtrl = TextEditingController();
  final _caloriesCtrl = TextEditingController();

  // Rest timer
  bool _restActive = false;
  int _restRemaining = 0;
  static const int _restTotal = 60;
  Timer? _restTimer;

  @override
  void initState() {
    super.initState();
    final init = widget.initialWorkout;
    _exercises = _hydrateSets(init?['exercises']);
    _cardio = ((init?['cardio'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    _noteCtrl.text = (init?['note'] as String?) ?? '';
    _caloriesCtrl.text = ((init?['calories'] as num?)?.toInt() ?? 0).toString();
  }

  /// Ensure every set map has a 'done' bool field.
  List<Map<String, dynamic>> _hydrateSets(dynamic raw) {
    return ((raw as List?) ?? []).map((e) {
      final ex = Map<String, dynamic>.from(e as Map);
      ex['sets'] = ((ex['sets'] as List?) ?? []).map((s) {
        final sm = Map<String, dynamic>.from(s as Map);
        sm.putIfAbsent('done', () => false);
        return sm;
      }).toList();
      return ex;
    }).toList();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _caloriesCtrl.dispose();
    _restTimer?.cancel();
    super.dispose();
  }

  // ─── Rest timer ─────────────────────────────────────────────────────────
  void _startRest() {
    _restTimer?.cancel();
    setState(() {
      _restActive = true;
      _restRemaining = _restTotal;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _restRemaining = (_restRemaining - 1).clamp(0, _restTotal);
        if (_restRemaining == 0) {
          t.cancel();
          _restActive = false;
        }
      });
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() => _restActive = false);
  }

  // ─── Text import ─────────────────────────────────────────────────────────

  /// Parses a freeform workout text like:
  ///   Incline Chest Press
  ///   5kg - 10reps
  ///   15kg - 8 reps
  List<Map<String, dynamic>> _parseWorkoutText(String text) {
    // Matches: "5kg - 10reps", "15 - 8 reps", "32kg - 10 reps", "9kg - 6 sets"
    final setPattern = RegExp(
      r'^(\d+(?:\.\d+)?)\s*(?:kg|lbs?)?\s*[-–x×]\s*(\d+)\s*(?:reps?|sets?)?',
      caseSensitive: false,
    );
    // Detect cardio lines like "0.71 miles - 64" or "30 min walk"
    final cardioKeywords = RegExp(r'\b(mile|km|kilometer|minute|min|hour|hr)\b', caseSensitive: false);

    final exercises = <Map<String, dynamic>>[];
    String? currentExercise;
    List<Map<String, dynamic>> currentSets = [];

    void flush() {
      if (currentExercise == null) return;
      exercises.add({
        'name': currentExercise,
        'sets': currentSets.isNotEmpty
            ? currentSets
            : [{'reps': 8, 'weight': 0.0, 'done': false}],
      });
      currentExercise = null;
      currentSets = [];
    }

    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        flush();
        continue;
      }
      // Skip cardio lines (they'll be ignored for now as they need different handling)
      if (cardioKeywords.hasMatch(line)) continue;

      final match = setPattern.firstMatch(line);
      if (match != null) {
        final weight = double.tryParse(match.group(1) ?? '') ?? 0.0;
        final reps = int.tryParse(match.group(2) ?? '') ?? 0;
        currentSets.add({'reps': reps, 'weight': weight, 'done': false});
      } else {
        // New exercise name
        flush();
        currentExercise = line;
      }
    }
    flush();
    return exercises;
  }

  Future<void> _importFromText() async {
    final ctrl = TextEditingController();
    final parsed = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NudgeTokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Paste Workout',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: NudgeTokens.textHigh),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'One exercise per line, then sets below it:\n  15kg - 8 reps\n  20 - 6 reps',
              style: TextStyle(fontSize: 12, color: NudgeTokens.textLow),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 12,
              autofocus: true,
              style: const TextStyle(fontSize: 13, color: NudgeTokens.textHigh, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'Incline Chest Press\n5kg - 10 reps\n15kg - 8 reps\n\nLateral Raises\n20kg - 15 reps',
                hintStyle: const TextStyle(color: NudgeTokens.textLow, fontSize: 12),
                filled: true,
                fillColor: NudgeTokens.elevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: NudgeTokens.textMid)),
          ),
          FilledButton(
            onPressed: () {
              final exercises = _parseWorkoutText(ctrl.text);
              Navigator.pop(ctx, exercises);
            },
            style: FilledButton.styleFrom(backgroundColor: NudgeTokens.gymB, foregroundColor: NudgeTokens.gymA),
            child: const Text('Import', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (parsed == null || parsed.isEmpty || !mounted) return;
    setState(() {
      for (final ex in parsed) {
        final name = ex['name'] as String;
        final existing = _exercises.indexWhere((e) => (e['name'] as String).toLowerCase() == name.toLowerCase());
        if (existing >= 0) {
          // Append sets to existing exercise
          final exSets = List<dynamic>.from(_exercises[existing]['sets'] as List);
          exSets.addAll(ex['sets'] as List);
          final updated = Map<String, dynamic>.from(_exercises[existing]);
          updated['sets'] = exSets;
          _exercises[existing] = updated;
        } else {
          _exercises.add(ex);
        }
      }
    });
  }

  // ─── Data mutations ──────────────────────────────────────────────────────

  /// Toggle a set's done state; starts rest timer when marking done.
  void _toggleSetDone(int exIdx, int setIdx) {
    final sets = List<dynamic>.from(_exercises[exIdx]['sets'] as List);
    final s = Map<String, dynamic>.from(sets[setIdx] as Map);
    final wasDone = s['done'] as bool? ?? false;
    s['done'] = !wasDone;
    sets[setIdx] = s;
    final ex = Map<String, dynamic>.from(_exercises[exIdx]);
    ex['sets'] = sets;
    setState(() => _exercises[exIdx] = ex);
    if (!wasDone) _startRest();
  }

  /// Mutates exercise/set data in-place without setState (called from text
  /// field onChanged — avoids rebuilding controllers on each keystroke).
  void _updateSetValue(int exIdx, int setIdx, {int? reps, double? weight}) {
    final sets = _exercises[exIdx]['sets'] as List;
    final s = Map<String, dynamic>.from(sets[setIdx] as Map);
    if (reps != null) s['reps'] = reps;
    if (weight != null) s['weight'] = weight;
    sets[setIdx] = s;
  }

  void _addSet(int exIdx) {
    final sets = List<dynamic>.from(_exercises[exIdx]['sets'] as List);
    final lastW = sets.isNotEmpty
        ? ((sets.last as Map)['weight'] as num?)?.toDouble() ?? 0.0
        : 0.0;
    final lastR = sets.isNotEmpty
        ? ((sets.last as Map)['reps'] as int?) ?? 8
        : 8;
    sets.add({'reps': lastR, 'weight': lastW, 'done': false});
    final ex = Map<String, dynamic>.from(_exercises[exIdx]);
    ex['sets'] = sets;
    setState(() => _exercises[exIdx] = ex);
  }

  void _removeSet(int exIdx, int setIdx) {
    final sets = List<dynamic>.from(_exercises[exIdx]['sets'] as List);
    if (sets.length <= 1) return;
    sets.removeAt(setIdx);
    final ex = Map<String, dynamic>.from(_exercises[exIdx]);
    ex['sets'] = sets;
    setState(() => _exercises[exIdx] = ex);
  }

  void _removeExercise(int idx) => setState(() => _exercises.removeAt(idx));

  Future<void> _addExercise() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const ExercisePickerSheet(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _exercises.add({
        'name': picked,
        'sets': [
          {'reps': 8, 'weight': 0.0, 'done': false}
        ],
      });
    });
  }

  Future<void> _renameExercise(int idx) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const ExercisePickerSheet(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final ex = Map<String, dynamic>.from(_exercises[idx]);
      ex['name'] = picked;
      _exercises[idx] = ex;
    });
  }

  // ─── Previous-session helpers ────────────────────────────────────────────

  List<Map<String, dynamic>> _prevSetsFor(String name) {
    final last = widget.lastByExercise?[name] as Map?;
    if (last == null) return [];
    // Prefer raw sets list if stored
    final raw = last['sets'];
    if (raw is List) {
      return raw.map((s) => Map<String, dynamic>.from(s as Map)).toList();
    }
    // Fall back to parsing compact setsText "8x80, 10x80"
    final text = (last['setsText'] as String?) ?? '';
    if (text.isEmpty) return [];
    return text.split(',').map((part) {
      final p = part.trim().split('x');
      final reps = int.tryParse(p.isNotEmpty ? p[0] : '') ?? 0;
      final weight = double.tryParse(p.length > 1 ? p[1] : '') ?? 0.0;
      return <String, dynamic>{'reps': reps, 'weight': weight};
    }).toList();
  }

  String _prevSessionLabel(String name) {
    final last = widget.lastByExercise?[name] as Map?;
    if (last == null) return '';
    final day = (last['dayIso'] as String?) ?? '';
    final setsText = (last['setsText'] as String?) ?? '';
    if (day.isEmpty) return '';
    final parts = day.split('-');
    String label = day;
    if (parts.length == 3) {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final m = int.tryParse(parts[1]) ?? 0;
      final d = int.tryParse(parts[2]) ?? 0;
      if (m >= 1 && m <= 12) label = '${months[m - 1]} $d';
    }
    return setsText.isNotEmpty ? '$label  ·  $setsText' : label;
  }

  // ─── Save / Delete ───────────────────────────────────────────────────────

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NudgeTokens.card,
        title: Text('Discard workout?',
            style: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh), fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text('Your changes will not be saved.',
            style: TextStyle(color: NudgeTokens.textMid, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing', style: TextStyle(color: NudgeTokens.purple)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard', style: TextStyle(color: NudgeTokens.red)),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  void _done() {
    // Strip internal 'done' field before persisting
    final cleanExercises = _exercises.map((ex) {
      final sets = ((ex['sets'] as List?) ?? []).map((s) {
        return Map<String, dynamic>.from(s as Map)..remove('done');
      }).toList();
      return Map<String, dynamic>.from(ex)..['sets'] = sets;
    }).toList();
    final now = DateTime.now().toIso8601String();
    Navigator.of(context).pop(<String, dynamic>{
      '__action': 'save',
      'id': widget.initialWorkout?['id'] ??
          '${DateTime.now().millisecondsSinceEpoch}',
      'dayIso': widget.dayIso,
      'createdAt': widget.initialWorkout?['createdAt'] ?? now,
      'updatedAt': now,
      'note': _noteCtrl.text.trim(),
      'calories': int.tryParse(_caloriesCtrl.text.trim()) ?? 0,
      'exercises': cleanExercises,
      'cardio': _cardio,
      if (widget.initialWorkout?['hcSessions'] != null)
        'hcSessions': widget.initialWorkout!['hcSessions'],
    });
  }

  void _delete() {
    final id = widget.initialWorkout?['id'];
    if (id == null) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context)
        .pop(<String, dynamic>{'__action': 'delete', 'id': id});
  }

  // ─── Date label ──────────────────────────────────────────────────────────

  String _dayLabel() {
    final parts = widget.dayIso.split('-');
    if (parts.length != 3) return widget.dayIso;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final y = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final d = int.tryParse(parts[2]) ?? 0;
    if (m < 1 || m > 12) return widget.dayIso;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(y, m, d);
    if (date == today) return 'Today';
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${months[m - 1]} $d';
  }

  // ─── Counts ──────────────────────────────────────────────────────────────

  int get _doneSets => _exercises.fold(0, (sum, ex) {
        final sets = (ex['sets'] as List?) ?? [];
        return sum +
            sets.where((s) => (s as Map)['done'] == true).length;
      });

  int get _totalSets => _exercises.fold(0, (sum, ex) {
        return sum + ((ex['sets'] as List?) ?? []).length;
      });

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialWorkout != null;
    final done = _doneSets;
    final total = _totalSets;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done();
      },
      child: Scaffold(
      body: Stack(
        children: [
          // ── Main scrollable content ──────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _AppBar(
                  dayLabel: _dayLabel(),
                  isEditing: isEditing,
                  doneSets: done,
                  totalSets: total,
                  onCancel: _confirmDiscard,
                  onFinish: _done,
                  onImport: _importFromText,
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                        16, 16, 16, _restActive ? 120 : 40),
                    children: [
                      // Exercise cards
                      ...List.generate(_exercises.length, (idx) {
                        final ex = _exercises[idx];
                        final name = (ex['name'] as String?) ?? 'Exercise';
                        final sets = ((ex['sets'] as List?) ?? [])
                            .map((s) =>
                                Map<String, dynamic>.from(s as Map))
                            .toList();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ExerciseCard(
                            key: ValueKey('ex_${name}_$idx'),
                            name: name,
                            sets: sets,
                            prevSets: _prevSetsFor(name),
                            prevLabel: _prevSessionLabel(name),
                            onRemove: () => _removeExercise(idx),
                            onAddSet: () => _addSet(idx),
                            onRemoveSet: (si) => _removeSet(idx, si),
                            onToggleDone: (si) =>
                                _toggleSetDone(idx, si),
                            onUpdateSet: (si,
                                    {int? reps, double? weight}) =>
                                _updateSetValue(idx, si,
                                    reps: reps, weight: weight),
                            onRenameTap: () => _renameExercise(idx),
                          ),
                        );
                      }),

                      // Add Exercise button
                      _AddExerciseButton(onTap: _addExercise),
                      const SizedBox(height: 16),

                      // Optional note
                      _NoteField(controller: _noteCtrl),
                      const SizedBox(height: 16),

                      // Calories field
                      _CaloriesField(controller: _caloriesCtrl),
                      const SizedBox(height: 20),

                      // Delete (editing only)
                      if (isEditing)
                        GestureDetector(
                          onTap: _delete,
                          child: Center(
                            child: Text(
                              'Delete Workout',
                              style: TextStyle(
                                color: NudgeTokens.red
                                    .withValues(alpha: 0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Rest timer (slides up from bottom) ───────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSlide(
              offset:
                  _restActive ? Offset.zero : const Offset(0, 1),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              child: _RestTimerBanner(
                remaining: _restRemaining,
                total: _restTotal,
                onSkip: _skipRest,
              ),
            ),
          ),
        ],
      ),
    ));
  }
}

// ─── Custom app bar ───────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  final String dayLabel;
  final bool isEditing;
  final int doneSets;
  final int totalSets;
  final VoidCallback onCancel;
  final VoidCallback onFinish;
  final VoidCallback onImport;

  const _AppBar({
    required this.dayLabel,
    required this.isEditing,
    required this.doneSets,
    required this.totalSets,
    required this.onCancel,
    required this.onFinish,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: NudgeTokens.card,
        border: Border(bottom: BorderSide(color: NudgeTokens.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                TextButton(
                  onPressed: onCancel,
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                        color: NudgeTokens.textMid, fontSize: 15),
                  ),
                ),
                IconButton(
                  onPressed: onImport,
                  icon: const Icon(Icons.text_snippet_outlined, size: 20, color: NudgeTokens.textMid),
                  tooltip: 'Paste workout text',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        dayLabel,
                        style: TextStyle(
                          color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh),
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (totalSets > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          '$doneSets / $totalSets sets done',
                          style: const TextStyle(
                            color: NudgeTokens.textLow,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilledButton(
                    onPressed: onFinish,
                    style: FilledButton.styleFrom(
                      backgroundColor: NudgeTokens.gymB,
                      foregroundColor: NudgeTokens.gymA,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Finish'),
                  ),
                ),
              ],
            ),
          ),
          // Gym-green accent stripe
          Container(height: 2.5, color: NudgeTokens.gymB),
        ],
      ),
    );
  }
}

// ─── Exercise card ────────────────────────────────────────────────────────────

class _ExerciseCard extends StatefulWidget {
  final String name;
  final List<Map<String, dynamic>> sets;
  final List<Map<String, dynamic>> prevSets;
  final String prevLabel;
  final VoidCallback onRemove;
  final VoidCallback onAddSet;
  final void Function(int) onRemoveSet;
  final void Function(int) onToggleDone;
  final void Function(int, {int? reps, double? weight}) onUpdateSet;
  final VoidCallback? onRenameTap;

  const _ExerciseCard({
    super.key,
    required this.name,
    required this.sets,
    required this.prevSets,
    required this.prevLabel,
    required this.onRemove,
    required this.onAddSet,
    required this.onRemoveSet,
    required this.onToggleDone,
    required this.onUpdateSet,
    this.onRenameTap,
  });

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  final List<TextEditingController> _repsCtrl = [];
  final List<TextEditingController> _weightCtrl = [];

  @override
  void initState() {
    super.initState();
    _buildControllers();
  }

  @override
  void didUpdateWidget(covariant _ExerciseCard old) {
    super.didUpdateWidget(old);
    final prev = _repsCtrl.length;
    final curr = widget.sets.length;
    if (curr > prev) {
      // Only add controllers for the new sets — never touch existing ones
      for (int i = prev; i < curr; i++) {
        final s = widget.sets[i];
        final reps = (s['reps'] as int?) ?? 8;
        final w = (s['weight'] as num?)?.toDouble() ?? 0.0;
        _repsCtrl.add(TextEditingController(text: reps.toString()));
        _weightCtrl.add(TextEditingController(
          text: w == 0
              ? ''
              : (w % 1 == 0 ? w.toStringAsFixed(0) : w.toStringAsFixed(1)),
        ));
      }
    } else if (curr < prev) {
      // Dispose and remove controllers for removed sets
      for (int i = curr; i < prev; i++) {
        _repsCtrl[i].dispose();
        _weightCtrl[i].dispose();
      }
      _repsCtrl.removeRange(curr, prev);
      _weightCtrl.removeRange(curr, prev);
    }
  }

  void _buildControllers() {
    for (final c in _repsCtrl) { c.dispose(); }
    for (final c in _weightCtrl) { c.dispose(); }
    _repsCtrl.clear();
    _weightCtrl.clear();
    for (final s in widget.sets) {
      final reps = (s['reps'] as int?) ?? 8;
      final w = (s['weight'] as num?)?.toDouble() ?? 0.0;
      _repsCtrl.add(TextEditingController(text: reps.toString()));
      _weightCtrl.add(TextEditingController(
        text: w == 0
            ? ''
            : (w % 1 == 0
                ? w.toStringAsFixed(0)
                : w.toStringAsFixed(1)),
      ));
    }
  }

  @override
  void dispose() {
    for (final c in _repsCtrl) { c.dispose(); }
    for (final c in _weightCtrl) { c.dispose(); }
    super.dispose();
  }

  String _fmtPrev(int setIdx) {
    if (setIdx >= widget.prevSets.length) return '—';
    final s = widget.prevSets[setIdx];
    final w = (s['weight'] as num?)?.toDouble() ?? 0.0;
    final r = (s['reps'] as int?) ?? 0;
    if (w == 0 && r == 0) return '—';
    final wText = w == 0
        ? '—'
        : (w % 1 == 0 ? w.toStringAsFixed(0) : w.toStringAsFixed(1));
    if (w == 0) return '${r}r';
    return '$wText × $r';
  }



  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NudgeTokens.elevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 6, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => ExerciseDetailSheet(
                        exerciseName: widget.name,
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      ExerciseThumbnail(exerciseName: widget.name),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: widget.onRenameTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.name,
                          style: TextStyle(
                            color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh),
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.prevLabel.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            widget.prevLabel,
                            style: const TextStyle(
                              color: NudgeTokens.textLow,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (widget.onRenameTap != null)
                  IconButton(
                    onPressed: widget.onRenameTap,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    style: IconButton.styleFrom(foregroundColor: NudgeTokens.textLow),
                    tooltip: 'Change exercise',
                  ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  style: IconButton.styleFrom(
                      foregroundColor: NudgeTokens.textLow),
                ),
              ],
            ),
          ),

          // ── Column headers ───────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: [
                // SET
                SizedBox(
                  width: 32,
                  child: Text('SET',
                      style: _hdrStyle, textAlign: TextAlign.center),
                ),
                SizedBox(width: 10),
                // PREV
                Expanded(
                  flex: 5,
                  child: Text('PREVIOUS', style: _hdrStyle),
                ),
                // KG
                Expanded(
                  flex: 4,
                  child: Text('KG',
                      style: _hdrStyle, textAlign: TextAlign.center),
                ),
                SizedBox(width: 8),
                // REPS
                Expanded(
                  flex: 3,
                  child: Text('REPS',
                      style: _hdrStyle, textAlign: TextAlign.center),
                ),
                SizedBox(width: 8),
                // done button placeholder
                SizedBox(width: 36),
              ],
            ),
          ),
          const Divider(
              color: NudgeTokens.border, height: 1, indent: 14, endIndent: 14),

          // ── Set rows ─────────────────────────────────────────────────────
          ...List.generate(widget.sets.length, (si) {
            final s = widget.sets[si];
            final done = s['done'] as bool? ?? false;
            // All-time best weight from previous session sets
            double? prevBestWeight;
            for (final ps in widget.prevSets) {
              final w = (ps['weight'] as num?)?.toDouble() ?? 0.0;
              if (w > 0 && (prevBestWeight == null || w > prevBestWeight)) {
                prevBestWeight = w;
              }
            }
            return _SetRow(
              index: si,
              done: done,
              prevText: _fmtPrev(si),
              prevBestWeight: prevBestWeight,
              repsCtrl: _repsCtrl[si],
              weightCtrl: _weightCtrl[si],
              canRemove: widget.sets.length > 1,
              onToggleDone: () => widget.onToggleDone(si),
              onRemove: () => widget.onRemoveSet(si),
              onRepsChanged: (v) {
                final n = int.tryParse(v);
                if (n != null) {
                  widget.onUpdateSet(si, reps: n.clamp(0, 999));
                }
              },
              onWeightChanged: (v) {
                final n = double.tryParse(v.replaceAll(',', '.'));
                if (n != null) {
                  widget.onUpdateSet(si, weight: n.clamp(0.0, 999.0));
                }
              },
            );
          }),

          // ── Add set button ───────────────────────────────────────────────
          GestureDetector(
            onTap: widget.onAddSet,
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: NudgeTokens.gymB.withValues(alpha: 0.06),
                border: Border.all(
                    color: NudgeTokens.gymB.withValues(alpha: 0.22),
                    style: BorderStyle.solid),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 15, color: NudgeTokens.gymB),
                  SizedBox(width: 6),
                  Text(
                    'Add Set',
                    style: TextStyle(
                      color: NudgeTokens.gymB,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _hdrStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: NudgeTokens.textLow,
    letterSpacing: 1.1,
  );
}

// ─── Set row ──────────────────────────────────────────────────────────────────

class _SetRow extends StatelessWidget {
  final int index;
  final bool done;
  final String prevText;
  final double? prevBestWeight; // all-time best weight for PR detection
  final TextEditingController repsCtrl;
  final TextEditingController weightCtrl;
  final bool canRemove;
  final VoidCallback onToggleDone;
  final VoidCallback onRemove;
  final void Function(String) onRepsChanged;
  final void Function(String) onWeightChanged;

  const _SetRow({
    required this.index,
    required this.done,
    required this.prevText,
    required this.repsCtrl,
    required this.weightCtrl,
    required this.canRemove,
    required this.onToggleDone,
    required this.onRemove,
    required this.onRepsChanged,
    required this.onWeightChanged,
    this.prevBestWeight,
  });

  Widget _buildDoneFooter() {
    final w = double.tryParse(weightCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final r = int.tryParse(repsCtrl.text) ?? 0;
    if (w <= 0 || r <= 0) return const SizedBox.shrink();

    // Epley 1RM = weight × (1 + reps/30)
    final oneRm = w * (1 + r / 30.0);
    final isPR = prevBestWeight != null && w > prevBestWeight!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 0, 14, 6),
      child: Row(
        children: [
          Text(
            '1RM ≈ ${oneRm.toStringAsFixed(1)} kg',
            style: const TextStyle(color: NudgeTokens.textLow, fontSize: 10, fontWeight: FontWeight.w600),
          ),
          if (isPR) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: NudgeTokens.amber.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('🏆 PR!',
                  style: TextStyle(color: NudgeTokens.amber, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRow(),
        if (done) _buildDoneFooter(),
      ],
    );
  }

  Widget _buildRow() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      color: done ? NudgeTokens.gymB.withValues(alpha: 0.05) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onLongPress: canRemove ? onRemove : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 32,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: done ? NudgeTokens.gymB.withValues(alpha: 0.22) : NudgeTokens.gymA.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${index + 1}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
                      color: done ? NudgeTokens.gymB : NudgeTokens.textLow)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: Text(prevText,
                style: TextStyle(
                    color: done ? NudgeTokens.gymB.withValues(alpha: 0.55) : NudgeTokens.textLow,
                    fontSize: 12, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 4,
            child: _NumCell(controller: weightCtrl, done: done, onChanged: onWeightChanged, hint: '0', width: double.infinity),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: _NumCell(controller: repsCtrl, done: done, onChanged: onRepsChanged, hint: '0', width: double.infinity),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onToggleDone,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? NudgeTokens.gymB : Colors.transparent,
                border: Border.all(color: done ? NudgeTokens.gymB : NudgeTokens.borderHi, width: 1.5),
              ),
              child: Icon(Icons.check_rounded, size: 18, color: done ? NudgeTokens.gymA : NudgeTokens.textLow),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Number input cell ────────────────────────────────────────────────────────

class _NumCell extends StatelessWidget {
  final TextEditingController controller;
  final bool done;
  final void Function(String) onChanged;
  final String hint;
  final double width;

  const _NumCell({
    required this.controller,
    required this.done,
    required this.onChanged,
    this.hint = '0',
    this.width = 64,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: done
            ? NudgeTokens.gymB.withValues(alpha: 0.12)
            : NudgeTokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: done
              ? NudgeTokens.gymB.withValues(alpha: 0.45)
              : NudgeTokens.border,
        ),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        onChanged: onChanged,
        onTap: () => controller.selection = TextSelection(
            baseOffset: 0, extentOffset: controller.text.length),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: done ? NudgeTokens.gymB : (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh),
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          isDense: true,
          hintText: hint,
          hintStyle:
              const TextStyle(color: NudgeTokens.textLow, fontSize: 14),
        ),
      ),
    );
  }
}

// ─── Rest timer banner ────────────────────────────────────────────────────────

class _RestTimerBanner extends StatelessWidget {
  final int remaining;
  final int total;
  final VoidCallback onSkip;

  const _RestTimerBanner({
    required this.remaining,
    required this.total,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? remaining / total : 0.0;
    final m = remaining ~/ 60;
    final s = remaining % 60;
    final timeStr =
        '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 14, 20, 14 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: NudgeTokens.gymA,
        border: Border(
            top: BorderSide(color: NudgeTokens.gymB, width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_rounded,
                  color: NudgeTokens.gymB, size: 18),
              const SizedBox(width: 8),
              const Text(
                'REST',
                style: TextStyle(
                  color: NudgeTokens.gymB,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                timeStr,
                style: TextStyle(
                  color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh),
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onSkip,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: NudgeTokens.gymB.withValues(alpha: 0.12),
                    border: Border.all(
                        color: NudgeTokens.gymB.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: NudgeTokens.gymB,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: NudgeTokens.gymB.withValues(alpha: 0.15),
              valueColor:
                  const AlwaysStoppedAnimation(NudgeTokens.gymB),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Note field ───────────────────────────────────────────────────────────────

class _NoteField extends StatelessWidget {
  final TextEditingController controller;
  const _NoteField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: NudgeTokens.elevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: TextField(
        controller: controller,
        maxLines: 3,
        minLines: 1,
        style: const TextStyle(
            color: NudgeTokens.textMid, fontSize: 14, height: 1.5),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Workout notes...',
          hintStyle: TextStyle(color: NudgeTokens.textLow),
          isCollapsed: false,
        ),
      ),
    );
  }
}

// ─── Calories field ──────────────────────────────────────────────────────────

class _CaloriesField extends StatelessWidget {
  final TextEditingController controller;
  const _CaloriesField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: NudgeTokens.elevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(
            color: NudgeTokens.textMid, fontSize: 14, height: 1.5),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Total Kcal',
          hintStyle: TextStyle(color: NudgeTokens.textLow),
          isCollapsed: false,
          prefixIcon: Icon(Icons.local_fire_department_rounded, size: 20, color: Color(0xFFFF9800)),
          prefixIconConstraints: BoxConstraints(minWidth: 40),
        ),
      ),
    );
  }
}

// ─── Add Exercise button ──────────────────────────────────────────────────────

class _AddExerciseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddExerciseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: NudgeTokens.elevated,
          border: Border.all(color: NudgeTokens.borderHi),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded,
                color: NudgeTokens.gymB, size: 20),
            SizedBox(width: 8),
            Text(
              'Add Exercise',
              style: TextStyle(
                color: NudgeTokens.gymB,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Backwards-compat alias (used by gym_screen.dart) ────────────────────────
// Keep this so gym_screen.dart compiles until its import is updated.
@Deprecated('Use WorkoutEditorPage instead')
typedef WorkoutEditor = WorkoutEditorPage;

