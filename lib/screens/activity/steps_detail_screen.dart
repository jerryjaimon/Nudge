// lib/screens/activity/steps_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import '../../app.dart' show NudgeTokens;
import '../../utils/health_service.dart';

class StepsDetailScreen extends StatefulWidget {
  const StepsDetailScreen({super.key});

  @override
  State<StepsDetailScreen> createState() => _StepsDetailScreenState();
}

class _StepsDetailScreenState extends State<StepsDetailScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  List<HealthDataPoint> _points = [];
  Map<String, double> _localSteps = {};
  Map<String, dynamic> _aggregation = {};
  Set<String> _countedKeys = {};
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _fetch();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final pts = await HealthService.fetchRawHealthData();
    pts.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
    final localLogs = await HealthService.getLocalStepsForToday();
    final activity = await HealthService.fetchDailyActivityBySource();
    if (mounted) {
      setState(() {
        _points = pts
            .where((p) =>
                p.type == HealthDataType.STEPS ||
                p.type == HealthDataType.ACTIVE_ENERGY_BURNED ||
                p.type == HealthDataType.BASAL_ENERGY_BURNED ||
                p.type == HealthDataType.TOTAL_CALORIES_BURNED)
            .toList();
        _localSteps = localLogs;
        _aggregation = activity;
        _countedKeys = (activity['countedPointKeys'] as Set<String>?) ?? {};
        _loading = false;
      });
    }
  }

  String _mapSource(String source) {
    if (source.contains('com.google.android.apps.fitness')) return 'Google Fit';
    if (source.contains('com.sec.android') || source.contains('samsung.shealth')) {
      return 'Samsung Health';
    }
    if (source.contains('hevy')) return 'Hevy';
    if (source.contains('healthconnect')) return 'Health Connect';
    if (source.contains('com.google.android.apps.healthdata')) return 'Health Platform';
    return source.split('.').last;
  }

  Future<void> _addSteps() async {
    final ctrl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NudgeTokens.elevated,
        title: const Text('Add Steps Manually', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g. 500',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: NudgeTokens.border)),
            focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: NudgeTokens.green)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: NudgeTokens.textLow)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Save', style: TextStyle(color: NudgeTokens.green)),
          ),
        ],
      ),
    );
    if (res != null && res.isNotEmpty) {
      final steps = double.tryParse(res) ?? 0.0;
      if (steps > 0) {
        await HealthService.addLocalSteps(steps, steps * 0.04);
        _fetch();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step Tracking'),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Source Priority',
            onPressed: () async {
              await showModalBottomSheet(
                context: context,
                backgroundColor: NudgeTokens.elevated,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                builder: (_) => _SourcePrioritySheet(onChanged: _fetch),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetch,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: NudgeTokens.green,
          labelColor: NudgeTokens.green,
          unselectedLabelColor: NudgeTokens.textLow,
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: 'Hourly'),
            Tab(text: 'Raw Data'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSteps,
        icon: const Icon(Icons.add),
        label: const Text('Manual Entry'),
        backgroundColor: NudgeTokens.green,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: NudgeTokens.green))
          : TabBarView(
              controller: _tabs,
              children: [
                _SummaryTab(
                    aggregation: _aggregation,
                    localSteps: _localSteps,
                    mapSource: _mapSource),
                _HourlyTab(points: _points, mapSource: _mapSource),
                _RawTab(points: _points, mapSource: _mapSource, countedKeys: _countedKeys),
              ],
            ),
    );
  }
}

// ── Summary tab ───────────────────────────────────────────────────────────────

class _SummaryTab extends StatelessWidget {
  final Map<String, dynamic> aggregation;
  final Map<String, double> localSteps;
  final String Function(String) mapSource;

  const _SummaryTab(
      {required this.aggregation,
      required this.localSteps,
      required this.mapSource});

