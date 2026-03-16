// lib/screens/activity/activity_summary_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app.dart' show NudgeTokens;
import '../../utils/health_service.dart';
import '../../utils/food_service.dart';
import '../../storage.dart';
import '../gym/gym_screen.dart';
import '../books/books_screen.dart';
import '../movies/movies_screen.dart';
import '../food/food_screen.dart';
import '../pomodoro/pomodoro_screen.dart';
import 'steps_detail_screen.dart';
import 'activity_tracker_screen.dart';

class ActivitySummaryScreen extends StatefulWidget {
  const ActivitySummaryScreen({super.key});

  @override
  State<ActivitySummaryScreen> createState() => _ActivitySummaryScreenState();
}

class _ActivitySummaryScreenState extends State<ActivitySummaryScreen> {
  Map<String, dynamic> _healthTotals = {'steps': 0.0, 'calories': 0.0, 'distance': 0.0};
  List<Map<String, dynamic>> _todayGpsSessions = [];
  double _todayGpsDistKm = 0.0;
  int _todayGpsDurSec = 0;

  int _gymSets = 0;
  List _gymExercises = [];
  int _booksRead = 0;
  String _activeBook = '';
  int _movieMins = 0;
  String _lastMovie = '';
  double _waterDrank = 0.0;
  double _waterGoal = 2000.0;
  double _foodCals = 0.0;
  double _foodProt = 0.0;
  double _foodCarbs = 0.0;
  double _foodFat = 0.0;
  double _focusMins = 0.0;

