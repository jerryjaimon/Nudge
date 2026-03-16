import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:health/health.dart';
import 'package:uuid/uuid.dart';

import '../../app.dart' show NudgeTokens;
import '../../services/gps_tracking_service.dart';
import '../../storage.dart';
import '../../utils/health_service.dart';

// ── Activity type definitions ────────────────────────────────────────────────

class ActivityType {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final double kcalPerKm;

  const ActivityType({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.kcalPerKm,
  });
}

const List<ActivityType> kActivityTypes = [
  ActivityType(id: 'run',   label: 'Run',       icon: Icons.directions_run_rounded,  color: Color(0xFFFF4D6A), kcalPerKm: 62),
  ActivityType(id: 'walk',  label: 'Walk',      icon: Icons.directions_walk_rounded, color: Color(0xFF39D98A), kcalPerKm: 48),
  ActivityType(id: 'hike',  label: 'Hike',      icon: Icons.terrain_rounded,         color: Color(0xFFFF9500), kcalPerKm: 55),
  ActivityType(id: 'cycle', label: 'Cycle',     icon: Icons.directions_bike_rounded, color: Color(0xFF5AC8FA), kcalPerKm: 28),
  ActivityType(id: 'trail', label: 'Trail Run', icon: Icons.forest_rounded,          color: Color(0xFF7C4DFF), kcalPerKm: 70),
];

// ── Phase enum ───────────────────────────────────────────────────────────────

enum _Phase { setup, tracking, summary }

// ── Main screen ──────────────────────────────────────────────────────────────

class ActivityTrackerScreen extends StatefulWidget {
  const ActivityTrackerScreen({super.key});

  @override
  State<ActivityTrackerScreen> createState() => _ActivityTrackerScreenState();
}

class _ActivityTrackerScreenState extends State<ActivityTrackerScreen>
    with TickerProviderStateMixin {
  _Phase _phase = _Phase.setup;
  ActivityType _type = kActivityTypes[0];

  final _gps = GpsTrackingService.instance;
  final _mapController = MapController();
  StreamSubscription<TrackingSnapshot>? _trackingSub;

  TrackingSnapshot? _snap;
  String? _gpsError;
  bool _mapFollowing = true;

  // Summary state
  Map<String, dynamic>? _sessionData;
  List<Map<String, dynamic>> _hrPoints = [];
  bool _fetchingHr = false;
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  // Pulse animation for current position dot
  late AnimationController _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _trackingSub?.cancel();
    _gps.reset();
    _pulseAnim.dispose();
    _noteCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  // ── Start / Stop / Pause ──────────────────────────────────────────────────

  Future<void> _startTracking() async {
    final err = await _gps.start();
    if (err != null) {
      setState(() => _gpsError = err);
      return;
    }
    setState(() {
      _phase = _Phase.tracking;
      _gpsError = null;
    });
    _trackingSub = _gps.stream.listen((snap) {
      if (!mounted) return;
      setState(() => _snap = snap);
      if (_mapFollowing && snap.points.isNotEmpty) {
        final p = snap.points.last;
        _mapController.move(LatLng(p.lat, p.lng), _mapController.camera.zoom);
      }
    });
  }

  void _togglePause() {
    if (_gps.state == TrackingState.paused) {
      _gps.resume();
    } else {
      _gps.pause();
    }
  }

  Future<void> _stopTracking() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NudgeTokens.elevated,
        title: Text('End ${_type.label}?',
            style: GoogleFonts.outfit(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text('Review and save your session.',
            style: GoogleFonts.outfit(color: NudgeTokens.textMid)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: NudgeTokens.textLow))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _type.color),
            child: const Text('End Session',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    _trackingSub?.cancel();
    final data = _gps.stop();
    setState(() {
      _sessionData = data;
      _phase = _Phase.summary;
    });
    _fetchHrData(data);
  }

  Future<void> _fetchHrData(Map<String, dynamic> data) async {
    setState(() => _fetchingHr = true);
    try {
      final start = DateTime.parse(data['startTime'] as String);
      final end = DateTime.parse(data['endTime'] as String);
      final raw = await HealthService.fetchRawHealthData(start: start, end: end);
      final hrList = raw
          .where((p) => p.type == HealthDataType.HEART_RATE)
          .map((p) => {
                'bpm': p.value is NumericHealthValue
                    ? (p.value as NumericHealthValue).numericValue.toInt()
                    : 0,
                'ts': p.dateTo.toIso8601String(),
              })
          .where((d) => (d['bpm'] as int) > 0)
          .toList()
          .cast<Map<String, dynamic>>();
      if (mounted) setState(() => _hrPoints = hrList);
    } catch (_) {}
    if (mounted) setState(() => _fetchingHr = false);
  }

  Future<void> _saveSession() async {
    if (_sessionData == null) return;
    setState(() => _saving = true);

    final dist = (_sessionData!['distanceMeters'] as num?)?.toDouble() ?? 0.0;
    final kcal = (dist / 1000 * _type.kcalPerKm).round();

    int? avgHr, maxHr;
    if (_hrPoints.isNotEmpty) {
      final bpms = _hrPoints.map((d) => d['bpm'] as int).toList();
      avgHr = (bpms.reduce((a, b) => a + b) / bpms.length).round();
      maxHr = bpms.reduce((a, b) => a > b ? a : b);
    }

    final session = {
      'id': const Uuid().v4(),
      'activityType': _type.id,
      'activityLabel': _type.label,
      ..._sessionData!,
      'calories': kcal,
      if (avgHr != null) 'avgHrBpm': avgHr,
      if (maxHr != null) 'maxHrBpm': maxHr,
      'hrData': _hrPoints,
      'note': _noteCtrl.text.trim(),
    };

    final box = await AppStorage.getGymBox();
    final List<dynamic> sessions =
        (box.get('gps_sessions', defaultValue: <dynamic>[]) as List)
            .cast<dynamic>();
    sessions.insert(0, session);
    await box.put('gps_sessions', sessions);

    if (mounted) Navigator.of(context).pop(true);
  }

  // ── Build router ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _Phase.setup => _SetupView(
          selectedType: _type,
          onTypeSelected: (t) => setState(() => _type = t),
          onStart: _startTracking,
          error: _gpsError,
        ),
      _Phase.tracking => _TrackingView(
          type: _type,
          snap: _snap,
          mapController: _mapController,
          mapFollowing: _mapFollowing,
          pulseAnim: _pulseAnim,
          onFollowToggle: () => setState(() => _mapFollowing = !_mapFollowing),
          onPauseResume: _togglePause,
          onStop: _stopTracking,
        ),
      _Phase.summary => _SummaryView(
          type: _type,
          sessionData: _sessionData!,
          hrPoints: _hrPoints,
          fetchingHr: _fetchingHr,
          noteCtrl: _noteCtrl,
          saving: _saving,
          onSave: _saveSession,
          onDiscard: () => Navigator.of(context).pop(false),
        ),
    };
  }
}

