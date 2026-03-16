// lib/screens/health/health_center_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../app.dart' show NudgeTokens;
import '../../services/health_center_service.dart';
import '../../utils/health_service.dart';
import '../../utils/nudge_theme_extension.dart';
import 'sleep_screen.dart';
import 'goals_screen.dart';
import '../activity/steps_detail_screen.dart';
import '../gym/gym_screen.dart';

class HealthCenterScreen extends StatefulWidget {
  const HealthCenterScreen({super.key});

  @override
  State<HealthCenterScreen> createState() => _HealthCenterScreenState();
}

extension on BuildContext {
  NudgeThemeExtension get nudgeTheme => Theme.of(this).extension<NudgeThemeExtension>()!;
}

class _HealthCenterScreenState extends State<HealthCenterScreen> {
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _recovery = {};
  bool _loading = true;
  DateTime _selectedDate = DateTime.now();

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  BoxDecoration _cardDecor(BuildContext context) {
    return context.nudgeTheme.cardDecoration(context);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    if (_isToday) await HealthCenterService.tryAutoLogWeight();
    final results = await Future.wait([
      HealthCenterService.getStatsForDate(_selectedDate),
      HealthCenterService.getRecoveryStats(),
    ]);
    if (mounted) {
      setState(() {
        _stats = results[0];
        _recovery = results[1];
        _loading = false;
      });
    }
  }

  void _goDay(int delta) {
    final next = _selectedDate.add(Duration(days: delta));
    if (next.isAfter(DateTime.now())) return; // no future dates
    setState(() => _selectedDate = next);
    _load();
  }

  String _dateLabel() {
    final now = DateTime.now();
    if (_isToday) return 'Today';
    final yesterday = now.subtract(const Duration(days: 1));
    if (_selectedDate.year == yesterday.year &&
        _selectedDate.month == yesterday.month &&
        _selectedDate.day == yesterday.day) { return 'Yesterday'; }
    return '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}';
  }

  // ── Helper getters ────────────────────────────────────────────────────────

  double get _caloriesIn => (_stats['caloriesIn'] as num?)?.toDouble() ?? 0;
  int get _caloriesTarget => (_stats['caloriesTarget'] as num?)?.toInt() ?? 2000;
  double get _protein => (_stats['protein'] as num?)?.toDouble() ?? 0;
  double get _carbs   => (_stats['carbs']   as num?)?.toDouble() ?? 0;
  double get _fat     => (_stats['fat']     as num?)?.toDouble() ?? 0;
  double get _fibre   => (_stats['fibre']   as num?)?.toDouble() ?? 0;
  int get _proteinTarget => (_stats['proteinTarget'] as num?)?.toInt() ?? 150;
  int get _carbsTarget   => (_stats['carbsTarget']   as num?)?.toInt() ?? 200;
  int get _fatTarget     => (_stats['fatTarget']     as num?)?.toInt() ?? 65;
  int get _fibreTarget   => (_stats['fibreTarget']   as num?)?.toInt() ?? 30;
  double get _steps          => (_stats['steps']          as num?)?.toDouble() ?? 0;
  double get _caloriesBurned => (_stats['caloriesBurned'] as num?)?.toDouble() ?? 0;
  double get _distanceKm     => (_stats['distanceKm']     as num?)?.toDouble() ?? 0;
  double get _waterMl        => (_stats['waterMl']        as num?)?.toDouble() ?? 0;
  double get _runningCal     => (_stats['runningCal']     as num?)?.toDouble() ?? 0;
  double get _workoutCal     => (_stats['workoutCal']     as num?)?.toDouble() ?? 0;
  double get _walkingDistKm  => (_stats['walkingDistKm']  as num?)?.toDouble() ?? 0;
  double get _runningDistKm  => (_stats['runningDistKm']  as num?)?.toDouble() ?? 0;
  int get _workouts          => (_stats['workoutsToday']  as num?)?.toInt() ?? 0;
  int get _weeklyWorkouts    => (_stats['weeklyWorkouts'] as num?)?.toInt() ?? 0;
  // goals
  int get _stepsGoal          => (_stats['stepsGoal']         as num?)?.toInt() ?? 10000;
  int get _calBurnedGoal      => (_stats['caloriesBurnedGoal'] as num?)?.toInt() ?? 500;
  double get _distGoal        => (_stats['distanceGoalKm']    as num?)?.toDouble() ?? 5.0;
  int get _weeklyWorkoutsGoal => (_stats['weeklyWorkoutsGoal'] as num?)?.toInt() ?? 3;

