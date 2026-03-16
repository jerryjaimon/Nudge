// lib/screens/health/running_coach_list_screen.dart
//
// Home page for the Activity Coach feature.
// Lists all recent runs (HC + GPS), lets the user validate them,
// and taps through to RunningCoachScreen for individual analysis.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../app.dart' show NudgeTokens;
import '../../services/running_coach_service.dart';
import 'package:nudge/screens/health/running_coach_screen.dart';
import 'package:nudge/screens/activity/activity_summary_screen.dart';

const _pink = Color(0xFFFF2D95);

// ─────────────────────────────────────────────────────────────────────────────

class RunningCoachListScreen extends StatefulWidget {
  const RunningCoachListScreen({super.key});

  @override
  State<RunningCoachListScreen> createState() => _RunningCoachListScreenState();
}

class _RunningCoachListScreenState extends State<RunningCoachListScreen> {
  List<Map<String, dynamic>> _runs = [];
  Map<String, dynamic> _prs = {};
  Map<String, dynamic>? _racePredictions;
  Map<String, double> _loadTrend = {};
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final runs = RunningCoachService.getMergedSessions(days: 90);
    final prs = RunningCoachService.getPersonalRecords();
    final racePredictions = RunningCoachService.getRacePredictions();
    final loadTrend = RunningCoachService.getTrainingLoadTrend();
    final streak = RunningCoachService.getRunStreak();
    setState(() {
      _runs = runs;
      _prs = prs;
      _racePredictions = racePredictions;
      _loadTrend = loadTrend;
      _streak = streak;
    });
  }

  void _toggleValidation(String startTime) {
    RunningCoachService.setRunValidated(
        startTime, !RunningCoachService.isRunValidated(startTime));
    _load();
  }

  Future<void> _showTagPicker(BuildContext context, String startTime) async {
    final current = RunningCoachService.getRunTag(startTime);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: NudgeTokens.elevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: NudgeTokens.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('ACTIVITY TYPE',
                style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: NudgeTokens.textLow)),
            const SizedBox(height: 4),
            Text('Tag this run for category-specific analysis',
                style:
                    GoogleFonts.outfit(fontSize: 13, color: NudgeTokens.textMid)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                GestureDetector(
                  onTap: () async {
                    await RunningCoachService.clearRunTag(startTime);
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: current == null
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            current == null ? Colors.white38 : Colors.white12,
                      ),
                    ),
                    child: Text('✕  No tag',
                        style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: current == null
                                ? Colors.white
                                : NudgeTokens.textLow,
                            fontWeight: current == null
                                ? FontWeight.w700
                                : FontWeight.w500)),
                  ),
                ),
                ...RunningCoachService.activityTags.map((t) {
                  final isSelected = current == t.label;
                  return GestureDetector(
                    onTap: () async {
                      await RunningCoachService.setRunTag(startTime, t.label);
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? t.color.withValues(alpha: 0.18)
                            : t.color.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? t.color.withValues(alpha: 0.6)
                              : t.color.withValues(alpha: 0.2),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Text('${t.emoji}  ${t.label}',
                          style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: isSelected ? t.color : NudgeTokens.textMid,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w500)),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Zone legend ──────────────────────────────────────────────────────────────

  void _showZoneLegend(BuildContext context) {
    const zones = [
      (
        zone: 1,
        name: 'Zone 1 · Recovery',
        paceRange: '> 7:00 /km',
        color: Color(0xFF5AC8FA),
        icon: Icons.self_improvement_rounded,
        desc: 'Very easy. Active recovery. Your body repairs and adapts. '
            'Should feel effortless — you could hold a full conversation.',
        use: 'Rest days, cool-downs, easy base-building days.',
      ),
      (
        zone: 2,
        name: 'Zone 2 · Aerobic',
        paceRange: '6:00 – 7:00 /km',
        color: Color(0xFF39D98A),
        icon: Icons.directions_run_rounded,
        desc: 'Conversational pace. Burns fat efficiently. The backbone of '
            'endurance. Most of your weekly mileage should be here.',
        use: 'Long runs, easy runs, 80% of all training volume.',
      ),
      (
        zone: 3,
        name: 'Zone 3 · Tempo',
        paceRange: '5:00 – 6:00 /km',
        color: Color(0xFFFFBF00),
        icon: Icons.bolt_rounded,
        desc: 'Comfortably hard. You can speak in short sentences. Builds '
            'aerobic power and lactate clearance. Do not overuse.',
        use: 'Tempo runs, moderate-effort workouts, fartleks.',
      ),
      (
        zone: 4,
        name: 'Zone 4 · Threshold',
        paceRange: '4:00 – 5:00 /km',
        color: Color(0xFFFF9500),
        icon: Icons.local_fire_department_rounded,
        desc: 'Hard sustained effort at your lactate threshold. You can '
            'barely speak. Raises your speed ceiling.',
        use: 'Threshold intervals, race-pace training.',
      ),
      (
        zone: 5,
        name: 'Zone 5 · Max Effort',
        paceRange: '< 4:00 /km',
        color: Color(0xFFFF4D6A),
        icon: Icons.flash_on_rounded,
        desc: 'VO₂ Max intensity. Race effort or hard intervals. '
            'Cannot sustain beyond 2–5 minutes. High injury risk if overdone.',
        use: 'Short intervals, race day, 5K / 10K efforts.',
      ),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: NudgeTokens.elevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, ctrl) => Column(
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: NudgeTokens.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.speed_rounded, color: _pink, size: 18),
                  const SizedBox(width: 8),
                  Text('PACE ZONES EXPLAINED',
                      style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: _pink,
                          letterSpacing: 1.4)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: zones.map((z) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: z.color.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: z.color.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: z.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(z.icon, color: z.color, size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(z.name,
                                      style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: z.color)),
                                  Text(z.paceRange,
                                      style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color:
                                              z.color.withValues(alpha: 0.7))),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: z.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('Z${z.zone}',
                                  style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: z.color)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(z.desc,
                            style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: NudgeTokens.textMid,
                                height: 1.5)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.check_circle_outline_rounded,
                                size: 12, color: NudgeTokens.textLow),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(z.use,
                                  style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      color: NudgeTokens.textLow,
                                      fontStyle: FontStyle.italic)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // Aggregate stats
    double weeklyKm = 0;
    int weeklyRuns = 0;
    double monthlyKm = 0;
    int validatedCount = 0;
    final List<double> dailyKm = List.filled(7, 0.0);
    final List<double> dailyMainKm = List.filled(7, 0.0);
    final List<Color> dailyColor = List.filled(7, _pink);

    for (final r in _runs) {
      try {
        final start = DateTime.parse(r['startTime'] as String);
        final rawDist = (r['distanceKm'] as num?)?.toDouble() ?? 0.0;
        final effectiveDist =
            RunningCoachService.getManualDistance(r['startTime'] as String? ?? '') ?? rawDist;
        final daysAgo = now.difference(start).inDays;
        final tag = RunningCoachService.getRunTag(r['startTime'] as String? ?? '');
        Color runColor = _pink;
        if (tag != null) {
          final t = RunningCoachService.activityTags.where((x) => x.label == tag).firstOrNull;
          if (t != null) runColor = t.color;
        }
        if (daysAgo <= 7) { weeklyKm += effectiveDist; weeklyRuns++; }
        if (daysAgo <= 6) {
          final idx = 6 - daysAgo;
          dailyKm[idx] += effectiveDist;
          if (effectiveDist > dailyMainKm[idx]) { dailyMainKm[idx] = effectiveDist; dailyColor[idx] = runColor; }
        }
        if (daysAgo <= 30) monthlyKm += effectiveDist;
        if (RunningCoachService.isRunValidated(r['startTime'] as String? ?? '')) validatedCount++;
      } catch (_) {}
    }

    // Partition runs into groups by date
    final Map<String, List<Map<String, dynamic>>> byDate = {};
    for (final r in _runs) {
      try {
        final start = DateTime.parse(r['startTime'] as String);
        final diff = now.difference(start).inDays;
        final label = diff == 0 ? 'TODAY' : diff == 1 ? 'YESTERDAY' : _fmtDate(start);
        byDate.putIfAbsent(label, () => []).add(r);
      } catch (_) {}
    }

    final items = <_ListItem>[];
    for (final entry in byDate.entries) {
      items.add(_ListItem.header(entry.key));
      for (final r in entry.value) { items.add(_ListItem.run(r)); }
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: NudgeTokens.bg,
        appBar: AppBar(
          backgroundColor: NudgeTokens.bg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Activity Coach',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline_rounded, color: Colors.white54, size: 20),
              tooltip: 'Pace zones guide',
              onPressed: () => _showZoneLegend(context),
            ),
          ],
          bottom: TabBar(
            indicatorColor: _pink,
            labelColor: Colors.white,
            unselectedLabelColor: NudgeTokens.textLow,
            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12),
            unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 12),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Records'),
              Tab(text: 'Training'),
              Tab(text: 'Runs'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: NudgeTokens.purple,
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const ActivitySummaryScreen()))
              .then((_) => _load()),
          icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
          label: Text('Start GPS Tracker',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.white)),
        ),
        body: _runs.isEmpty
            ? _buildEmpty()
            : TabBarView(
                children: [
                  // ── Overview ──────────────────────────────────────────────
                  SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 100),
                    child: Column(
                      children: [
                        _WeeklySummaryStrip(
                          weeklyKm: weeklyKm,
                          weeklyRuns: weeklyRuns,
                          monthlyKm: monthlyKm,
                          validatedCount: validatedCount,
                          totalCount: _runs.length,
                          dailyKm: dailyKm,
                          dailyColor: dailyColor,
                        ),
                        if (_streak > 1)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9500).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFFF9500).withValues(alpha: 0.3)),
                              ),
                              child: Row(children: [
                                const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF9500), size: 22),
                                const SizedBox(width: 12),
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('$_streak-day running streak!',
                                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                                  Text("Don't break the chain.",
                                      style: GoogleFonts.outfit(fontSize: 11, color: NudgeTokens.textLow)),
                                ]),
                              ]),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ── Records ───────────────────────────────────────────────
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    child: _PersonalRecordsCard(prs: _prs, streak: _streak),
                  ),

                  // ── Training ──────────────────────────────────────────────
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    child: _TrainingCard(
                      weeklyKm: weeklyKm,
                      loadTrend: _loadTrend,
                      racePredictions: _racePredictions,
                    ),
                  ),

                  // ── Runs ──────────────────────────────────────────────────
                  CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        sliver: SliverToBoxAdapter(
                          child: Row(children: [
                            Text('${_runs.length} activities',
                                style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.textLow)),
                            const Spacer(),
                            const Icon(Icons.check_circle_outline_rounded, size: 12, color: NudgeTokens.textLow),
                            const SizedBox(width: 4),
                            Text('Tap ✓ to validate',
                                style: GoogleFonts.outfit(fontSize: 10, color: NudgeTokens.textLow)),
                          ]),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) {
                              final item = items[i];
                              if (item.isHeader) return _SectionHeader(label: item.headerLabel!);
                              final r = item.run!;
                              final startTime = r['startTime'] as String? ?? '';
                              return _RunListCard(
                                run: r,
                                source: r['_source'] as String? ?? 'HC',
                                isValidated: RunningCoachService.isRunValidated(startTime),
                                tag: RunningCoachService.getRunTag(startTime),
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => RunningCoachScreen(session: r)))
                                    .then((_) => _load()),
                                onValidate: () => _toggleValidation(startTime),
                                onTagTap: () => _showTagPicker(context, startTime),
                              );
                            },
                            childCount: items.length,
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

  String _fmtDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_run_rounded,
              size: 64, color: _pink.withValues(alpha: 0.3)),
          const SizedBox(height: 20),
          Text('No activities found',
              style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Running sessions from Health Connect or GPS Tracker will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  fontSize: 13, color: NudgeTokens.textLow, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Simple tagged-union for list items ────────────────────────────────────────

class _ListItem {
  final String? headerLabel;
  final Map<String, dynamic>? run;

  const _ListItem._({this.headerLabel, this.run});

  factory _ListItem.header(String label) => _ListItem._(headerLabel: label);
  factory _ListItem.run(Map<String, dynamic> r) => _ListItem._(run: r);

  bool get isHeader => headerLabel != null;
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 0, 8),
      child: Row(
        children: [
          if (label == 'TODAY')
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _pink.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _pink.withValues(alpha: 0.35)),
              ),
              child: Text('TODAY',
                  style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: _pink,
                      letterSpacing: 1.2)),
            )
          else
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: NudgeTokens.textLow,
                    letterSpacing: 1.4)),
        ],
      ),
    );
  }
}