  @override
  Widget build(BuildContext context) {
    final grouped = (aggregation['grouped'] as Map<String, dynamic>?) ?? {};
    final totals = aggregation['totals'] as Map? ?? {};
    final bestSource = aggregation['bestSource'] as String? ?? 'Unknown';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // How steps are counted explanation
        _SectionHeader('HOW TRACKING WORKS'),
        const SizedBox(height: 8),
        _InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(
                icon: Icons.looks_one_rounded,
                color: NudgeTokens.green,
                text:
                    'Health Connect collects step data from all connected apps (Google Fit, Samsung Health, wearables, etc.)',
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.looks_two_rounded,
                color: NudgeTokens.green,
                text:
                    'Each source reports independently — Nudge picks the source with the highest step count to avoid double-counting.',
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.looks_3_rounded,
                color: NudgeTokens.green,
                text:
                    'Calories are estimated from the winning source. Manual entries are added on top.',
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        _SectionHeader('TODAY\'S RESULT'),
        const SizedBox(height: 8),
        _InfoCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Selected source',
                      style: TextStyle(color: NudgeTokens.textMid)),
                  Text(mapSource(bestSource),
                      style: const TextStyle(
                          color: NudgeTokens.green,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                ],
              ),
              const Divider(color: NudgeTokens.border, height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Steps', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(
                    '${((totals['steps'] as double?) ?? 0.0).toInt()}',
                    style: const TextStyle(
                        color: NudgeTokens.green,
                        fontWeight: FontWeight.w900,
                        fontSize: 22),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Calories', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(
                    '${((totals['calories'] as double?) ?? 0.0).toInt()} kcal',
                    style: const TextStyle(
                        color: NudgeTokens.amber, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ],
          ),
        ),