  String _goalLabel() {
    switch (HealthCenterService.goal) {
      case 'lose':   return 'Weight Loss';
      case 'gain':   return 'Muscle Gain';
      default:       return 'Maintenance';
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _logWeight() async {
    final existing = HealthCenterService.getTodayWeight();
    final ctrl = TextEditingController(
      text: existing != null ? existing.toStringAsFixed(1) : '',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NudgeTokens.card,
        title: Text('Log Weight',
            style: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh), fontSize: 15, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh)),
          decoration: const InputDecoration(
            suffixText: 'kg',
            suffixStyle: TextStyle(color: NudgeTokens.textLow),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: NudgeTokens.border)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: NudgeTokens.healthB)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel', style: TextStyle(color: NudgeTokens.textLow))),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save', style: TextStyle(color: NudgeTokens.healthB))),
        ],
      ),
    );
    if (confirmed == true) {
      final kg = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
      if (kg != null && kg > 0) {
        await HealthCenterService.logWeight(kg);
        _load();
      }
    }
  }

  Future<void> _logWater() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NudgeTokens.card,
        title: Text('Log Water',
            style: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh), fontSize: 15, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh)),
          decoration: const InputDecoration(
            suffixText: 'ml',
            suffixStyle: TextStyle(color: NudgeTokens.textLow),
            hintText: 'e.g. 250',
            hintStyle: TextStyle(color: NudgeTokens.textLow),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: NudgeTokens.border)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: NudgeTokens.healthB)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel', style: TextStyle(color: NudgeTokens.textLow))),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save', style: TextStyle(color: NudgeTokens.healthB))),
        ],
      ),
    );
    if (confirmed == true) {
      final ml = int.tryParse(ctrl.text.trim());
      if (ml != null && ml > 0) {
        await HealthService.addLocalWater(ml.toDouble());
        _load();
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text('HEALTH CENTER',
                style: TextStyle(
                  color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                )),
            if (!_isToday)
              Text(_dateLabel(),
                  style: const TextStyle(color: NudgeTokens.healthB, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
        centerTitle: true,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.chevron_left_rounded, color: NudgeTokens.textMid),
              onPressed: () => _goDay(-1),
            ),
          ],
        ),
        actions: [
          IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(Icons.chevron_right_rounded,
                color: _isToday ? NudgeTokens.border : NudgeTokens.textMid),
            onPressed: _isToday ? null : () => _goDay(1),
          ),
          IconButton(
            icon: Icon(Icons.calendar_today_rounded,
                color: _isToday ? NudgeTokens.textMid : NudgeTokens.healthB,
                size: 18),
            tooltip: 'Pick date',
            onPressed: _pickDate,
          ),
          IconButton(
            onPressed: _openCardioGoalsSheet,
            icon: const Icon(Icons.flag_outlined, color: NudgeTokens.textMid),
            tooltip: 'Activity Goals',
          ),
          IconButton(
            onPressed: _openProfileSheet,
            icon: const Icon(Icons.person_outline_rounded, color: NudgeTokens.textMid),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Content ───────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: NudgeTokens.healthB))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: NudgeTokens.healthB,
                    backgroundColor: NudgeTokens.card,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                      children: [
                  _ProfileStrip(),
                  const SizedBox(height: 16),
                  _CalorieRingCard(
                    eaten: _caloriesIn,
                    target: _caloriesTarget,
                    burned: _caloriesBurned,
                  ),
                  const SizedBox(height: 12),
                  _MacroBarsCard(
                    protein: _protein, proteinTarget: _proteinTarget,
                    carbs: _carbs,     carbsTarget: _carbsTarget,
                    fat: _fat,         fatTarget: _fatTarget,
                    fibre: _fibre,     fibreTarget: _fibreTarget,
                  ),
                  const SizedBox(height: 12),
                  _ActivityGoalsCard(
                    steps: _steps,           stepsGoal: _stepsGoal,
                    burned: _caloriesBurned, burnedGoal: _calBurnedGoal,
                    distanceKm: _distanceKm, distanceGoal: _distGoal,
                    weeklyWorkouts: _weeklyWorkouts, weeklyGoal: _weeklyWorkoutsGoal,
                    waterMl: _waterMl,
                    onEditGoals: _openCardioGoalsSheet,
                    onTapMetric: _showGoalRawData,
                  ),
                  const SizedBox(height: 16),
                  _WeightChartCard(onLogWeight: _logWeight),
                  const SizedBox(height: 12),
                  _QuickLogRow(onLogWeight: _logWeight, onLogWater: _logWater, waterMl: _waterMl),
                  const SizedBox(height: 12),
                  _BodyMetricsRow(),
                  const SizedBox(height: 12),
                  _RecoveryCard(recovery: _recovery),
                  const SizedBox(height: 12),
                  _SettingTile(
                    icon: Icons.nights_stay_rounded,
                    title: 'Sleep Cycle',
                    subtitle: 'View inferred sleep data',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SleepScreen()));
                    },
                    trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow),
                  ),
                  _SettingTile(
                    icon: Icons.schedule_rounded,
                    title: 'Day Boundary',
                    subtitle: 'Set when your day starts (e.g. 6 AM for night owls)',
                    onTap: _openDayBoundarySheet,
                    trailing: Text(
                      () {
                        final h = HealthService.getDayStartHour();
                        if (h == 0) return 'Midnight';
                        final suffix = h < 12 ? 'AM' : 'PM';
                        final disp = h % 12 == 0 ? 12 : h % 12;
                        return '$disp:00 $suffix';
                      }(),
                      style: const TextStyle(color: NudgeTokens.textLow, fontSize: 12, fontWeight: FontWeight.w600),
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

  // ── Profile sheet ─────────────────────────────────────────────────────────

  void _openProfileSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NudgeTokens.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ProfileSheet(onSaved: _load),
    );
  }

  void _openCardioGoalsSheet() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GoalsScreen()));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: NudgeTokens.healthB,
            onPrimary: NudgeTokens.textHigh,
            surface: NudgeTokens.card,
            onSurface: NudgeTokens.textMid,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _load();
    }
  }

  void _showGoalRawData(String metric) {
    switch (metric) {
      case 'steps':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const StepsDetailScreen()));
        break;
      case 'burn':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _RawDataScreen(
              title: 'Calories Burned',
              date: _selectedDate,
              keys: const ['active_cal', 'basal_cal', 'total_cal'],
              summary: {
                'Total': '${_caloriesBurned.round()} kcal',
                'Running': '${_runningCal.round()} kcal',
                'Workout': '${_workoutCal.round()} kcal',
              },
            ),
          ),
        );
        break;
      case 'distance':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _RawDataScreen(
              title: 'Distance',
              date: _selectedDate,
              keys: const ['distance'],
              summary: {
                'Total': '${_distanceKm.toStringAsFixed(2)} km',
                'Walking': '${_walkingDistKm.toStringAsFixed(2)} km',
                'Running': '${_runningDistKm.toStringAsFixed(2)} km',
              },
            ),
          ),
        );
        break;
      case 'week':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const GymScreen()));
        break;
    }
  }

  void _openDayBoundarySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: NudgeTokens.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _DayBoundarySheet(onSaved: _load),
    );
  }
}

// ─── Profile strip ────────────────────────────────────────────────────────────