  bool _loading = true;
  DateTime _currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  String get _isoDate {
    final d = _currentDate;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _fetchStats() async {
    setState(() => _loading = true);

    final iso = _isoDate;
    final now = DateTime.now();
    final todayIso =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    Map<String, dynamic> healthData;
    if (iso == todayIso) {
      healthData = await HealthService.fetchDailyActivityBySource();
    } else {
      final gymBox = await AppStorage.getGymBox();
      final history =
          (gymBox.get('health_history', defaultValue: <dynamic>[]) as List).cast<Map>();
      final pastLog = history.firstWhere((e) => e['dayIso'] == iso, orElse: () => {});
      final pastWater = await HealthService.getTodayWater(date: _currentDate);
      healthData = {
        'totals': {
          'steps': (pastLog['steps'] as num?)?.toDouble() ?? 0.0,
          'calories': (pastLog['calories'] as num?)?.toDouble() ?? 0.0,
          'distance': (pastLog['distance'] as num?)?.toDouble() ?? 0.0,
        },
        'water_today': pastWater,
      };
    }

    final gymBox = await AppStorage.getGymBox();
    final movieBox = await AppStorage.getMoviesBox();
    final bookBox = await AppStorage.getBooksBox();

    // GPS
    final allGps = (gymBox.get('gps_sessions', defaultValue: <dynamic>[]) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final todayGps = allGps.where((s) => (s['startTime'] as String? ?? '').startsWith(iso)).toList();
    final gpsDistKm = todayGps.fold(
        0.0, (sum, s) => sum + ((s['distanceMeters'] as num?)?.toDouble() ?? 0.0) / 1000);
    final gpsDurSec = todayGps.fold(
        0, (sum, s) => sum + ((s['durationSeconds'] as num?)?.toInt() ?? 0));

    // Gym
    final workouts = (gymBox.get('workouts', defaultValue: []) as List).cast<Map>();
    final todayWorkout = workouts.firstWhere((w) => w['dayIso'] == iso, orElse: () => {});
    final exercises = (todayWorkout['exercises'] as List?) ?? [];
    final gymSets =
        exercises.fold(0, (sum, ex) => sum + ((ex['sets'] as List?) ?? []).length as int);

    // Movies
    final moviesRaw = (movieBox.get('movies', defaultValue: []) as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    final todayMovies = moviesRaw.where((m) => m['watchDay'] == iso).toList();
    final movieMins =
        todayMovies.fold(0, (sum, m) => sum + ((m['runtimeMin'] as num?)?.toInt() ?? 0));
    final movieTitles = todayMovies.map((m) => m['title']).join(', ');

    // Books
    final booksRaw = (bookBox.get('books', defaultValue: []) as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    int pagesToday = 0;
    String activeBook = '';
    for (var b in booksRaw) {
      final logs = (b['readingLogs'] as List?) ?? [];
      for (var l in logs) {
        if (l['dayIso'] == iso) pagesToday += (l['pages'] as num?)?.toInt() ?? 0;
      }
      final total = b['totalPages'] as int? ?? 0;
      final read = b['pagesRead'] as int? ?? 0;
      if (activeBook.isEmpty && (total == 0 || read < total)) {
        activeBook = b['title'] as String? ?? '';
      }
    }

    // Food
    final foodEntries = await FoodService.getTodayEntries(date: _currentDate);
    double totalCals = 0, totalProt = 0, totalCarbs = 0, totalFat = 0;
    for (var e in foodEntries) {
      totalCals += (e['calories'] as num?)?.toDouble() ?? 0;
      totalProt += (e['protein'] as num?)?.toDouble() ?? 0;
      totalCarbs += (e['carbs'] as num?)?.toDouble() ?? 0;
      totalFat += (e['fat'] as num?)?.toDouble() ?? 0;
    }

    // Pomodoro
    final pomBox = await AppStorage.getPomodoroBox();
    final pomLogs = (pomBox.get('logs', defaultValue: []) as List).cast<Map>();
    double pomMins = 0;
    for (var l in pomLogs) {
      if (l['startTime'].toString().startsWith(iso)) {
        pomMins += (l['durationMin'] as num?)?.toDouble() ?? 0;
      }
    }

    if (mounted) {
      setState(() {
        _healthTotals =
            healthData['totals'] ?? {'steps': 0.0, 'calories': 0.0, 'distance': 0.0};
        _todayGpsSessions = todayGps;
        _todayGpsDistKm = gpsDistKm;
        _todayGpsDurSec = gpsDurSec;
        _gymSets = gymSets;
        _gymExercises = exercises;
        _booksRead = pagesToday;
        _activeBook = activeBook;
        _movieMins = movieMins;
        _lastMovie = movieTitles;
        final waterRes = healthData['water_today'] ?? {'total': 0.0};
        _waterDrank = (waterRes['total'] as num?)?.toDouble() ?? 0.0;
        _waterGoal = AppStorage.settingsBox.get('water_goal', defaultValue: 2000.0) as double;
        _foodCals = totalCals;
        _foodProt = totalProt;
        _foodCarbs = totalCarbs;
        _foodFat = totalFat;
        _focusMins = pomMins;
        _loading = false;
      });
    }
  }

  void _changeDate(int offset) {
    setState(() => _currentDate = _currentDate.add(Duration(days: offset)));
    _fetchStats();
  }

  String _fmtDur(int sec) {
    if (sec <= 0) return '0m';
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  void _showWaterEditor() {
    showModalBottomSheet(
      context: context,
      backgroundColor: NudgeTokens.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Hydration',
                  style: GoogleFonts.outfit(
                      fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _WaterBtn(label: '-250ml', onTap: () async {
                    Navigator.pop(ctx);
                    await HealthService.addLocalWater(-250, date: _currentDate);
                    _fetchStats();
                  }),
                  _WaterBtn(label: '+250ml', highlight: true, onTap: () async {
                    Navigator.pop(ctx);
                    await HealthService.addLocalWater(250, date: _currentDate);
                    _fetchStats();
                  }),
                  _WaterBtn(label: '+500ml', highlight: true, onTap: () async {
                    Navigator.pop(ctx);
                    await HealthService.addLocalWater(500, date: _currentDate);
                    _fetchStats();
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = _currentDate.year == now.year &&
        _currentDate.month == now.month &&
        _currentDate.day == now.day;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Date nav ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                    onPressed: () => _changeDate(-1),
                  ),
                  Text(
                    isToday
                        ? 'TODAY'
                        : '${_currentDate.year}-${_currentDate.month.toString().padLeft(2, '0')}-${_currentDate.day.toString().padLeft(2, '0')}',
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 1.5),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right_rounded,
                        color: isToday ? Colors.white24 : Colors.white),
                    onPressed: isToday ? null : () => _changeDate(1),
                  ),
                ],
              ),
            ),
            // ── Body ──────────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _fetchStats,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Start activity button
                            _StartActivityButton(
                              sessions: _todayGpsSessions,
                              distKm: _todayGpsDistKm,
                              durSec: _todayGpsDurSec,
                              fmtDur: _fmtDur,
                              onTap: () => Navigator.of(context)
                                  .push(MaterialPageRoute(
                                      builder: (_) => const ActivityTrackerScreen()))
                                  .then((_) => _fetchStats()),
                            ),
                            const SizedBox(height: 16),
                            // 2-column grid
                            _grid([
                              _Tile(
                                icon: Icons.directions_walk_rounded,
                                color: NudgeTokens.green,
                                title: 'Steps',
                                value: '${(_healthTotals['steps'] ?? 0.0).toInt()}',
                                sub: '${((_healthTotals['distance'] ?? 0.0) / 1000).toStringAsFixed(1)} km  ·  ${(_healthTotals['calories'] ?? 0.0).toInt()} kcal',
                                onTap: () => Navigator.of(context)
                                    .push(MaterialPageRoute(
                                        builder: (_) => const StepsDetailScreen()))
                                    .then((_) => _fetchStats()),
                              ),
                              _Tile(
                                icon: Icons.fitness_center_rounded,
                                color: NudgeTokens.gymB,
                                title: 'Gym',
                                value: '$_gymSets sets',
                                sub: _exercisesLabel(_gymExercises),
                                onTap: () => Navigator.of(context)
                                    .push(MaterialPageRoute(builder: (_) => const GymScreen()))
                                    .then((_) => _fetchStats()),
                              ),
                              _Tile(
                                icon: Icons.restaurant_rounded,
                                color: NudgeTokens.foodB,
                                title: 'Nutrition',
                                value: '${_foodCals.toInt()} kcal',
                                sub: 'P ${_foodProt.toInt()}g  C ${_foodCarbs.toInt()}g  F ${_foodFat.toInt()}g',
                                onTap: () => Navigator.of(context)
                                    .push(MaterialPageRoute(builder: (_) => const FoodScreen()))
                                    .then((_) => _fetchStats()),
                              ),
                              _Tile(
                                icon: Icons.water_drop_rounded,
                                color: NudgeTokens.blue,
                                title: 'Hydration',
                                value: '${_waterDrank.toInt()} ml',
                                sub: 'goal ${_waterGoal.toInt()} ml  ·  ${(_waterDrank / _waterGoal * 100).clamp(0, 100).toInt()}%',
                                onTap: _showWaterEditor,
                              ),
                              _Tile(
                                icon: Icons.timer_rounded,
                                color: NudgeTokens.pomB,
                                title: 'Focus',
                                value: '${_focusMins.toInt()}m',
                                sub: 'deep work today',
                                onTap: () => Navigator.of(context)
                                    .push(MaterialPageRoute(
                                        builder: (_) => const PomodoroScreen()))
                                    .then((_) => _fetchStats()),
                              ),
                              _Tile(
                                icon: Icons.menu_book_rounded,
                                color: NudgeTokens.booksB,
                                title: 'Reading',
                                value: '$_booksRead pages',
                                sub: _activeBook.isNotEmpty ? _activeBook : 'No active book',
                                onTap: () => Navigator.of(context)
                                    .push(MaterialPageRoute(
                                        builder: (_) => const BooksScreen()))
                                    .then((_) => _fetchStats()),
                              ),
                              _Tile(
                                icon: Icons.local_movies_rounded,
                                color: NudgeTokens.moviesB,
                                title: 'Watching',
                                value: _movieMins > 60
                                    ? '${(_movieMins / 60).toStringAsFixed(1)}h'
                                    : '$_movieMins min',
                                sub: _lastMovie.isNotEmpty ? _lastMovie : 'Nothing logged',
                                onTap: () => Navigator.of(context)
                                    .push(MaterialPageRoute(
                                        builder: (_) => const MoviesScreen()))
                                    .then((_) => _fetchStats()),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _exercisesLabel(List exercises) {
    if (exercises.isEmpty) return 'No exercises logged';
    final names = exercises.take(2).map((e) => e['name'] ?? '').join(', ');
    return exercises.length > 2 ? '$names +${exercises.length - 2}' : names;
  }

  Widget _grid(List<_Tile> tiles) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.15,
      children: tiles,
    );
  }
}

// ── Start Activity banner ─────────────────────────────────────────────────────

class _StartActivityButton extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  final double distKm;
  final int durSec;
  final String Function(int) fmtDur;
  final VoidCallback onTap;

  const _StartActivityButton({
    required this.sessions,
    required this.distKm,
    required this.durSec,
    required this.fmtDur,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasSessions = sessions.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [NudgeTokens.purple.withValues(alpha: 0.9), NudgeTokens.purpleDim],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: NudgeTokens.purple.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.route_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasSessions ? 'GPS Activity' : 'Start Activity',
                    style: GoogleFonts.outfit(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  if (hasSessions)
                    Text(
                      '${sessions.length} session${sessions.length > 1 ? 's' : ''}  ·  ${distKm.toStringAsFixed(2)} km  ·  ${fmtDur(durSec)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    )
                  else
                    const Text('Run, walk, hike, cycle',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

// ── Stat tile ─────────────────────────────────────────────────────────────────

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String sub;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NudgeTokens.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow, size: 16),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                  color: NudgeTokens.textLow, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.outfit(
                  color: color, fontSize: 20, fontWeight: FontWeight.w900, height: 1.1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: const TextStyle(color: NudgeTokens.textLow, fontSize: 10),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Water button helper ───────────────────────────────────────────────────────

class _WaterBtn extends StatelessWidget {
  final String label;
  final bool highlight;
  final VoidCallback onTap;

  const _WaterBtn({required this.label, required this.onTap, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: highlight ? NudgeTokens.blue : NudgeTokens.surface,
        foregroundColor: highlight ? Colors.black : Colors.white,
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
