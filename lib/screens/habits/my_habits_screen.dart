// lib/screens/habits/my_habits_screen.dart
// Public (non-PIN-protected) habit tracker.
// Stores data in protectedBox under keys 'pub_habits' / 'pub_habit_logs'
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import '../../storage.dart';
import '../../app.dart' show NudgeTokens;
import '../../utils/notification_service.dart';
import '../protected/habit_card.dart';
import '../protected/habit_routine_card.dart';
import '../protected/habit_editor_sheet.dart';
import '../protected/habit_detail_screen.dart';

class MyHabitsScreen extends StatefulWidget {
  const MyHabitsScreen({super.key});

  @override
  State<MyHabitsScreen> createState() => _MyHabitsScreenState();
}

class _MyHabitsScreenState extends State<MyHabitsScreen> {
  Box? _box;
  bool _loading = true;
  DateTime _day = DateTime.now();

  static const _habitsKey = 'pub_habits';
  static const _logsKey = 'pub_habit_logs';

  static const _categoryOrder = [
    'morning',
    'evening',
    'fitness',
    'mindfulness',
    'finance',
    'learning',
    'anytime',
  ];

  static const _categoryLabels = {
    'morning': 'Morning Routine',
    'evening': 'Evening Routine',
    'fitness': 'Fitness',
    'mindfulness': 'Mindfulness',
    'finance': 'Finance',
    'learning': 'Learning',
    'anytime': 'All Day',
  };

  static const _categoryIcons = {
    'morning': Icons.wb_sunny_rounded,
    'evening': Icons.nights_stay_rounded,
    'fitness': Icons.fitness_center_rounded,
    'mindfulness': Icons.self_improvement_rounded,
    'finance': Icons.credit_card_rounded,
    'learning': Icons.menu_book_rounded,
    'anytime': Icons.all_inclusive_rounded,
  };

  static const _categoryColors = {
    'morning': NudgeTokens.amber,
    'evening': NudgeTokens.blue,
    'fitness': NudgeTokens.gymB,
    'mindfulness': NudgeTokens.purple,
    'finance': NudgeTokens.finB,
    'learning': NudgeTokens.booksB,
    'anytime': NudgeTokens.textMid,
  };

  // ── init ──────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _box = await AppStorage.getProtectedBox();
    // Ensure keys exist
    if (!_box!.containsKey(_habitsKey)) {
      await _box!.put(_habitsKey, <dynamic>[]);
    }
    if (!_box!.containsKey(_logsKey)) {
      await _box!.put(_logsKey, <String, dynamic>{});
    }
    await NotificationService().requestPermissions();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  // ── date helpers ──────────────────────────────────────────────────────────

  DateTime _onlyDay(DateTime d) => DateTime(d.year, d.month, d.day);

  String _isoDay(DateTime d) {
    final dt = _onlyDay(d);
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$mm-$dd';
  }

