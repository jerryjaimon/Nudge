// lib/widgets/weekly_progress_card.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app.dart' show NudgeTokens;
import '../storage.dart';
import '../utils/food_service.dart';

class WeeklyProgressCard extends StatefulWidget {
  final VoidCallback? onRefresh;
  /// When true, renders as a full-screen page (no card border, always expanded, with header).
  final bool fullScreen;
  const WeeklyProgressCard({super.key, this.onRefresh, this.fullScreen = false});

  @override
  State<WeeklyProgressCard> createState() => _WeeklyProgressCardState();
}

class _WeeklyProgressCardState extends State<WeeklyProgressCard> {
  bool _loading = true;
  bool _expanded = true;

  // Habits — per-day completion rate [0..1] for last 7 days (index 0 = 6 days ago, 6 = today)
  List<double> _habitRates = List.filled(7, 0.0);
  int _totalHabits = 0;
  int _habitDaysCompleted = 0; // days where all habits done

  // Finance (current month)
  double _financeSpent = 0;
  double _financeBudget = 0;
  String _monthLabel = '';

  // Gym sessions per day
  List<bool> _gymDays = List.filled(7, false);
  int _gymSessions = 0;

  // Focus minutes per day
  List<double> _focusMins = List.filled(7, 0.0);
  double _totalFocusMins = 0;

  // Calories per day vs target
  List<double> _calRates = List.filled(7, 0.0);
  List<double> _calTotals = List.filled(7, 0.0);
  double _calTarget = 2000;

  // Gym sets per day
  List<int> _gymSetsPerDay = List.filled(7, 0);
  int _totalGymSets = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<DateTime> get _days {
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
  }

  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final days = _days;

    // ── Habits ─────────────────────────────────────────────────────────────
    final protBox = await AppStorage.getProtectedBox();
    final allHabits = <Map<String, dynamic>>[];
    for (final key in ['habits', 'pub_habits']) {
      final raw =
          protBox.get(key, defaultValue: <dynamic>[]) as List;
      allHabits.addAll(
          raw.map((e) => (e as Map).cast<String, dynamic>()));
    }

    // Build combined logs map: habitId -> {dayIso: count}
    final allLogs = <String, Map<String, dynamic>>{};
    for (final key in ['habit_logs', 'pub_habit_logs']) {
      final raw = (protBox.get(key,
              defaultValue: <String, dynamic>{}) as Map)
          .cast<String, dynamic>();
      raw.forEach((id, logs) {
        if (logs is Map) {
          final existing = allLogs[id] ?? {};
          existing.addAll(logs.cast<String, dynamic>());
          allLogs[id] = existing;
        }
      });
    }
    // Routine item logs
    for (final key in ['habit_logs', 'pub_habit_logs']) {
      final raw = (protBox.get(key,
              defaultValue: <String, dynamic>{}) as Map)
          .cast<String, dynamic>();
      raw.forEach((id, logs) {
        final sid = id.toString();
        if (sid.contains('__') && logs is Map) {
          final existing = allLogs[sid] ?? {};
          existing.addAll(logs.cast<String, dynamic>());
          allLogs[sid] = existing;
        }
      });
    }

    final habitRates = <double>[];
    for (final day in days) {
      final iso = _iso(day);
      if (allHabits.isEmpty) {
        habitRates.add(0.0);
        continue;
      }
      int done = 0;
      for (final h in allHabits) {
        final id = (h['id'] as String?) ?? '';
        final type = (h['type'] as String?) ?? 'counter';
        final target = (h['target'] as int?) ?? 1;
        final logs = allLogs[id] ?? {};

        if (type == 'routine') {
          final items = (h['routineItems'] as List?) ?? [];
          if (items.isEmpty) continue;
          int itemDone = 0;
          for (final item in items) {
            final itemId = (item['id'] as String?) ?? '';
            final itemLogs =
                allLogs['${id}__$itemId'] ?? {};
            if ((itemLogs[iso] as num? ?? 0) >= 1) itemDone++;
          }
          if (itemDone == items.length) done++;
        } else {
          final count = (logs[iso] as num? ?? 0).toInt();
          final isDone =
              type == 'quit' ? count <= target : count >= target;
          if (isDone) done++;
        }
      }
      habitRates
          .add(allHabits.isNotEmpty ? done / allHabits.length : 0.0);
    }