class _ProfileStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final name = HealthCenterService.displayName;
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';
    final wt = HealthCenterService.getLatestWeight();
    final tgt = HealthCenterService.targetWeightKg;
    final goal = _goalLabel(HealthCenterService.goal);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: NudgeTokens.healthA,
              border: Border.all(color: NudgeTokens.healthB.withValues(alpha: 0.4)),
            ),
            alignment: Alignment.center,
            child: Text(initials,
                style: const TextStyle(
                    color: NudgeTokens.healthB, fontWeight: FontWeight.w900, fontSize: 16)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : 'Set up your profile',
                  style: TextStyle(
                      color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh), fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(goal,
                    style: const TextStyle(color: NudgeTokens.textLow, fontSize: 12)),
              ],
            ),
          ),
          // Weight progress
          if (wt != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${wt.toStringAsFixed(1)} kg',
                  style: TextStyle(
                      color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh),
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
                if (tgt != null)
                  Text('Goal: ${tgt.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                          color: NudgeTokens.textLow, fontSize: 11)),
              ],
            ),
        ],
      ),
    );
  }

  String _goalLabel(String g) {
    switch (g) {
      case 'lose':   return 'Goal · Weight Loss';
      case 'gain':   return 'Goal · Muscle Gain';
      default:       return 'Goal · Maintenance';
    }
  }
}

// ─── Calorie ring card ────────────────────────────────────────────────────────

class _CalorieRingCard extends StatelessWidget {
  final double eaten;
  final int target;
  final double burned;