  void _bumpDay(int delta) =>
      setState(() => _day = _onlyDay(_day.add(Duration(days: delta))));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _onlyDay(_day),
      firstDate: DateTime(1970, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          dialogTheme:
              const DialogThemeData(backgroundColor: NudgeTokens.elevated),
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(surface: NudgeTokens.elevated),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => _day = _onlyDay(picked));
  }

  bool get _isToday => _onlyDay(_day) == _onlyDay(DateTime.now());

  // ── data accessors ────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _habits() {
    final b = _box;
    if (b == null) return [];
    final raw = b.get(_habitsKey, defaultValue: <dynamic>[]) as List;
    final list = raw.map((e) => (e as Map).cast<String, dynamic>()).toList();
    list.sort((a, b) {
      final so = (a['sortOrder'] as int? ?? 0)
          .compareTo(b['sortOrder'] as int? ?? 0);
      if (so != 0) return so;
      return ((b['createdAt'] as String?) ?? '')
          .compareTo((a['createdAt'] as String?) ?? '');
    });
    return list;
  }

  Map<String, dynamic> _logsAll() {
    final b = _box;
    if (b == null) return {};
    final raw = b.get(_logsKey, defaultValue: <String, dynamic>{});
    return (raw as Map).cast<String, dynamic>();
  }

  int _countForDay(String habitId, String dayIso) {
    final logs = _logsAll();
    final per = logs[habitId];
    if (per is Map) {
      final v = per[dayIso];
      if (v is int) return v;
      if (v is num) return v.toInt();
    }
    return 0;
  }

  Future<void> _setCountForDay(
      String habitId, String dayIso, int count) async {
    final b = _box;
    if (b == null) return;
    final logs = Map<String, dynamic>.from(_logsAll());
    final perRaw = logs[habitId];
    final per = (perRaw is Map)
        ? Map<String, dynamic>.from(perRaw.cast<String, dynamic>())
        : <String, dynamic>{};
    if (count <= 0) {
      per.remove(dayIso);
    } else {
      per[dayIso] = count;
    }
    logs[habitId] = per;
    await b.put(_logsKey, logs);
    setState(() {});
  }

  Future<void> _toggleRoutineItem(
      String habitId, String itemId, bool done) async {
    final b = _box;
    if (b == null) return;
    final logs = Map<String, dynamic>.from(_logsAll());
    final key = '${habitId}__$itemId';
    final perRaw = logs[key];
    final per = (perRaw is Map)
        ? Map<String, dynamic>.from(perRaw.cast<String, dynamic>())
        : <String, dynamic>{};
    final dayIso = _isoDay(_day);
    if (done) {
      per[dayIso] = 1;
    } else {
      per.remove(dayIso);
    }
    logs[key] = per;
    await b.put(_logsKey, logs);
    setState(() {});
  }

  List<int> _last7Counts(String habitId) {
    final out = <int>[];
    for (int i = 6; i >= 0; i--) {
      final d = _onlyDay(_day.subtract(Duration(days: i)));
      out.add(_countForDay(habitId, _isoDay(d)));
    }
    return out;
  }

  bool _isHabitDone(Map<String, dynamic> h, String dayIso) {
    final type = (h['type'] as String?) ?? 'counter';
    final id = (h['id'] as String?) ?? '';

    if (type == 'routine') {
      final items = (h['routineItems'] as List?) ?? [];
      if (items.isEmpty) return false;
      final logs = _logsAll();
      final doneCount = items.where((item) {
        final itemId = (item['id'] as String?) ?? '';
        final key = '${id}__$itemId';
        final perLog = logs[key];
        if (perLog is Map) {
          final v = perLog[dayIso];
          if (v is int) return v >= 1;
          if (v is num) return v >= 1;
        }
        return false;
      }).length;
      return doneCount == items.length;
    }

    final count = _countForDay(id, dayIso);
    final target = (h['target'] as int?) ?? 1;
    if (type == 'quit') return count <= target;
    return count >= target;
  }

  // ── add / edit habit ──────────────────────────────────────────────────────

  Future<void> _openAddHabit({Map<String, dynamic>? initial}) async {
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NudgeTokens.elevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => HabitEditorSheet(initial: initial),
    );
    if (res == null) return;

    final action = (res['__action'] as String?) ?? 'save';
    final b = _box!;
    final list = _habits();

    if (action == 'delete') {
      final id = res['id']?.toString();
      if (id == null) return;
      try {
        final intId = int.parse(id.substring(id.length - 8));
        await NotificationService().cancelReminder(intId);
      } catch (_) {}
      list.removeWhere((h) => h['id']?.toString() == id);
      await b.put(_habitsKey, list);
      final logs = Map<String, dynamic>.from(_logsAll());
      logs.remove(id);
      await b.put(_logsKey, logs);
      setState(() {});
      return;
    }

    final cleaned = Map<String, dynamic>.from(res)..remove('__action');
    final id = cleaned['id']?.toString();
    if (id == null) return;

    try {
      final intId = int.parse(id.substring(id.length - 8));
      final remStr = cleaned['reminderTime'] as String?;
      if (remStr != null && remStr.contains(':')) {
        final pts = remStr.split(':');
        final t = TimeOfDay(
            hour: int.parse(pts[0]), minute: int.parse(pts[1]));
        await NotificationService().scheduleDailyReminder(
            intId, cleaned['name'] ?? 'Habit', 'Time to log your habit!', t);
      } else {
        await NotificationService().cancelReminder(intId);
      }
    } catch (_) {}

    final idx = list.indexWhere((h) => h['id']?.toString() == id);
    if (idx >= 0) {
      list[idx] = cleaned;
    } else {
      list.insert(0, cleaned);
    }
    await b.put(_habitsKey, list);
    setState(() {});
  }

  void _openDetail(Map<String, dynamic> habit) {
    final id = (habit['id'] as String?) ?? '';
    final allLogs = _logsAll();
    final habitLogs = allLogs[id];

    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => HabitDetailScreen(
        habit: habit,
        logs: (habitLogs is Map) ? habitLogs : null,
        isPublic: true,
      ),
    ))
        .then((_) => setState(() {}));
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final dayIso = _isoDay(_day);
    final habits = _habits();

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final h in habits) {
      final cat = (h['category'] as String?) ?? 'anytime';
      grouped.putIfAbsent(cat, () => []).add(h);
    }

    final doneCount = habits.where((h) => _isHabitDone(h, dayIso)).length;

    return Scaffold(
      backgroundColor: NudgeTokens.bg,
      appBar: AppBar(
        backgroundColor: NudgeTokens.bg,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              width: 3,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: NudgeTokens.purple,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'My Habits',
              style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add habit',
            onPressed: () => _openAddHabit(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: NudgeTokens.border),
        ),
      ),
      body: Column(
        children: [
          // Date nav
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _DateNavBar(
              dayIso: dayIso,
              isToday: _isToday,
              onPrev: () => _bumpDay(-1),
              onNext: () => _bumpDay(1),
              onPick: _pickDate,
            ),
          ),

          // Progress strip
          if (habits.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _ProgressStrip(done: doneCount, total: habits.length),
            ),

          // Habit list
          Expanded(
            child: habits.isEmpty
                ? const _EmptyHabits()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
                    children: [
                      for (final cat in _categoryOrder)
                        if (grouped.containsKey(cat)) ...[
                          _SectionHeader(
                            label: _categoryLabels[cat] ?? cat,
                            icon: _categoryIcons[cat] ?? Icons.label_rounded,
                            color: _categoryColors[cat] ?? NudgeTokens.textMid,
                          ),
                          ...grouped[cat]!.map((h) {
                            final id = (h['id'] as String?) ?? '';
                            final type = (h['type'] as String?) ?? 'counter';

                            if (type == 'routine') {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: RoutineCard(
                                  habit: h,
                                  allLogs: _logsAll(),
                                  dayIso: dayIso,
                                  onToggleItem: (itemId, done) =>
                                      _toggleRoutineItem(id, itemId, done),
                                  onLongPress: () =>
                                      _openAddHabit(initial: h),
                                  onTap: () => _openDetail(h),
                                ),
                              );
                            }

                            final current = _countForDay(id, dayIso);
                            final last7 = _last7Counts(id);
                            final target = (h['target'] as int?) ?? 1;
                            final isBoolean = type == 'boolean';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: HabitCard(
                                habit: h,
                                todayCount: current,
                                last7: last7,
                                dayIso: dayIso,
                                onIncrement: () => _setCountForDay(
                                    id,
                                    dayIso,
                                    (current + 1).clamp(0, 999999)),
                                onDecrement: () => _setCountForDay(
                                    id,
                                    dayIso,
                                    (current - 1).clamp(0, 999999)),
                                onTap: () => _openDetail(h),
                                onLongPress: () => _openAddHabit(initial: h),
                                onToggle: isBoolean
                                    ? () => _setCountForDay(
                                        id,
                                        dayIso,
                                        current >= target ? 0 : 1)
                                    : null,
                              ),
                            );
                          }),
                          const SizedBox(height: 4),
                        ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Supporting widgets (copied from ProtectedHabitsScreen) ─────────────────

class _DateNavBar extends StatelessWidget {
  final String dayIso;
  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;

  const _DateNavBar({
    required this.dayIso,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: NudgeTokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded,
                color: NudgeTokens.textMid, size: 20),
            onPressed: onPrev,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
          Expanded(
            child: GestureDetector(
              onTap: onPick,
              child: Column(
                children: [
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: NudgeTokens.purple,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'TODAY',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    )
                  else
                    Text(
                      dayIso,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: NudgeTokens.textMid,
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right_rounded,
                color: isToday
                    ? NudgeTokens.border
                    : NudgeTokens.textMid,
                size: 20),
            onPressed: isToday ? null : onNext,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _ProgressStrip extends StatelessWidget {
  final int done;
  final int total;
  const _ProgressStrip({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? done / total : 0.0;
    final color = pct >= 1.0
        ? NudgeTokens.green
        : pct >= 0.5
            ? NudgeTokens.amber
            : NudgeTokens.purple;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: NudgeTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Row(
        children: [
          Text(
            '$done / $total',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0),
                backgroundColor: NudgeTokens.border,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(pct * 100).round()}%',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: NudgeTokens.textLow,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SectionHeader(
      {required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHabits extends StatelessWidget {
  const _EmptyHabits();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.checklist_rounded,
              size: 56, color: NudgeTokens.textLow),
          const SizedBox(height: 16),
          Text(
            'No habits yet',
            style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: NudgeTokens.textMid),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + to add your first habit',
            style: GoogleFonts.outfit(
                fontSize: 13, color: NudgeTokens.textLow),
          ),
        ],
      ),
    );
  }
}
