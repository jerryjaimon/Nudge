// lib/screens/protected/protected_habits_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import '../../storage.dart';
import '../../app.dart' show NudgeTokens;
import 'habit_card.dart';
import 'habit_editor_sheet.dart';
import 'habit_detail_screen.dart';
import 'package:nudge/utils/nudge_theme_extension.dart';
import '../../utils/notification_service.dart';

class ProtectedHabitsScreen extends StatefulWidget {
  const ProtectedHabitsScreen({super.key});

  @override
  State<ProtectedHabitsScreen> createState() => _ProtectedHabitsScreenState();
}

class _ProtectedHabitsScreenState extends State<ProtectedHabitsScreen> {
  Box? _box;
  bool _loading = true;

  DateTime _day = DateTime.now();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _box = await AppStorage.getProtectedBox();
    await NotificationService().requestPermissions();
    if (!mounted) return;
    setState(() => _loading = false);
  }

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
    setState(() => _day = _onlyDay(picked));
  }

  List<Map<String, dynamic>> _habits() {
    final b = _box;
    if (b == null) return [];
    final raw = (b.get('habits', defaultValue: <dynamic>[]) as List);
    final list = raw.map((e) => (e as Map).cast<String, dynamic>()).toList();
    list.sort((a, b) =>
        (b['createdAt'] as String? ?? '').compareTo(a['createdAt'] as String? ?? ''));
    return list;
  }

  Map<String, dynamic> _logsAll() {
    final b = _box;
    if (b == null) return <String, dynamic>{};
    final raw = b.get('habit_logs', defaultValue: <String, dynamic>{});
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

  Future<void> _setCountForDay(String habitId, String dayIso, int count) async {
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
    await b.put('habit_logs', logs);
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
      await b.put('habits', list);
      final logs = Map<String, dynamic>.from(_logsAll());
      logs.remove(id);
      await b.put('habit_logs', logs);
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
        final t = TimeOfDay(hour: int.parse(pts[0]), minute: int.parse(pts[1]));
        await NotificationService().scheduleDailyReminder(intId, cleaned['name'] ?? 'Habit', 'Time to log your habit!', t);
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
    await b.put('habits', list);
    setState(() {});
  }

  bool get _isToday {
    final today = _onlyDay(DateTime.now());
    return _onlyDay(_day) == today;
  }
  
  void _openDetail(Map<String, dynamic> habit) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => HabitDetailScreen(habit: habit, logs: _logsAll()[habit['id']?.toString()] as Map?),
    )).then((_) => setState((){}));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final dayIso = _isoDay(_day);
    final habits = _habits();
    final doneCount = habits.where((h) {
      final id = h['id']?.toString() ?? '';
      final count = _countForDay(id, dayIso);
      final type = (h['type'] as String?) ?? 'build';
      final target = (h['target'] as int?) ?? 1;
      
      if (type == 'quit') return count <= target;
      return count >= target;
    }).length;

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
                color: NudgeTokens.protB,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Habits'),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: NudgeTokens.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          _DateNavBar(
            dayIso: dayIso,
            isToday: _isToday,
            onPrev: () => _bumpDay(-1),
            onNext: () => _bumpDay(1),
            onPick: _pickDate,
          ),

          if (habits.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ProgressRow(done: doneCount, total: habits.length),
          ],

          const SizedBox(height: 10),

          if (habits.isEmpty)
            const _EmptyHabits()
          else
            ...habits.map((h) {
              final id = h['id']?.toString() ?? '';
              final name = (h['name'] as String?) ?? 'Habit';
              final iconCode = (h['iconCode'] is int)
                  ? (h['iconCode'] as int)
                  : Icons.check_rounded.codePoint;
              final type = (h['type'] as String?) ?? 'build';
              final target = (h['target'] as int?) ?? 1;
              final current = _countForDay(id, dayIso);
              final last7 = _last7Counts(id);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onLongPress: () => _openAddHabit(initial: h),
                  onTap: () => _openDetail(h),
                  child: HabitCard(
                    title: name,
                    iconCode: iconCode,
                    count: current,
                    last7: last7,
                    type: type,
                    target: target,
                    onTapEdit: () => _openAddHabit(initial: h),
                    onMinus: () =>
                        _setCountForDay(id, dayIso, (current - 1).clamp(0, 999999)),
                    onPlus: () =>
                        _setCountForDay(id, dayIso, (current + 1).clamp(0, 999999)),
                  ),
                ),
              );
            }),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: () => _openAddHabit(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add habit'),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
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
                    dayIso,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh),
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        color: NudgeTokens.blue.withValues(alpha: 0.12),
                      ),
                      child: const Text(
                        'TODAY',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: NudgeTokens.blue,
                          letterSpacing: 1,
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
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: NudgeTokens.elevated,
          border: Border.all(color: NudgeTokens.border),
        ),
        child: Icon(icon, size: 20, color: NudgeTokens.textMid),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final int done;
  final int total;

  const _ProgressRow({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? done / total : 0.0;
    final allDone = done == total && total > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: allDone
            ? NudgeTokens.green.withValues(alpha: 0.08)
            : NudgeTokens.card,
        border: Border.all(
          color: allDone
              ? NudgeTokens.green.withValues(alpha: 0.25)
              : NudgeTokens.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                allDone ? 'All done! 🎉' : '$done of $total habits',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: allDone ? NudgeTokens.green : (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh),
                      fontSize: 13,
                    ),
              ),
              const Spacer(),
              Text(
                '${(pct * 100).round()}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: allDone ? NudgeTokens.green : NudgeTokens.textMid,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 4,
              backgroundColor: NudgeTokens.elevated,
              valueColor: AlwaysStoppedAnimation<Color>(
                allDone ? NudgeTokens.green : NudgeTokens.blue,
              ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: NudgeTokens.card,
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: NudgeTokens.protB.withValues(alpha: 0.10),
              border: Border.all(color: NudgeTokens.protB.withValues(alpha: 0.20)),
            ),
            child: const Icon(Icons.lock_rounded, size: 22, color: NudgeTokens.protB),
          ),
          const SizedBox(height: 12),
          Text(
            'No habits yet',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: NudgeTokens.textMid),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap Add habit below to get started',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: NudgeTokens.textLow),
          ),
        ],
      ),
    );
  }
}