  const _CalorieRingCard({
    required this.eaten,
    required this.target,
    required this.burned,
  });

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? (eaten / target).clamp(0.0, 1.0) : 0.0;
    final isOver = eaten > target;
    final ringColor = isOver ? NudgeTokens.red : NudgeTokens.gymB;
    final remaining = (target - eaten).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Row(
        children: [
          // Ring
          SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(110, 110),
                  painter: _RingPainter(progress: progress, color: ringColor),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      eaten.toInt().toString(),
                      style: TextStyle(
                          color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh),
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                          height: 1),
                    ),
                    const Text('kcal',
                        style: TextStyle(
                            color: NudgeTokens.textLow, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _calRow('Target', '$target kcal', NudgeTokens.textMid),
                const SizedBox(height: 10),
                _calRow(
                  isOver ? 'Over by' : 'Remaining',
                  '${remaining.abs()} kcal',
                  isOver ? NudgeTokens.red : NudgeTokens.gymB,
                ),
                const SizedBox(height: 10),
                _calRow('Burned', '${burned.toInt()} kcal', NudgeTokens.healthB),
                if (burned > 0) ...[
                  const SizedBox(height: 10),
                  _calRow('Net', '${(eaten - burned).toInt()} kcal', NudgeTokens.textMid),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _calRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: NudgeTokens.textLow, fontSize: 12)),
        Text(value,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ─── Activity goals card ──────────────────────────────────────────────────────

class _ActivityGoalsCard extends StatelessWidget {
  final double steps;
  final int stepsGoal;
  final double burned;
  final int burnedGoal;
  final double distanceKm;
  final double distanceGoal;
  final int weeklyWorkouts;
  final int weeklyGoal;
  final double waterMl;
  final VoidCallback onEditGoals;
  final void Function(String metric) onTapMetric;

  const _ActivityGoalsCard({
    required this.steps,           required this.stepsGoal,
    required this.burned,          required this.burnedGoal,
    required this.distanceKm,      required this.distanceGoal,
    required this.weeklyWorkouts,  required this.weeklyGoal,
    required this.waterMl,
    required this.onEditGoals,
    required this.onTapMetric,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ACTIVITY GOALS',
                  style: TextStyle(
                      color: NudgeTokens.textLow,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4)),
              GestureDetector(
                onTap: onEditGoals,
                child: const Text('EDIT',
                    style: TextStyle(
                        color: NudgeTokens.healthB,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: GestureDetector(onTap: () => onTapMetric('steps'),    child: _goalTile(context, Icons.directions_walk_rounded, 'Steps', steps, stepsGoal.toDouble(), NudgeTokens.gymB, 'steps'))),
              const SizedBox(width: 8),
              Expanded(child: GestureDetector(onTap: () => onTapMetric('burn'),     child: _goalTile(context, Icons.local_fire_department_rounded, 'Burn', burned, burnedGoal.toDouble(), NudgeTokens.amber, 'kcal'))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: GestureDetector(onTap: () => onTapMetric('distance'), child: _goalTile(context, Icons.straighten_rounded, 'Distance', distanceKm, distanceGoal, NudgeTokens.healthB, 'km'))),
              const SizedBox(width: 8),
              Expanded(child: GestureDetector(onTap: () => onTapMetric('week'),     child: _goalTile(context, Icons.fitness_center_rounded, 'Week', weeklyWorkouts.toDouble(), weeklyGoal.toDouble(), NudgeTokens.purple, 'sessions'))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _goalTile(BuildContext context, IconData icon, String label, double current, double target, Color color, String unit) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: NudgeTokens.textLow, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text('${current.toInt()} / ${target.toInt()} $unit',
              style: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh), fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: NudgeTokens.border,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (size.width / 2) - 8;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Track
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi,
        false,
        Paint()
          ..color = NudgeTokens.elevated
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round);

    // Progress
    if (progress > 0) {
      canvas.drawArc(
          rect,
          -math.pi / 2,
          2 * math.pi * progress,
          false,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 10
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: NudgeTokens.purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: NudgeTokens.purple, size: 20),
        ),
        title: Text(title, style: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh), fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(color: NudgeTokens.textLow, fontSize: 12)),
        trailing: trailing,
      ),
    );
  }
}

// ─── Macro bars card ──────────────────────────────────────────────────────────

class _MacroBarsCard extends StatelessWidget {
  final double protein, carbs, fat, fibre;
  final int proteinTarget, carbsTarget, fatTarget, fibreTarget;

  const _MacroBarsCard({
    required this.protein, required this.proteinTarget,
    required this.carbs,   required this.carbsTarget,
    required this.fat,     required this.fatTarget,
    required this.fibre,   required this.fibreTarget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Column(
        children: [
          _macroRow('Protein', protein, proteinTarget, NudgeTokens.healthB),
          const SizedBox(height: 10),
          _macroRow('Carbs', carbs, carbsTarget, NudgeTokens.amber),
          const SizedBox(height: 10),
          _macroRow('Fat', fat, fatTarget, NudgeTokens.red),
          const SizedBox(height: 10),
          _macroRow('Fibre', fibre, fibreTarget, NudgeTokens.green),
        ],
      ),
    );
  }

  Widget _macroRow(String label, double current, int target, Color color) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(label,
              style: const TextStyle(
                  color: NudgeTokens.textLow, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: NudgeTokens.elevated,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 70,
          child: Text(
            '${current.toInt()}/${target}g',
            textAlign: TextAlign.right,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

// ─── Stats row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final double steps, burned, waterMl;
  final int workouts;

  const _StatsRow({
    required this.steps,
    required this.burned,
    required this.waterMl,
    required this.workouts,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _chip(context, Icons.directions_walk_rounded,
            '${steps.toInt()}', 'steps', NudgeTokens.gymB)),
        const SizedBox(width: 8),
        Expanded(child: _chip(context, Icons.local_fire_department_rounded,
            '${burned.toInt()}', 'kcal burned', NudgeTokens.amber)),
        const SizedBox(width: 8),
        Expanded(child: _chip(context, Icons.water_drop_rounded,
            (waterMl / 1000).toStringAsFixed(1), 'L water', NudgeTokens.healthB)),
        const SizedBox(width: 8),
        Expanded(child: _chip(context, Icons.fitness_center_rounded,
            '$workouts', 'workout${workouts != 1 ? 's' : ''}', NudgeTokens.purple)),
      ],
    );
  }

  Widget _chip(BuildContext context, IconData icon, String val, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 5),
          Text(val,
              style: TextStyle(
                  color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh),
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
          Text(label,
              style: const TextStyle(
                  color: NudgeTokens.textLow, fontSize: 9),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─── Weight chart card ────────────────────────────────────────────────────────

class _WeightChartCard extends StatelessWidget {
  final VoidCallback onLogWeight;
  const _WeightChartCard({required this.onLogWeight});

  @override
  Widget build(BuildContext context) {
    final log = HealthCenterService.getWeightLog();
    final target = HealthCenterService.targetWeightKg;
    final todaySource = HealthCenterService.getTodayWeightSource();
    final startWeight = HealthCenterService.getStartWeight();

    // Build sorted entries for last 30 days
    final sorted = log.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final last30 = sorted.length > 30 ? sorted.sublist(sorted.length - 30) : sorted;

    final spots = <FlSpot>[];
    final avgSpots = <FlSpot>[]; // 7-day moving average
    final sources = <String>[];
    final dateLabels = <double, String>{};

    double? height = HealthCenterService.heightCm;
    double? minNormalWeight;
    double? maxNormalWeight;
    if (height != null) {
      minNormalWeight = 18.5 * (height / 100) * (height / 100);
      maxNormalWeight = 24.9 * (height / 100) * (height / 100);
    }

    final rawPoints = last30.toList();
    for (int i = 0; i < rawPoints.length; i++) {
      final entry = rawPoints[i];
      final kg = (entry.value['kg'] as num?)?.toDouble();
      final dt = DateTime.tryParse(entry.key);
      if (kg != null && dt != null) {
        final x = i.toDouble();
        spots.add(FlSpot(x, kg));
        sources.add((entry.value['source'] as String?) ?? 'manual');
        dateLabels[x] = '${dt.day}/${dt.month}';

        // Moving average (7-day)
        int start = math.max(0, i - 6);
        double sum = 0;
        int count = 0;
        for (int j = start; j <= i; j++) {
          final val = (rawPoints[j].value['kg'] as num?)?.toDouble();
          if (val != null) {
            sum += val;
            count++;
          }
        }
        avgSpots.add(FlSpot(x, sum / count));
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 24, 12),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Weight Trend',
                      style: TextStyle(
                          color: NudgeTokens.textLow,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4)),
                  if (spots.isNotEmpty)
                    Text(
                      '${spots.last.y.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  if (startWeight != null && spots.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Start: ${startWeight.toStringAsFixed(1)} kg',
                        style: const TextStyle(
                            color: NudgeTokens.textLow, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              _LogWeightMiniButton(onLogWeight: onLogWeight),
            ],
          ),
          const SizedBox(height: 16),
          if (spots.isEmpty)
            _EmptyState(onLogWeight: onLogWeight)
          else
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => NudgeTokens.surface.withValues(alpha: 0.95),
                      tooltipRoundedRadius: 12,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          if (spot.barIndex != 1) return null; // Tooltip for main line only
                          final src = sources[spot.spotIndex];
                          final date = dateLabels[spot.x] ?? '';
                          
                          String deltaText = '';
                          if (spot.spotIndex > 0) {
                            final delta = spot.y - spots[spot.spotIndex - 1].y;
                            final deltaSign = delta >= 0 ? '+' : '';
                            deltaText = '\n$deltaSign${delta.toStringAsFixed(1)}kg vs last';
                          }

                          return LineTooltipItem(
                            '${spot.y.toStringAsFixed(1)} kg\n$date ($src)$deltaText',
                            const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _yInterval(spots),
                    getDrawingHorizontalLine: (_) => const FlLine(
                        color: NudgeTokens.border, strokeWidth: 0.5),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: _yInterval(spots),
                        getTitlesWidget: (v, _) => Text(
                          v.toStringAsFixed(0),
                          style: const TextStyle(
                              color: NudgeTokens.textLow, fontSize: 9),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: spots.length > 20 ? 7 : (spots.length > 10 ? 5 : 3), 
                        getTitlesWidget: (v, _) {
                          final label = dateLabels[v];
                          if (label == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(label, style: const TextStyle(color: NudgeTokens.textLow, fontSize: 9)),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    // Moving Average
                    LineChartBarData(
                      spots: avgSpots,
                      isCurved: true,
                      color: Colors.orange.withValues(alpha: 0.4),
                      barWidth: 2,
                      dashArray: [5, 5],
                      dotData: const FlDotData(show: false),
                    ),
                    // Main Bar
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: NudgeTokens.healthB,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            NudgeTokens.healthB.withValues(alpha: 0.2),
                            NudgeTokens.healthB.withValues(alpha: 0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          final src = index < sources.length ? sources[index] : 'manual';
                          return FlDotCirclePainter(
                            radius: 4,
                            color: src == 'manual' ? NudgeTokens.gymB : NudgeTokens.healthB,
                            strokeWidth: 2,
                            strokeColor: Colors.black,
                          );
                        },
                      ),
                    ),
                  ],
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      if (target != null)
                        HorizontalLine(
                          y: target,
                          color: NudgeTokens.healthB.withValues(alpha: 0.6),
                          strokeWidth: 2,
                          dashArray: [10, 5],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            style: const TextStyle(color: NudgeTokens.healthB, fontSize: 9, fontWeight: FontWeight.bold),
                            labelResolver: (_) => 'Target ${target.toInt()}kg',
                          ),
                        ),
                    ],
                  ),
                  rangeAnnotations: RangeAnnotations(
                    horizontalRangeAnnotations: [
                      if (minNormalWeight != null && maxNormalWeight != null)
                        HorizontalRangeAnnotation(
                          y1: minNormalWeight,
                          y2: maxNormalWeight,
                          color: Colors.green.withValues(alpha: 0.05),
                        ),
                    ],
                  ),
                  minY: _minY(spots, target, minNormalWeight),
                  maxY: _maxY(spots, target, maxNormalWeight),
                ),
              ),
            ),
          // Legend
          if (spots.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                   const _LegendItem(color: NudgeTokens.gymB, label: 'Manual'),
                   const _LegendItem(color: NudgeTokens.healthB, label: 'Auto'),
                   _LegendItem(color: Colors.orange.withValues(alpha: 0.6), label: '7d Avg', dotted: true),
                   if (minNormalWeight != null)
                     _LegendItem(color: Colors.green.withValues(alpha: 0.2), label: 'Healthy Range'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  double _minY(List<FlSpot> spots, double? target, double? rangeMin) {
    if (spots.isEmpty) return 40;
    var min = spots.map((s) => s.y).reduce(math.min);
    if (target != null && target < min) min = target;
    if (rangeMin != null && rangeMin < min) min = rangeMin;
    
    // Round down to nearest 5
    return ((min - 2) / 5).floorToDouble() * 5;
  }

  double _maxY(List<FlSpot> spots, double? target, double? rangeMax) {
    if (spots.isEmpty) return 100;
    var max = spots.map((s) => s.y).reduce(math.max);
    if (target != null && target > max) max = target;
    if (rangeMax != null && rangeMax > max) max = rangeMax;
    
    // Round up to nearest 5
    return ((max + 2) / 5).ceilToDouble() * 5;
  }

  double _yInterval(List<FlSpot> spots) {
    if (spots.isEmpty) return 10;
    final minY = _minY(spots, HealthCenterService.targetWeightKg, null);
    final maxY = _maxY(spots, HealthCenterService.targetWeightKg, null);
    final range = maxY - minY;
    
    if (range <= 10) return 2;
    if (range <= 25) return 5;
    if (range <= 50) return 10;
    return 20;
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool dotted;

  const _LegendItem({required this.color, required this.label, this.dotted = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: dotted ? Colors.transparent : color,
            border: dotted ? Border.all(color: color, width: 1.5) : null,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: NudgeTokens.textLow, fontSize: 10)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onLogWeight;
  const _EmptyState({required this.onLogWeight});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.monitor_weight_outlined, color: NudgeTokens.textLow, size: 32),
            const SizedBox(height: 8),
            const Text('No weight entries yet', style: TextStyle(color: NudgeTokens.textLow, fontSize: 13)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onLogWeight,
              child: const Text('Log today\'s weight', style: TextStyle(color: NudgeTokens.healthB)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogWeightMiniButton extends StatelessWidget {
  final VoidCallback onLogWeight;
  const _LogWeightMiniButton({required this.onLogWeight});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onLogWeight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: NudgeTokens.healthB.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: NudgeTokens.healthB.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.add_rounded, color: NudgeTokens.healthB, size: 14),
            SizedBox(width: 2),
            Text('LOG', style: TextStyle(color: NudgeTokens.healthB, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}

// ─── Quick log row ────────────────────────────────────────────────────────────

class _QuickLogRow extends StatelessWidget {
  final VoidCallback onLogWeight;
  final VoidCallback onLogWater;
  final double waterMl;

  const _QuickLogRow({
    required this.onLogWeight,
    required this.onLogWater,
    required this.waterMl,
  });

  @override
  Widget build(BuildContext context) {
    final weight = HealthCenterService.getTodayWeight();
    final weightSrc = HealthCenterService.getTodayWeightSource();
    final weightVal = weight != null
        ? '${weight.toStringAsFixed(1)} kg${weightSrc == 'auto' ? '  AUTO' : ''}'
        : 'Not logged today';
    final waterVal = waterMl > 0
        ? '${(waterMl / 1000).toStringAsFixed(2)} L today'
        : 'Nothing logged';

    return Row(
      children: [
        Expanded(child: _logBtn(Icons.monitor_weight_outlined, 'Log Weight',
            NudgeTokens.gymB, weightVal, weight != null, onLogWeight)),
        const SizedBox(width: 10),
        Expanded(child: _logBtn(Icons.water_drop_rounded, 'Log Water',
            NudgeTokens.healthB, waterVal, waterMl > 0, onLogWater)),
      ],
    );
  }

  Widget _logBtn(IconData icon, String label, Color color, String currentVal,
      bool hasValue, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: hasValue
                  ? color.withValues(alpha: 0.4)
                  : color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 15),
                const SizedBox(width: 7),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              currentVal,
              style: TextStyle(
                  color: hasValue ? color : NudgeTokens.textLow,
                  fontSize: hasValue ? 15 : 11,
                  fontWeight:
                      hasValue ? FontWeight.w800 : FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Body metrics row ─────────────────────────────────────────────────────────

class _BodyMetricsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bmi = HealthCenterService.computeBMI();
    final bmr = HealthCenterService.computeBMR();
    final tdee = HealthCenterService.computeTDEE();

    String bmiLabel = '';
    Color bmiColor = (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh);
    if (bmi != null) {
      if (bmi < 18.5) { bmiLabel = 'Underweight'; bmiColor = NudgeTokens.blue; }
      else if (bmi < 25) { bmiLabel = 'Normal'; bmiColor = NudgeTokens.green; }
      else if (bmi < 30) { bmiLabel = 'Overweight'; bmiColor = NudgeTokens.amber; }
      else { bmiLabel = 'Obese'; bmiColor = NudgeTokens.red; }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('BODY METRICS',
              style: TextStyle(
                  color: NudgeTokens.textLow,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _metricTile(context, 'BMI',
                  bmi != null ? bmi.toStringAsFixed(1) : '—',
                  bmiLabel, valueColor: bmiColor, subColor: bmiColor.withValues(alpha: 0.7))),
              Expanded(child: _metricTile(context, 'BMR',
                  bmr != null ? '${bmr.round()} kcal' : '—',
                  'at rest', valueColor: NudgeTokens.healthB)),
              Expanded(child: _metricTile(context, 'TDEE',
                  tdee != null ? '$tdee kcal' : '—',
                  'daily burn', valueColor: NudgeTokens.gymB)),
            ],
          ),
          if (bmi == null || bmr == null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Complete your profile to see metrics',
                style: TextStyle(
                    color: NudgeTokens.textLow.withValues(alpha: 0.6),
                    fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _metricTile(BuildContext context, String label, String value, String sub,
      {Color? valueColor, Color? subColor}) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: valueColor ?? (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh),
                fontWeight: FontWeight.w800,
                fontSize: 16)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: NudgeTokens.textLow,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
        Text(sub,
            style: TextStyle(color: subColor ?? NudgeTokens.textLow, fontSize: 9)),
      ],
    );
  }
}

// ─── Profile sheet ────────────────────────────────────────────────────────────

class _ProfileSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const _ProfileSheet({required this.onSaved});

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  final _nameCtrl   = TextEditingController();
  final _ageCtrl    = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();

  String _gender   = 'male';
  String _goal     = 'maintain';
  String _activity = 'moderate';
  DateTime? _targetDate;

  @override
  void initState() {
    super.initState();
    final p = HealthCenterService.profile;
    _nameCtrl.text   = (p['name'] as String?) ?? '';
    _ageCtrl.text    = (p['age'] != null) ? p['age'].toString() : '';
    _heightCtrl.text = (p['heightCm'] as num?) != null
        ? (p['heightCm'] as num).toStringAsFixed(0) : '';
    _weightCtrl.text = (p['weightKg'] as num?) != null
        ? (p['weightKg'] as num).toStringAsFixed(1) : '';
    _targetCtrl.text = (p['targetWeightKg'] as num?) != null
        ? (p['targetWeightKg'] as num).toStringAsFixed(1) : '';
    _gender   = (p['gender']        as String?) ?? 'male';
    _goal     = (p['goal']          as String?) ?? 'maintain';
    _activity = (p['activityLevel'] as String?) ?? 'moderate';
    _targetDate = HealthCenterService.targetWeightDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await HealthCenterService.saveProfile({
      'name':           _nameCtrl.text.trim(),
      'age':            int.tryParse(_ageCtrl.text.trim()),
      'heightCm':       double.tryParse(_heightCtrl.text.trim().replaceAll(',', '.')),
      'weightKg':       double.tryParse(_weightCtrl.text.trim().replaceAll(',', '.')),
      'targetWeightKg': double.tryParse(_targetCtrl.text.trim().replaceAll(',', '.')),
      'gender':   _gender,
      'goal':     _goal,
      'activityLevel': _activity,
      'targetWeightDate': _targetDate?.toIso8601String(),
    });
    widget.onSaved();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: NudgeTokens.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('YOUR PROFILE',
                style: TextStyle(
                    color: NudgeTokens.textLow,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4)),
            const SizedBox(height: 20),

            _field('Name', _nameCtrl, hint: 'Your name'),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _field('Age', _ageCtrl,
                  hint: 'e.g. 25', keyboard: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _field('Height (cm)', _heightCtrl,
                  hint: 'e.g. 175', keyboard: TextInputType.number)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _field('Weight (kg)', _weightCtrl,
                  hint: 'e.g. 75.0', keyboard: const TextInputType.numberWithOptions(decimal: true))),
              const SizedBox(width: 12),
              Expanded(child: _field('Target (kg)', _targetCtrl,
                  hint: 'e.g. 70.0', keyboard: const TextInputType.numberWithOptions(decimal: true))),
            ]),
            const SizedBox(height: 14),
            _label('Target Reach Date'),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                );
                if (d != null) setState(() => _targetDate = d);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: NudgeTokens.elevated, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, color: NudgeTokens.textMid, size: 18),
                    const SizedBox(width: 12),
                    Text(_targetDate == null ? 'Set date' : '${_targetDate!.day}/${_targetDate!.month}/${_targetDate!.year}', style: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Gender
            _label('Gender'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'male',   label: Text('Male')),
                ButtonSegment(value: 'female', label: Text('Female')),
                ButtonSegment(value: 'other',  label: Text('Other')),
              ],
              selected: {_gender},
              onSelectionChanged: (s) => setState(() => _gender = s.first),
              style: _segStyle(),
            ),
            const SizedBox(height: 16),

            // Goal
            _label('Goal'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'lose',     label: Text('Lose')),
                ButtonSegment(value: 'maintain', label: Text('Maintain')),
                ButtonSegment(value: 'gain',     label: Text('Gain')),
              ],
              selected: {_goal},
              onSelectionChanged: (s) => setState(() => _goal = s.first),
              style: _segStyle(),
            ),
            const SizedBox(height: 16),

            // Activity
            _label('Activity Level'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _activity,
              dropdownColor: NudgeTokens.elevated,
              style: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh), fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: NudgeTokens.elevated,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              items: const [
                DropdownMenuItem(value: 'sedentary', child: Text('Sedentary (desk job, no exercise)')),
                DropdownMenuItem(value: 'light',     child: Text('Light (1–2 workouts/week)')),
                DropdownMenuItem(value: 'moderate',  child: Text('Moderate (3–5 workouts/week)')),
                DropdownMenuItem(value: 'active',    child: Text('Active (6–7 workouts/week)')),
                DropdownMenuItem(value: 'very_active', child: Text('Very Active (athlete / physical job)')),
              ],
              onChanged: (v) { if (v != null) setState(() => _activity = v); },
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                    backgroundColor: NudgeTokens.healthB,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('SAVE PROFILE',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {String? hint, TextInputType? keyboard}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          style: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh), fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: NudgeTokens.textLow, fontSize: 13),
            filled: true,
            fillColor: NudgeTokens.elevated,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Text(text,
        style: const TextStyle(
            color: NudgeTokens.textMid, fontSize: 12, fontWeight: FontWeight.w600));
  }

  ButtonStyle _segStyle() {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return NudgeTokens.healthB.withValues(alpha: 0.18);
        }
        return NudgeTokens.elevated;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return NudgeTokens.healthB;
        return NudgeTokens.textLow;
      }),
      side: const WidgetStatePropertyAll(BorderSide(color: NudgeTokens.border)),
    );
  }
}
// ─── Cardio goals sheet ───────────────────────────────────────────────────────

