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
    final isQuit = type == 'quit';

    final today = _onlyDay(DateTime.now());
    
    // gather last 30 days
    final counts = <int>[];
    for (int i = 29; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      counts.add(_countForDay(_isoDay(d)));
    }

    final maxC = counts.reduce((a, b) => a > b ? a : b);
    double chartMax = (maxC > target ? maxC : target) * 1.2;
    if (chartMax == 0) chartMax = 5.0; // buffer

    // stats
    int currentStreak = 0;
    int bestStreak = 0;
    int totalSuccess = 0;
    
    // calculate streaks
    // for quit, success means count <= target (and normally we only consider days where they logged something or we consider all passing days).
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
    
    // trace backward for current streak
    for (int i = counts.length - 1; i >= 0; i--) {
      final c = counts[i];
      final success = isQuit ? (c <= target) : (c >= target);
      if (success) {
        currentStreak++;
      } else {
        // if today is not a success yet, allow it (don't break streak if they just haven't logged today yet)
        if (i == counts.length - 1 && c == 0 && !isQuit) {
           continue; 
        }
        break;
      }
    }

    final successRate = (totalSuccess / 30.0) * 100;

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: Text(name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Graphic
          Container(
            height: 250,
            padding: const EdgeInsets.fromLTRB(16, 32, 24, 16),
            decoration: BoxDecoration(
              color: NudgeTokens.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: NudgeTokens.border),
            ),
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: chartMax == 0 ? 5 : chartMax,
                minX: 0,
                maxX: 29,
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(30, (i) => FlSpot(i.toDouble(), counts[i].toDouble())),
                    isCurved: true,
                    color: isQuit ? Colors.redAccent : NudgeTokens.blue,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: (isQuit ? Colors.redAccent : NudgeTokens.blue).withValues(alpha: 0.1),
                    ),
                  ),
                  LineChartBarData(
                    spots: [
                      FlSpot(0, target.toDouble()),
                      FlSpot(29, target.toDouble())
                    ],
                    isCurved: false,
                    color: isQuit ? NudgeTokens.green : NudgeTokens.green, // target line is green
                    barWidth: 2,
                    dashArray: [5, 5],
                    dotData: const FlDotData(show: false),
                  ),
                ],
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, meta) {
                        if (v == 0) return const Text('30d ago', style: TextStyle(fontSize: 10, color: NudgeTokens.textLow));
                        if (v == 29) return const Text('Today', style: TextStyle(fontSize: 10, color: NudgeTokens.textLow));
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (v, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            v.toInt().toString(),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 10, color: NudgeTokens.textLow),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: target > 0 ? target.toDouble() : 1,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: NudgeTokens.border,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          Text(
            'Analytics (Last 30 Days)',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(child: _StatBox(label: 'Current Streak', value: '$currentStreak days', icon: Icons.local_fire_department_rounded, color: NudgeTokens.amber)),
              const SizedBox(width: 12),
              Expanded(child: _StatBox(label: 'Best Streak', value: '$bestStreak days', icon: Icons.emoji_events_rounded, color: NudgeTokens.textHigh)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatBox(label: 'Target', value: '$target/day', icon: Icons.flag_rounded, color: NudgeTokens.blue)),
              const SizedBox(width: 12),
              Expanded(child: _StatBox(label: 'Success Rate', value: '${successRate.round()}%', icon: Icons.pie_chart_rounded, color: NudgeTokens.green)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatBox({required this.label, required this.value, required this.icon, required this.color});

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
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: NudgeTokens.textHigh)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: NudgeTokens.textLow)),
        ],
      ),
    );
  }
}
