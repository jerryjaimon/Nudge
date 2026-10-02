import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app.dart' show NudgeTokens;

class HabitDetailScreen extends StatelessWidget {
  final Map<String, dynamic> habit;
  final Map<dynamic, dynamic>? logs;

  const HabitDetailScreen({super.key, required this.habit, this.logs});

  DateTime _onlyDay(DateTime d) => DateTime(d.year, d.month, d.day);

  String _isoDay(DateTime d) {
    final dt = _onlyDay(d);
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$mm-$dd';
  }

  int _countForDay(String dayIso) {
    if (logs == null) return 0;
    final v = logs![dayIso];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final name = (habit['name'] as String?) ?? 'Habit';
    final type = (habit['type'] as String?) ?? 'build';
    final target = (habit['target'] as int?) ?? 1;
    final iconCode = (habit['iconCode'] is int) ? (habit['iconCode'] as int) : Icons.check_rounded.codePoint;
    final isQuit = type == 'quit';

    final today = _onlyDay(DateTime.now());
    
    // gather last 30 days
    final counts = <int>[];
    for (int i = 29; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      counts.add(_countForDay(_isoDay(d)));
    }

    final maxC = counts.reduce((a, b) => a > b ? a : b);
    double chartMax = (maxC > target ? maxC : target).toDouble();
    chartMax = chartMax == 0 ? 5.0 : chartMax * 1.25;

    // stats
    int currentStreak = 0;
    int bestStreak = 0;
    int totalSuccess = 0;
    
    int tempStreak = 0;
    for (final c in counts) {
      final success = isQuit ? (c <= target) : (c >= target);
      if (success) {
        totalSuccess++;
        tempStreak++;
        if (tempStreak > bestStreak) bestStreak = tempStreak;
      } else {
        tempStreak = 0;
      }
    }
    
    for (int i = counts.length - 1; i >= 0; i--) {
      final c = counts[i];
      final success = isQuit ? (c <= target) : (c >= target);
      if (success) {
        currentStreak++;
      } else {
        if (i == counts.length - 1 && c == 0 && !isQuit) continue; 
        break;
      }
    }

    final successRate = (totalSuccess / 30.0) * 100;
    final accentColor = isQuit ? Colors.redAccent : NudgeTokens.blue;

    return Scaffold(
      backgroundColor: NudgeTokens.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            stretch: true,
            backgroundColor: NudgeTokens.bg,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Decorative gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accentColor.withValues(alpha: 0.15),
                          NudgeTokens.bg,
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor.withValues(alpha: 0.12),
                            border: Border.all(color: accentColor.withValues(alpha: 0.25), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.1),
                                blurRadius: 20,
                                spreadRadius: 5,
                              )
                            ],
                          ),
                          child: Icon(
                            IconData(iconCode, fontFamily: 'MaterialIcons'),
                            size: 42,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name,
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -- Progress Metrics Row --
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: 'Current Streak',
                          value: '$currentStreak',
                          desc: 'Days',
                          icon: Icons.local_fire_department_rounded,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          label: 'Success Rate',
                          value: '${successRate.round()}%',
                          desc: 'Last 30d',
                          icon: Icons.auto_graph_rounded,
                          color: NudgeTokens.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // -- Chart Section --
                  Text(
                    'History Statistics',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: NudgeTokens.textHigh,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 220,
                    padding: const EdgeInsets.fromLTRB(12, 24, 20, 12),
                    decoration: BoxDecoration(
                      color: NudgeTokens.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: NudgeTokens.border),
                    ),
                    child: LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: chartMax,
                        minX: 0,
                        maxX: 29,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: target > 0 ? target.toDouble() : 1,
                          getDrawingHorizontalLine: (v) => FlLine(
                            color: NudgeTokens.border.withValues(alpha: 0.5),
                            strokeWidth: 1,
                            dashArray: [8, 4],
                          ),
                        ),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              getTitlesWidget: (v, meta) => Text(
                                v.toInt().toString(),
                                style: const TextStyle(fontSize: 10, color: NudgeTokens.textLow, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, meta) {
                                if (v == 0) return const Text('30d', style: TextStyle(fontSize: 10, color: NudgeTokens.textLow));
                                if (v == 29) return const Text('Today', style: TextStyle(fontSize: 10, color: NudgeTokens.textLow));
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(30, (i) => FlSpot(i.toDouble(), counts[i].toDouble())),
                            isCurved: true,
                            curveSmoothness: 0.35,
                            color: accentColor,
                            barWidth: 4,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  accentColor.withValues(alpha: 0.2),
                                  accentColor.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                          // Target line
                          LineChartBarData(
                            spots: [FlSpot(0, target.toDouble()), FlSpot(29, target.toDouble())],
                            isCurved: false,
                            color: NudgeTokens.green.withValues(alpha: 0.5),
                            barWidth: 2,
                            dashArray: [10, 5],
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // -- Summary Stats --
                  _StatRow(
                    label: 'Target Goal',
                    value: '$target ${isQuit ? "or less" : "or more"} per day',
                    icon: Icons.track_changes_rounded,
                    color: NudgeTokens.textMid,
                  ),
                  _StatRow(
                    label: 'Best Streak',
                    value: '$bestStreak days',
                    icon: Icons.emoji_events_rounded,
                    color: Colors.amber,
                  ),
                  _StatRow(
                    label: 'Total Sessions',
                    value: '${counts.where((c) => c > 0).length} of 30 days',
                    icon: Icons.calendar_today_rounded,
                    color: NudgeTokens.blue,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String desc;
  final IconData icon;
  final Color color;

  const _MetricCard({required this.label, required this.value, required this.desc, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.textMid, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: NudgeTokens.textHigh, letterSpacing: -1)),
          Text(desc, style: GoogleFonts.outfit(fontSize: 11, color: NudgeTokens.textLow, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatRow({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NudgeTokens.card.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NudgeTokens.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 14),
            Text(label, style: GoogleFonts.outfit(color: NudgeTokens.textMid, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(value, style: GoogleFonts.outfit(color: NudgeTokens.textHigh, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
