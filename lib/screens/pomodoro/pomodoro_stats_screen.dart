// lib/screens/pomodoro/pomodoro_stats_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app.dart' show NudgeTokens;
import '../../storage.dart';

class PomodoroStatsScreen extends StatefulWidget {
  const PomodoroStatsScreen({super.key});

  @override
  State<PomodoroStatsScreen> createState() => _PomodoroStatsScreenState();
}

class _PomodoroStatsScreenState extends State<PomodoroStatsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final box = await AppStorage.getPomodoroBox();
    final rawProjects = (box.get('projects', defaultValue: <dynamic>[]) as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    rawProjects.sort((a, b) =>
        (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));

    final rawLogs = (box.get('logs', defaultValue: <dynamic>[]) as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    rawLogs.sort((a, b) =>
        (b['at'] as String? ?? '').compareTo(a['at'] as String? ?? ''));

    if (mounted) {
      setState(() {
        _projects = rawProjects;
        _logs = rawLogs;
        _loading = false;
      });
    }
  }

  int _totalProductiveMinutes() {
    int sum = 0;
    for (final l in _logs) {
      final kind = (l['kind'] as String?) ?? '';
      if (kind == 'work' || kind == 'manual') {
        sum += (l['minutes'] is int) ? (l['minutes'] as int) : 0;
      }
    }
    return sum;
  }

  Map<String, int> _minutesByProject() {
    final out = <String, int>{};
    for (final l in _logs) {
      final pid = (l['projectId'] as String?) ?? '';
      if (pid.isEmpty) continue;
      final kind = (l['kind'] as String?) ?? '';
      if (kind != 'work' && kind != 'manual') continue;
      final min = (l['minutes'] is int) ? (l['minutes'] as int) : 0;
      out[pid] = (out[pid] ?? 0) + min;
    }
    return out;
  }

  // Group logs by ISO date (YYYY-MM-DD)
  Map<String, List<Map<String, dynamic>>> _logsByDay() {
    final out = <String, List<Map<String, dynamic>>>{};
    for (final l in _logs) {
      final at = l['at'] as String? ?? '';
      if (at.isEmpty) continue;
      final day = at.substring(0, 10);
      out.putIfAbsent(day, () => []).add(l);
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

  String _fmtTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    } catch (_) {
      return '';
    }
  }

  String _fmtDayLabel(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final today = DateTime.now();
      final todayIso =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final yesterdayDt = today.subtract(const Duration(days: 1));
      final yesterdayIso =
          '${yesterdayDt.year}-${yesterdayDt.month.toString().padLeft(2, '0')}-${yesterdayDt.day.toString().padLeft(2, '0')}';
      if (iso == todayIso) return 'Today';
      if (iso == yesterdayIso) return 'Yesterday';
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: NudgeTokens.bg,
        body: Center(child: CircularProgressIndicator(color: NudgeTokens.pomB)),
      );
    }

    final totalMin = _totalProductiveMinutes();
    final byProject = _minutesByProject();
    final maxProjectMin = byProject.values.isEmpty
        ? 1
        : byProject.values.reduce((a, b) => a > b ? a : b);
    final logsByDay = _logsByDay();
    final sortedDays = logsByDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: NudgeTokens.bg,
      appBar: AppBar(
        backgroundColor: NudgeTokens.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Focus Stats',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
            onPressed: _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: NudgeTokens.border),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: NudgeTokens.pomB,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 60),
          children: [
            // Hero total
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    NudgeTokens.pomB.withValues(alpha: 0.18),
                    NudgeTokens.card,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: NudgeTokens.pomB.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.analytics_rounded, color: NudgeTokens.pomB, size: 16),
                      const SizedBox(width: 8),
                      Text('ALL TIME',
                          style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: NudgeTokens.textLow,
                              letterSpacing: 1.3)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(_fmtHours(totalMin),
                      style: GoogleFonts.outfit(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: NudgeTokens.pomB,
                          height: 1.0)),
                  const SizedBox(height: 4),
                  Text('total focused time',
                      style: GoogleFonts.outfit(
                          fontSize: 13, color: NudgeTokens.textMid)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _StatPill(
                          label: '${_logs.where((l) => (l['kind'] as String?) == 'work' || (l['kind'] as String?) == 'manual').length} sessions',
                          color: NudgeTokens.pomB),
                      const SizedBox(width: 8),
                      _StatPill(
                          label: '${_projects.length} projects',
                          color: NudgeTokens.blue),
                    ],
                  ),
                ],
              ),
            ),

            if (_projects.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('BY PROJECT',
                  style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: NudgeTokens.textLow,
                      letterSpacing: 1.2)),
              const SizedBox(height: 10),
              ...(_projects.map((p) {
                final id = p['id']?.toString() ?? '';
                final name = (p['name'] as String?) ?? 'Project';
                final min = byProject[id] ?? 0;
                final frac = maxProjectMin > 0 ? (min / maxProjectMin).clamp(0.0, 1.0) : 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: NudgeTokens.pomB.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(Icons.folder_rounded, size: 14, color: NudgeTokens.pomB),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(name,
                                style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ),
                          Text(_fmtHours(min),
                              style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: NudgeTokens.pomB)),
                        ],
                      ),
                      if (min > 0) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: frac,
                            minHeight: 5,
                            backgroundColor: NudgeTokens.elevated,
                            valueColor: const AlwaysStoppedAnimation(NudgeTokens.pomB),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              })),
            ],

            if (sortedDays.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('SESSION HISTORY',
                  style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: NudgeTokens.textLow,
                      letterSpacing: 1.2)),
              const SizedBox(height: 10),
              ...sortedDays.map((day) {
                final entries = logsByDay[day]!
                    .where((l) =>
                        (l['kind'] as String?) == 'work' ||
                        (l['kind'] as String?) == 'manual')
                    .toList();
                if (entries.isEmpty) return const SizedBox.shrink();
                final dayMin = entries.fold<int>(
                    0,
                    (s, l) =>
                        s +
                        ((l['minutes'] is int)
                            ? (l['minutes'] as int)
                            : 0));

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                          Text(_fmtDayLabel(day),
                              style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: NudgeTokens.pomB.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: NudgeTokens.pomB.withValues(alpha: 0.25)),
                            ),
                            child: Text(_fmtHours(dayMin),
                                style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: NudgeTokens.pomB)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...entries.map((l) {
                        final min = (l['minutes'] is int) ? (l['minutes'] as int) : 0;
                        final pid = (l['projectId'] as String?) ?? '';
                        final proj = _projects.firstWhere(
                            (p) => p['id']?.toString() == pid,
                            orElse: () => {});
                        final projName = proj.isNotEmpty
                            ? (proj['name'] as String? ?? '')
                            : '';
                        final at = (l['at'] as String?) ?? '';
                        final timeStr = at.isNotEmpty ? _fmtTime(at) : '';
                        final isManual = (l['kind'] as String?) == 'manual';

                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: isManual
                                      ? NudgeTokens.blue.withValues(alpha: 0.1)
                                      : NudgeTokens.pomB.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Icon(
                                  isManual
                                      ? Icons.edit_calendar_rounded
                                      : Icons.timer_rounded,
                                  size: 12,
                                  color: isManual ? NudgeTokens.blue : NudgeTokens.pomB,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  projName.isNotEmpty ? projName : 'No project',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: NudgeTokens.textMid),
                                ),
                              ),
                              if (timeStr.isNotEmpty)
                                Text(timeStr,
                                    style: const TextStyle(
                                        fontSize: 11, color: NudgeTokens.textLow)),
                              const SizedBox(width: 8),
                              Text('${min}m',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: NudgeTokens.textMid)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
            ],

            if (sortedDays.isEmpty && _projects.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text('No focus sessions yet.',
                      style: TextStyle(color: NudgeTokens.textLow)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
