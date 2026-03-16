// lib/screens/health/water_history_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app.dart' show NudgeTokens;
import '../../storage.dart';
import '../../utils/health_service.dart';

class WaterHistoryScreen extends StatefulWidget {
  const WaterHistoryScreen({super.key});

  @override
  State<WaterHistoryScreen> createState() => _WaterHistoryScreenState();
}

class _WaterHistoryScreenState extends State<WaterHistoryScreen> {
  List<Map<String, dynamic>> _logs = [];
  double _goal = 2000;
  double _todayTotal = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final box = AppStorage.gymBox;
    final raw = (box.get('water_logs', defaultValue: <dynamic>[]) as List)
        .map((l) => Map<String, dynamic>.from(l as Map))
        .toList();
    raw.sort((a, b) => (b['dayIso'] as String).compareTo(a['dayIso'] as String));

    final goal = AppStorage.settingsBox.get('water_goal', defaultValue: 2000.0) as double;
    final today = await HealthService.getTodayWater();

    setState(() {
      _logs = raw;
      _goal = goal;
      _todayTotal = (today['total'] as num? ?? 0.0).toDouble();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NudgeTokens.bg,
      appBar: AppBar(
        backgroundColor: NudgeTokens.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Hydration History',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: NudgeTokens.blue))
          : RefreshIndicator(
              onRefresh: _load,
              color: NudgeTokens.blue,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  _buildTodayCard(),
                  const SizedBox(height: 20),
                  if (_logs.isNotEmpty) ...[
                    _buildChart(),
                    const SizedBox(height: 20),
                    _buildHistory(),
                  ] else
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Text('No history yet. Start logging water!',
                            style: TextStyle(color: NudgeTokens.textLow)),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildTodayCard() {
    final frac = (_todayTotal / _goal).clamp(0.0, 1.0);
    final color = frac >= 1.0 ? NudgeTokens.green : frac >= 0.6 ? NudgeTokens.blue : NudgeTokens.amber;
    final remaining = (_goal - _todayTotal).clamp(0.0, _goal);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [NudgeTokens.blue.withValues(alpha: 0.15), NudgeTokens.card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NudgeTokens.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_drop_rounded, color: color, size: 16),
              const SizedBox(width: 8),
              Text('TODAY', style: GoogleFonts.outfit(
                  fontSize: 10, fontWeight: FontWeight.w900,
                  color: NudgeTokens.textLow, letterSpacing: 1.3)),
              const Spacer(),
              Text('${_goal.toInt()} ml goal',
                  style: GoogleFonts.outfit(fontSize: 11, color: NudgeTokens.textLow)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${_todayTotal.toInt()}',
                  style: GoogleFonts.outfit(fontSize: 40, fontWeight: FontWeight.w900, color: color)),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Text('ml', style: GoogleFonts.outfit(fontSize: 14, color: color.withValues(alpha: 0.7))),
              ),
              const Spacer(),
              if (frac < 1.0)
                Text('${remaining.toInt()} ml to go',
                    style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.textMid))
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: NudgeTokens.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: NudgeTokens.green.withValues(alpha: 0.4)),
                  ),
                  child: Text('Goal met! 🎉',
                      style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.green, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 8,
              backgroundColor: NudgeTokens.elevated,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    // Last 14 days shown in chart (oldest → newest, left → right)
    final chartLogs = _logs.take(14).toList().reversed.toList();
    final maxVal = chartLogs.fold(0.0, (m, l) {
      final v = (l['totalAmount'] as num?)?.toDouble() ?? 0.0;
      return v > m ? v : m;
    });

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LAST 14 DAYS',
              style: GoogleFonts.outfit(
                  fontSize: 10, fontWeight: FontWeight.w900,
                  color: NudgeTokens.textLow, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal > 0 ? maxVal * 1.3 : _goal * 1.3,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: _goal,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: NudgeTokens.blue.withValues(alpha: 0.2), strokeWidth: 1, dashArray: [4, 4]),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= chartLogs.length) return const SizedBox.shrink();
                    final iso = chartLogs[i]['dayIso'] as String;
                    final day = iso.substring(8); // DD
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(day,
                          style: GoogleFonts.outfit(fontSize: 9, color: NudgeTokens.textLow)),
                    );
                  },
                )),
              ),
              barGroups: List.generate(chartLogs.length, (i) {
                final total = (chartLogs[i]['totalAmount'] as num?)?.toDouble() ?? 0.0;
                final frac = (total / _goal).clamp(0.0, double.infinity);
                final color = frac >= 1.0 ? NudgeTokens.green : frac >= 0.6 ? NudgeTokens.blue : NudgeTokens.amber;
                return BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: total,
                    color: color,
                    width: chartLogs.length > 10 ? 14 : 20,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxVal > 0 ? maxVal * 1.3 : _goal * 1.3,
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                ]);
              }),
            )),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Legend(color: NudgeTokens.green, label: 'Goal met'),
              const SizedBox(width: 16),
              _Legend(color: NudgeTokens.blue, label: '≥60%'),
              const SizedBox(width: 16),
              _Legend(color: NudgeTokens.amber, label: '<60%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DAILY LOG',
            style: GoogleFonts.outfit(
                fontSize: 10, fontWeight: FontWeight.w900,
                color: NudgeTokens.textLow, letterSpacing: 1.2)),
        const SizedBox(height: 10),
        ..._logs.map((log) {
          final iso = log['dayIso'] as String;
          final total = (log['totalAmount'] as num?)?.toInt() ?? 0;
          final local = (log['localAmount'] as num?)?.toInt() ?? 0;
          final hc = (log['healthConnectAmount'] as num?)?.toInt() ?? 0;
          final frac = (total / _goal).clamp(0.0, 1.0);
          final color = frac >= 1.0 ? NudgeTokens.green : frac >= 0.6 ? NudgeTokens.blue : NudgeTokens.amber;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: NudgeTokens.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: frac >= 1.0 ? NudgeTokens.green.withValues(alpha: 0.3) : NudgeTokens.border,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(iso,
                          style: GoogleFonts.outfit(
                              fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                      const Spacer(),
                      Text('$total ml',
                          style: GoogleFonts.outfit(
                              fontSize: 16, fontWeight: FontWeight.w900, color: color)),
                      if (frac >= 1.0) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.check_circle_rounded, color: NudgeTokens.green, size: 16),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: frac,
                      minHeight: 6,
                      backgroundColor: NudgeTokens.elevated,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  if (local > 0 || hc > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (local > 0)
                          _SourceChip(label: '$local ml logged', color: NudgeTokens.blue),
                        if (local > 0 && hc > 0) const SizedBox(width: 6),
                        if (hc > 0)
                          _SourceChip(label: '$hc ml from HC', color: NudgeTokens.purple),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: NudgeTokens.textLow, fontSize: 9, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _SourceChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SourceChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}