    final habitDaysCompleted =
        habitRates.where((r) => r >= 1.0).length;

    // ── Finance ─────────────────────────────────────────────────────────────
    final finBox = await AppStorage.getFinanceBox();
    final now = DateTime.now();
    final monthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final allExpenses =
        (finBox.get('expenses', defaultValue: <dynamic>[]) as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .where(
                (e) => (e['date'] as String? ?? '').startsWith(monthKey))
            .toList();
    final spent = allExpenses.fold<double>(0.0, (s, e) {
      final a = (e['amount'] as num?)?.toDouble() ?? 0.0;
      return s + (a < 0 ? -a : 0);
    });
    final budgets = finBox.get('budgets',
        defaultValue: <String, dynamic>{}) as Map;
    final budget = (budgets[monthKey] is num)
        ? (budgets[monthKey] as num).toDouble()
        : 0.0;
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final monthLabel =
        '${monthNames[now.month - 1]} ${now.year}';

    // ── Gym ─────────────────────────────────────────────────────────────────
    final gymBox = await AppStorage.getGymBox();
    final workouts =
        (gymBox.get('workouts', defaultValue: []) as List).cast<Map>();
    final gymDays = days.map((day) {
      final iso = _iso(day);
      return workouts.any((w) => w['dayIso'] == iso);
    }).toList();
    final gymSetsPerDay = days.map((day) {
      final iso = _iso(day);
      final w = workouts.firstWhere((w) => w['dayIso'] == iso, orElse: () => {});
      if (w.isEmpty) return 0;
      final exList = (w['exercises'] as List?) ?? [];
      return exList.fold<int>(0, (s, ex) => s + ((ex['sets'] as List?) ?? []).length);
    }).toList();

    // ── Focus ────────────────────────────────────────────────────────────────
    final pomBox = await AppStorage.getPomodoroBox();
    final pomLogs =
        (pomBox.get('logs', defaultValue: []) as List).cast<Map>();
    final focusMins = days.map((day) {
      final iso = _iso(day);
      return pomLogs
          .where((l) => l['startTime'].toString().startsWith(iso))
          .fold<double>(
              0.0,
              (sum, l) =>
                  sum + ((l['durationMin'] as num?)?.toDouble() ?? 0));
    }).toList();
    final totalFocusMins = focusMins.fold<double>(0, (a, b) => a + b);

    // ── Calories per day ─────────────────────────────────────────────────────
    final calTarget = (AppStorage.settingsBox
            .get('calorie_goal', defaultValue: 2000) as num)
        .toDouble();
    final calRates = <double>[];
    final calTotals = <double>[];
    for (final day in days) {
      final entries = await FoodService.getTodayEntries(date: day);
      final cals = entries.fold<double>(
          0.0, (sum, e) => sum + ((e['calories'] as num?)?.toDouble() ?? 0));
      calTotals.add(cals);
      calRates.add(calTarget > 0 ? (cals / calTarget).clamp(0.0, 1.0) : 0.0);
    }

    if (mounted) {
      setState(() {
        _habitRates = habitRates;
        _totalHabits = allHabits.length;
        _habitDaysCompleted = habitDaysCompleted;
        _financeSpent = spent;
        _financeBudget = budget;
        _monthLabel = monthLabel;
        _gymDays = gymDays;
        _gymSessions = gymDays.where((d) => d).length;
        _gymSetsPerDay = gymSetsPerDay;
        _totalGymSets = gymSetsPerDay.fold(0, (a, b) => a + b);
        _focusMins = focusMins;
        _totalFocusMins = totalFocusMins;
        _calRates = calRates;
        _calTotals = calTotals;
        _calTarget = calTarget;
        _loading = false;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  // Compact content used inside the collapsible card on the home screen
  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DayLabelRow(days: _days),
        const SizedBox(height: 12),
        if (_totalHabits > 0) ...[
          _SectionRow(icon: Icons.checklist_rounded, color: NudgeTokens.purple, label: 'Habits', trailingLabel: '$_habitDaysCompleted/7 days full'),
          const SizedBox(height: 6),
          _HabitDayDots(rates: _habitRates),
          const SizedBox(height: 14),
        ],
        _SectionRow(icon: Icons.restaurant_rounded, color: NudgeTokens.foodB, label: 'Nutrition', trailingLabel: _calRates.any((r) => r > 0) ? '${(_calRates.where((r) => r >= 0.8).length)}/7 on target' : 'no data'),
        const SizedBox(height: 6),
        _CalorieDayBars(rates: _calRates),
        const SizedBox(height: 14),
        _SectionRow(icon: Icons.fitness_center_rounded, color: NudgeTokens.gymB, label: 'Training', trailingLabel: '$_gymSessions session${_gymSessions != 1 ? 's' : ''}'),
        const SizedBox(height: 6),
        _GymDayDots(gymDays: _gymDays),
        const SizedBox(height: 14),
        _SectionRow(icon: Icons.timer_rounded, color: NudgeTokens.pomB, label: 'Focus', trailingLabel: '${(_totalFocusMins / 60).toStringAsFixed(1)}h total'),
        const SizedBox(height: 6),
        _FocusDayBars(mins: _focusMins),
        const SizedBox(height: 14),
        _SectionRow(icon: Icons.account_balance_wallet_rounded, color: NudgeTokens.finB, label: 'Finance', trailingLabel: _monthLabel),
        const SizedBox(height: 8),
        _FinanceBar(spent: _financeSpent, budget: _financeBudget),
      ],
    );
  }

  // ── Full-screen rich section cards ──────────────────────────────────────
  Widget _sectionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String summary,
    required Widget body,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: NudgeTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 10),
                Text(title, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
                const Spacer(),
                Text(summary, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.7))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: body,
          ),
        ],
      ),
    );
  }

  Widget _buildFullScreenContent() {
    final days = _days;
    const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final todayIso = _iso(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));

    // ── Summary strip ──────────────────────────────────────────────────────
    final habitPct = _totalHabits > 0
        ? (_habitRates.fold(0.0, (a, b) => a + b) / 7 * 100).round()
        : 0;
    final focusHours = (_totalFocusMins / 60);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary strip
        Row(
          children: [
            _SummaryPill(value: '$_gymSessions', label: 'Sessions', color: NudgeTokens.gymB),
            const SizedBox(width: 10),
            _SummaryPill(value: '$_totalGymSets', label: 'Sets', color: NudgeTokens.amber),
            const SizedBox(width: 10),
            _SummaryPill(value: '${focusHours.toStringAsFixed(1)}h', label: 'Focus', color: NudgeTokens.pomB),
            const SizedBox(width: 10),
            _SummaryPill(value: '$habitPct%', label: 'Habits', color: NudgeTokens.purple),
          ],
        ),
        const SizedBox(height: 18),

        // ── Habits ──────────────────────────────────────────────────────
        if (_totalHabits > 0)
          _sectionCard(
            icon: Icons.checklist_rounded,
            color: NudgeTokens.purple,
            title: 'Habits',
            summary: '$_habitDaysCompleted / 7 full days',
            body: Column(
              children: [
                Row(
                  children: List.generate(7, (i) {
                    final r = _habitRates[i];
                    final iso = _iso(days[i]);
                    final isToday = iso == todayIso;
                    Color col;
                    if (r >= 1.0) col = NudgeTokens.green;
                    else if (r >= 0.5) col = NudgeTokens.amber;
                    else if (r > 0) col = NudgeTokens.blue;
                    else col = NudgeTokens.elevated;
                    return Expanded(
                      child: Column(
                        children: [
                          Text(dayLetters[days[i].weekday - 1],
                              style: GoogleFonts.outfit(fontSize: 10, fontWeight: isToday ? FontWeight.w900 : FontWeight.w500,
                                  color: isToday ? NudgeTokens.purple : NudgeTokens.textLow)),
                          const SizedBox(height: 6),
                          Container(
                            height: 44,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: r > 0 ? col.withValues(alpha: 0.18) : NudgeTokens.elevated,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: r > 0 ? col.withValues(alpha: 0.4) : Colors.transparent),
                            ),
                            child: Center(
                              child: r >= 1.0
                                  ? Icon(Icons.check_rounded, size: 16, color: col)
                                  : r > 0
                                      ? Text('${(r * 100).round()}%',
                                          style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w800, color: col))
                                      : const Icon(Icons.remove_rounded, size: 12, color: NudgeTokens.textLow),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _StatChip('Total habits', '$_totalHabits', NudgeTokens.purple),
                    _StatChip('Best streak', '${_habitRates.where((r) => r >= 1.0).length}d', NudgeTokens.green),
                    _StatChip('Avg rate', '${(_habitRates.fold(0.0, (a, b) => a + b) / 7 * 100).round()}%', NudgeTokens.amber),
                  ],
                ),
              ],
            ),
          ),

        // ── Nutrition ────────────────────────────────────────────────────
        _sectionCard(
          icon: Icons.restaurant_rounded,
          color: NudgeTokens.foodB,
          title: 'Nutrition',
          summary: _calTotals.any((c) => c > 0)
              ? '${(_calRates.where((r) => r >= 0.8).length)}/7 on target'
              : 'no data',
          body: Column(
            children: [
              SizedBox(
                height: 80,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    final cal = i < _calTotals.length ? _calTotals[i] : 0.0;
                    final rate = i < _calRates.length ? _calRates[i] : 0.0;
                    final barH = rate > 0 ? (rate * 60).clamp(4.0, 60.0) : 3.0;
                    final iso = _iso(days[i]);
                    final isToday = iso == todayIso;
                    Color col;
                    if (rate >= 0.9) col = NudgeTokens.green;
                    else if (rate >= 0.6) col = NudgeTokens.amber;
                    else if (rate > 0) col = NudgeTokens.foodB;
                    else col = NudgeTokens.elevated;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (cal > 0)
                              Text(
                                cal >= 1000 ? '${(cal / 1000).toStringAsFixed(1)}k' : '${cal.toInt()}',
                                style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w700, color: col),
                              ),
                            const SizedBox(height: 2),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              height: barH,
                              decoration: BoxDecoration(
                                color: col,
                                borderRadius: BorderRadius.circular(4),
                                border: isToday ? Border.all(color: NudgeTokens.foodB, width: 1.5) : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(dayLetters[days[i].weekday - 1],
                                style: GoogleFonts.outfit(fontSize: 9, fontWeight: isToday ? FontWeight.w900 : FontWeight.w500,
                                    color: isToday ? NudgeTokens.foodB : NudgeTokens.textLow)),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              if (_calTarget > 0) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _StatChip('Target', '${_calTarget.toInt()} kcal', NudgeTokens.foodB),
                    _StatChip('Weekly avg', '${(_calTotals.fold(0.0, (a, b) => a + b) / 7).toInt()} kcal', NudgeTokens.amber),
                    _StatChip('On target', '${(_calRates.where((r) => r >= 0.8).length)}/7 days', NudgeTokens.green),
                  ],
                ),
              ],
            ],
          ),
        ),

        // ── Training ─────────────────────────────────────────────────────
        _sectionCard(
          icon: Icons.fitness_center_rounded,
          color: NudgeTokens.gymB,
          title: 'Training',
          summary: '$_gymSessions session${_gymSessions != 1 ? 's' : ''}  ·  $_totalGymSets sets',
          body: Column(
            children: [
              Row(
                children: List.generate(7, (i) {
                  final done = i < _gymDays.length ? _gymDays[i] : false;
                  final sets = i < _gymSetsPerDay.length ? _gymSetsPerDay[i] : 0;
                  final iso = _iso(days[i]);
                  final isToday = iso == todayIso;
                  return Expanded(
                    child: Column(
                      children: [
                        Text(dayLetters[days[i].weekday - 1],
                            style: GoogleFonts.outfit(fontSize: 10, fontWeight: isToday ? FontWeight.w900 : FontWeight.w500,
                                color: isToday ? NudgeTokens.gymB : NudgeTokens.textLow)),
                        const SizedBox(height: 6),
                        Container(
                          height: 52,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: done ? NudgeTokens.gymB.withValues(alpha: 0.15) : NudgeTokens.elevated,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: done ? NudgeTokens.gymB.withValues(alpha: 0.4) : Colors.transparent,
                            ),
                          ),
                          child: Center(
                            child: done
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.fitness_center_rounded, size: 13, color: NudgeTokens.gymB),
                                      if (sets > 0) ...[
                                        const SizedBox(height: 2),
                                        Text('$sets', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w800, color: NudgeTokens.gymB)),
                                        Text('sets', style: const TextStyle(fontSize: 7, color: NudgeTokens.textLow)),
                                      ],
                                    ],
                                  )
                                : const Icon(Icons.remove_rounded, size: 12, color: NudgeTokens.textLow),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _StatChip('Sessions', '$_gymSessions', NudgeTokens.gymB),
                  _StatChip('Total sets', '$_totalGymSets', NudgeTokens.amber),
                  _StatChip('Rest days', '${7 - _gymSessions}', NudgeTokens.textMid),
                ],
              ),
            ],
          ),
        ),

        // ── Focus ────────────────────────────────────────────────────────
        _sectionCard(
          icon: Icons.timer_rounded,
          color: NudgeTokens.pomB,
          title: 'Focus',
          summary: '${(_totalFocusMins / 60).toStringAsFixed(1)}h this week',
          body: Column(
            children: [
              SizedBox(
                height: 80,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    final m = i < _focusMins.length ? _focusMins[i] : 0.0;
                    final maxM = _focusMins.reduce((a, b) => a > b ? a : b);
                    final barH = maxM > 0 ? ((m / maxM) * 60).clamp(3.0, 60.0) : 3.0;
                    final iso = _iso(days[i]);
                    final isToday = iso == todayIso;
                    final col = m >= 60 ? NudgeTokens.green : m >= 25 ? NudgeTokens.pomB : m > 0 ? NudgeTokens.pomB.withValues(alpha: 0.5) : NudgeTokens.elevated;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (m > 0)
                              Text(
                                m >= 60 ? '${(m / 60).toStringAsFixed(1)}h' : '${m.toInt()}m',
                                style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w700, color: col),
                              ),
                            const SizedBox(height: 2),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              height: barH,
                              decoration: BoxDecoration(
                                color: col,
                                borderRadius: BorderRadius.circular(4),
                                border: isToday ? Border.all(color: NudgeTokens.pomB, width: 1.5) : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(dayLetters[days[i].weekday - 1],
                                style: GoogleFonts.outfit(fontSize: 9, fontWeight: isToday ? FontWeight.w900 : FontWeight.w500,
                                    color: isToday ? NudgeTokens.pomB : NudgeTokens.textLow)),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _StatChip('Total', '${(_totalFocusMins / 60).toStringAsFixed(1)}h', NudgeTokens.pomB),
                  _StatChip('Best day', () {
                    final maxM = _focusMins.reduce((a, b) => a > b ? a : b);
                    if (maxM == 0) return '—';
                    return maxM >= 60 ? '${(maxM / 60).toStringAsFixed(1)}h' : '${maxM.toInt()}m';
                  }(), NudgeTokens.green),
                  _StatChip('Active days', '${_focusMins.where((m) => m > 0).length}', NudgeTokens.amber),
                ],
              ),
            ],
          ),
        ),

        // ── Finance ──────────────────────────────────────────────────────
        _sectionCard(
          icon: Icons.account_balance_wallet_rounded,
          color: NudgeTokens.finB,
          title: 'Finance',
          summary: _monthLabel,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_financeBudget > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '£${_financeSpent.toStringAsFixed(0)}',
                          style: GoogleFonts.outfit(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: _financeSpent > _financeBudget ? NudgeTokens.red : NudgeTokens.finB,
                            height: 1.0,
                          ),
                        ),
                        Text('spent of £${_financeBudget.toStringAsFixed(0)} budget',
                            style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.textMid)),
                      ],
                    ),
                    _BudgetRing(_financeSpent, _financeBudget),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (_financeSpent / _financeBudget).clamp(0.0, 1.0),
                    backgroundColor: NudgeTokens.elevated,
                    valueColor: AlwaysStoppedAnimation(
                      _financeSpent > _financeBudget ? NudgeTokens.red : _financeSpent / _financeBudget > 0.8 ? NudgeTokens.amber : NudgeTokens.finB,
                    ),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${((_financeSpent / _financeBudget) * 100).clamp(0, 150).round()}% used',
                        style: GoogleFonts.outfit(fontSize: 11, color: NudgeTokens.textLow)),
                    Text(
                      _financeSpent > _financeBudget
                          ? '£${(_financeSpent - _financeBudget).toStringAsFixed(0)} over budget'
                          : '£${(_financeBudget - _financeSpent).toStringAsFixed(0)} remaining',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _financeSpent > _financeBudget ? NudgeTokens.red : NudgeTokens.green,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text('£${_financeSpent.toStringAsFixed(0)} spent',
                    style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: NudgeTokens.finB, height: 1.0)),
                const SizedBox(height: 4),
                Text('No budget set — add one in Finance',
                    style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.textLow)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fullScreen) {
      return Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: NudgeTokens.purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_view_week_rounded,
                      size: 18, color: NudgeTokens.purple),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WEEKLY PROGRESS',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: NudgeTokens.purple,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        _weekRangeLabel(),
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: NudgeTokens.textLow,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: NudgeTokens.textLow),
                  )
                else
                  GestureDetector(
                    onTap: _load,
                    child: const Icon(Icons.refresh_rounded, size: 18, color: NudgeTokens.textLow),
                  ),
              ],
            ),
          ),
          Container(height: 1, color: NudgeTokens.border),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [_buildFullScreenContent()],
              ),
            ),
        ],
      );
    }

    // ── Compact card mode (used in home screen) ────────────────────────────
    return Container(
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: NudgeTokens.purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.calendar_view_week_rounded,
                        size: 16, color: NudgeTokens.purple),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WEEKLY PROGRESS',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: NudgeTokens.purple,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          _weekRangeLabel(),
                          style: GoogleFonts.outfit(fontSize: 11, color: NudgeTokens.textLow),
                        ),
                      ],
                    ),
                  ),
                  if (_loading)
                    const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: NudgeTokens.textLow),
                    )
                  else ...[
                    GestureDetector(
                      onTap: _load,
                      child: const Icon(Icons.refresh_rounded, size: 16, color: NudgeTokens.textLow),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: NudgeTokens.textLow,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (_expanded) ...[
            Container(height: 1, color: NudgeTokens.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: _buildContent(),
            ),
          ],
        ],
      ),
    );
  }

  String _weekRangeLabel() {
    final days = _days;
    final first = days.first;
    final last = days.last;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (first.month == last.month) {
      return '${first.day}–${last.day} ${months[last.month - 1]}';
    }
    return '${first.day} ${months[first.month - 1]} – ${last.day} ${months[last.month - 1]}';
  }
}