// ── Weekly Summary Strip with fl_chart bar chart ───────────────────────────────

class _WeeklySummaryStrip extends StatelessWidget {
  final double weeklyKm, monthlyKm;
  final int weeklyRuns, validatedCount, totalCount;
  final List<double> dailyKm; // length 7, index 0 = 6 days ago, 6 = today
  final List<Color> dailyColor;

  const _WeeklySummaryStrip({
    required this.weeklyKm,
    required this.weeklyRuns,
    required this.monthlyKm,
    required this.validatedCount,
    required this.totalCount,
    required this.dailyKm,
    required this.dailyColor,
  });

  @override
  Widget build(BuildContext context) {
    final maxKm = dailyKm.fold(0.0, (m, v) => v > m ? v : m);
    final now = DateTime.now();
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    // Map index to actual day-of-week label
    final labels = List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      return dayLabels[date.weekday - 1]; // weekday: 1=Mon..7=Sun
    });
    const todayIdx = 6;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_pink.withValues(alpha: 0.14), NudgeTokens.card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _pink.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stat row ────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Stat(
                  value: weeklyKm.toStringAsFixed(1),
                  unit: 'km',
                  label: '7-day total',
                  color: _pink),
              const SizedBox(width: 22),
              _Stat(
                  value: '$weeklyRuns',
                  unit: 'runs',
                  label: 'This week',
                  color: NudgeTokens.purple),
              const SizedBox(width: 22),
              _Stat(
                  value: monthlyKm.toStringAsFixed(0),
                  unit: 'km',
                  label: '30 days',
                  color: NudgeTokens.amber),
              const Spacer(),
              if (totalCount > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$validatedCount / $totalCount',
                        style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: validatedCount > 0
                                ? NudgeTokens.green
                                : NudgeTokens.textLow)),
                    Text('validated',
                        style: GoogleFonts.outfit(
                            fontSize: 9, color: NudgeTokens.textLow)),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 20),

          // ── 7-day bar chart ──────────────────────────────────────────────
          Text('DAILY DISTANCE — LAST 7 DAYS',
              style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: NudgeTokens.textLow,
                  letterSpacing: 1.2)),
          const SizedBox(height: 10),

          SizedBox(
            height: 110,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxKm > 0 ? maxKm * 1.35 : 10,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        NudgeTokens.elevated.withValues(alpha: 0.95),
                    getTooltipItem: (group, _, rod, __) {
                      final km = rod.toY;
                      if (km <= 0) return null;
                      final clr = dailyColor[group.x.toInt()];
                      return BarTooltipItem(
                        '${km.toStringAsFixed(1)} km',
                        GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: clr),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i > 6) return const SizedBox.shrink();
                        final isToday = i == todayIdx;
                        return Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            isToday ? '●' : labels[i],
                            style: GoogleFonts.outfit(
                              fontSize: isToday ? 9 : 9,
                              fontWeight: isToday
                                  ? FontWeight.w900
                                  : FontWeight.w500,
                              color: isToday ? dailyColor[i] : NudgeTokens.textLow,
                            ),
                          ),
                        );
                      },
                      reservedSize: 20,
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxKm > 0 ? maxKm / 2 : 5,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (i) {
                  final km = dailyKm[i];
                  final color = dailyColor[i];
                  final isToday = i == todayIdx;
                  final hasData = km > 0;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: km,
                        width: 18,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                        color: hasData
                            ? (isToday
                                ? color
                                : color.withValues(alpha: 0.55))
                            : Colors.white.withValues(alpha: 0.06),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxKm > 0 ? maxKm * 1.35 : 10,
                          color: Colors.white.withValues(alpha: 0.04),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),

          // km labels above bars — small text row
          if (maxKm > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (i) {
                  final km = dailyKm[i];
                  return SizedBox(
                    width: 30,
                    child: Text(
                      km > 0 ? km.toStringAsFixed(1) : '',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          fontSize: 8,
                          color: dailyColor[i].withValues(alpha: 0.7),
                          fontWeight: FontWeight.w700),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value, unit, label;
  final Color color;

  const _Stat(
      {required this.value,
      required this.unit,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value,
                style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1.1)),
            const SizedBox(width: 2),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(unit,
                  style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: color.withValues(alpha: 0.7))),
            ),
          ],
        ),
        Text(label,
            style:
                GoogleFonts.outfit(fontSize: 9, color: NudgeTokens.textLow)),
      ],
    );
  }
}