// ── Setup View ────────────────────────────────────────────────────────────────

class _SetupView extends StatelessWidget {
  final ActivityType selectedType;
  final ValueChanged<ActivityType> onTypeSelected;
  final VoidCallback onStart;
  final String? error;

  const _SetupView({
    required this.selectedType,
    required this.onTypeSelected,
    required this.onStart,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NudgeTokens.bg,
      appBar: AppBar(
        backgroundColor: NudgeTokens.bg,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text('New Activity',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700, color: Colors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What are you training?',
                  style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(height: 4),
              Text('GPS will track your route and pace.',
                  style: GoogleFonts.outfit(
                      fontSize: 14, color: NudgeTokens.textLow)),
              const SizedBox(height: 24),
              // Activity type grid
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.35,
                  ),
                  itemCount: kActivityTypes.length,
                  itemBuilder: (ctx, i) {
                    final t = kActivityTypes[i];
                    final selected = t.id == selectedType.id;
                    return GestureDetector(
                      onTap: () => onTypeSelected(t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: selected
                              ? t.color.withValues(alpha: 0.18)
                              : NudgeTokens.card,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selected
                                ? t.color
                                : Colors.white.withValues(alpha: 0.08),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(t.icon,
                                size: 36,
                                color: selected ? t.color : NudgeTokens.textMid),
                            const SizedBox(height: 10),
                            Text(t.label,
                                style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected ? t.color : Colors.white)),
                            if (selected)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '~${t.kcalPerKm} kcal/km',
                                  style: GoogleFonts.outfit(
                                      fontSize: 11, color: t.color.withValues(alpha: 0.7)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: NudgeTokens.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: NudgeTokens.red.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.gps_off_rounded,
                          color: NudgeTokens.red, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(error!,
                              style: GoogleFonts.outfit(
                                  fontSize: 13, color: NudgeTokens.red))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: onStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: selectedType.color,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded,
                      size: 26, color: Colors.black),
                  label: Text('Start ${selectedType.label}',
                      style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.black)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tracking View ─────────────────────────────────────────────────────────────

class _TrackingView extends StatelessWidget {
  final ActivityType type;
  final TrackingSnapshot? snap;
  final MapController mapController;
  final bool mapFollowing;
  final AnimationController pulseAnim;
  final VoidCallback onFollowToggle;
  final VoidCallback onPauseResume;
  final VoidCallback onStop;

  const _TrackingView({
    required this.type,
    required this.snap,
    required this.mapController,
    required this.mapFollowing,
    required this.pulseAnim,
    required this.onFollowToggle,
    required this.onPauseResume,
    required this.onStop,
  });

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _fmtPace(double minPerKm) {
    if (minPerKm <= 0 || minPerKm.isInfinite || minPerKm.isNaN) return '--:--';
    final min = minPerKm.floor();
    final sec = ((minPerKm % 1) * 60).round();
    return "$min'${sec.toString().padLeft(2, '0')}\"";
  }

  String _fmtDist(double m) {
    if (m >= 1000) return '${(m / 1000).toStringAsFixed(2)} km';
    return '${m.toInt()} m';
  }

  @override
  Widget build(BuildContext context) {
    final points = snap?.points ?? [];
    final polyline = points
        .map((p) => LatLng(p.lat, p.lng))
        .toList();
    final hasRoute = points.isNotEmpty;
    final isPaused = snap?.state == TrackingState.paused;

    // Initial map center — London fallback until GPS fix
    final mapCenter = hasRoute
        ? LatLng(points.last.lat, points.last.lng)
        : const LatLng(51.5, -0.09);

    return Scaffold(
      backgroundColor: NudgeTokens.bg,
      body: Stack(
        children: [
          // ── Map ───────────────────────────────────────────────────────────
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: mapCenter,
              initialZoom: 16.5,
              onMapEvent: (event) {
                if (event is MapEventMoveStart &&
                    event.source != MapEventSource.mapController) {
                  // User is panning manually — stop following
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.nudge.app',
                maxZoom: 20,
              ),
              if (polyline.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: polyline,
                      strokeWidth: 5,
                      color: type.color,
                    ),
                  ],
                ),
              if (hasRoute)
                MarkerLayer(
                  markers: [
                    // Start dot
                    Marker(
                      point: polyline.first,
                      width: 16,
                      height: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: NudgeTokens.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                      ),
                    ),
                    // Current position with pulse
                    Marker(
                      point: polyline.last,
                      width: 36,
                      height: 36,
                      child: AnimatedBuilder(
                        animation: pulseAnim,
                        builder: (_, __) => Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 30 + pulseAnim.value * 6,
                              height: 30 + pulseAnim.value * 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: type.color
                                    .withValues(alpha: 0.25 * (1 - pulseAnim.value)),
                              ),
                            ),
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: isPaused ? NudgeTokens.amber : type.color,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isPaused
                                            ? NudgeTokens.amber
                                            : type.color)
                                        .withValues(alpha: 0.6),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ── Top header overlay ────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    NudgeTokens.bg.withValues(alpha: 0.92),
                    NudgeTokens.bg.withValues(alpha: 0),
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Activity label
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: type.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: type.color.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(type.icon, size: 15, color: type.color),
                            const SizedBox(width: 6),
                            Text(type.label,
                                style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: type.color)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Timer
                      Text(
                        _fmtDuration(snap?.elapsed ?? Duration.zero),
                        style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: isPaused ? NudgeTokens.amber : Colors.white,
                            letterSpacing: 1),
                      ),
                      // Re-center button
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: onFollowToggle,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            mapFollowing
                                ? Icons.gps_fixed_rounded
                                : Icons.gps_not_fixed_rounded,
                            size: 18,
                            color: mapFollowing
                                ? type.color
                                : NudgeTokens.textLow,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Auto-paused banner ─────────────────────────────────────────────
          if (isPaused && snap!.autoPaused)
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: NudgeTokens.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: NudgeTokens.amber.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pause_circle_rounded,
                        color: NudgeTokens.amber, size: 18),
                    const SizedBox(width: 8),
                    Text('AUTO-PAUSED · Move to resume',
                        style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: NudgeTokens.amber)),
                  ],
                ),
              ),
            ),

          // ── Bottom stats + controls ────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    NudgeTokens.bg,
                    NudgeTokens.bg.withValues(alpha: 0.95),
                    NudgeTokens.bg.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.75, 1],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Distance (hero number)
                      Text(
                        _fmtDist(snap?.distanceMeters ?? 0),
                        style: GoogleFonts.outfit(
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1),
                      ),
                      const SizedBox(height: 12),
                      // Stat row
                      Row(
                        children: [
                          _StatChip(
                            label: 'Avg Pace',
                            value: _fmtPace(snap?.avgPaceMinPerKm ?? 0),
                            icon: Icons.speed_rounded,
                            color: type.color,
                          ),
                          const SizedBox(width: 10),
                          _StatChip(
                            label: 'Speed',
                            value: snap != null
                                ? '${(snap!.currentSpeedMs * 3.6).toStringAsFixed(1)} km/h'
                                : '-- km/h',
                            icon: Icons.trending_up_rounded,
                            color: NudgeTokens.blue,
                          ),
                          const SizedBox(width: 10),
                          _StatChip(
                            label: 'Elevation',
                            value: snap != null
                                ? '+${snap!.elevationGain.toInt()}m'
                                : '+0m',
                            icon: Icons.landscape_rounded,
                            color: NudgeTokens.amber,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Controls
                      Row(
                        children: [
                          // Pause / Resume
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 56,
                              child: FilledButton.icon(
                                onPressed: onPauseResume,
                                style: FilledButton.styleFrom(
                                  backgroundColor: isPaused
                                      ? NudgeTokens.green.withValues(alpha: 0.18)
                                      : NudgeTokens.amber.withValues(alpha: 0.18),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: Icon(
                                  isPaused
                                      ? Icons.play_arrow_rounded
                                      : Icons.pause_rounded,
                                  color: isPaused
                                      ? NudgeTokens.green
                                      : NudgeTokens.amber,
                                  size: 26,
                                ),
                                label: Text(
                                  isPaused ? 'Resume' : 'Pause',
                                  style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: isPaused
                                          ? NudgeTokens.green
                                          : NudgeTokens.amber),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Stop
                          Expanded(
                            flex: 1,
                            child: SizedBox(
                              height: 56,
                              child: FilledButton(
                                onPressed: onStop,
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      NudgeTokens.red.withValues(alpha: 0.18),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  padding: EdgeInsets.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.stop_rounded,
                                        color: NudgeTokens.red, size: 20),
                                    Text('Stop',
                                        style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: NudgeTokens.red)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(height: 2),
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 10, color: NudgeTokens.textLow)),
          ],
        ),
      ),
    );
  }
}

// ── Summary View ──────────────────────────────────────────────────────────────

class _SummaryView extends StatelessWidget {
  final ActivityType type;
  final Map<String, dynamic> sessionData;
  final List<Map<String, dynamic>> hrPoints;
  final bool fetchingHr;
  final TextEditingController noteCtrl;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  const _SummaryView({
    required this.type,
    required this.sessionData,
    required this.hrPoints,
    required this.fetchingHr,
    required this.noteCtrl,
    required this.saving,
    required this.onSave,
    required this.onDiscard,
  });

  String _fmtDuration(int seconds) {
    final d = Duration(seconds: seconds);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  String _fmtPace(double minPerKm) {
    if (minPerKm <= 0 || minPerKm.isInfinite || minPerKm.isNaN) return '--';
    final min = minPerKm.floor();
    final sec = ((minPerKm % 1) * 60).round();
    return "$min'${sec.toString().padLeft(2, '0')}\"";
  }

  @override
  Widget build(BuildContext context) {
    final dist = (sessionData['distanceMeters'] as num?)?.toDouble() ?? 0.0;
    final dur = (sessionData['durationSeconds'] as num?)?.toInt() ?? 0;
    final avgPace = (sessionData['avgPaceMinPerKm'] as num?)?.toDouble() ?? 0.0;
    final maxSpeedKmh = (sessionData['maxSpeedKmh'] as num?)?.toDouble() ?? 0.0;
    final elevGain = (sessionData['elevationGain'] as num?)?.toDouble() ?? 0.0;
    final kcal = ((dist / 1000) * type.kcalPerKm).round();

    final rawPoints = sessionData['points'] as List?;
    final routePoints = rawPoints
            ?.map((p) => LatLng(
                  (p['lat'] as num).toDouble(),
                  (p['lng'] as num).toDouble(),
                ))
            .toList() ??
        [];

    int? avgHr, maxHr;
    if (hrPoints.isNotEmpty) {
      final bpms = hrPoints.map((d) => d['bpm'] as int).toList();
      avgHr = (bpms.reduce((a, b) => a + b) / bpms.length).round();
      maxHr = bpms.reduce((a, b) => a > b ? a : b);
    }

    return Scaffold(
      backgroundColor: NudgeTokens.bg,
      appBar: AppBar(
        backgroundColor: NudgeTokens.bg,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text('${type.label} Complete',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: NudgeTokens.red),
          tooltip: 'Discard',
          onPressed: () => showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: NudgeTokens.elevated,
              title: Text('Discard session?',
                  style: GoogleFonts.outfit(
                      color: Colors.white, fontWeight: FontWeight.w700)),
              content: Text('This activity will not be saved.',
                  style: GoogleFonts.outfit(color: NudgeTokens.textMid)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel',
                        style: TextStyle(color: NudgeTokens.textLow))),
                TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onDiscard();
                    },
                    child: const Text('Discard',
                        style: TextStyle(color: NudgeTokens.red))),
              ],
            ),
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          // ── Route map ────────────────────────────────────────────────────
          if (routePoints.length >= 2) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 220,
                child: FlutterMap(
                  options: MapOptions(
                    initialCameraFit: CameraFit.coordinates(
                      coordinates: routePoints,
                      padding: const EdgeInsets.all(32),
                    ),
                    interactionOptions:
                        const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.nudge.app',
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: routePoints,
                          strokeWidth: 4,
                          color: type.color,
                        ),
                      ],
                    ),
                    MarkerLayer(markers: [
                      Marker(
                          point: routePoints.first,
                          width: 16,
                          height: 16,
                          child: Container(
                              decoration: BoxDecoration(
                                  color: NudgeTokens.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.black, width: 2)))),
                      Marker(
                          point: routePoints.last,
                          width: 16,
                          height: 16,
                          child: Container(
                              decoration: BoxDecoration(
                                  color: NudgeTokens.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.black, width: 2)))),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Stats grid ────────────────────────────────────────────────────
          _SectionLabel('Performance'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.0,
            children: [
              _SummaryStatCard(
                  label: 'Distance',
                  value: dist >= 1000
                      ? '${(dist / 1000).toStringAsFixed(2)} km'
                      : '${dist.toInt()} m',
                  icon: Icons.straighten_rounded,
                  color: type.color),
              _SummaryStatCard(
                  label: 'Duration',
                  value: _fmtDuration(dur),
                  icon: Icons.timer_rounded,
                  color: NudgeTokens.blue),
              _SummaryStatCard(
                  label: 'Avg Pace',
                  value: _fmtPace(avgPace),
                  icon: Icons.speed_rounded,
                  color: NudgeTokens.green),
              _SummaryStatCard(
                  label: 'Max Speed',
                  value: '${maxSpeedKmh.toStringAsFixed(1)} km/h',
                  icon: Icons.trending_up_rounded,
                  color: NudgeTokens.purple),
              _SummaryStatCard(
                  label: 'Elev Gain',
                  value: '+${elevGain.toInt()} m',
                  icon: Icons.landscape_rounded,
                  color: NudgeTokens.amber),
              _SummaryStatCard(
                  label: 'Calories',
                  value: '~$kcal kcal',
                  icon: Icons.local_fire_department_rounded,
                  color: NudgeTokens.red),
            ],
          ),

          // ── Heart rate ────────────────────────────────────────────────────
          if (fetchingHr) ...[
            const SizedBox(height: 20),
            _SectionLabel('Heart Rate'),
            const SizedBox(height: 12),
            const Center(
                child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: NudgeTokens.red))),
          ] else if (avgHr != null) ...[
            const SizedBox(height: 20),
            _SectionLabel('Heart Rate'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: _SummaryStatCard(
                        label: 'Avg HR',
                        value: '$avgHr bpm',
                        icon: Icons.favorite_rounded,
                        color: NudgeTokens.red)),
                const SizedBox(width: 10),
                Expanded(
                    child: _SummaryStatCard(
                        label: 'Max HR',
                        value: '$maxHr bpm',
                        icon: Icons.monitor_heart_rounded,
                        color: NudgeTokens.red)),
              ],
            ),
          ],

          // ── Note ─────────────────────────────────────────────────────────
          const SizedBox(height: 20),
          _SectionLabel('Note (optional)'),
          const SizedBox(height: 10),
          TextField(
            controller: noteCtrl,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'How did it feel? Any details...',
              hintStyle:
                  GoogleFonts.outfit(color: NudgeTokens.textLow, fontSize: 14),
              filled: true,
              fillColor: NudgeTokens.card,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: NudgeTokens.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: NudgeTokens.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: type.color)),
            ),
          ),

          const SizedBox(height: 24),

          // ── Save button ───────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: saving ? null : onSave,
              style: FilledButton.styleFrom(
                backgroundColor: type.color,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.black))
                  : const Icon(Icons.save_rounded,
                      size: 22, color: Colors.black),
              label: Text(saving ? 'Saving...' : 'Save Activity',
                  style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.black)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: NudgeTokens.textLow,
            letterSpacing: 1.4),
      );
}

class _SummaryStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

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
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value,
                    style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(label,
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: NudgeTokens.textLow)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
