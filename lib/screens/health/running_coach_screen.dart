import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../utils/health_service.dart';
import '../../services/running_coach_service.dart';
import '../../app.dart' show NudgeTokens;
import '../../utils/nudge_theme_extension.dart';
import '../../storage.dart';

const _pink = Color(0xFFFF2D95);
const _pinkDeep = Color(0xFF2D0015);

class RunningCoachScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const RunningCoachScreen({super.key, required this.session});

  @override
  State<RunningCoachScreen> createState() => _RunningCoachScreenState();
}

class _RunningCoachScreenState extends State<RunningCoachScreen> {
  String? _analysis;
  String? _error;
  bool _analyzing = false;
  Map<String, dynamic> _runMetrics = {};
  bool _metricsLoading = true;
  double? _manualDistanceKm;
  double? _manualCalories;
  bool _reportExpanded = false;
  String? _runTag;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final cached =
        RunningCoachService.getSavedAnalysis(widget.session['startTime'] ?? '');
    final manualDist =
        RunningCoachService.getManualDistance(widget.session['startTime'] ?? '');
    final manualCal =
        RunningCoachService.getManualCalories(widget.session['startTime'] ?? '');
    final tag = RunningCoachService.getRunTag(widget.session['startTime'] ?? '');

    final dist =
        (widget.session['distanceKm'] as num?)?.toDouble() ?? 0.0;
    final dur =
        (widget.session['durationMin'] as num?)?.toDouble() ?? 0.0;
    Map<String, dynamic> metrics = {};
    try {
      final start = DateTime.parse(widget.session['startTime'] as String);
      final end = DateTime.parse(widget.session['endTime'] as String);
      print('[HEALTH_DEBUG] Requesting HR, STEPS, ROUTE from $start to $end');
      final data = await HealthService.health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.HEART_RATE, HealthDataType.STEPS, HealthDataType.WORKOUT_ROUTE],
      );
      
      final typeCounts = <HealthDataType, int>{};
      for (final p in data) {
        typeCounts[p.type] = (typeCounts[p.type] ?? 0) + 1;
      }
      print('[HEALTH_DEBUG] Batch fetch returned ${data.length} points: $typeCounts');

      // If batch fetch missing route, try targeted fetch
      if ((typeCounts[HealthDataType.WORKOUT_ROUTE] ?? 0) == 0) {
        print('[HEALTH_DEBUG] No route in batch, trying targeted WORKOUT_ROUTE fetch...');
        try {
          final routeData = await HealthService.health.getHealthDataFromTypes(
            startTime: start,
            endTime: end,
            types: [HealthDataType.WORKOUT_ROUTE],
          );
          print('[HEALTH_DEBUG] Targeted route fetch returned ${routeData.length} points');
          data.addAll(routeData);
        } catch (e) {
          print('[HEALTH_DEBUG] Targeted route fetch error: $e');
        }
      }
      metrics = await HealthService.fetchRunMetrics(
        start: start,
        end: end,
        distanceKm: dist,
        durationMin: dur,
        sessionSteps: widget.session['sessionSteps'] as int?,
        healthData: data, // Pass the fetched health data
      );
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _analysis = cached;
      _runMetrics = metrics;
      _metricsLoading = false;
      _manualDistanceKm = manualDist;
      _manualCalories = manualCal;
      _runTag = tag;
    });

    if (cached == null) _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    if (_analyzing) return;
    setState(() {
      _analyzing = true;
      _error = null;
    });
    final res = await RunningCoachService.analyzeRun(
      session: widget.session,
      runMetrics: _runMetrics.isEmpty ? null : _runMetrics,
    );
    if (!mounted) return;
    setState(() {
      if (res != null) {
        _analysis = res;
        _error = null;
      } else {
        _error = 'Analysis failed. Check your Gemini API key in Settings.';
      }
      _analyzing = false;
    });
  }

  /// Returns steps adjusted proportionally when the user corrects the distance.
  int? get _adjustedSteps {
    final origSteps = _runMetrics['totalSteps'] as int?;
    final origDist =
        (widget.session['distanceKm'] as num?)?.toDouble() ?? 0.0;
    if (origSteps == null || origDist == 0 || _manualDistanceKm == null) {
      return origSteps;
    }
    return (origSteps * (_manualDistanceKm! / origDist)).round();
  }

  Future<void> _showTagPicker() async {
    final startTime = widget.session['startTime'] as String? ?? '';
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
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: NudgeTokens.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('ACTIVITY TYPE',
                style: GoogleFonts.outfit(
                    fontSize: 10, fontWeight: FontWeight.w900,
                    letterSpacing: 1.5, color: NudgeTokens.textLow)),
            const SizedBox(height: 4),
            Text('Tag this run for category-specific AI analysis',
                style: GoogleFonts.outfit(fontSize: 13, color: NudgeTokens.textMid)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                GestureDetector(
                  onTap: () async {
                    await RunningCoachService.clearRunTag(startTime);
                    if (!mounted) return;
                    setState(() => _runTag = null);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _runTag == null
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _runTag == null ? Colors.white38 : Colors.white12),
                    ),
                    child: Text('✕  No tag',
                        style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: _runTag == null ? Colors.white : NudgeTokens.textLow,
                            fontWeight: _runTag == null ? FontWeight.w700 : FontWeight.w500)),
                  ),
                ),
                ...RunningCoachService.activityTags.map((t) {
                  final isSelected = _runTag == t.label;
                  return GestureDetector(
                    onTap: () async {
                      await RunningCoachService.setRunTag(startTime, t.label);
                      if (!mounted) return;
                      setState(() => _runTag = t.label);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500)),
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

  Future<void> _showDistanceEditDialog(
      BuildContext context, double sessionDist) async {
    // Default to GPS-computed running distance if available, not the raw HC total
    final gpsDist = _runMetrics['runningDistanceKm'] as double?;
    final defaultDist = _manualDistanceKm ?? gpsDist ?? sessionDist;
    final controller =
        TextEditingController(text: defaultDist.toStringAsFixed(2));
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NudgeTokens.elevated,
        title: Text('Set Running Distance',
            style: GoogleFonts.outfit(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session total: ${sessionDist.toStringAsFixed(2)} km\n'
              'Enter your actual running distance:',
              style: GoogleFonts.outfit(
                  fontSize: 12, color: NudgeTokens.textMid),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                suffixText: 'km',
                suffixStyle:
                    GoogleFonts.outfit(color: NudgeTokens.textLow),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: NudgeTokens.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _pink),
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (_manualDistanceKm != null)
            TextButton(
              onPressed: () async {
                final st = widget.session['startTime'] as String? ?? '';
                await RunningCoachService.clearManualDistance(st);
                if (!mounted) return;
                setState(() => _manualDistanceKm = null);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text('Reset',
                  style: GoogleFonts.outfit(color: NudgeTokens.textLow)),
            ),
          TextButton(
            onPressed: () async {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                final st = widget.session['startTime'] as String? ?? '';
                await RunningCoachService.setManualDistance(st, val);
                if (!mounted) return;
                setState(() => _manualDistanceKm = val);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Save',
                style: GoogleFonts.outfit(
                    color: _pink, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _showCaloriesEditDialog(
      BuildContext context, int sessionCal) async {
    final controller = TextEditingController(
        text: (_manualCalories?.toInt() ?? sessionCal).toString());
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NudgeTokens.elevated,
        title: Text('Set Calories Burned',
            style: GoogleFonts.outfit(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HC recorded: $sessionCal kcal\n'
              'Enter the actual calories burned:',
              style:
                  GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.textMid),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                suffixText: 'kcal',
                suffixStyle: GoogleFonts.outfit(color: NudgeTokens.textLow),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: NudgeTokens.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _pink),
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (_manualCalories != null)
            TextButton(
              onPressed: () async {
                final st = widget.session['startTime'] as String? ?? '';
                await RunningCoachService.clearManualCalories(st);
                if (!mounted) return;
                setState(() => _manualCalories = null);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text('Reset',
                  style: GoogleFonts.outfit(color: NudgeTokens.textLow)),
            ),
          TextButton(
            onPressed: () async {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                final st = widget.session['startTime'] as String? ?? '';
                await RunningCoachService.setManualCalories(st, val);
                if (!mounted) return;
                setState(() => _manualCalories = val);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Save',
                style: GoogleFonts.outfit(
                    color: _pink, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _showDiagnosticsDialog() async {
    final session = widget.session;
    final st = session['startTime'] as String? ?? '';
    final et = session['endTime'] as String? ?? '';
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NudgeTokens.elevated,
        title: Text('Run Diagnostics', style: GoogleFonts.outfit(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DiagRow('Type', session['type']),
              _DiagRow('Source', session['sourceName']),
              _DiagRow('Sess Dist', '${session['distanceKm']} km'),
              _DiagRow('GPS Dist', '${_runMetrics['runningDistanceKm']} km'),
              _DiagRow('Cal', '${session['calories']}'),
              _DiagRow('Steps', '${_runMetrics['totalSteps'] ?? session['sessionSteps']}'),
              const Divider(color: NudgeTokens.border),
              const SizedBox(height: 8),
              Text('RAW JSON (Metadata)', style: GoogleFonts.outfit(fontSize: 10, color: _pink, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(4)),
                child: Text(session.toString(), style: GoogleFonts.firaCode(fontSize: 9, color: Colors.white70)),
              ),
              const SizedBox(height: 12),
              Text('RAW JSON (Metrics)', style: GoogleFonts.outfit(fontSize: 10, color: _pink, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(4)),
                child: Text(_runMetrics.toString(), style: GoogleFonts.firaCode(fontSize: 9, color: Colors.white70)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Emergency cache clear
              final box = await AppStorage.getGymBox();
              await box.delete('hc_sessions');
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData(); // Reload from scratch
            },
            child: Text('Wipe Cache', style: GoogleFonts.outfit(color: NudgeTokens.red)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showDeepDumpDialog();
            },
            child: Text('Deep Dump (2 Days)', style: GoogleFonts.outfit(color: _pink)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: GoogleFonts.outfit(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Opens a bottom sheet listing all cached recent runs.
  /// User can tap one to replace the current session view.
  Future<void> _showRunPicker() async {
    final allRuns = RunningCoachService.getRecentRuns(days: 90);
    if (allRuns.isEmpty) return;
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: NudgeTokens.elevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 14),
                decoration: BoxDecoration(
                  color: NudgeTokens.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'SELECT RUN',
                style: GoogleFonts.outfit(
                  fontSize: 10, fontWeight: FontWeight.w900,
                  color: NudgeTokens.textLow, letterSpacing: 1.5,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                itemCount: allRuns.length,
                itemBuilder: (ctx2, i) {
                  final r = allRuns[i];
                  final isCurrent = r['startTime'] == widget.session['startTime'];
                  final d = (r['distanceKm'] as num?)?.toDouble() ?? 0.0;
                  final m = (r['durationMin'] as num?)?.toDouble() ?? 0.0;
                  final p = m > 0 && d > 0 ? m / d : 0.0;
                  final pStr = p > 0
                      ? '${p.floor()}:${((p % 1) * 60).round().toString().padLeft(2, '0')}'
                      : '--';
                  final rZone = RunningCoachService.getPaceZone(p);
                  String dateStr = '';
                  try {
                    final dt = DateTime.parse(r['startTime'] as String);
                    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                    dateStr = '${months[dt.month - 1]} ${dt.day}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
                  } catch (_) {}
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: isCurrent ? null : () => Navigator.pop(ctx, r),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: isCurrent
                              ? _pink.withValues(alpha: 0.08)
                              : NudgeTokens.card,
                          border: Border.all(
                            color: isCurrent
                                ? _pink.withValues(alpha: 0.4)
                                : NudgeTokens.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 3, height: 40,
                              decoration: BoxDecoration(
                                color: rZone.color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dateStr,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12, fontWeight: FontWeight.w700,
                                      color: isCurrent ? _pink : Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${d.toStringAsFixed(2)} km  ·  $pStr /km',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11, color: NudgeTokens.textLow,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isCurrent)
                              Text(
                                'CURRENT',
                                style: GoogleFonts.outfit(
                                  fontSize: 9, fontWeight: FontWeight.w900,
                                  color: _pink, letterSpacing: 1.2,
                                ),
                              )
                            else
                              const Icon(Icons.chevron_right_rounded,
                                  color: NudgeTokens.textLow, size: 18),
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
      ),
    );
    if (picked == null || !mounted) return;
    // Push a fresh RunningCoachScreen for the selected run
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => RunningCoachScreen(session: picked)),
    );
  }

  Future<void> _showDeepDumpDialog() async {
    final queryController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: NudgeTokens.elevated,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Deep Dump (Last 48h)',
                    style: GoogleFonts.outfit(color: Colors.white)),
                const SizedBox(height: 8),
                TextField(
                  controller: queryController,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                  onChanged: (_) => setModalState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search JSON...',
                    hintStyle: GoogleFonts.outfit(color: Colors.white24),
                    prefixIcon: const Icon(Icons.search,
                        color: Colors.white24, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
            content: FutureBuilder<List<String>>(
              future: HealthService.fetchDeepDump(
                start: DateTime.now().subtract(const Duration(days: 2)),
                end: DateTime.now(),
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator(color: _pink)),
                  );
                }
                final allBlocks = snapshot.data ?? ['Error fetching data'];
                final query = queryController.text.toLowerCase();
                final filtered = query.isEmpty
                    ? allBlocks
                    : allBlocks.where((b) => b.toLowerCase().contains(query)).toList();

                if (filtered.isEmpty) {
                  return SizedBox(
                    height: 100,
                    child: Center(
                      child: Text('No matches found for "$query"',
                          style: GoogleFonts.outfit(color: Colors.white24)),
                    ),
                  );
                }

                return SizedBox(
                  width: double.maxFinite,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, i) =>
                        const Divider(color: Colors.white10, height: 20),
                    itemBuilder: (ctx, i) => SelectableText(
                      filtered[i],
                      style: GoogleFonts.firaCode(
                          fontSize: 9, color: Colors.white70),
                    ),
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Close',
                    style: GoogleFonts.outfit(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<NudgeThemeExtension>()!;
    final session = widget.session;
    final sessionDist = (session['distanceKm'] as num?)?.toDouble() ?? 0.0;
    // Use manual override if set, otherwise GPS-computed, otherwise session total
    final gpsDist = _runMetrics['runningDistanceKm'] as double?;
    final dist = _manualDistanceKm ?? gpsDist ?? sessionDist;
    final dur = (session['durationMin'] as num?)?.toDouble() ?? 0.0;
    final sessionCal = (session['calories'] as num?)?.toInt() ?? 0;
    final effectiveCalories = _manualCalories?.toInt() ?? sessionCal;
    final pace = dur > 0 && dist > 0 ? dur / dist : 0.0;
    final zone = RunningCoachService.getPaceZone(pace);

    return Scaffold(
      backgroundColor: theme.scaffoldBg ?? NudgeTokens.bg,
      body: CustomScrollView(
        slivers: [
          _HeroAppBar(
            session: session,
            dist: dist,
            sessionDist: sessionDist,
            dur: dur,
            pace: pace,
            calories: effectiveCalories,
            zone: zone,
            runMetrics: _runMetrics,
            hasManualOverride: _manualDistanceKm != null,
            hasManualCalories: _manualCalories != null,
            runTag: _runTag,
            onEditDistance: () => _showDistanceEditDialog(context, sessionDist),
            onEditCalories: () => _showCaloriesEditDialog(context, sessionCal),
            onDiagnostics: _showDiagnosticsDialog,
            onSwitchRun: _showRunPicker,
            onTagTap: _showTagPicker,
          ),

          // Data quality warning — pace > 9 min/km suggests session includes walking
          if (pace > 9.0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: NudgeTokens.amber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NudgeTokens.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: NudgeTokens.amber, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pace suggests this session may include walking. '
                          'Distance & duration come directly from ${session['sourceName'] ?? 'Health Connect'} — '
                          'split sessions in your fitness app for pure running data.',
                          style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: NudgeTokens.amber,
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // GPS route map
          if (!_metricsLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _runMetrics['gpsRoute'] != null
                    ? _RouteMapCard(
                        gpsRoute: (_runMetrics['gpsRoute'] as List)
                            .cast<Map<String, dynamic>>(),
                      )
                    : _NoRouteCard(source: widget.session['sourceName'] as String? ?? 'Health Connect'),
              ),
            ),

          // Per-km splits (GPS sessions only)
          if (!_metricsLoading && _runMetrics['gpsRoute'] != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _KmSplitsCard(
                  gpsRoute: (_runMetrics['gpsRoute'] as List).cast<Map<String, dynamic>>(),
                ),
              ),
            ),

          // Advanced metrics strip
          if (!_metricsLoading && _runMetrics.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _AdvancedMetricsStrip(
                  metrics: _runMetrics,
                  zone: zone,
                  adjustedSteps: _adjustedSteps,
                ),
              ),
            ),

          // HR + pace charts
          if (!_metricsLoading &&
              (_runMetrics['hrTimeline'] != null ||
                  _runMetrics['speedTimeline'] != null))
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _RunChartsCard(
                  sessionStart: DateTime.tryParse(
                          session['startTime'] as String? ?? '') ??
                      DateTime.now(),
                  durationMin: dur,
                  hrTimeline: (_runMetrics['hrTimeline'] as List?)
                      ?.cast<Map<String, dynamic>>(),
                  speedTimeline: (_runMetrics['speedTimeline'] as List?)
                      ?.cast<Map<String, dynamic>>(),
                ),
              ),
            ),

          // Pace zone card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _PaceZoneCard(zone: zone),
            ),
          ),

          // Coach report
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              child: _CoachReportCard(
                analysis: _analysis,
                error: _error,
                analyzing: _analyzing,
                onAnalyze: _runAnalysis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Hero App Bar
// ─────────────────────────────────────────────────────────────
class _HeroAppBar extends StatelessWidget {
  final Map<String, dynamic> session;
  final double dist, sessionDist, dur, pace;
  final int calories;
  final PaceZone zone;

  final Map<String, dynamic> runMetrics;
  final bool hasManualOverride;
  final bool hasManualCalories;
  final String? runTag;
  final VoidCallback onEditDistance;
  final VoidCallback onEditCalories;
  final VoidCallback onDiagnostics;
  final VoidCallback onSwitchRun;
  final VoidCallback onTagTap;

  const _HeroAppBar({
    required this.session,
    required this.dist,
    required this.sessionDist,
    required this.dur,
    required this.pace,
    required this.calories,
    required this.zone,
    required this.onEditDistance,
    required this.onEditCalories,
    required this.onDiagnostics,
    required this.onSwitchRun,
    required this.onTagTap,
    this.runMetrics = const {},
    this.hasManualOverride = false,
    this.hasManualCalories = false,
    this.runTag,
  });

  @override
  Widget build(BuildContext context) {
    String dateStr = '';
    String timeStr = '';
    try {
      final dt = DateTime.parse(session['startTime'] as String);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      dateStr = '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
      timeStr =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    // dist is already the effective distance (manual > GPS > session)
    final hasMixed = runMetrics['hasMixedActivity'] == true ||
        (dist < sessionDist * 0.95);

    // Use running-only pace if available
    final displayPace = (runMetrics['avgRunningPaceMinKm'] as double?) ?? pace;
    final paceStr = displayPace > 0
        ? "${displayPace.floor()}:${((displayPace % 1) * 60).round().toString().padLeft(2, '0')}"
        : '--:--';
    final durMins = dur.floor();
    final durSecs = ((dur % 1) * 60).round();
    final durStr = dur >= 60
        ? '${(dur / 60).floor()}h ${dur.floor() % 60}m'
        : '${durMins}m ${durSecs.toString().padLeft(2, '0')}s';

    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: NudgeTokens.bg,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.swap_vert_rounded, color: Colors.white70, size: 22),
          tooltip: 'Switch run',
          onPressed: onSwitchRun,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_pinkDeep, Color(0xFF1A0010), NudgeTokens.bg],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 26),
                  // Label row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _pink.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: _pink.withValues(alpha: 0.4), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.directions_run_rounded,
                                color: _pink, size: 12),
                            const SizedBox(width: 5),
                            Text(
                              'ACTIVITY COACH',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: _pink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Activity tag chip
                      GestureDetector(
                        onTap: onTagTap,
                        child: () {
                          if (runTag != null) {
                            final t = RunningCoachService.activityTags
                                .where((x) => x.label == runTag)
                                .firstOrNull;
                            final tagColor = t?.color ?? Colors.white38;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: tagColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: tagColor.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                '${t?.emoji ?? ''} $runTag',
                                style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: tagColor),
                              ),
                            );
                          }
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.white12,
                                  style: BorderStyle.solid),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('＋ tag',
                                style: GoogleFonts.outfit(
                                    fontSize: 10, color: Colors.white24)),
                          );
                        }(),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(dateStr,
                              style: GoogleFonts.outfit(
                                  fontSize: 11, color: Colors.white38)),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(timeStr,
                                  style: GoogleFonts.outfit(
                                      fontSize: 10, color: Colors.white24)),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: onDiagnostics,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white10),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.bug_report_rounded, color: Colors.white38, size: 14),
                                      const SizedBox(width: 4),
                                      Text('DIAGS', style: GoogleFonts.outfit(fontSize: 8, color: Colors.white24, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Main stats
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Big distance
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dist.toStringAsFixed(2),
                            style: GoogleFonts.outfit(
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.0,
                              letterSpacing: -2,
                            ),
                          ),
                          Row(
                            children: [
                              Text('kilometres',
                                  style: GoogleFonts.outfit(
                                      fontSize: 12, color: Colors.white38)),
                              if (hasMixed) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: NudgeTokens.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'RUN ONLY · ${sessionDist.toStringAsFixed(2)} total',
                                    style: GoogleFonts.outfit(
                                        fontSize: 9,
                                        color: NudgeTokens.amber,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: onEditDistance,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.edit_rounded,
                                          size: 9, color: Colors.white38),
                                      const SizedBox(width: 3),
                                      Text(
                                        hasManualOverride ? 'MANUAL' : 'EDIT',
                                        style: GoogleFonts.outfit(
                                            fontSize: 9,
                                            color: hasManualOverride
                                                ? _pink
                                                : Colors.white38,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Side stats
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _HeroStat(label: 'PACE', value: '$paceStr /km'),
                          const SizedBox(height: 10),
                          _HeroStat(label: 'TIME', value: durStr),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: onEditCalories,
                            child: _HeroStat(
                              label: 'CALS',
                              value: calories > 0 ? '$calories kcal' : 'tap to set',
                              valueColor: hasManualCalories ? _pink : null,
                              editBadge: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _HeroStat(
                            label: 'ZONE',
                            value: zone.name.split('·')[0].trim(),
                            valueColor: zone.color,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool editBadge;
  const _HeroStat(
      {required this.label,
      required this.value,
      this.valueColor,
      this.editBadge = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (editBadge)
              const Padding(
                padding: EdgeInsets.only(right: 3),
                child: Icon(Icons.edit_rounded, size: 8, color: Colors.white24),
              ),
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 9,
                    color: Colors.white30,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800)),
          ],
        ),
        Text(value,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: valueColor ?? Colors.white,
            )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Advanced Metrics Strip
// ─────────────────────────────────────────────────────────────
class _AdvancedMetricsStrip extends StatelessWidget {
  final Map<String, dynamic> metrics;
  final PaceZone zone;
  final int? adjustedSteps;
  const _AdvancedMetricsStrip({required this.metrics, required this.zone, this.adjustedSteps});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<NudgeThemeExtension>()!;

    final items = <({String label, String value, String unit, Color color})>[];

    if (metrics['runningDistanceKm'] != null &&
        metrics['hasMixedActivity'] == true) {
      final runKm = (metrics['runningDistanceKm'] as double);
      final walkKm = (metrics['walkingDistanceKm'] as double?) ?? 0.0;
      items.add((
        label: 'RUN DIST',
        value: runKm.toStringAsFixed(2),
        unit: 'km',
        color: _pink,
      ));
      if (walkKm > 0) {
        items.add((
          label: 'WALK DIST',
          value: walkKm.toStringAsFixed(2),
          unit: 'km',
          color: NudgeTokens.amber,
        ));
      }
    }
    if (metrics['avgHrBpm'] != null) {
      final avg = (metrics['avgHrBpm'] as double).round();
      items.add((
        label: 'AVG HR',
        value: '$avg',
        unit: 'bpm',
        color: NudgeTokens.red,
      ));
    }
    if (metrics['peakHrBpm'] != null) {
      final peak = (metrics['peakHrBpm'] as double).round();
      items.add((
        label: 'PEAK HR',
        value: '$peak',
        unit: 'bpm',
        color: NudgeTokens.red,
      ));
    }
    if (metrics['estimatedCadenceSpm'] != null) {
      final spm = metrics['estimatedCadenceSpm'] as int;
      final cadenceColor = spm >= 160 && spm <= 180
          ? NudgeTokens.green
          : spm < 160
              ? NudgeTokens.amber
              : NudgeTokens.red;
      items.add((
        label: 'CADENCE',
        value: '$spm',
        unit: 'spm',
        color: cadenceColor,
      ));
    }
    if (metrics['strideLengthM'] != null) {
      final stride = (metrics['strideLengthM'] as double);
      items.add((
        label: 'STRIDE',
        value: stride.toStringAsFixed(2),
        unit: 'm',
        color: NudgeTokens.blue,
      ));
    }
    if (metrics['totalSteps'] != null) {
      final steps = adjustedSteps ?? metrics['totalSteps'] as int;
      items.add((
        label: 'STEPS',
        value: steps > 999 ? '${(steps / 1000).toStringAsFixed(1)}k' : '$steps',
        unit: '',
        color: NudgeTokens.purple,
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: theme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ADVANCED METRICS',
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: NudgeTokens.textLow,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: items
                .map((item) => Expanded(
                      child: _MetricChip(
                        label: item.label,
                        value: item.value,
                        unit: item.unit,
                        color: item.color,
                      ),
                    ))
                .toList(),
          ),
          // Cadence advice if available
          if (metrics['estimatedCadenceSpm'] != null) ...[
            const SizedBox(height: 10),
            Builder(builder: (context) {
              final spm = metrics['estimatedCadenceSpm'] as int;
              final String advice;
              final Color advColor;
              if (spm < 150) {
                advice = 'Low cadence — try shortening stride, increasing step rate';
                advColor = NudgeTokens.amber;
              } else if (spm < 160) {
                advice = 'Below optimal — aim for 160+ SPM with quick, light steps';
                advColor = NudgeTokens.amber;
              } else if (spm <= 180) {
                advice = 'Optimal cadence range — efficient biomechanics';
                advColor = NudgeTokens.green;
              } else {
                advice = 'High cadence — check stride power, may be under-striding';
                advColor = NudgeTokens.blue;
              }
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: advColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: advColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 13, color: advColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        advice,
                        style: GoogleFonts.outfit(
                            fontSize: 11, color: advColor),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  const _MetricChip(
      {required this.label,
      required this.value,
      required this.unit,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: GoogleFonts.outfit(
                fontSize: 8,
                color: NudgeTokens.textLow,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        RichText(
          text: TextSpan(children: [
            TextSpan(
              text: value,
              style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1.1),
            ),
            if (unit.isNotEmpty)
              TextSpan(
                text: ' $unit',
                style: GoogleFonts.outfit(
                    fontSize: 10, color: color.withValues(alpha: 0.7)),
              ),
          ]),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Pace Zone Card
// ─────────────────────────────────────────────────────────────
class _PaceZoneCard extends StatelessWidget {
  final PaceZone zone;
  const _PaceZoneCard({required this.zone});

  void _showZoneLegendSheet(BuildContext context) {
    const zones = [
      (
        label: 'Z1 · Recovery',
        color: Color(0xFF5AC8FA),
        pace: '> 7:00 /km',
        icon: Icons.self_improvement_rounded,
        desc: 'Very easy effort. Active recovery, warm-up/cool-down. '
            'Builds aerobic base with minimal fatigue.',
      ),
      (
        label: 'Z2 · Aerobic',
        color: Color(0xFF39D98A),
        pace: '6:00 – 7:00 /km',
        icon: Icons.favorite_rounded,
        desc: 'Comfortable conversational pace. Develops fat-burning '
            'efficiency and cardiovascular endurance. The bulk of training.',
      ),
      (
        label: 'Z3 · Tempo',
        color: Color(0xFFFFBF00),
        pace: '5:00 – 6:00 /km',
        icon: Icons.speed_rounded,
        desc: 'Comfortably hard — you can speak in short sentences. '
            'Improves lactate threshold. Good for race-pace training.',
      ),
      (
        label: 'Z4 · Threshold',
        color: Color(0xFFFF9500),
        pace: '4:00 – 5:00 /km',
        icon: Icons.local_fire_department_rounded,
        desc: 'Hard effort near your anaerobic threshold. '
            'Significantly boosts speed endurance. Use sparingly.',
      ),
      (
        label: 'Z5 · Max Effort',
        color: Color(0xFFFF4D6A),
        pace: '< 4:00 /km',
        icon: Icons.bolt_rounded,
        desc: 'All-out sprint intensity. Builds VO₂ max and raw speed. '
            'Only sustainable for very short intervals.',
      ),
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: NudgeTokens.elevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
            Text(
              'PACE ZONES',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: NudgeTokens.textLow,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Understanding your training zones',
              style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
            const SizedBox(height: 20),
            ...zones.map((z) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: z.color.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: z.color.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: z.color.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(z.icon, color: z.color, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(z.label,
                                      style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: z.color)),
                                  const Spacer(),
                                  Text(z.pace,
                                      style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: z.color.withValues(
                                              alpha: 0.7),
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(z.desc,
                                  style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: NudgeTokens.textMid,
                                      height: 1.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<NudgeThemeExtension>()!;
    const zoneColors = [
      Color(0xFF5AC8FA), // Z1 recovery
      Color(0xFF39D98A), // Z2 aerobic
      Color(0xFFFFBF00), // Z3 tempo
      Color(0xFFFF9500), // Z4 threshold
      Color(0xFFFF4D6A), // Z5 max
    ];
    const zoneLabels = ['Z1', 'Z2', 'Z3', 'Z4', 'Z5'];
    const zonePaceRanges = ['>7:00', '6-7', '5-6', '4-5', '<4:00'];
    final activeIdx = (zone.zone - 1).clamp(0, 4);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: theme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('PACE ZONE',
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: NudgeTokens.textLow,
                  )),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: zone.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: zone.color.withValues(alpha: 0.3)),
                ),
                child: Text(zone.name,
                    style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: zone.color)),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showZoneLegendSheet(context),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.info_outline_rounded,
                      size: 14, color: Colors.white38),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Zone bar
          Row(
            children: List.generate(5, (i) {
              final isActive = i == activeIdx;
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      height: isActive ? 10 : 6,
                      margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                      decoration: BoxDecoration(
                        color: isActive
                            ? zoneColors[i]
                            : zoneColors[i].withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                    color: zoneColors[i].withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2))
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(zoneLabels[i],
                        style: GoogleFonts.outfit(
                          fontSize: 8,
                          color: isActive ? zoneColors[i] : NudgeTokens.textLow,
                          fontWeight: isActive
                              ? FontWeight.w900
                              : FontWeight.w500,
                        )),
                    Text(zonePaceRanges[i],
                        style: GoogleFonts.outfit(
                            fontSize: 7, color: NudgeTokens.textLow)),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          // Description
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: zone.color.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: zone.color.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt_rounded, color: zone.color, size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(zone.description,
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: zone.color,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// No Route Placeholder
// ─────────────────────────────────────────────────────────────
class _NoRouteCard extends StatelessWidget {
  final String source;
  const _NoRouteCard({required this.source});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.map_outlined,
                color: NudgeTokens.textLow, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Route map unavailable',
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: NudgeTokens.textMid)),
                const SizedBox(height: 2),
                Text(
                  '$source does not include GPS route data for this session. '
                  'Use a GPS-enabled app (e.g. Strava) to get route maps.',
                  style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: NudgeTokens.textLow,
                      height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Coach Report Card
// ─────────────────────────────────────────────────────────────
class _CoachReportCard extends StatelessWidget {
  final String? analysis;
  final String? error;
  final bool analyzing;
  final VoidCallback onAnalyze;

  const _CoachReportCard({
    this.analysis,
    this.error,
    required this.analyzing,
    required this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<NudgeThemeExtension>()!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: theme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: _pink, size: 16),
              const SizedBox(width: 8),
              Text("COACH'S REPORT",
                  style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: _pink)),
              const Spacer(),
              if (analysis != null && !analyzing)
                GestureDetector(
                  onTap: onAnalyze,
                  child: Text('Re-analyze',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: NudgeTokens.textLow,
                        decoration: TextDecoration.underline,
                        decorationColor: NudgeTokens.textLow,
                      )),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (analyzing)
            _loadingState()
          else if (error != null)
            _errorState(error!, onAnalyze)
          else if (analysis != null)
            _analysisView(context, analysis!)
          else
            _emptyState(onAnalyze),
        ],
      ),
    );
  }

  Widget _loadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                  color: _pink, strokeWidth: 2.5),
            ),
            const SizedBox(height: 16),
            Text('AI coach is analyzing your run...',
                style: GoogleFonts.outfit(
                    fontSize: 13, color: NudgeTokens.textMid)),
            const SizedBox(height: 4),
            Text('Reviewing performance data & training history',
                style: GoogleFonts.outfit(
                    fontSize: 11, color: NudgeTokens.textLow)),
          ],
        ),
      ),
    );
  }

  Widget _errorState(String err, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: NudgeTokens.red, size: 28),
            const SizedBox(height: 10),
            Text('Analysis Failed',
                style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 6),
            Text(err,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    fontSize: 12, color: NudgeTokens.textLow)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _pink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _analysisView(BuildContext context, String data) {
    return MarkdownBody(
      data: data,
      styleSheet: MarkdownStyleSheet(
        p: GoogleFonts.outfit(
            fontSize: 14, color: NudgeTokens.textMid, height: 1.6),
        h2: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 2.0),
        h3: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: _pink,
            height: 1.8),
        listBullet: GoogleFonts.outfit(
            fontSize: 14, color: NudgeTokens.textMid),
        strong: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white),
        em: GoogleFonts.outfit(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: NudgeTokens.textMid),
        blockquotePadding: const EdgeInsets.all(12),
        blockquoteDecoration: BoxDecoration(
          color: _pink.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: const Border(left: BorderSide(color: _pink, width: 3)),
        ),
        code: GoogleFonts.robotoMono(
            fontSize: 12, color: NudgeTokens.green),
        codeblockDecoration: BoxDecoration(
          color: NudgeTokens.elevated,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _emptyState(VoidCallback onAnalyze) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            const Icon(Icons.auto_awesome_rounded,
                color: Colors.white24, size: 32),
            const SizedBox(height: 12),
            Text('Ready to coach',
                style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70)),
            const SizedBox(height: 6),
            Text('Get AI-powered form, load & recovery analysis',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    fontSize: 12, color: NudgeTokens.textLow)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAnalyze,
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: const Text('Analyze Performance'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _pink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GPS Route Map Card
// ─────────────────────────────────────────────────────────────
class _RouteMapCard extends StatelessWidget {
  final List<Map<String, dynamic>> gpsRoute;
  const _RouteMapCard({required this.gpsRoute});

  Color _speedColor(double? mps) {
    if (mps == null || mps <= 0) return NudgeTokens.textLow;
    if (mps >= 4.17) return const Color(0xFFFF4D6A); // Z5
    if (mps >= 3.33) return const Color(0xFFFF9500); // Z4
    if (mps >= 2.78) return const Color(0xFFFFBF00); // Z3
    if (mps >= 2.38) return const Color(0xFF39D98A); // Z2
    return const Color(0xFF5AC8FA);                  // Z1 / walk
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<NudgeThemeExtension>()!;
    if (gpsRoute.isEmpty) return const SizedBox.shrink();

    final points = gpsRoute
        .map((p) => LatLng(p['lat'] as double, p['lng'] as double))
        .toList();

    final center = LatLng(
      gpsRoute.map((p) => p['lat'] as double).reduce((a, b) => a + b) / gpsRoute.length,
      gpsRoute.map((p) => p['lng'] as double).reduce((a, b) => a + b) / gpsRoute.length,
    );

    // Build colored polyline segments by zone
    final segments = <Polyline>[];
    for (int i = 0; i < gpsRoute.length - 1; i++) {
      final spd = gpsRoute[i]['speed'] as double?;
      segments.add(Polyline(
        points: [
          LatLng(gpsRoute[i]['lat'] as double, gpsRoute[i]['lng'] as double),
          LatLng(gpsRoute[i + 1]['lat'] as double, gpsRoute[i + 1]['lng'] as double),
        ],
        color: _speedColor(spd),
        strokeWidth: 4.0,
      ));
    }

    return Container(
      decoration: theme.cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Text('GPS ROUTE',
                    style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: NudgeTokens.textLow)),
                const Spacer(),
                Text('${gpsRoute.length} points',
                    style: GoogleFonts.outfit(
                        fontSize: 10, color: NudgeTokens.textLow)),
              ],
            ),
          ),
          SizedBox(
            height: 240,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 15,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.nudge.app',
                ),
                PolylineLayer(polylines: segments),
                // Start marker
                MarkerLayer(markers: [
                  Marker(
                    point: points.first,
                    width: 16, height: 16,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: NudgeTokens.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Marker(
                    point: points.last,
                    width: 16, height: 16,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: _pink,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          // Zone legend
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ZoneDot(color: Color(0xFF5AC8FA), label: 'Walk'),
                _ZoneDot(color: Color(0xFF39D98A), label: 'Z2'),
                _ZoneDot(color: Color(0xFFFFBF00), label: 'Z3'),
                _ZoneDot(color: Color(0xFFFF9500), label: 'Z4'),
                _ZoneDot(color: Color(0xFFFF4D6A), label: 'Z5'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneDot extends StatelessWidget {
  final Color color;
  final String label;
  const _ZoneDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.outfit(fontSize: 9, color: NudgeTokens.textLow)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HR + Pace Charts Card
// ─────────────────────────────────────────────────────────────
class _RunChartsCard extends StatelessWidget {
  final DateTime sessionStart;
  final double durationMin;
  final List<Map<String, dynamic>>? hrTimeline;
  final List<Map<String, dynamic>>? speedTimeline;

  const _RunChartsCard({
    required this.sessionStart,
    required this.durationMin,
    this.hrTimeline,
    this.speedTimeline,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<NudgeThemeExtension>()!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: theme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PERFORMANCE CHARTS',
              style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: NudgeTokens.textLow)),
          if (hrTimeline != null && hrTimeline!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const _ChartLabel(
                icon: Icons.favorite_rounded,
                color: NudgeTokens.red,
                label: 'Heart Rate'),
            const SizedBox(height: 8),
            _HrChart(timeline: hrTimeline!, durationMin: durationMin),
          ],
          if (speedTimeline != null && speedTimeline!.isNotEmpty) ...[
            const SizedBox(height: 20),
            const _ChartLabel(
                icon: Icons.speed_rounded,
                color: _pink,
                label: 'Pace  (min/km)'),
            const SizedBox(height: 8),
            _PaceChart(timeline: speedTimeline!, durationMin: durationMin),
          ],
        ],
      ),
    );
  }
}

class _ChartLabel extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _ChartLabel(
      {required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 6),
      Text(label,
          style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: NudgeTokens.textMid)),
    ]);
  }
}

class _HrChart extends StatelessWidget {
  final List<Map<String, dynamic>> timeline;
  final double durationMin;
  const _HrChart({required this.timeline, required this.durationMin});

  @override
  Widget build(BuildContext context) {
    final spots = timeline
        .map((p) => FlSpot(p['t'] as double, p['bpm'] as double))
        .toList();
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 10;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 10;

    return SizedBox(
      height: 100,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: durationMin,
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.white.withValues(alpha: 0.05),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 20,
                getTitlesWidget: (v, _) => Text('${v.toInt()}',
                    style: GoogleFonts.outfit(
                        fontSize: 8, color: NudgeTokens.textLow)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 16,
                interval: durationMin > 30 ? 10 : 5,
                getTitlesWidget: (v, _) => Text('${v.toInt()}m',
                    style: GoogleFonts.outfit(
                        fontSize: 8, color: NudgeTokens.textLow)),
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: NudgeTokens.red,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    NudgeTokens.red.withValues(alpha: 0.25),
                    NudgeTokens.red.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaceChart extends StatelessWidget {
  final List<Map<String, dynamic>> timeline;
  final double durationMin;
  const _PaceChart({required this.timeline, required this.durationMin});

  @override
  Widget build(BuildContext context) {
    // Cap pace at 15 min/km to avoid outliers distorting the chart
    final spots = timeline
        .where((p) => (p['pace'] as double) < 15.0 && (p['pace'] as double) > 0)
        .map((p) => FlSpot(p['t'] as double, p['pace'] as double))
        .toList();
    if (spots.isEmpty) return const SizedBox.shrink();

    final minY = (spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 0.5)
        .clamp(0.0, 99.0);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 0.5;


    return SizedBox(
      height: 100,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: durationMin,
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.white.withValues(alpha: 0.05),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 1,
                getTitlesWidget: (v, _) => Text('${v.floor()}:${((v % 1) * 60).round().toString().padLeft(2, '0')}',
                    style: GoogleFonts.outfit(
                        fontSize: 8, color: NudgeTokens.textLow)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 16,
                interval: durationMin > 30 ? 10 : 5,
                getTitlesWidget: (v, _) => Text('${v.toInt()}m',
                    style: GoogleFonts.outfit(
                        fontSize: 8, color: NudgeTokens.textLow)),
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: _pink,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _pink.withValues(alpha: 0.2),
                    _pink.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}class _DiagRow extends StatelessWidget {
  final String label, value;
  const _DiagRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: GoogleFonts.outfit(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold)),
          Text(value, style: GoogleFonts.outfit(fontSize: 10, color: Colors.white70)),
        ],
      ),
    );
  }
}

// ─── Per-km Splits Card ───────────────────────────────────────────────────────

class _KmSplitsCard extends StatelessWidget {
  final List<Map<String, dynamic>> gpsRoute;
  const _KmSplitsCard({required this.gpsRoute});

  static double _haversineM(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * 3.141592653589793 / 180;
    final dLng = (lng2 - lng1) * 3.141592653589793 / 180;
    final sinLat = dLat / 2;
    final sinLng = dLng / 2;
    final aa = sinLat * sinLat +
        (lat1 * 3.141592653589793 / 180) *
            (lat2 * 3.141592653589793 / 180).abs() *
            sinLng * sinLng;
    return r * 2 * (aa < 1 ? aa : 1);
  }

  List<_KmSplit> _computeSplits() {
    if (gpsRoute.length < 2) return [];
    final splits = <_KmSplit>[];
    double cumDist = 0;
    int kmIndex = 1;
    int? tStart = gpsRoute.first['t'] as int?;
    double elevGain = 0;
    double? prevAlt = (gpsRoute.first['alt'] as num?)?.toDouble();
    int? tKmStart = tStart;

    for (int i = 1; i < gpsRoute.length; i++) {
      final prev = gpsRoute[i - 1];
      final curr = gpsRoute[i];
      final segDist = _haversineM(
        (prev['lat'] as num).toDouble(), (prev['lng'] as num).toDouble(),
        (curr['lat'] as num).toDouble(), (curr['lng'] as num).toDouble(),
      );
      cumDist += segDist;

      final currAlt = (curr['alt'] as num?)?.toDouble();
      if (prevAlt != null && currAlt != null && currAlt > prevAlt) {
        elevGain += currAlt - prevAlt;
      }
      prevAlt = currAlt;

      while (cumDist >= kmIndex * 1000) {
        final tEnd = curr['t'] as int?;
        if (tKmStart != null && tEnd != null) {
          final splitSec = (tEnd - tKmStart) / 1000;
          final paceMin = splitSec / 60;
          splits.add(_KmSplit(
            km: kmIndex,
            paceMin: paceMin,
            elevGainM: elevGain,
          ));
        }
        elevGain = 0;
        tKmStart = curr['t'] as int?;
        kmIndex++;
      }
    }
    return splits;
  }

  String _fmtPace(double paceMin) {
    final m = paceMin.floor();
    final s = ((paceMin % 1) * 60).round();
    return "$m'${s.toString().padLeft(2, '0')}\"";
  }

  @override
  Widget build(BuildContext context) {
    final splits = _computeSplits();
    if (splits.isEmpty) return const SizedBox.shrink();

    // Best and worst pace for color scaling
    final paces = splits.map((s) => s.paceMin).toList();
    final best = paces.reduce((a, b) => a < b ? a : b);
    final worst = paces.reduce((a, b) => a > b ? a : b);
    final range = (worst - best).clamp(0.01, double.infinity);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_list_numbered_rounded, color: _pink, size: 14),
              const SizedBox(width: 6),
              Text('KM SPLITS',
                  style: GoogleFonts.outfit(
                      fontSize: 10, fontWeight: FontWeight.w900,
                      color: NudgeTokens.textLow, letterSpacing: 1.3)),
              const Spacer(),
              Text('${splits.length} km',
                  style: GoogleFonts.outfit(fontSize: 11, color: NudgeTokens.textLow)),
            ],
          ),
          const SizedBox(height: 10),
          // Header row
          Row(
            children: [
              SizedBox(width: 32, child: Text('KM', style: TextStyle(color: NudgeTokens.textLow, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8))),
              Expanded(child: Text('PACE', style: TextStyle(color: NudgeTokens.textLow, fontSize: 9, fontWeight: FontWeight.w700))),
              SizedBox(width: 60, child: Text('ELEV +', style: TextStyle(color: NudgeTokens.textLow, fontSize: 9, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
              SizedBox(width: 60, child: Text('BAR', style: TextStyle(color: NudgeTokens.textLow, fontSize: 9, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
            ],
          ),
          const SizedBox(height: 4),
          ...splits.map((split) {
            // Faster pace = greener; slower = redder
            final t = ((split.paceMin - best) / range).clamp(0.0, 1.0);
            final color = Color.lerp(NudgeTokens.green, NudgeTokens.red, t)!;
            final barW = (1 - t) * 56 + 4; // 4–60px
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text('${split.km}',
                        style: GoogleFonts.outfit(color: NudgeTokens.textMid, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: Text(_fmtPace(split.paceMin),
                        style: GoogleFonts.outfit(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      split.elevGainM > 0.5 ? '+${split.elevGainM.toStringAsFixed(0)}m' : '--',
                      style: GoogleFonts.outfit(color: NudgeTokens.textLow, fontSize: 11),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Container(
                      width: barW,
                      height: 8,
                      color: color,
                    ),
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

class _KmSplit {
  final int km;
  final double paceMin;
  final double elevGainM;
  const _KmSplit({required this.km, required this.paceMin, required this.elevGainM});
}