        if (localSteps['steps'] != null && localSteps['steps']! > 0) ...[
          const SizedBox(height: 8),
          _InfoCard(
            accent: NudgeTokens.blue,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.edit_rounded, color: NudgeTokens.blue, size: 16),
                  const SizedBox(width: 8),
                  const Text('Manual steps added',
                      style: TextStyle(color: Colors.white)),
                ]),
                Text('+${localSteps['steps']!.toInt()} steps',
                    style: const TextStyle(
                        color: NudgeTokens.blue, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),
        _SectionHeader('ALL SOURCES COMPARED'),
        const SizedBox(height: 8),
        if (grouped.isEmpty)
          const Text('No source data available.',
              style: TextStyle(color: NudgeTokens.textLow))
        else
          ...grouped.entries.map((e) {
            final d = e.value as Map<String, double>? ?? {};
            final stp = (d['steps'] ?? 0.0).toInt();
            final cal = (d['calories'] ?? 0.0).toInt();
            final act = (d['active_cal'] ?? 0.0).toInt();
            final bsl = (d['basal_cal'] ?? 0.0).toInt();
            final isWinner = e.key == bestSource;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _InfoCard(
                accent: isWinner ? NudgeTokens.green : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(children: [
                            if (isWinner)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(Icons.check_circle_rounded,
                                    color: NudgeTokens.green, size: 16),
                              ),
                            Expanded(
                              child: Text(
                                mapSource(e.key),
                                style: TextStyle(
                                    color: isWinner
                                        ? NudgeTokens.green
                                        : Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ]),
                        ),
                        Text(
                          '$stp steps · $cal kcal',
                          style: const TextStyle(
                              color: NudgeTokens.textMid,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (act > 0 || bsl > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Active $act kcal  ·  Basal $bsl kcal',
                        style: const TextStyle(
                            color: NudgeTokens.textLow, fontSize: 11),
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

// ── Hourly tab ────────────────────────────────────────────────────────────────

class _HourlyTab extends StatelessWidget {
  final List<HealthDataPoint> points;
  final String Function(String) mapSource;

  const _HourlyTab({required this.points, required this.mapSource});

  @override
  Widget build(BuildContext context) {
    // Build hour → steps map
    final Map<int, int> hourSteps = {};
    final Map<int, List<String>> hourSources = {};

    for (final p in points) {
      if (p.type != HealthDataType.STEPS) continue;
      final h = p.dateFrom.hour;
      final val = p.value is NumericHealthValue
          ? (p.value as NumericHealthValue).numericValue.toInt()
          : 0;
      hourSteps[h] = (hourSteps[h] ?? 0) + val;
      hourSources.putIfAbsent(h, () => []);
      final src = mapSource(p.sourceName);
      if (!hourSources[h]!.contains(src)) hourSources[h]!.add(src);
    }

    if (hourSteps.isEmpty) {
      return const Center(
        child: Text('No step data available for today.',
            style: TextStyle(color: NudgeTokens.textLow)),
      );
    }

    final maxSteps = hourSteps.values.fold(0, (a, b) => a > b ? a : b);
    final hours = List.generate(24, (i) => i);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _SectionHeader('STEPS BY HOUR'),
        const SizedBox(height: 12),
        ...hours.where((h) => hourSteps.containsKey(h)).map((h) {
          final steps = hourSteps[h] ?? 0;
          final sources = hourSources[h] ?? [];
          final fraction = maxSteps > 0 ? steps / maxSteps : 0.0;
          final label = h == 0
              ? '12 AM'
              : h < 12
                  ? '$h AM'
                  : h == 12
                      ? '12 PM'
                      : '${h - 12} PM';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(label,
                      style: const TextStyle(
                          color: NudgeTokens.textLow, fontSize: 11),
                      textAlign: TextAlign.right),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fraction.toDouble(),
                          minHeight: 10,
                          backgroundColor: NudgeTokens.elevated,
                          valueColor: const AlwaysStoppedAnimation(NudgeTokens.green),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$steps steps  ·  ${sources.join(', ')}',
                        style: const TextStyle(
                            color: NudgeTokens.textLow, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 40,
                  child: Text(
                    steps > 999 ? '${(steps / 1000).toStringAsFixed(1)}k' : '$steps',
                    style: const TextStyle(
                        color: NudgeTokens.green,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── Raw data tab ──────────────────────────────────────────────────────────────

class _RawTab extends StatelessWidget {
  final List<HealthDataPoint> points;
  final String Function(String) mapSource;
  final Set<String> countedKeys;

  const _RawTab({required this.points, required this.mapSource, required this.countedKeys});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(
        child: Text('No raw data from Health Connect.',
            style: TextStyle(color: NudgeTokens.textLow)),
      );
    }

    // Show newest first
    final sorted = [...points]..sort((a, b) => b.dateFrom.compareTo(a.dateFrom));

    Color _typeColor(HealthDataType t) {
      if (t == HealthDataType.STEPS) return NudgeTokens.green;
      if (t == HealthDataType.ACTIVE_ENERGY_BURNED) return NudgeTokens.amber;
      if (t == HealthDataType.BASAL_ENERGY_BURNED) return NudgeTokens.textLow;
      return NudgeTokens.blue;
    }

    String _typeLabel(HealthDataType t) {
      if (t == HealthDataType.STEPS) return 'STEPS';
      if (t == HealthDataType.ACTIVE_ENERGY_BURNED) return 'ACTIVE CAL';
      if (t == HealthDataType.BASAL_ENERGY_BURNED) return 'BASAL CAL';
      if (t == HealthDataType.TOTAL_CALORIES_BURNED) return 'TOTAL CAL';
      return t.name;
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: sorted.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SectionHeader('${sorted.length} RAW DATA POINTS (newest first)'),
          );
        }
        final p = sorted[i - 1];
        final val = p.value is NumericHealthValue
            ? (p.value as NumericHealthValue).numericValue.toDouble()
            : 0.0;
        final color = _typeColor(p.type);
        final typeLabel = _typeLabel(p.type);
        final src = mapSource(p.sourceName);
        final from = p.dateFrom;
        final to = p.dateTo;
        final durMin = to.difference(from).inMinutes;
        final timeStr =
            '${from.hour.toString().padLeft(2, '0')}:${from.minute.toString().padLeft(2, '0')}'
            ' – ${to.hour.toString().padLeft(2, '0')}:${to.minute.toString().padLeft(2, '0')}';

        // Determine if this step point was counted in the final total
        final pointKey = '${p.sourceName}_${from.millisecondsSinceEpoch}';
        final isStepPoint = p.type == HealthDataType.STEPS;
        final isCounted = isStepPoint && countedKeys.contains(pointKey);
        final isFiltered = isStepPoint && !isCounted;

        return Opacity(
          opacity: isFiltered ? 0.38 : 1.0,
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: NudgeTokens.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCounted
                    ? NudgeTokens.green.withValues(alpha: 0.55)
                    : color.withValues(alpha: 0.18),
                width: isCounted ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(typeLabel,
                      style: TextStyle(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(src,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (isCounted)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.check_circle_rounded,
                                color: NudgeTokens.green, size: 13),
                          ),
                        if (isFiltered)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.block_rounded,
                                color: NudgeTokens.textLow, size: 13),
                          ),
                      ]),
                      Text(
                        '$timeStr${durMin > 0 ? '  ($durMin min)' : ''}',
                        style: const TextStyle(
                            color: NudgeTokens.textLow, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Text(
                  p.type == HealthDataType.STEPS
                      ? '${val.toInt()} steps'
                      : '${val.toInt()} kcal',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 14),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            color: NudgeTokens.textLow,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2),
      );
}

class _InfoCard extends StatelessWidget {
  final Widget child;
  final Color? accent;
  const _InfoCard({required this.child, this.accent});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NudgeTokens.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: accent != null
                  ? accent!.withValues(alpha: 0.25)
                  : NudgeTokens.border),
        ),
        child: child,
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InfoRow({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: NudgeTokens.textMid, fontSize: 13, height: 1.4)),
          ),
        ],
      );
}

// ── Source Priority Sheet ─────────────────────────────────────────────────────

class _SourcePrioritySheet extends StatefulWidget {
  final VoidCallback onChanged;
  const _SourcePrioritySheet({required this.onChanged});

  @override
  State<_SourcePrioritySheet> createState() => _SourcePrioritySheetState();
}

class _SourcePrioritySheetState extends State<_SourcePrioritySheet> {
  List<String> _priority = [];
  Set<String> _disabled = {};

  @override
  void initState() {
    super.initState();
    _priority = HealthService.getSourcePriority();
    _disabled = HealthService.getDisabledSources();
  }

  Future<void> _save() async {
    await HealthService.setSourcePriority(_priority);
    await HealthService.setDisabledSources(_disabled);
    widget.onChanged();
  }

  void _move(int index, int delta) {
    final newIdx = index + delta;
    if (newIdx < 0 || newIdx >= _priority.length) return;
    setState(() {
      final item = _priority.removeAt(index);
      _priority.insert(newIdx, item);
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Data Source Priority',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('Higher sources are trusted first. Lower sources only fill uncovered time gaps.',
                        style: TextStyle(color: NudgeTokens.textLow, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Legend
          Row(
            children: [
              _LegendDot(color: NudgeTokens.green, label: 'Counted'),
              const SizedBox(width: 16),
              _LegendDot(color: NudgeTokens.textLow, label: 'Filtered (dim in raw view)'),
            ],
          ),
          const SizedBox(height: 16),
          ..._priority.asMap().entries.map((entry) {
            final idx = entry.key;
            final cat = entry.value;
            final name = HealthService.sourceDisplayNames[cat] ?? cat;
            final desc = HealthService.sourceDescriptions[cat] ?? '';
            final isDisabled = _disabled.contains(cat);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: NudgeTokens.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDisabled
                      ? NudgeTokens.border
                      : NudgeTokens.green.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  // Priority number
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDisabled
                          ? NudgeTokens.elevated
                          : NudgeTokens.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isDisabled ? '—' : '${idx + 1}',
                      style: TextStyle(
                          color: isDisabled ? NudgeTokens.textLow : NudgeTokens.green,
                          fontWeight: FontWeight.w900,
                          fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                                color: isDisabled ? NudgeTokens.textLow : Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                        Text(desc,
                            style: const TextStyle(
                                color: NudgeTokens.textLow, fontSize: 11)),
                      ],
                    ),
                  ),
                  // Up/down buttons
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                    color: idx == 0 ? NudgeTokens.border : NudgeTokens.textMid,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: idx == 0 ? null : () => _move(idx, -1),
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                    color: idx == _priority.length - 1
                        ? NudgeTokens.border
                        : NudgeTokens.textMid,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: idx == _priority.length - 1 ? null : () => _move(idx, 1),
                  ),
                  const SizedBox(width: 4),
                  // Enable/disable toggle
                  Switch(
                    value: !isDisabled,
                    activeThumbColor: NudgeTokens.green,
                    activeTrackColor: NudgeTokens.green.withValues(alpha: 0.4),
                    onChanged: (val) {
                      setState(() {
                        if (val) {
                          _disabled.remove(cat);
                        } else {
                          _disabled.add(cat);
                        }
                      });
                      _save();
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: NudgeTokens.textMid, fontSize: 11)),
        ],
      );
}
