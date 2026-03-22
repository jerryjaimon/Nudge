// lib/screens/health/body_composition_screen.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:health/health.dart';
import 'package:image_picker/image_picker.dart';
import '../../app.dart' show NudgeTokens;
import '../../storage.dart';
import '../../utils/health_service.dart';

// ─── Metric definition ────────────────────────────────────────────────────────

typedef _MetricDef = ({String key, String label, String unit, Color color});

const List<_MetricDef> _kMetrics = [
  (key: 'bodyFatPct',    label: 'Body Fat %',     unit: '%',   color: NudgeTokens.amber),
  (key: 'muscleMassPct', label: 'Muscle %',       unit: '%',   color: NudgeTokens.gymB),
  (key: 'muscleMassKg',  label: 'Skeletal Muscle',unit: 'kg',  color: NudgeTokens.gymB),
  (key: 'fatMassKg',     label: 'Fat Mass',       unit: 'kg',  color: NudgeTokens.amber),
  (key: 'waterPct',      label: 'Water %',        unit: '%',   color: NudgeTokens.blue),
  (key: 'waterKg',       label: 'Body Water',     unit: 'kg',  color: NudgeTokens.blue),
  (key: 'boneMassKg',    label: 'Bone Mass',      unit: 'kg',  color: NudgeTokens.textMid),
  (key: 'visceralFat',   label: 'Visceral Fat',   unit: '',    color: NudgeTokens.red),
  (key: 'bmi',           label: 'BMI',            unit: '',    color: NudgeTokens.healthB),
  (key: 'bmrCal',        label: 'BMR',            unit: 'cal', color: NudgeTokens.purple),
  (key: 'metabolicAge',  label: 'Metabolic Age',  unit: 'yrs', color: NudgeTokens.purple),
  (key: 'weightKg',      label: 'Weight',         unit: 'kg',  color: Colors.white),
];