// ── Day label row ─────────────────────────────────────────────────────────────

class _DayLabelRow extends StatelessWidget {
  final List<DateTime> days;
  const _DayLabelRow({required this.days});

  @override
  Widget build(BuildContext context) {
    const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime(DateTime.now().year, DateTime.now().month,
        DateTime.now().day);
    return Row(
      children: List.generate(7, (i) {
        final isToday = days[i] == today;
        return Expanded(
          child: Center(
            child: Text(
              dayLetters[days[i].weekday - 1],
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight:
                    isToday ? FontWeight.w800 : FontWeight.w500,
                color: isToday
                    ? NudgeTokens.purple
                    : NudgeTokens.textLow,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Section row label ─────────────────────────────────────────────────────────

class _SectionRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String trailingLabel;

  const _SectionRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.trailingLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: NudgeTokens.textMid,
          ),
        ),
        const Spacer(),
        Text(
          trailingLabel,
          style: GoogleFonts.outfit(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ── Habit day dots ────────────────────────────────────────────────────────────

class _HabitDayDots extends StatelessWidget {
  final List<double> rates; // 0..1 per day

  const _HabitDayDots({required this.rates});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(7, (i) {
        final r = i < rates.length ? rates[i] : 0.0;
        Color dotColor;
        if (r >= 1.0) {
          dotColor = NudgeTokens.green;
        } else if (r >= 0.5) {
          dotColor = NudgeTokens.amber;
        } else if (r > 0) {
          dotColor = NudgeTokens.blue;
        } else {
          dotColor = NudgeTokens.elevated;
        }

        return Expanded(
          child: Center(
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor.withValues(
                    alpha: r > 0 ? 0.9 : 0.5),
                border: Border.all(
                  color: dotColor.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: r >= 1.0
                  ? const Icon(Icons.check_rounded,
                      size: 12, color: Colors.black)
                  : r > 0
                      ? Center(
                          child: Text(
                            '${(r * 100).round()}',
                            style: const TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        )
                      : null,
            ),
          ),
        );
      }),
    );
  }
}

// ── Calorie day bars ──────────────────────────────────────────────────────────

class _CalorieDayBars extends StatelessWidget {
  final List<double> rates; // 0..1 per day

  const _CalorieDayBars({required this.rates});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final r = i < rates.length ? rates[i] : 0.0;
          final barH = r > 0 ? (r * 24).clamp(3.0, 24.0) : 2.0;
          Color barColor;
          if (r >= 0.9) {
            barColor = NudgeTokens.green;
          } else if (r >= 0.6) {
            barColor = NudgeTokens.amber;
          } else if (r > 0) {
            barColor = NudgeTokens.foodB.withValues(alpha: 0.6);
          } else {
            barColor = NudgeTokens.elevated;
          }

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  width: double.infinity,
                  height: barH,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Gym day dots ──────────────────────────────────────────────────────────────

class _GymDayDots extends StatelessWidget {
  final List<bool> gymDays;

  const _GymDayDots({required this.gymDays});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(7, (i) {
        final done = i < gymDays.length ? gymDays[i] : false;
        return Expanded(
          child: Center(
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? NudgeTokens.gymB.withValues(alpha: 0.85)
                    : NudgeTokens.elevated,
                border: Border.all(
                  color: done
                      ? NudgeTokens.gymB.withValues(alpha: 0.4)
                      : NudgeTokens.border,
                  width: 1.5,
                ),
              ),
              child: done
                  ? const Icon(Icons.fitness_center_rounded,
                      size: 11, color: Colors.black)
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

// ── Focus day bars ────────────────────────────────────────────────────────────

class _FocusDayBars extends StatelessWidget {
  final List<double> mins;

  const _FocusDayBars({required this.mins});

  @override
  Widget build(BuildContext context) {
    final maxV = mins.reduce((a, b) => a > b ? a : b);
    final scale = maxV > 0 ? maxV : 120.0; // 2 hours as reference

    return SizedBox(
      height: 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final m = i < mins.length ? mins[i] : 0.0;
          final barH =
              m > 0 ? ((m / scale) * 24).clamp(3.0, 24.0) : 2.0;
          final color = m >= 60
              ? NudgeTokens.green
              : m >= 25
                  ? NudgeTokens.pomB
                  : m > 0
                      ? NudgeTokens.pomB.withValues(alpha: 0.4)
                      : NudgeTokens.elevated;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  width: double.infinity,
                  height: barH,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Finance progress bar ──────────────────────────────────────────────────────

class _FinanceBar extends StatelessWidget {
  final double spent;
  final double budget;

  const _FinanceBar({required this.spent, required this.budget});

  @override
  Widget build(BuildContext context) {
    if (budget <= 0 && spent <= 0) {
      return Text(
        'No budget set — add one in Finance',
        style: GoogleFonts.outfit(
            fontSize: 11, color: NudgeTokens.textLow),
      );
    }

    final hasBudget = budget > 0;
    final pct = hasBudget ? (spent / budget).clamp(0.0, 1.5) : 0.0;
    final isOver = pct > 1.0;
    final barColor =
        isOver ? NudgeTokens.red : pct > 0.8 ? NudgeTokens.amber : NudgeTokens.finB;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasBudget) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              backgroundColor: NudgeTokens.elevated,
              valueColor: AlwaysStoppedAnimation(barColor),
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 5),
        ],
        Row(
          children: [
            Text(
              '£${spent.toStringAsFixed(0)} spent',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: barColor,
              ),
            ),
            if (hasBudget) ...[
              Text(
                ' of £${budget.toStringAsFixed(0)} budget',
                style: GoogleFonts.outfit(
                    fontSize: 11, color: NudgeTokens.textLow),
              ),
              const Spacer(),
              Text(
                isOver
                    ? '${((pct - 1.0) * 100).round()}% over'
                    : '${((1.0 - pct) * 100).round()}% left',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: barColor,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ── _SummaryPill ──────────────────────────────────────────────────────────────
class _SummaryPill extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _SummaryPill({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: NudgeTokens.textLow,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── _StatChip ─────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: value,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            TextSpan(
              text: '  $label',
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: NudgeTokens.textLow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _BudgetRing ───────────────────────────────────────────────────────────────
class _BudgetRing extends StatelessWidget {
  final double spent;
  final double budget;
  const _BudgetRing(this.spent, this.budget);

  @override
  Widget build(BuildContext context) {
    final pct = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final isOver = budget > 0 && spent > budget;
    final color = isOver ? NudgeTokens.red : NudgeTokens.green;

    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: pct,
              strokeWidth: 7,
              backgroundColor: NudgeTokens.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(pct * 100).round()}%',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                isOver ? 'over' : 'used',
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  color: NudgeTokens.textLow,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
