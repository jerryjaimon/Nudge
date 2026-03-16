import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import '../app.dart' show NudgeTokens;
import '../storage.dart';
import '../utils/health_service.dart';
import 'package:nudge/utils/nudge_theme_extension.dart';

class RawHealthDataScreen extends StatefulWidget {
  const RawHealthDataScreen({super.key});

  @override
  State<RawHealthDataScreen> createState() => _RawHealthDataScreenState();
}

class _RawHealthDataScreenState extends State<RawHealthDataScreen> {
  List<HealthDataPoint> _points = [];
  bool _loading = false;
  String _error = '';

  // Date range
  _Range _range = _Range.today;

  // Filter
  String _filter = 'ALL';

  static const _filterOptions = ['ALL', 'STEPS', 'CALORIES', 'WORKOUT', 'WATER', 'DISTANCE'];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final now = DateTime.now();
      final DateTime start;
      switch (_range) {
        case _Range.today:
          start = DateTime(now.year, now.month, now.day);
          break;
        case _Range.week:
          start = now.subtract(const Duration(days: 7));
          break;
        case _Range.month:
          start = now.subtract(const Duration(days: 30));
          break;
        default:
          start = DateTime(now.year, now.month, now.day);
      }
      final rawPoints = await HealthService.fetchAllRawData(start: start, end: now);
      final points = List<HealthDataPoint>.from(rawPoints);
      // Newest first
      points.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
      setState(() {
        _points = points;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _dumpAll() async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 1));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fetching deep dump (last 24 hours)...')),
    );
    final dump = await HealthService.fetchDeepDump(start: start, end: now);
    await Clipboard.setData(ClipboardData(text: dump.join('\n\n')));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deep dump copied to clipboard!')),
      );
    }
  }

  List<HealthDataPoint> get _filtered {
    if (_filter == 'ALL') return _points;
    return _points.where((p) {
      switch (_filter) {
        case 'STEPS':
          return p.type == HealthDataType.STEPS;
        case 'CALORIES':
          return p.type == HealthDataType.ACTIVE_ENERGY_BURNED ||
              p.type == HealthDataType.BASAL_ENERGY_BURNED ||
              p.type == HealthDataType.TOTAL_CALORIES_BURNED;
        case 'WORKOUT':
          return p.type == HealthDataType.WORKOUT;
        case 'WATER':
          return p.type == HealthDataType.WATER;
        case 'DISTANCE':
          return p.type == HealthDataType.DISTANCE_DELTA;
        default:
          return true;
      }
    }).toList();
  }

  String _valueString(HealthDataPoint p) {
    final v = p.value;
    if (v is WorkoutHealthValue) {
      final type = v.workoutActivityType.name.replaceAll('_', ' ');
      final cal = v.totalEnergyBurned;
      final dist = v.totalDistance;
      final dur = p.dateTo.difference(p.dateFrom);
      final parts = [
        type,
        '${dur.inMinutes}min',
        if (cal != null && cal > 0) '${cal}kcal',
        if (dist != null && dist > 0) '${(dist / 1000).toStringAsFixed(2)}km',
      ];
      return parts.join(' · ');
    }
    if (v is NumericHealthValue) {
      final n = v.numericValue;
      final unit = p.unitString;
      if (p.type == HealthDataType.STEPS) {
        return '${n.toStringAsFixed(0)} steps';
      }
      if (p.type == HealthDataType.WATER) {
        return '${n.toStringAsFixed(0)} $unit';
      }
      if (p.type == HealthDataType.DISTANCE_DELTA) {
        return '${(n / 1000).toStringAsFixed(3)} km (${n.toStringAsFixed(0)} m)';
      }
      return '${n.toStringAsFixed(2)} $unit';
    }
    return v.toString() ?? 'None';
  }

  Color _typeColor(HealthDataType t) {
    switch (t) {
      case HealthDataType.STEPS:
        return NudgeTokens.green;
      case HealthDataType.ACTIVE_ENERGY_BURNED:
        return NudgeTokens.amber;
      case HealthDataType.BASAL_ENERGY_BURNED:
        return const Color(0xFFFFD54F);
      case HealthDataType.TOTAL_CALORIES_BURNED:
        return NudgeTokens.red;
      case HealthDataType.WORKOUT:
        return NudgeTokens.blue;
      case HealthDataType.WATER:
        return const Color(0xFF40C4FF);
      case HealthDataType.DISTANCE_DELTA:
        return NudgeTokens.purple;
      default:
        return NudgeTokens.textLow;
    }
  }

  String _typeName(HealthDataType t) {
    switch (t) {
      case HealthDataType.STEPS:
        return 'STEPS';
      case HealthDataType.ACTIVE_ENERGY_BURNED:
        return 'ACTIVE CAL';
      case HealthDataType.BASAL_ENERGY_BURNED:
        return 'BASAL CAL';
      case HealthDataType.TOTAL_CALORIES_BURNED:
        return 'TOTAL CAL';
      case HealthDataType.WORKOUT:
        return 'WORKOUT';
      case HealthDataType.WATER:
        return 'WATER';
      case HealthDataType.DISTANCE_DELTA:
        return 'DISTANCE';
      default:
        return t.name;
    }
  }

  String _formatDt(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final monthIdx = dt.month.clamp(1, 12) - 1;
    return '${months[monthIdx]} ${dt.day}  $h:$m';
  }

  /// Summary card: count per type + calorie breakdown
  Widget _buildSummary() {
    final steps = _points.where((p) => p.type == HealthDataType.STEPS);
    final activeKcal = _points.where((p) => p.type == HealthDataType.ACTIVE_ENERGY_BURNED);
    final basalKcal = _points.where((p) => p.type == HealthDataType.BASAL_ENERGY_BURNED);
    final totalKcal = _points.where((p) => p.type == HealthDataType.TOTAL_CALORIES_BURNED);
    final workouts = _points.where((p) => p.type == HealthDataType.WORKOUT);
    final water = _points.where((p) => p.type == HealthDataType.WATER);

    double sumNum(Iterable<HealthDataPoint> pts) => pts.fold(0.0, (s, p) {
          final v = p.value;
          return s + (v is NumericHealthValue ? v.numericValue.toDouble() : 0.0);
        });

    final rows = <_SummaryRow>[
      _SummaryRow('Steps', '${sumNum(steps).toStringAsFixed(0)} steps', '${steps.length} pts', NudgeTokens.green),
      _SummaryRow('Active Cal', '${sumNum(activeKcal).toStringAsFixed(0)} kcal', '${activeKcal.length} pts', NudgeTokens.amber),
      _SummaryRow('Basal Cal', '${sumNum(basalKcal).toStringAsFixed(0)} kcal', '${basalKcal.length} pts', const Color(0xFFFFD54F)),
      _SummaryRow('Total Cal', '${sumNum(totalKcal).toStringAsFixed(0)} kcal', '${totalKcal.length} pts', NudgeTokens.red),
      _SummaryRow('Workouts', '${workouts.length} sessions', '', NudgeTokens.blue),
      _SummaryRow('Water', '${sumNum(water).toStringAsFixed(0)} ml', '${water.length} pts', const Color(0xFF40C4FF)),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Summary · ${_points.length} total points',
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: NudgeTokens.textMid,
                  letterSpacing: 0.5)),
          const SizedBox(height: 10),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: r.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(r.label,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: NudgeTokens.textMid)),
                    const Spacer(),
                    Text(r.value,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: r.color)),
                    if (r.sub.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(r.sub,
                          style: const TextStyle(
                              fontSize: 10, color: NudgeTokens.textLow)),
                    ],
                  ],
                ),
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Connect Raw Data', style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            tooltip: 'Debug API Key',
            icon: const Icon(Icons.key_rounded),
            onPressed: () {
              final key = AppStorage.activeGeminiKey;
              // ignore: avoid_print
              print('################################################################');
              // ignore: avoid_print
              print('!!!! MANUAL DEBUG: TAPPING DEBUG KEY BUTTON !!!!');
              // ignore: avoid_print
              print('KEY: $key');
              // ignore: avoid_print
              print('################################################################');
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('API Key Logged with high visibility!')),
              );
            },
          ),
          IconButton(
            tooltip: 'Deep Dump (Clipboard)',
            icon: const Icon(Icons.content_paste_go_rounded),
            onPressed: _dumpAll,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetch,
          ),
        ],
      ),
      body: Column(
        children: [
          // Range selector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: _Range.values.map((r) {
                final selected = _range == r;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _range = r);
                      _fetch();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected
                            ? NudgeTokens.purple.withValues(alpha: 0.15)
                            : NudgeTokens.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: selected
                                ? NudgeTokens.purple.withValues(alpha: 0.5)
                                : NudgeTokens.border),
                      ),
                      child: Text(
                        r.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected ? NudgeTokens.purple : NudgeTokens.textMid,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // Filter chips
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _filterOptions.map((f) {
                final selected = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? NudgeTokens.blue.withValues(alpha: 0.15)
                            : NudgeTokens.elevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: selected
                                ? NudgeTokens.blue.withValues(alpha: 0.5)
                                : NudgeTokens.border),
                      ),
                      child: Text(
                        f,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: selected ? NudgeTokens.blue : NudgeTokens.textLow,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error,
                            style: const TextStyle(color: NudgeTokens.red, fontSize: 12)),
                      )
                    : _points.isEmpty
                        ? const Center(
                            child: Text(
                              'No data — check Health Connect is enabled\nand permissions granted.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: NudgeTokens.textLow, height: 1.5),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 32),
                            itemCount: filtered.length + 1, // +1 for summary header
                            itemBuilder: (ctx, i) {
                              if (i == 0) return _buildSummary();
                              final p = filtered[i - 1];
                              final color = _typeColor(p.type);
                              final typeName = _typeName(p.type);
                              final value = _valueString(p);
                              final fromDt = _formatDt(p.dateFrom);
                              final toDt = _formatDt(p.dateTo);
                              final sameTime = fromDt == toDt;

                              return GestureDetector(
                                onLongPress: () {
                                  final text = '$typeName | $value | $fromDt | ${p.sourceName}';
                                  Clipboard.setData(ClipboardData(text: text));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Copied to clipboard'),
                                        duration: Duration(seconds: 1)),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                  decoration: BoxDecoration(
                                    color: NudgeTokens.card,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: NudgeTokens.border),
                                  ),
                                  child: IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Container(
                                          width: 3,
                                          margin: const EdgeInsets.only(right: 12),
                                          decoration: BoxDecoration(
                                            color: color,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: color.withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(typeName,
                                                        style: TextStyle(
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.w900,
                                                            color: color,
                                                            letterSpacing: 0.8)),
                                                  ),
                                                  const Spacer(),
                                                  Text(fromDt,
                                                      style: const TextStyle(
                                                          fontSize: 10,
                                                          color: NudgeTokens.textLow)),
                                                ],
                                              ),
                                              const SizedBox(height: 5),
                                              Text(value,
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w700,
                                                      color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh))),
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(p.sourceName,
                                                        style: const TextStyle(
                                                            fontSize: 10,
                                                            color: NudgeTokens.textLow),
                                                        overflow: TextOverflow.ellipsis),
                                                  ),
                                                  if (!sameTime)
                                                    Text('→ $toDt',
                                                        style: const TextStyle(
                                                            fontSize: 10,
                                                            color: NudgeTokens.textLow)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

enum _Range {
  today('Today'),
  week('7 days'),
  month('30 days');

  final String label;
  const _Range(this.label);
}

class _SummaryRow {
  final String label;
  final String value;
  final String sub;
  final Color color;
  const _SummaryRow(this.label, this.value, this.sub, this.color);
}