String _fmt(num? v, String unit) {
  if (v == null) return '—';
  final s = v is double ? v.toStringAsFixed(1) : v.toString();
  return unit.isEmpty ? s : '$s $unit';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class BodyCompositionScreen extends StatefulWidget {
  const BodyCompositionScreen({super.key});

  @override
  State<BodyCompositionScreen> createState() => _BodyCompositionScreenState();
}

class _BodyCompositionScreenState extends State<BodyCompositionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _load() {
    final raw = (AppStorage.gymBox.get('body_comp_entries', defaultValue: <dynamic>[]) as List);
    _entries = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
      ..sort((a, b) => (b['dateIso'] as String).compareTo(a['dateIso'] as String));
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _persist() async {
    await AppStorage.gymBox.put('body_comp_entries', _entries);
  }

  // ── HC sync ─────────────────────────────────────────────────────────────────

  Future<void> _syncHC() async {
    setState(() => _busy = true);
    try {
      final bodyTypes = [
        HealthDataType.BODY_FAT_PERCENTAGE,
        HealthDataType.WEIGHT,
        HealthDataType.HEIGHT,
      ];
      final granted = await HealthService.health.requestAuthorization(bodyTypes);
      if (!granted) {
        _snack('Health Connect permission not granted');
        return;
      }
      final now = DateTime.now();
      final points = await HealthService.health.getHealthDataFromTypes(
        startTime: now.subtract(const Duration(days: 365)),
        endTime: now,
        types: bodyTypes,
      );
      if (points.isEmpty) {
        _snack('No body composition data found in Health Connect');
        return;
      }

      final byDate = <String, Map<String, dynamic>>{};
      for (final p in points) {
        final d = p.dateFrom;
        final iso = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        byDate.putIfAbsent(iso, () => {'dateIso': iso, 'source': 'hc'});
        if (p.value is! NumericHealthValue) continue;
        final v = (p.value as NumericHealthValue).numericValue.toDouble();
        switch (p.type) {
          case HealthDataType.BODY_FAT_PERCENTAGE:
            // HC stores as fraction (0.25) or percent (25.0) — normalise to %
            byDate[iso]!['bodyFatPct'] = v > 1.0 ? v : v * 100;
          case HealthDataType.WEIGHT:
            byDate[iso]!['weightKg'] = v;
          case HealthDataType.HEIGHT:
            // HC stores height in metres
            byDate[iso]!['heightCm'] = v > 3.0 ? v : v * 100;
          default:
            break;
        }
      }

      // Compute BMI where possible
      for (final e in byDate.values) {
        final w = (e['weightKg'] as num?)?.toDouble();
        final h = (e['heightCm'] as num?)?.toDouble();
        if (w != null && h != null && h > 0 && e['bmi'] == null) {
          final hm = h / 100;
          e['bmi'] = double.parse((w / (hm * hm)).toStringAsFixed(1));
        }
      }

      int added = 0, updated = 0;
      for (final e in byDate.values) {
        final idx = _entries.indexWhere(
            (x) => x['dateIso'] == e['dateIso'] && x['source'] == 'hc');
        if (idx >= 0) { _entries[idx] = e; updated++; }
        else { _entries.add(e); added++; }
      }
      _entries.sort((a, b) => (b['dateIso'] as String).compareTo(a['dateIso'] as String));
      await _persist();
      if (mounted) setState(() {});
      _snack('Synced: $added new, $updated updated');
    } catch (e) {
      _snack('Sync failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Screenshot OCR (on-device ML Kit) ──────────────────────────────────────

  Future<void> _scanScreenshot() async {
    final xfile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (xfile == null) return;
    setState(() => _busy = true);
    try {
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final inputImage = InputImage.fromFilePath(xfile.path);
      final recognized = await recognizer.processImage(inputImage);
      await recognizer.close();
      final text = recognized.text;
      if (text.trim().isEmpty) {
        _snack('No text found in image');
        return;
      }
      final parsed = _parseBodyCompText(text);
      if (mounted) {
        final saved = await _showReview(parsed, 'screenshot');
        if (saved != null) _upsertEntry(saved, 'screenshot');
      }
    } catch (e) {
      _snack('OCR failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Extracts body composition metrics from raw OCR text using regex patterns
  /// that cover RENPHO, Xiaomi, Tanita, Samsung Health, Huawei Health, etc.
  static Map<String, dynamic> _parseBodyCompText(String text) {
    final result = <String, dynamic>{};
    final t = text.toLowerCase();

    // Returns the first number found after [keyword] within [window] chars.
    double? after(String keyword, {int window = 60}) {
      final idx = t.indexOf(keyword);
      if (idx < 0) return null;
      final slice = text.substring(idx, (idx + window).clamp(0, text.length));
      final m = RegExp(r'(\d{1,3}(?:[.,]\d{1,2})?)').firstMatch(slice.replaceFirst(keyword, ''));
      return m == null ? null : double.tryParse(m.group(1)!.replaceAll(',', '.'));
    }

    // Helper: check if a number near keyword is followed by "kg" or "%"
    // Returns ('kg'|'%'|'') unit hint within window chars after keyword.
    String unitAfter(String keyword, {int window = 80}) {
      final idx = t.indexOf(keyword);
      if (idx < 0) return '';
      final slice = t.substring(idx, (idx + window).clamp(0, t.length));
      if (RegExp(r'\d\s*kg').hasMatch(slice)) return 'kg';
      if (RegExp(r'\d\s*%').hasMatch(slice)) return '%';
      return '';
    }

    // Weight — look for explicit kg label first, then "weight" keyword
    final kgMatch = RegExp(r'(\d{2,3}(?:[.,]\d{1,2})?)\s*kg', caseSensitive: false).firstMatch(text);
    if (kgMatch != null) result['weightKg'] = double.tryParse(kgMatch.group(1)!.replaceAll(',', '.'));
    result['weightKg'] ??= after('weight');

    // Body fat — could be % (RENPHO/Tanita) or kg (Samsung "Fat mass")
    final fatVal = after('body fat') ?? after('fat %') ?? after('fat:') ?? after('bf:') ?? after('bf %');
    if (fatVal != null) result['bodyFatPct'] = fatVal;
    final fatMassVal = after('fat mass');
    if (fatMassVal != null) {
      final u = unitAfter('fat mass');
      if (u == 'kg') result['fatMassKg'] = fatMassVal;
      else result['bodyFatPct'] ??= fatMassVal;
    }

    // Skeletal muscle — Samsung shows kg, others show %
    final muscleVal = after('skeletal muscle') ?? after('muscle mass') ?? after('muscle %') ?? after('muscle:') ?? after('smm');
    if (muscleVal != null) {
      final src = t.contains('skeletal muscle') ? 'skeletal muscle'
                : t.contains('muscle mass') ? 'muscle mass' : '';
      final u = src.isNotEmpty ? unitAfter(src) : '';
      if (u == 'kg') result['muscleMassKg'] = muscleVal;
      else result['muscleMassPct'] = muscleVal;
    }

    // Body water — Samsung shows kg, others show %
    final waterVal = after('body water') ?? after('water %') ?? after('water:') ?? after('tbw');
    if (waterVal != null) {
      final src = t.contains('body water') ? 'body water' : '';
      final u = src.isNotEmpty ? unitAfter(src) : '';
      if (u == 'kg') result['waterKg'] = waterVal;
      else result['waterPct'] = waterVal;
    }

    // Bone mass (kg value, usually small like 2–4)
    result['boneMassKg'] = after('bone mass') ?? after('bone mineral') ?? after('bone weight') ?? after('bone:');

    // Visceral fat (integer level, usually 1–30)
    final vf = after('visceral fat') ?? after('visceral:') ?? after('vf:') ?? after('vf ');
    if (vf != null) result['visceralFat'] = vf.round();

    // BMI
    result['bmi'] = after('bmi') ?? after('body mass index');

    // BMR / Basal metabolic rate
    final bmr = after('basal metabolic rate') ?? after('bmr') ?? after('basal metabolism');
    if (bmr != null && bmr > 100) result['bmrCal'] = bmr.round();

    // Metabolic age
    final ma = after('metabolic age') ?? after('met. age') ?? after('metabolic:');
    if (ma != null) result['metabolicAge'] = ma.round();

    // Height
    final heightMatch = RegExp(r'(\d{3})\s*cm', caseSensitive: false).firstMatch(text);
    if (heightMatch != null) {
      result['heightCm'] = double.tryParse(heightMatch.group(1)!);
    }
    result['heightCm'] ??= after('height');

    result.removeWhere((_, v) => v == null);
    return result;
  }

  // ── Manual entry ─────────────────────────────────────────────────────────────

  Future<void> _manualEntry() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NudgeTokens.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _ManualEntrySheet(),
    );
    if (result != null) _upsertEntry(result, 'manual');
  }

  // ── Confirm sheet ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _showReview(Map<String, dynamic> data, String source) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NudgeTokens.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ReviewSheet(data: data, source: source),
    );
  }

  // ── Upsert ────────────────────────────────────────────────────────────────

  void _upsertEntry(Map<String, dynamic> data, String source) {
    final now = DateTime.now();
    final iso =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final entry = <String, dynamic>{'dateIso': iso, 'source': source};
    for (final k in [
      'weightKg', 'bodyFatPct', 'muscleMassPct', 'waterPct',
      'boneMassKg', 'visceralFat', 'bmi', 'metabolicAge', 'heightCm'
    ]) {
      final v = data[k];
      if (v != null) entry[k] = v is int ? v : (v as num?)?.toDouble();
    }
    if (entry['bmi'] == null) {
      final w = (entry['weightKg'] as num?)?.toDouble();
      final h = (entry['heightCm'] as num?)?.toDouble();
      if (w != null && h != null && h > 0) {
        final hm = h / 100;
        entry['bmi'] = double.parse((w / (hm * hm)).toStringAsFixed(1));
      }
    }
    _entries.removeWhere((e) => e['dateIso'] == iso && e['source'] == source);
    _entries.insert(0, entry);
    _entries.sort((a, b) => (b['dateIso'] as String).compareTo(a['dateIso'] as String));
    _persist();
    setState(() {});
    _snack('Entry saved');
  }

  void _deleteEntry(int idx) {
    _entries.removeAt(idx);
    _persist();
    setState(() {});
    _snack('Entry removed');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: NudgeTokens.surface));
  }

  // ── Add options sheet ─────────────────────────────────────────────────────

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: NudgeTokens.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: NudgeTokens.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Add Body Composition',
                  style: TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              _OptionTile(
                icon: Icons.health_and_safety_rounded,
                color: NudgeTokens.healthB,
                title: 'Sync from Health Connect',
                subtitle: 'Import body fat, weight & height',
                onTap: () { Navigator.pop(ctx); _syncHC(); },
              ),
              const SizedBox(height: 8),
              _OptionTile(
                icon: Icons.document_scanner_rounded,
                color: NudgeTokens.gymB,
                title: 'Scan Scale Screenshot',
                subtitle: 'AI reads your scale app screenshot',
                onTap: () { Navigator.pop(ctx); _scanScreenshot(); },
              ),
              const SizedBox(height: 8),
              _OptionTile(
                icon: Icons.edit_rounded,
                color: NudgeTokens.purple,
                title: 'Enter Manually',
                subtitle: 'Type in your metrics',
                onTap: () { Navigator.pop(ctx); _manualEntry(); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NudgeTokens.bg,
      appBar: AppBar(
        backgroundColor: NudgeTokens.surface,
        title: const Text('BODY COMPOSITION',
            style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8)),
        centerTitle: true,
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: NudgeTokens.gymB, strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.add_rounded, color: NudgeTokens.textMid),
              tooltip: 'Add entry',
              onPressed: _showAddOptions,
            ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: NudgeTokens.gymB,
          labelColor: NudgeTokens.gymB,
          unselectedLabelColor: NudgeTokens.textLow,
          labelStyle: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
          tabs: const [Tab(text: 'OVERVIEW'), Tab(text: 'HISTORY')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: NudgeTokens.gymB))
          : TabBarView(
              controller: _tab,
              children: [
                _OverviewTab(entries: _entries),
                _HistoryTab(entries: _entries, onDelete: _deleteEntry),
              ],
            ),
    );
  }
}

