import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:geolocator/geolocator.dart';

enum TrackingState { idle, active, paused, stopped }

class GeoTrackPoint {
  final double lat;
  final double lng;
  final double alt;
  final double speedMs;
  final DateTime timestamp;

  const GeoTrackPoint({
    required this.lat,
    required this.lng,
    required this.alt,
    required this.speedMs,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'alt': alt,
        'speed': speedMs,
        'ts': timestamp.toIso8601String(),
      };

  static GeoTrackPoint fromJson(Map<String, dynamic> j) => GeoTrackPoint(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        alt: (j['alt'] as num?)?.toDouble() ?? 0.0,
        speedMs: (j['speed'] as num?)?.toDouble() ?? 0.0,
        timestamp: DateTime.parse(j['ts'] as String),
      );
}

class TrackingSnapshot {
  final TrackingState state;
  final List<GeoTrackPoint> points;
  final double distanceMeters;
  final Duration elapsed;
  final double currentSpeedMs;
  final double currentPaceMinPerKm;
  final double avgPaceMinPerKm;
  final double elevationGain;
  final bool autoPaused;

  const TrackingSnapshot({
    required this.state,
    required this.points,
    required this.distanceMeters,
    required this.elapsed,
    required this.currentSpeedMs,
    required this.currentPaceMinPerKm,
    required this.avgPaceMinPerKm,
    required this.elevationGain,
    this.autoPaused = false,
  });
}

/// Singleton GPS tracking service. Call [GpsTrackingService.instance].
class GpsTrackingService {
  static final GpsTrackingService _instance = GpsTrackingService._internal();
  factory GpsTrackingService() => _instance;
  GpsTrackingService._internal();

  static GpsTrackingService get instance => _instance;

  TrackingState _state = TrackingState.idle;
  final List<GeoTrackPoint> _points = [];
  double _distanceMeters = 0.0;
  double _maxSpeedMs = 0.0;
  double _elevationGain = 0.0;
  double _prevAlt = 0.0;
  bool _prevAltSet = false;

  DateTime? _startTime;
  Duration _pausedDuration = Duration.zero;
  DateTime? _pauseStart;
  bool _autoPaused = false;

  StreamSubscription<Position>? _positionSub;
  Timer? _autoPauseTimer;
  Timer? _tickTimer;

  final _snapshotController = StreamController<TrackingSnapshot>.broadcast();
  Stream<TrackingSnapshot> get stream => _snapshotController.stream;

  TrackingState get state => _state;
  bool get isIdle => _state == TrackingState.idle;

  // Auto-pause when slower than 0.5 m/s (~1.8 km/h) for 6 seconds
  static const double _autoPauseThresholdMs = 0.5;
  static const Duration _autoPauseDelay = Duration(seconds: 6);