class _CardioGoalsSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const _CardioGoalsSheet({required this.onSaved});

  @override
  State<_CardioGoalsSheet> createState() => _CardioGoalsSheetState();
}

class _CardioGoalsSheetState extends State<_CardioGoalsSheet> {
  final _stepsCtrl    = TextEditingController();
  final _burnedCtrl   = TextEditingController();
  final _distanceCtrl = TextEditingController();
  final _weeklyCtrl   = TextEditingController();

  @override
  void initState() {
    super.initState();
    _stepsCtrl.text    = HealthCenterService.stepsGoal.toString();
    _burnedCtrl.text   = HealthCenterService.caloriesBurnedGoal.toString();
    _distanceCtrl.text = HealthCenterService.distanceGoalKm.toString();
    _weeklyCtrl.text   = HealthCenterService.weeklyWorkoutsGoal.toString();
  }

  @override
  void dispose() {
    _stepsCtrl.dispose();
    _burnedCtrl.dispose();
    _distanceCtrl.dispose();
    _weeklyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await HealthCenterService.saveCardioGoals(
      steps: int.tryParse(_stepsCtrl.text.trim()),
      caloriesBurned: int.tryParse(_burnedCtrl.text.trim()),
      distanceKm: double.tryParse(_distanceCtrl.text.trim().replaceAll(',', '.')),
      weeklyWorkouts: int.tryParse(_weeklyCtrl.text.trim()),
    );
    widget.onSaved();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: NudgeTokens.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Text('ACTIVITY GOALS',
              style: TextStyle(color: NudgeTokens.textLow, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
          const SizedBox(height: 20),
          _field('Daily Steps', _stepsCtrl, keyboard: TextInputType.number),
          const SizedBox(height: 14),
          _field('Daily Calories Burned', _burnedCtrl, keyboard: TextInputType.number),
          const SizedBox(height: 14),
          _field('Daily Distance (km)', _distanceCtrl, keyboard: const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 14),
          _field('Weekly Workouts', _weeklyCtrl, keyboard: TextInputType.number),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                  backgroundColor: NudgeTokens.healthB, foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('SAVE GOALS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {TextInputType? keyboard}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: NudgeTokens.textMid, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          style: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh), fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: NudgeTokens.elevated,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

// ─── Recovery Card ─────────────────────────────────────────────────────────────

class _RecoveryCard extends StatelessWidget {
  final Map<String, dynamic> recovery;
  const _RecoveryCard({required this.recovery});

  @override
  Widget build(BuildContext context) {
    final score = recovery['recoveryScore'] as int?;
    final rhr   = (recovery['restingHrBpm'] as num?)?.toDouble();
    final hrv   = (recovery['hrvMs'] as num?)?.toDouble();
    final avg7  = (recovery['avgHrv7d'] as num?)?.toDouble();

    Color scoreColor;
    String scoreLabel;
    if (score == null) {
      scoreColor = NudgeTokens.textLow;
      scoreLabel = '--';
    } else if (score >= 75) {
      scoreColor = NudgeTokens.green;
      scoreLabel = 'High';
    } else if (score >= 50) {
      scoreColor = NudgeTokens.amber;
      scoreLabel = 'Moderate';
    } else {
      scoreColor = NudgeTokens.red;
      scoreLabel = 'Low';
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
              const Icon(Icons.favorite_border_rounded, color: NudgeTokens.red, size: 16),
              const SizedBox(width: 8),
              const Text('RECOVERY', style: TextStyle(color: NudgeTokens.textLow, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              const Spacer(),
              if (score != null) ...[
                Text(score.toString(), style: TextStyle(color: scoreColor, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(width: 4),
                const Text('/100', style: TextStyle(color: NudgeTokens.textLow, fontSize: 12)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: scoreColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                  child: Text(scoreLabel, style: TextStyle(color: scoreColor, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ] else
                const Text('No HC data', style: TextStyle(color: NudgeTokens.textLow, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _RecovMetric(
                label: 'Resting HR',
                value: rhr != null ? '${rhr.round()} bpm' : '--',
                icon: Icons.monitor_heart_outlined,
                color: NudgeTokens.red,
                sub: rhr != null
                    ? (rhr < 60 ? 'Excellent' : rhr < 70 ? 'Good' : 'Elevated')
                    : null,
              ),
              const SizedBox(width: 10),
              _RecovMetric(
                label: 'HRV',
                value: hrv != null ? '${hrv.round()} ms' : '--',
                icon: Icons.timeline_rounded,
                color: NudgeTokens.purple,
                sub: avg7 != null && hrv != null
                    ? (hrv >= avg7 * 1.05
                        ? '↑ vs 7d avg'
                        : hrv <= avg7 * 0.95
                            ? '↓ vs 7d avg'
                            : 'avg ${avg7.round()} ms')
                    : null,
              ),
            ],
          ),
          if (score == null) ...[
            const SizedBox(height: 10),
            const Text(
              'Connect a wearable via Health Connect to see recovery data.',
              style: TextStyle(color: NudgeTokens.textLow, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecovMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? sub;
  const _RecovMetric({required this.label, required this.value, required this.icon, required this.color, this.sub});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: NudgeTokens.textLow, fontSize: 10, fontWeight: FontWeight.w600)),
                  Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
                  if (sub != null)
                    Text(sub!, style: const TextStyle(color: NudgeTokens.textLow, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─── Raw data screen (full-page, for burn / distance debug) ──────────────────

class _RawDataScreen extends StatefulWidget {
  final String title;
  final DateTime date;
  final List<String> keys; // which data types to show: 'active_cal', 'basal_cal', 'total_cal', 'distance'
  final Map<String, String> summary;

  const _RawDataScreen({
    required this.title,
    required this.date,
    required this.keys,
    required this.summary,
  });

  @override
  State<_RawDataScreen> createState() => _RawDataScreenState();
}

class _RawDataScreenState extends State<_RawDataScreen> {
  Map<String, List<Map<String, dynamic>>> _raw = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final data = await HealthService.fetchRawPointsForDebug(widget.date);
    if (mounted) setState(() { _raw = data; _loading = false; });
  }

  String _fmtTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      final s = dt.second.toString().padLeft(2, '0');
      return '$h:$m:$s';
    } catch (_) { return iso; }
  }

  String _fmtVal(String key, double val) {
    if (key == 'distance') return '${val.toStringAsFixed(1)} m';
    return '${val.toStringAsFixed(1)} kcal';
  }

  Color _keyColor(String key) {
    switch (key) {
      case 'active_cal':   return NudgeTokens.amber;
      case 'basal_cal':    return NudgeTokens.blue;
      case 'total_cal':    return NudgeTokens.green;
      case 'distance':     return NudgeTokens.healthB;
      default:             return NudgeTokens.textMid;
    }
  }

  @override
  Widget build(BuildContext context) {
    final allPoints = <Map<String, dynamic>>[];
    for (final key in widget.keys) {
      if (_raw.containsKey(key)) allPoints.addAll(_raw[key]!);
    }
    allPoints.sort((a, b) => (a['from'] as String).compareTo(b['from'] as String));

    // Group by source
    final bySource = <String, List<Map<String, dynamic>>>{};
    for (final p in allPoints) {
      final src = p['source'] as String;
      bySource.putIfAbsent(src, () => []).add(p);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetch),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: NudgeTokens.healthB))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // ── Summary strip ──
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: NudgeTokens.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: NudgeTokens.border),
                  ),
                  child: Wrap(
                    spacing: 16, runSpacing: 8,
                    children: widget.summary.entries.map((e) => Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.key, style: const TextStyle(color: NudgeTokens.textLow, fontSize: 10, fontWeight: FontWeight.w600)),
                        Text(e.value, style: const TextStyle(color: NudgeTokens.textHigh, fontSize: 14, fontWeight: FontWeight.w800)),
                      ],
                    )).toList(),
                  ),
                ),
                if (allPoints.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No raw data points found.\nCheck Health Connect permissions.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: NudgeTokens.textLow)),
                    ),
                  ),
                // ── Per-source sections ──
                for (final src in bySource.keys) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(src,
                        style: const TextStyle(color: NudgeTokens.textMid, fontSize: 11,
                            fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  ),
                  ...bySource[src]!.map((p) {
                    final key = widget.keys.firstWhere(
                      (k) => (p['typeLabel'] as String).toLowerCase().contains(k.replaceAll('_cal', '').replaceAll('_', ' ')),
                      orElse: () => widget.keys.first,
                    );
                    final color = _keyColor(key);
                    final val = (p['value'] as num).toDouble();
                    final fromStr = _fmtTime(p['from'] as String);
                    final toStr   = _fmtTime(p['to']   as String);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: NudgeTokens.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withValues(alpha: 0.25)),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$fromStr → $toStr',
                                  style: const TextStyle(color: NudgeTokens.textLow, fontSize: 10)),
                              Text(p['typeLabel'] as String,
                                  style: const TextStyle(color: NudgeTokens.textMid, fontSize: 11)),
                            ],
                          ),
                        ),
                        Text(_fmtVal(key, val),
                            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
                      ]),
                    );
                  }),
                ],
              ],
            ),
    );
  }
}