// ─── Overview tab ─────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  const _OverviewTab({required this.entries});

  Map<String, dynamic>? get _latest => entries.isNotEmpty ? entries.first : null;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _CurrentMetricsCard(entry: _latest),
        const SizedBox(height: 12),
        _TrendChart(entries: entries, metricKey: 'bodyFatPct',
            label: 'Body Fat %', color: NudgeTokens.amber, unit: '%'),
        const SizedBox(height: 12),
        if (entries.any((e) => e['weightKg'] != null))
          _TrendChart(entries: entries, metricKey: 'weightKg',
              label: 'Weight', color: NudgeTokens.healthB, unit: 'kg'),
        if (entries.any((e) => e['muscleMassPct'] != null)) ...[
          const SizedBox(height: 12),
          _TrendChart(entries: entries, metricKey: 'muscleMassPct',
              label: 'Muscle Mass %', color: NudgeTokens.gymB, unit: '%'),
        ],
      ],
    );
  }
}

// ── Current metrics card ─────────────────────────────────────────────────────

class _CurrentMetricsCard extends StatelessWidget {
  final Map<String, dynamic>? entry;
  const _CurrentMetricsCard({this.entry});

  @override
  Widget build(BuildContext context) {
    final hasData = entry != null;
    final dateStr = hasData ? (entry!['dateIso'] as String? ?? '') : '';
    final source = hasData ? (entry!['source'] as String? ?? '') : '';
    final sourceIcon = source == 'hc'
        ? Icons.health_and_safety_rounded
        : source == 'screenshot'
            ? Icons.document_scanner_rounded
            : Icons.edit_rounded;
    final sourceColor = source == 'hc'
        ? NudgeTokens.healthB
        : source == 'screenshot'
            ? NudgeTokens.gymB
            : NudgeTokens.purple;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: NudgeTokens.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NudgeTokens.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('LATEST READING',
                  style: TextStyle(
                      color: NudgeTokens.textLow,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4)),
              const Spacer(),
              if (hasData) ...[
                Icon(sourceIcon, color: sourceColor, size: 12),
                const SizedBox(width: 4),
                Text(dateStr,
                    style: const TextStyle(
                        color: NudgeTokens.textLow, fontSize: 10)),
              ],
            ],
          ),
          const SizedBox(height: 14),
          if (!hasData)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No entries yet — tap + to add one',
                  style: TextStyle(color: NudgeTokens.textLow, fontSize: 13)),
            )
          else
            _MetricsGrid(entry: entry!),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _MetricsGrid({required this.entry});

  @override
  Widget build(BuildContext context) {
    // Build rows of 3
    final tiles = _kMetrics.map((m) {
      final v = entry[m.key];
      final n = v is num ? v : null;
      return _MetricCell(label: m.label, value: _fmt(n, m.unit), color: m.color, hasValue: n != null);
    }).toList();

    final rows = <Widget>[];
    for (int i = 0; i < tiles.length; i += 3) {
      final rowItems = tiles.sublist(i, (i + 3).clamp(0, tiles.length));
      while (rowItems.length < 3) { rowItems.add(const _MetricCell(label: '', value: '', color: Colors.transparent, hasValue: false)); }
      rows.add(Row(children: rowItems.map((t) => Expanded(child: t)).toList()));
      if (i + 3 < tiles.length) rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }
}