// ── Individual run card ────────────────────────────────────────────────────────

class _RunListCard extends StatelessWidget {
  final Map<String, dynamic> run;
  final String source; // 'HC' or 'GPS'
  final bool isValidated;
  final String? tag;
  final VoidCallback onTap;
  final VoidCallback onValidate;
  final VoidCallback onTagTap;

  const _RunListCard({
    required this.run,
    required this.source,
    required this.isValidated,
    required this.onTap,
    required this.onValidate,
    required this.onTagTap,
    this.tag,
  });

  @override
  Widget build(BuildContext context) {
    final startTime = run['startTime'] as String? ?? '';
    final rawDist = (run['distanceKm'] as num?)?.toDouble() ?? 0.0;
    final manualDist = RunningCoachService.getManualDistance(startTime);
    final effectiveDist = manualDist ?? rawDist;
    final dur = (run['durationMin'] as num?)?.toDouble() ?? 0.0;
    final cal = RunningCoachService.getManualCalories(startTime)?.toInt() ??
        (run['calories'] as num?)?.toInt() ?? 0;
    final pace = dur > 0 && effectiveDist > 0 ? dur / effectiveDist : 0.0;
    final zone = RunningCoachService.getPaceZone(pace);
    final pStr = pace > 0
        ? '${pace.floor()}:${((pace % 1) * 60).round().toString().padLeft(2, '0')}'
        : '--';

    String dateStr = '';
    String timeStr = '';
    try {
      final dt = DateTime.parse(startTime);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final diff = DateTime.now().difference(dt).inDays;
      final relStr =
          diff == 0 ? 'Today' : diff == 1 ? 'Yesterday' : '$diff days ago';
      dateStr = '${months[dt.month - 1]} ${dt.day}  ($relStr)';
      timeStr =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    final hasAnalysis =
        RunningCoachService.getSavedAnalysis(startTime) != null;
    final isGps = source == 'GPS';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: NudgeTokens.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isValidated
                    ? zone.color.withValues(alpha: 0.45)
                    : NudgeTokens.border,
                width: isValidated ? 1.5 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  // Zone colour bar
                  Container(
                    width: 4,
                    height: 56,
                    decoration: BoxDecoration(
                      color: zone.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(dateStr,
                                style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            const SizedBox(width: 6),
                            Text(timeStr,
                                style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    color: NudgeTokens.textLow)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Text('${effectiveDist.toStringAsFixed(2)} km',
                                style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: zone.color)),
                            const SizedBox(width: 10),
                            Text('$pStr /km',
                                style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: NudgeTokens.textMid)),
                            if (cal > 0) ...[
                              const SizedBox(width: 10),
                              Text('$cal kcal',
                                  style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      color: NudgeTokens.textLow)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Source badge
                            _Pill(
                              label: isGps ? 'GPS' : 'HC',
                              color: isGps
                                  ? NudgeTokens.purple
                                  : NudgeTokens.blue,
                              icon: isGps
                                  ? Icons.gps_fixed_rounded
                                  : Icons.favorite_rounded,
                            ),
                            // Tag chip
                            GestureDetector(
                              onTap: onTagTap,
                              child: () {
                                if (tag != null) {
                                  final t = RunningCoachService.activityTags
                                      .where((x) => x.label == tag)
                                      .firstOrNull;
                                  final tagColor =
                                      t?.color ?? NudgeTokens.textLow;
                                  return _Pill(
                                    label: '${t?.emoji ?? ''} $tag',
                                    color: tagColor,
                                  );
                                }
                                return _Pill(
                                  label: '＋ tag',
                                  color: NudgeTokens.textLow,
                                );
                              }(),
                            ),
                            _Pill(
                                label:
                                    zone.name.split('·')[0].trim(),
                                color: zone.color),
                            if (manualDist != null) ...[
                              _Pill(label: 'EDITED', color: _pink),
                            ],
                            if (hasAnalysis) ...[
                              _Pill(
                                  label: 'ANALYZED',
                                  color: NudgeTokens.purple,
                                  icon: Icons.auto_awesome_rounded),
                            ],
                            if (isValidated) ...[
                              _Pill(
                                  label: 'VALIDATED',
                                  color: NudgeTokens.green,
                                  icon: Icons.verified_rounded),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Validate button
                  GestureDetector(
                    onTap: onValidate,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isValidated
                            ? NudgeTokens.green.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isValidated
                              ? NudgeTokens.green.withValues(alpha: 0.4)
                              : Colors.white12,
                        ),
                      ),
                      child: Icon(
                        isValidated
                            ? Icons.check_circle_rounded
                            : Icons.check_circle_outline_rounded,
                        color: isValidated
                            ? NudgeTokens.green
                            : NudgeTokens.textLow,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded,
                      color: NudgeTokens.textLow, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _Pill({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: icon != null ? 5 : 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 8, color: color),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 8,
                  color: color,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3)),
        ],
      ),
    );
  }
}

