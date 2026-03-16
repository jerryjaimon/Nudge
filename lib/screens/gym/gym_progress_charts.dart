// lib/screens/gym/gym_progress_charts.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class GymProgressCharts extends StatelessWidget {
  final List<Map<String, dynamic>> workouts;
  final String exerciseName;

  const GymProgressCharts({
    super.key,
    required this.workouts,
    required this.exerciseName,
  });

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    final dates = <DateTime>[];

    final sorted = List<Map<String, dynamic>>.from(workouts);
    sorted.sort((a, b) => (a['dayIso'] as String).compareTo(b['dayIso'] as String));

    bool isBodyweight = true;
    for (final w in sorted) {
      final exercises = (w['exercises'] as List?) ?? [];
      for (final ex in exercises) {
        if (ex['name'] == exerciseName) {
          final sets = (ex['sets'] as List?) ?? [];
          for (final s in sets) {
            final w = ((s as Map)['weight'] as num?)?.toDouble() ?? 0.0;
            if (w > 0) {
              isBodyweight = false;
              break;
            }
          }
        }
      }
    }

    for (final w in sorted) {
      final exercises = (w['exercises'] as List?) ?? [];
      for (final ex in exercises) {
        if (ex['name'] == exerciseName) {
          final sets = (ex['sets'] as List?) ?? [];
          if (sets.isNotEmpty) {
            double metricVal = 0;
            if (isBodyweight) {
               // Take max reps for bodyweight
               for (final s in sets) {
                 final repsNum = (s as Map)['reps'];
                 final r = (repsNum is int) ? repsNum : (repsNum is num) ? repsNum.toInt() : int.tryParse(repsNum?.toString() ?? '') ?? 0;
                 if (r > metricVal) metricVal = r.toDouble();
               }
            } else {
               // Take max weight
               for (final s in sets) {
                 final wWeight = ((s as Map)['weight'] as num?)?.toDouble() ?? 0.0;
                 if (wWeight > metricVal) metricVal = wWeight;
               }
            }
            if (metricVal > 0) {
              final date = DateTime.parse(w['dayIso'] as String);
              dates.add(date);
              spots.add(FlSpot(dates.length - 1.0, metricVal));
            }
          }
        }
      }
    }

    // Volume per session: Σ(weight × reps)
    final volumeSpots = <FlSpot>[];
    final volumeDates = <DateTime>[];
    for (final w in sorted) {
      final exercises = (w['exercises'] as List?) ?? [];
      for (final ex in exercises) {
        if (ex['name'] == exerciseName) {
          final sets = (ex['sets'] as List?) ?? [];
          double vol = 0;
          for (final s in sets) {
            final sw = ((s as Map)['weight'] as num?)?.toDouble() ?? 0.0;
            final sr = (s['reps'] is int) ? (s['reps'] as int) : int.tryParse(s['reps']?.toString() ?? '') ?? 0;
            vol += sw > 0 ? sw * sr : sr.toDouble();
          }
          if (vol > 0) {
            final date = DateTime.parse(w['dayIso'] as String);
            volumeDates.add(date);
            volumeSpots.add(FlSpot(volumeDates.length - 1.0, vol));
          }
        }
      }
    }

    if (spots.isEmpty && volumeSpots.isEmpty) {
      return const Center(child: Text('No history for this exercise yet.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Max weight / reps chart ─────────────────────────────────────
          if (spots.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                isBodyweight ? 'MAX REPS' : 'MAX WEIGHT (kg)',
                style: const TextStyle(color: Color(0xFF7C4DFF), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2),
              ),
            ),
            Container(
              height: 200,
              padding: const EdgeInsets.fromLTRB(0, 16, 16, 8),
              decoration: BoxDecoration(
                color: const Color(0xFF101722),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: LineChart(LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true, reservedSize: 36,
                    getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                        style: const TextStyle(fontSize: 9, color: Colors.white38)),
                  )),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= dates.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(DateFormat('MM/dd').format(dates[idx]),
                            style: const TextStyle(fontSize: 9, color: Colors.white38)),
                      );
                    },
                  )),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [LineChartBarData(
                  spots: spots, isCurved: true,
                  color: const Color(0xFF7C4DFF), barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(show: true, color: const Color(0xFF7C4DFF).withValues(alpha: 0.12)),
                )],
              )),
            ),
            const SizedBox(height: 16),
          ],

          // ── Volume chart (bar) ──────────────────────────────────────────
          if (volumeSpots.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                isBodyweight ? 'TOTAL REPS / SESSION' : 'TOTAL VOLUME kg / SESSION',
                style: const TextStyle(color: Color(0xFF39D98A), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2),
              ),
            ),
            Container(
              height: 180,
              padding: const EdgeInsets.fromLTRB(0, 16, 16, 8),
              decoration: BoxDecoration(
                color: const Color(0xFF101722),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: BarChart(BarChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true, reservedSize: 40,
                    getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                        style: const TextStyle(fontSize: 9, color: Colors.white38)),
                  )),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= volumeDates.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(DateFormat('MM/dd').format(volumeDates[idx]),
                            style: const TextStyle(fontSize: 9, color: Colors.white38)),
                      );
                    },
                  )),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                barGroups: volumeSpots.map((s) => BarChartGroupData(
                  x: s.x.toInt(),
                  barRods: [BarChartRodData(
                    toY: s.y,
                    color: const Color(0xFF39D98A),
                    width: volumeSpots.length > 8 ? 8 : 14,
                    borderRadius: BorderRadius.circular(4),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true, toY: volumeSpots.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.1,
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  )],
                )).toList(),
              )),
            ),
          ],
        ],
      ),
    );
  }
}