class _MetricCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool hasValue;
  const _MetricCell({required this.label, required this.value, required this.color, required this.hasValue});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: hasValue ? color : NudgeTokens.textLow,
                fontSize: 15,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: NudgeTokens.textLow, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.6)),
      ],
    );
  }
}

// ── Trend chart ───────────────────────────────────────────────────────────────

class _TrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  final String metricKey;
  final String label;
  final Color color;
  final String unit;
  const _TrendChart({
    required this.entries,
    required this.metricKey,
    required this.label,
    required this.color,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = entries
        .where((e) => e[metricKey] != null)
        .toList()
      ..sort((a, b) => (a['dateIso'] as String).compareTo(b['dateIso'] as String));
    final last30 = sorted.length > 30 ? sorted.sublist(sorted.length - 30) : sorted;
    if (last30.isEmpty) return const SizedBox.shrink();

    final spots = <FlSpot>[];
    final dateLabels = <double, String>{};
    for (int i = 0; i < last30.length; i++) {
      final v = (last30[i][metricKey] as num?)?.toDouble();
      if (v == null) continue;
      spots.add(FlSpot(i.toDouble(), v));
      final dt = DateTime.tryParse(last30[i]['dateIso'] as String? ?? '');
      if (dt != null) dateLabels[i.toDouble()] = '${dt.day}/${dt.month}';
    }
    if (spots.isEmpty) return const SizedBox.shrink();

    final latest = spots.last.y;
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.2 + 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 24, 12),
      decoration: BoxDecoration(
          color: NudgeTokens.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NudgeTokens.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(),
                      style: const TextStyle(
                          color: NudgeTokens.textLow,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4)),
                  const SizedBox(height: 2),
                  Text(_fmt(latest, unit),
                      style: TextStyle(
                          color: color, fontSize: 20, fontWeight: FontWeight.w900)),
                ],
              ),
              const Spacer(),
              if (spots.length >= 2)
                Builder(builder: (_) {
                  final delta = spots.last.y - spots.first.y;
                  final sign = delta >= 0 ? '+' : '';
                  final deltaColor = metricKey == 'muscleMassPct'
                      ? (delta >= 0 ? NudgeTokens.green : NudgeTokens.red)
                      : (delta <= 0 ? NudgeTokens.green : NudgeTokens.red);
                  return Text('$sign${delta.toStringAsFixed(1)} $unit',
                      style: TextStyle(
                          color: deltaColor, fontSize: 12, fontWeight: FontWeight.w700));
                }),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => NudgeTokens.surface.withValues(alpha: 0.95),
                    tooltipRoundedRadius: 10,
                    getTooltipItems: (spots) => spots.map((s) {
                      final date = dateLabels[s.x] ?? '';
                      return LineTooltipItem(
                        '${_fmt(s.y, unit)}\n$date',
                        TextStyle(
                            color: color, fontSize: 12, fontWeight: FontWeight.w700),
                      );
                    }).toList(),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY + padding * 2) / 4,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: NudgeTokens.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                minY: minY - padding,
                maxY: maxY + padding,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: color,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, idx) => FlDotCirclePainter(
                        radius: idx == spots.length - 1 ? 4 : 2,
                        color: color,
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [color.withValues(alpha: 0.25), Colors.transparent],
                      ),
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
}

