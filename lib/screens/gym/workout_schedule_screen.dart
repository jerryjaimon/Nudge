// lib/screens/gym/workout_schedule_screen.dart
// Editable weekly workout schedule — linked from both Settings and Gym tabs.
// Stores in gymBox['workout_schedule'] as {'1': 'workout', '2': 'rest', ...}
// Keys are weekday numbers as strings (1=Mon…7=Sun).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app.dart' show NudgeTokens;
import '../../storage.dart';

/// Workout type labels and display config
const _typeLabel = {
  'workout': 'Workout',
  'rest': 'Rest',
};
const _typeIcon = {
  'workout': Icons.fitness_center_rounded,
  'rest': Icons.self_improvement_rounded,
};
const _typeColor = {
  'workout': NudgeTokens.gymB,
  'rest': NudgeTokens.textLow,
};

class WorkoutScheduleScreen extends StatefulWidget {
  const WorkoutScheduleScreen({super.key});

  @override
  State<WorkoutScheduleScreen> createState() =>
      _WorkoutScheduleScreenState();
}

class _WorkoutScheduleScreenState extends State<WorkoutScheduleScreen> {
  static const _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  // weekday string key '1'..'7' → type string
  Map<String, String> _schedule = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final box = await AppStorage.getGymBox();
    final raw = box.get('workout_schedule', defaultValue: <String, dynamic>{});
    final schedule = <String, String>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        schedule[k.toString()] = v.toString();
      });
    }
    // Migrate cardio → workout, fill defaults
    for (final k in schedule.keys.toList()) {
      if (schedule[k] == 'cardio') schedule[k] = 'workout';
    }
    for (int i = 1; i <= 7; i++) {
      schedule.putIfAbsent(i.toString(), () => 'rest');
    }
    if (mounted) setState(() { _schedule = schedule; _loading = false; });
  }

  Future<void> _save() async {
    final box = await AppStorage.getGymBox();
    await box.put('workout_schedule', Map<String, dynamic>.from(_schedule));
  }

  void _setType(int weekday, String type) {
    setState(() => _schedule[weekday.toString()] = type);
    _save();
  }

  String _cycleType(String current) {
    return current == 'workout' ? 'rest' : 'workout';
  }

  int get _workoutCount =>
      _schedule.values.where((t) => t == 'workout').length;
  int get _restCount =>
      _schedule.values.where((t) => t == 'rest').length;

  @override
  Widget build(BuildContext context) {
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
                color: NudgeTokens.gymB,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Workout Schedule',
              style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: NudgeTokens.border),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
              children: [
                // Summary strip
                _SummaryStrip(
                  workouts: _workoutCount,
                  rest: _restCount,
                ),
                const SizedBox(height: 20),

                Text(
                  'TAP A DAY TO CHANGE ITS TYPE',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: NudgeTokens.textLow,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),

                // Day rows
                for (int i = 0; i < _days.length; i++) ...[
                  _DayRow(
                    dayName: _days[i],
                    weekday: i + 1,
                    type: _schedule[(i + 1).toString()] ?? 'rest',
                    onTap: () => _setType(
                        i + 1,
                        _cycleType(
                            _schedule[(i + 1).toString()] ?? 'rest')),
                    onTypeSelected: (t) => _setType(i + 1, t),
                  ),
                  const SizedBox(height: 8),
                ],

                const SizedBox(height: 20),

                // Legend
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: NudgeTokens.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: NudgeTokens.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Legend',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: NudgeTokens.textMid,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final type in ['workout', 'rest'])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                _typeIcon[type],
                                size: 16,
                                color: _typeColor[type],
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _typeLabel[type]!,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _typeColor[type],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  type == 'workout'
                                      ? 'Strength / resistance training'
                                      : 'Recovery & mobility work',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: NudgeTokens.textLow,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Summary strip ─────────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  final int workouts;
  final int rest;
  const _SummaryStrip(
      {required this.workouts,
      required this.rest});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryItem(
              icon: Icons.fitness_center_rounded,
              color: NudgeTokens.gymB,
              value: '$workouts',
              label: 'Workout'),
          Container(width: 1, height: 30, color: NudgeTokens.border),
          _SummaryItem(
              icon: Icons.self_improvement_rounded,
              color: NudgeTokens.textLow,
              value: '$rest',
              label: 'Rest'),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _SummaryItem(
      {required this.icon,
      required this.color,
      required this.value,
      required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1)),
        Text(label,
            style: GoogleFonts.outfit(
                fontSize: 10, color: NudgeTokens.textLow)),
      ],
    );
  }
}

// ── Day row ───────────────────────────────────────────────────────────────────

class _DayRow extends StatelessWidget {
  final String dayName;
  final int weekday;
  final String type;
  final VoidCallback onTap;
  final ValueChanged<String> onTypeSelected;

  const _DayRow({
    required this.dayName,
    required this.weekday,
    required this.type,
    required this.onTap,
    required this.onTypeSelected,
  });

  bool get _isToday => DateTime.now().weekday == weekday;

  @override
  Widget build(BuildContext context) {
    final color = _typeColor[type] ?? NudgeTokens.textLow;
    final icon = _typeIcon[type] ?? Icons.help_outline_rounded;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _isToday
              ? color.withValues(alpha: 0.08)
              : NudgeTokens.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isToday
                ? color.withValues(alpha: 0.4)
                : NudgeTokens.border,
          ),
        ),
        child: Row(
          children: [
            // Day name
            SizedBox(
              width: 90,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dayName,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _isToday ? Colors.white : NudgeTokens.textMid,
                    ),
                  ),
                  if (_isToday)
                    Text(
                      'TODAY',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: color,
                        letterSpacing: 1,
                      ),
                    ),
                ],
              ),
            ),

            const Spacer(),

            // Type chips
            Row(
              mainAxisSize: MainAxisSize.min,
              children: ['workout', 'rest'].map((t) {
                final isSelected = type == t;
                final c = _typeColor[t] ?? NudgeTokens.textLow;
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: GestureDetector(
                    onTap: () => onTypeSelected(t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? c.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? c.withValues(alpha: 0.5)
                              : NudgeTokens.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _typeIcon[t],
                            size: 12,
                            color: isSelected ? c : NudgeTokens.textLow,
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 4),
                            Text(
                              _typeLabel[t]!,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: c,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(width: 8),
            Icon(icon, size: 20, color: color),
          ],
        ),
      ),
    );
  }
}