  /// Check/request permissions. Returns null on success, error message on failure.
  Future<String?> checkPermissions() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return 'GPS is disabled. Please enable location services.';
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return 'Location permission denied.';
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return 'Location permission permanently denied. Enable it in app Settings.';
    }
    return null;
  }

  /// Start a new tracking session. Returns null on success, error string on failure.
  Future<String?> start() async {
    if (_state != TrackingState.idle) return 'Already tracking.';

    final err = await checkPermissions();
    if (err != null) return err;

    _points.clear();
    _distanceMeters = 0.0;
    _maxSpeedMs = 0.0;
    _elevationGain = 0.0;
    _prevAlt = 0.0;
    _prevAltSet = false;
    _startTime = DateTime.now();
    _pausedDuration = Duration.zero;
    _pauseStart = null;
    _autoPaused = false;
    _state = TrackingState.active;

    _startPositionStream();
    return null;
  }

  void pause({bool auto = false}) {
    if (_state != TrackingState.active) return;
    _state = TrackingState.paused;
    _autoPaused = auto;
    _pauseStart = DateTime.now();
    _positionSub?.cancel();
    _positionSub = null;
    _autoPauseTimer?.cancel();
    _autoPauseTimer = null;
    _tickTimer?.cancel();
    _tickTimer = null;
    _emit();
  }

  void resume() {
    if (_state != TrackingState.paused) return;
    if (_pauseStart != null) {
      _pausedDuration += DateTime.now().difference(_pauseStart!);
      _pauseStart = null;
    }
    _autoPaused = false;
    _state = TrackingState.active;
    _startPositionStream();
    _emit();
  }

  /// Stop tracking and return the raw session data map.
  Map<String, dynamic> stop() {
    if (_pauseStart != null) {
      _pausedDuration += DateTime.now().difference(_pauseStart!);
    }
    final endTime = DateTime.now();
    _state = TrackingState.stopped;
    _positionSub?.cancel();
    _positionSub = null;
    _autoPauseTimer?.cancel();
    _autoPauseTimer = null;
    _tickTimer?.cancel();
    _tickTimer = null;

    final elapsed = _calcElapsed(at: endTime);
    final avgPace = _calcAvgPace(elapsed: elapsed);
    final avgSpeedKmh = elapsed.inSeconds > 0
        ? (_distanceMeters / 1000) / (elapsed.inSeconds / 3600)
        : 0.0;

    final result = {
      'startTime': _startTime?.toIso8601String() ?? endTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'durationSeconds': elapsed.inSeconds,
      'distanceMeters': _distanceMeters,
      'avgPaceMinPerKm': avgPace,
      'avgSpeedKmh': avgSpeedKmh,
      'maxSpeedKmh': _maxSpeedMs * 3.6,
      'elevationGain': _elevationGain,
      'points': _points.map((p) => p.toJson()).toList(),
    };

    _state = TrackingState.idle;
    return result;
  }

  void _startPositionStream() {
    final LocationSettings settings;
    if (Platform.isAndroid) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Run in progress',
          notificationText: 'Nudge is tracking your activity in the background.',
          enableWakeLock: true,
        ),
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
      );
    }
    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_onPosition, onError: (_) {});

    // Tick every second so the elapsed timer updates smoothly in the UI,
    // independent of how often GPS position events arrive.
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state == TrackingState.active) _emit();
    });
  }

  void _onPosition(Position pos) {
    if (_state != TrackingState.active) return;

    final speed = pos.speed < 0 ? 0.0 : pos.speed;

    // Auto-pause detection
    if (speed < _autoPauseThresholdMs) {
      _autoPauseTimer ??= Timer(_autoPauseDelay, () {
        if (_state == TrackingState.active) pause(auto: true);
      });
    } else {
      _autoPauseTimer?.cancel();
      _autoPauseTimer = null;
      if (_state == TrackingState.paused && _autoPaused) resume();
    }

    final point = GeoTrackPoint(
      lat: pos.latitude,
      lng: pos.longitude,
      alt: pos.altitude,
      speedMs: speed,
      timestamp: DateTime.now(),
    );

    // Distance
    if (_points.isNotEmpty) {
      final last = _points.last;
      _distanceMeters += _haversine(last.lat, last.lng, point.lat, point.lng);
    }

    // Elevation gain (only upward, filter noise < 0.5m)
    if (_prevAltSet) {
      final gain = pos.altitude - _prevAlt;
      if (gain > 0.5) _elevationGain += gain;
    }
    _prevAlt = pos.altitude;
    _prevAltSet = true;

    if (speed > _maxSpeedMs) _maxSpeedMs = speed;

    _points.add(point);
    _emit();
  }

  void _emit() {
    if (_snapshotController.isClosed) return;
    final elapsed = _calcElapsed();
    final currentSpeed = _points.isNotEmpty ? _points.last.speedMs : 0.0;
    final currentPace = currentSpeed > 0.3 ? (1000 / currentSpeed) / 60 : 0.0;
    _snapshotController.add(TrackingSnapshot(
      state: _state,
      points: List.unmodifiable(_points),
      distanceMeters: _distanceMeters,
      elapsed: elapsed,
      currentSpeedMs: currentSpeed,
      currentPaceMinPerKm: currentPace,
      avgPaceMinPerKm: _calcAvgPace(elapsed: elapsed),
      elevationGain: _elevationGain,
      autoPaused: _autoPaused,
    ));
  }

  Duration _calcElapsed({DateTime? at}) {
    if (_startTime == null) return Duration.zero;
    final now = at ??
        (_state == TrackingState.paused && _pauseStart != null
            ? _pauseStart!
            : DateTime.now());
    return now.difference(_startTime!) - _pausedDuration;
  }

  double _calcAvgPace({Duration? elapsed}) {
    final e = elapsed ?? _calcElapsed();
    final km = _distanceMeters / 1000;
    if (km < 0.01) return 0;
    return (e.inSeconds / 60) / km;
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _rad(double deg) => deg * pi / 180;

  /// Reset without starting — safe to call when navigating away.
  void reset() {
    _positionSub?.cancel();
    _autoPauseTimer?.cancel();
    _tickTimer?.cancel();
    _positionSub = null;
    _autoPauseTimer = null;
    _tickTimer = null;
    _state = TrackingState.idle;
    _points.clear();
    _distanceMeters = 0;
    _pausedDuration = Duration.zero;
    _startTime = null;
    _pauseStart = null;
    _autoPaused = false;
  }

  void dispose() {
    reset();
    _snapshotController.close();
  }
}