// ─── History tab ──────────────────────────────────────────────────────────────

class _HistoryTab extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  final void Function(int) onDelete;
  const _HistoryTab({required this.entries, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Text('No entries yet',
            style: TextStyle(color: NudgeTokens.textLow, fontSize: 13)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      itemCount: entries.length,
      itemBuilder: (ctx, i) => _HistoryCard(
        entry: entries[i],
        onDelete: () => onDelete(i),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onDelete;
  const _HistoryCard({required this.entry, required this.onDelete});

  String get _sourceLabel {
    switch (entry['source'] as String? ?? '') {
      case 'hc': return 'Health Connect';
      case 'screenshot': return 'Screenshot';
      default: return 'Manual';
    }
  }

  Color get _sourceColor {
    switch (entry['source'] as String? ?? '') {
      case 'hc': return NudgeTokens.healthB;
      case 'screenshot': return NudgeTokens.gymB;
      default: return NudgeTokens.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = entry['dateIso'] as String? ?? '';
    final metrics = _kMetrics.where((m) => entry[m.key] != null).toList();

    return Dismissible(
      key: ValueKey('${dateStr}_${entry['source']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
            color: NudgeTokens.red.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete_outline_rounded, color: NudgeTokens.red),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: NudgeTokens.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: NudgeTokens.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(dateStr,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _sourceColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_sourceLabel,
                      style: TextStyle(
                          color: _sourceColor, fontSize: 9, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            if (metrics.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: metrics.map((m) {
                  final v = entry[m.key] as num;
                  return RichText(
                    text: TextSpan(children: [
                      TextSpan(
                          text: _fmt(v, m.unit),
                          style: TextStyle(
                              color: m.color,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      TextSpan(
                          text: '  ${m.label}',
                          style: const TextStyle(
                              color: NudgeTokens.textLow, fontSize: 10)),
                    ]),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Manual entry sheet ───────────────────────────────────────────────────────

class _ManualEntrySheet extends StatefulWidget {
  const _ManualEntrySheet();

  @override
  State<_ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends State<_ManualEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _ctrls = <String, TextEditingController>{};

  static const _fields = [
    (key: 'weightKg',     label: 'Weight',          hint: 'kg',   integer: false),
    (key: 'bodyFatPct',   label: 'Body Fat',         hint: '%',    integer: false),
    (key: 'muscleMassPct',label: 'Muscle Mass',      hint: '%',    integer: false),
    (key: 'waterPct',     label: 'Body Water',       hint: '%',    integer: false),
    (key: 'boneMassKg',   label: 'Bone Mass',        hint: 'kg',   integer: false),
    (key: 'visceralFat',  label: 'Visceral Fat',     hint: 'level',integer: true),
    (key: 'bmi',          label: 'BMI',              hint: '',     integer: false),
    (key: 'metabolicAge', label: 'Metabolic Age',    hint: 'yrs',  integer: true),
    (key: 'heightCm',     label: 'Height',           hint: 'cm',   integer: false),
  ];

  @override
  void initState() {
    super.initState();
    for (final f in _fields) { _ctrls[f.key] = TextEditingController(); }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) { c.dispose(); }
    super.dispose();
  }

  void _submit() {
    final data = <String, dynamic>{};
    for (final f in _fields) {
      final text = _ctrls[f.key]!.text.trim();
      if (text.isEmpty) continue;
      if (f.integer) {
        final v = int.tryParse(text);
        if (v != null) data[f.key] = v;
      } else {
        final v = double.tryParse(text.replaceAll(',', '.'));
        if (v != null) data[f.key] = v;
      }
    }
    if (data.isEmpty) { _showError('Enter at least one value'); return; }
    Navigator.pop(context, data);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: NudgeTokens.red));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: NudgeTokens.border,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            const Text('Manual Entry',
                style: TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 0,
                  children: _fields.map((f) => SizedBox(
                    width: (MediaQuery.of(context).size.width - 52) / 2,
                    child: TextFormField(
                      controller: _ctrls[f.key],
                      keyboardType: f.integer
                          ? TextInputType.number
                          : const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: '${f.label}${f.hint.isNotEmpty ? " (${f.hint})" : ""}',
                        labelStyle: const TextStyle(color: NudgeTokens.textLow, fontSize: 12),
                        enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: NudgeTokens.border)),
                        focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: NudgeTokens.gymB)),
                      ),
                    ),
                  )).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                    backgroundColor: NudgeTokens.gymB,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Save Entry',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Confirm sheet (for screenshot OCR results) ───────────────────────────────

/// Editable review sheet — pre-fills fields with OCR-parsed values,
/// lets user correct any misreads, returns final map on save.
class _ReviewSheet extends StatefulWidget {
  final Map<String, dynamic> data;
  final String source;
  const _ReviewSheet({required this.data, required this.source});

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final _ctrls = <String, TextEditingController>{};

  static const _fields = [
    (key: 'weightKg',     label: 'Weight',        hint: 'kg',    integer: false),
    (key: 'bodyFatPct',   label: 'Body Fat',       hint: '%',     integer: false),
    (key: 'muscleMassPct',label: 'Muscle Mass',    hint: '%',     integer: false),
    (key: 'waterPct',     label: 'Body Water',     hint: '%',     integer: false),
    (key: 'boneMassKg',   label: 'Bone Mass',      hint: 'kg',    integer: false),
    (key: 'visceralFat',  label: 'Visceral Fat',   hint: 'level', integer: true),
    (key: 'bmi',          label: 'BMI',            hint: '',      integer: false),
    (key: 'metabolicAge', label: 'Metabolic Age',  hint: 'yrs',   integer: true),
    (key: 'heightCm',     label: 'Height',         hint: 'cm',    integer: false),
  ];

  @override
  void initState() {
    super.initState();
    for (final f in _fields) {
      final v = widget.data[f.key];
      final text = v == null ? '' : (f.integer ? '${(v as num).round()}' : (v as num).toStringAsFixed(1));
      _ctrls[f.key] = TextEditingController(text: text);
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) { c.dispose(); }
    super.dispose();
  }

  void _save() {
    final result = <String, dynamic>{};
    for (final f in _fields) {
      final text = _ctrls[f.key]!.text.trim();
      if (text.isEmpty) continue;
      if (f.integer) {
        final v = int.tryParse(text);
        if (v != null) result[f.key] = v;
      } else {
        final v = double.tryParse(text.replaceAll(',', '.'));
        if (v != null) result[f.key] = v;
      }
    }
    if (result.isEmpty) return;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final detected = _fields.where((f) => widget.data[f.key] != null).length;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: NudgeTokens.border,
                    borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 20),
          const Text('Review & Edit',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            detected > 0
                ? '$detected metric${detected == 1 ? '' : 's'} detected — fix any errors before saving'
                : 'No metrics detected — enter values manually',
            style: TextStyle(
                color: detected > 0 ? NudgeTokens.gymB : NudgeTokens.amber,
                fontSize: 11),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 0,
                children: _fields.map((f) {
                  final wasDetected = widget.data[f.key] != null;
                  return SizedBox(
                    width: (MediaQuery.of(context).size.width - 52) / 2,
                    child: TextFormField(
                      controller: _ctrls[f.key],
                      keyboardType: f.integer
                          ? TextInputType.number
                          : const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                          color: wasDetected ? Colors.white : NudgeTokens.textMid,
                          fontSize: 14),
                      decoration: InputDecoration(
                        labelText: '${f.label}${f.hint.isNotEmpty ? " (${f.hint})" : ""}',
                        labelStyle: TextStyle(
                            color: wasDetected ? NudgeTokens.gymB : NudgeTokens.textLow,
                            fontSize: 12),
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: wasDetected
                                    ? NudgeTokens.gymB.withValues(alpha: 0.4)
                                    : NudgeTokens.border)),
                        focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: NudgeTokens.gymB)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: NudgeTokens.textLow,
                      side: const BorderSide(color: NudgeTokens.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13)),
                  child: const Text('Discard'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: NudgeTokens.gymB,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13)),
                  child: const Text('Save',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Option tile ──────────────────────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _OptionTile({
    required this.icon, required this.color,
    required this.title, required this.subtitle, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.18))),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: NudgeTokens.textLow, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.5), size: 18),
          ],
        ),
      ),
    );
  }
}