// ─── Personal Records card ────────────────────────────────────────────────────

class _PersonalRecordsCard extends StatelessWidget {
  final Map<String, dynamic> prs;
  final int streak;
  const _PersonalRecordsCard({required this.prs, required this.streak});

  String _fmtPace(double? pace) {
    if (pace == null) return '--';
    final m = pace.floor();
    final s = ((pace % 1) * 60).round();
    return "$m'${s.toString().padLeft(2, '0')}\"/km";
  }

  @override
  Widget build(BuildContext context) {
    final longestKm = (prs['longestRunKm'] as num?)?.toDouble();
    final elev = (prs['mostElevationM'] as num?)?.toDouble();
    final count = (prs['sessionCount'] as int?) ?? 0;

    final records = [
      (label: 'Best km pace',    value: _fmtPace(prs['fastestKmPace'] as double?),  color: _pink,              icon: Icons.speed_rounded),
      (label: 'Fastest 5K',      value: _fmtPace(prs['fastest5kPace'] as double?),   color: const Color(0xFFFF9500), icon: Icons.timer_rounded),
      (label: 'Fastest 10K',     value: _fmtPace(prs['fastest10kPace'] as double?),  color: NudgeTokens.amber,  icon: Icons.timer_outlined),
      (label: 'Longest run',     value: longestKm != null ? '${longestKm.toStringAsFixed(1)} km' : '--', color: NudgeTokens.green, icon: Icons.straighten_rounded),
      if (elev != null && elev > 0)
        (label: 'Most elevation', value: '${elev.toInt()} m',                        color: NudgeTokens.blue,   icon: Icons.landscape_rounded),
      (label: 'Total sessions',  value: count.toString(),                            color: NudgeTokens.textMid, icon: Icons.directions_run_rounded),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PERSONAL RECORDS',
            style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900,
                color: NudgeTokens.textLow, letterSpacing: 1.3)),
        const SizedBox(height: 12),
        ...records.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: r.color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: r.color.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: r.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(r.icon, color: r.color, size: 18),
                ),
                const SizedBox(width: 14),
                Text(r.label,
                    style: TextStyle(color: r.color.withValues(alpha: 0.8),
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(r.value,
                    style: TextStyle(color: r.color, fontSize: 18, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        )),
      ],
    );
  }
}