// ─── Day boundary sheet ───────────────────────────────────────────────────────

class _DayBoundarySheet extends StatefulWidget {
  final VoidCallback onSaved;
  const _DayBoundarySheet({required this.onSaved});

  @override
  State<_DayBoundarySheet> createState() => _DayBoundarySheetState();
}

class _DayBoundarySheetState extends State<_DayBoundarySheet> {
  late int _hour;

  @override
  void initState() {
    super.initState();
    _hour = HealthService.getDayStartHour();
  }

  String _label(int h) {
    if (h == 0) return 'Midnight (default)';
    final suffix = h < 12 ? 'AM' : 'PM';
    final disp = h % 12 == 0 ? 12 : h % 12;
    return '$disp:00 $suffix';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.schedule_rounded, color: NudgeTokens.healthB, size: 20),
              SizedBox(width: 8),
              Text('Day Boundary',
                  style: TextStyle(color: NudgeTokens.textHigh, fontSize: 16, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 6),
            const Text(
              'Set when your day starts. Data before this hour is counted as the previous day. '
              'Useful if you regularly sleep past midnight.',
              style: TextStyle(color: NudgeTokens.textLow, fontSize: 12),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Day starts at', style: TextStyle(color: NudgeTokens.textMid, fontSize: 13)),
                Text(_label(_hour),
                    style: const TextStyle(color: NudgeTokens.healthB, fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
            Slider(
              value: _hour.toDouble(),
              min: 0, max: 12,
              divisions: 12,
              activeColor: NudgeTokens.healthB,
              inactiveColor: NudgeTokens.border,
              label: _label(_hour),
              onChanged: (v) => setState(() => _hour = v.round()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Midnight', style: TextStyle(color: NudgeTokens.textLow, fontSize: 10)),
                Text('Noon', style: TextStyle(color: NudgeTokens.textLow, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: NudgeTokens.healthB),
                onPressed: () async {
                  await HealthService.setDayStartHour(_hour);
                  if (context.mounted) Navigator.pop(context);
                  widget.onSaved();
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