// ─── Training load + Race predictor card ─────────────────────────────────────

class _TrainingCard extends StatelessWidget {
  final double weeklyKm;
  final Map<String, double> loadTrend;
  final Map<String, dynamic>? racePredictions;
  const _TrainingCard({required this.weeklyKm, required this.loadTrend, required this.racePredictions});

  @override
  Widget build(BuildContext context) {
    final goal = RunningCoachService.getWeeklyKmGoal();
    final weekKm = RunningCoachService.getThisWeekKm();
    final progress = (weekKm / goal).clamp(0.0, 1.0);
    final ratio = loadTrend['ratio'] ?? 1.0;

    Color ratioColor;
    String ratioLabel;
    if (ratio > 1.5) {
      ratioColor = NudgeTokens.red;
      ratioLabel = 'High risk';
    } else if (ratio > 1.3) {
      ratioColor = NudgeTokens.amber;
      ratioLabel = 'Caution';
    } else if (ratio < 0.8) {
      ratioColor = NudgeTokens.blue;
      ratioLabel = 'Detraining';
    } else {
      ratioColor = NudgeTokens.green;
      ratioLabel = 'Optimal';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NudgeTokens.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NudgeTokens.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Weekly goal
            Row(
              children: [
                const Icon(Icons.flag_rounded, color: _pink, size: 14),
                const SizedBox(width: 6),
                Text('WEEKLY GOAL',
                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900,
                        color: NudgeTokens.textLow, letterSpacing: 1.3)),
                const Spacer(),
                GestureDetector(
                  onTap: () => _editGoal(context, goal),
                  child: Text('${weekKm.toStringAsFixed(1)} / ${goal.toStringAsFixed(0)} km',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700,
                          color: progress >= 1 ? NudgeTokens.green : NudgeTokens.textMid)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: NudgeTokens.border,
                valueColor: AlwaysStoppedAnimation(progress >= 1 ? NudgeTokens.green : _pink),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 14),
            // Training load ratio
            Row(
              children: [
                const Icon(Icons.trending_up_rounded, color: NudgeTokens.amber, size: 14),
                const SizedBox(width: 6),
                Text('TRAINING LOAD',
                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900,
                        color: NudgeTokens.textLow, letterSpacing: 1.3)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ratioColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(ratioLabel,
                      style: TextStyle(color: ratioColor, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'ATL ${(loadTrend['acute'] ?? 0).toStringAsFixed(0)} AU  ·  CTL ${(loadTrend['chronic'] ?? 0).toStringAsFixed(0)} AU  ·  ratio ${ratio.toStringAsFixed(2)}',
              style: const TextStyle(color: NudgeTokens.textLow, fontSize: 10),
            ),
            const SizedBox(height: 4),
            Text(
              ratio > 1.3
                  ? '⚠ Acute load is high relative to chronic — consider an easy week.'
                  : ratio < 0.8
                      ? 'Load is low — safe to increase weekly volume.'
                      : 'Load ratio is healthy. Keep building consistently.',
              style: TextStyle(color: ratioColor, fontSize: 11),
            ),
            // Race predictor
            if (racePredictions != null) ...[
              const SizedBox(height: 14),
              const Divider(color: NudgeTokens.border, height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('🏁', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Text('RACE PREDICTOR',
                      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900,
                          color: NudgeTokens.textLow, letterSpacing: 1.3)),
                  const SizedBox(width: 6),
                  Text('(Riegel formula)',
                      style: GoogleFonts.outfit(fontSize: 9, color: NudgeTokens.textLow)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _RacePill('5K', racePredictions!['5k_str'] as String),
                  const SizedBox(width: 6),
                  _RacePill('10K', racePredictions!['10k_str'] as String),
                  const SizedBox(width: 6),
                  _RacePill('Half', racePredictions!['half_str'] as String),
                  const SizedBox(width: 6),
                  _RacePill('Full', racePredictions!['marathon_str'] as String),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _editGoal(BuildContext context, double current) async {
    final ctrl = TextEditingController(text: current.toStringAsFixed(0));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NudgeTokens.card,
        title: Text('Weekly km goal',
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            suffixText: 'km',
            suffixStyle: TextStyle(color: NudgeTokens.textLow),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: NudgeTokens.border)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _pink)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: NudgeTokens.textLow))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text.trim())),
            child: const Text('Save', style: TextStyle(color: _pink)),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      RunningCoachService.setWeeklyKmGoal(result);
      if (context.mounted) (context as Element).markNeedsBuild();
    }
  }
}

class _RacePill extends StatelessWidget {
  final String dist;
  final String time;
  const _RacePill(this.dist, this.time);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: NudgeTokens.elevated,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(dist, style: const TextStyle(color: NudgeTokens.textLow, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Text(time, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
