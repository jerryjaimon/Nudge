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
  final int initialPage;
  const ActivitySummaryScreen({super.key, this.initialPage = 0});

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

  late final PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(initialPage: widget.initialPage);
    _fetchStats();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
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

  String _avgPace(int durSec, double distKm) {
    if (distKm <= 0 || durSec <= 0) return '--';
    final minsPerKm = durSec / 60 / distKm;
    final m = minsPerKm.floor();
    final s = ((minsPerKm - m) * 60).round();
    return "$m'${s.toString().padLeft(2, '0')}\"";
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

  List<_CardData> get _cards {
    final steps = (_healthTotals['steps'] ?? 0.0).toInt();
    final distM = (_healthTotals['distance'] ?? 0.0).toDouble();
    final distKm = distM / 1000;
    final burnedKcal = (_healthTotals['calories'] ?? 0.0).toInt();
    final stepGoal = AppStorage.settingsBox.get('step_goal', defaultValue: 10000) as int;
    final calorieGoal = AppStorage.settingsBox.get('calorie_goal', defaultValue: 2000.0) as double;

    return [
      // 1. Movement
      _CardData(
        id: 'movement',
        color: NudgeTokens.green,
        icon: Icons.directions_walk_rounded,
        label: 'MOVEMENT',
        mainValue: '$steps',
        mainUnit: 'steps',
        subtitle: '${distKm.toStringAsFixed(1)} km walked',
        progress: (steps / stepGoal).clamp(0.0, 1.0),
        progressLabel: '${(steps / stepGoal * 100).clamp(0, 100).toInt()}% of $stepGoal step goal',
        tile1Icon: Icons.local_fire_department_rounded,
        tile1Value: '$burnedKcal kcal',
        tile1Label: 'Burned',
        tile2Icon: Icons.straighten_rounded,
        tile2Value: '${distKm.toStringAsFixed(2)} km',
        tile2Label: 'Distance',
        actionLabel: 'Open Steps Detail',
        onAction: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const StepsDetailScreen()))
            .then((_) => _fetchStats()),
      ),

      // 2. Gym
      _CardData(
        id: 'gym',
        color: NudgeTokens.gymB,
        icon: Icons.fitness_center_rounded,
        label: 'GYM',
        mainValue: '$_gymSets',
        mainUnit: 'sets',
        subtitle: _gymExercises.isEmpty
            ? 'No exercises logged'
            : _gymExercises.take(2).map((e) => e['name'] ?? '').join(', '),
        progress: (_gymSets / 20).clamp(0.0, 1.0),
        progressLabel: '$_gymSets sets today',
        tile1Icon: Icons.bar_chart_rounded,
        tile1Value: '${_gymExercises.length}',
        tile1Label: 'Exercises',
        tile2Icon: Icons.timer_outlined,
        tile2Value: _gymExercises.isNotEmpty ? '${_gymSets * 45}s' : '--',
        tile2Label: 'Est. time',
        actionLabel: 'Open Gym',
        onAction: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const GymScreen()))
            .then((_) => _fetchStats()),
      ),

      // 3. Nutrition
      _CardData(
        id: 'nutrition',
        color: NudgeTokens.foodB,
        icon: Icons.restaurant_rounded,
        label: 'NUTRITION',
        mainValue: '${_foodCals.toInt()}',
        mainUnit: 'kcal',
        subtitle: 'P ${_foodProt.toInt()}g · C ${_foodCarbs.toInt()}g · F ${_foodFat.toInt()}g',
        progress: calorieGoal > 0
            ? (_foodCals / calorieGoal).clamp(0.0, 1.0)
            : 0.0,
        progressLabel: '${(_foodCals / calorieGoal * 100).clamp(0, 100).toInt()}% of ${calorieGoal.toInt()} kcal goal',
        tile1Icon: Icons.egg_alt_rounded,
        tile1Value: '${_foodProt.toInt()}g',
        tile1Label: 'Protein',
        tile2Icon: Icons.grain_rounded,
        tile2Value: '${_foodCarbs.toInt()}g',
        tile2Label: 'Carbs',
        actionLabel: 'Open Nutrition',
        onAction: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const FoodScreen()))
            .then((_) => _fetchStats()),
      ),

      // 4. Hydration
      _CardData(
        id: 'hydration',
        color: NudgeTokens.blue,
        icon: Icons.water_drop_rounded,
        label: 'HYDRATION',
        mainValue: '${_waterDrank.toInt()}',
        mainUnit: 'ml',
        subtitle: 'of ${_waterGoal.toInt()} ml goal',
        progress: _waterGoal > 0
            ? (_waterDrank / _waterGoal).clamp(0.0, 1.0)
            : 0.0,
        progressLabel: '${(_waterDrank / _waterGoal * 100).clamp(0, 100).toInt()}% of ${_waterGoal.toInt()} ml',
        tile1Icon: Icons.local_drink_rounded,
        tile1Value: '${(_waterDrank / 250).floor()}',
        tile1Label: 'Glasses',
        tile2Icon: Icons.flag_rounded,
        tile2Value: '${_waterGoal.toInt()} ml',
        tile2Label: 'Goal',
        actionLabel: 'Log Water',
        onAction: _showWaterEditor,
      ),

      // 5. Focus
      _CardData(
        id: 'focus',
        color: NudgeTokens.pomB,
        icon: Icons.timer_rounded,
        label: 'FOCUS',
        mainValue: '${_focusMins.toInt()}',
        mainUnit: 'min',
        subtitle: 'deep work today',
        progress: (_focusMins / 90).clamp(0.0, 1.0),
        progressLabel: '${(_focusMins / 90 * 100).clamp(0, 100).toInt()}% of 90 min target',
        tile1Icon: Icons.self_improvement_rounded,
        tile1Value: '${(_focusMins / 25).floor()}',
        tile1Label: 'Sessions',
        tile2Icon: Icons.trending_up_rounded,
        tile2Value: _focusMins >= 90 ? 'Goal!' : '${(90 - _focusMins).toInt()}m left',
        tile2Label: 'Progress',
        actionLabel: 'Open Pomodoro',
        onAction: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const PomodoroScreen()))
            .then((_) => _fetchStats()),
      ),

      // 6. Reading
      _CardData(
        id: 'reading',
        color: NudgeTokens.booksB,
        icon: Icons.menu_book_rounded,
        label: 'READING',
        mainValue: '$_booksRead',
        mainUnit: 'pages',
        subtitle: _activeBook.isNotEmpty ? _activeBook : 'No active book',
        progress: (_booksRead / 30).clamp(0.0, 1.0),
        progressLabel: '${(_booksRead / 30 * 100).clamp(0, 100).toInt()}% of 30 page target',
        tile1Icon: Icons.auto_stories_rounded,
        tile1Value: '$_booksRead',
        tile1Label: 'Pages read',
        tile2Icon: Icons.bookmark_rounded,
        tile2Value: _activeBook.isNotEmpty ? _activeBook.split(' ').first : '--',
        tile2Label: 'Active book',
        actionLabel: 'Open Books',
        onAction: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const BooksScreen()))
            .then((_) => _fetchStats()),
      ),

      // 7. Watching / Entertainment
      _CardData(
        id: 'entertainment',
        color: NudgeTokens.moviesB,
        icon: Icons.local_movies_rounded,
        label: 'ENTERTAINMENT',
        mainValue: _movieMins > 60
            ? (_movieMins / 60).toStringAsFixed(1)
            : '$_movieMins',
        mainUnit: _movieMins > 60 ? 'h' : 'min',
        subtitle: _lastMovie.isNotEmpty ? _lastMovie : 'Nothing logged',
        progress: (_movieMins / 120).clamp(0.0, 1.0),
        progressLabel: '${(_movieMins / 120 * 100).clamp(0, 100).toInt()}% of 2 hour cap',
        tile1Icon: Icons.movie_rounded,
        tile1Value: _lastMovie.split(',').first.trim().isEmpty ? '--' : _lastMovie.split(',').first.trim(),
        tile1Label: 'Title',
        tile2Icon: Icons.access_time_rounded,
        tile2Value: '$_movieMins min',
        tile2Label: 'Watch time',
        actionLabel: 'Open Movies',
        onAction: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const MoviesScreen()))
            .then((_) => _fetchStats()),
      ),

      // 8. Cardio GPS
      _CardData(
        id: 'cardio',
        color: NudgeTokens.purple,
        icon: Icons.route_rounded,
        label: 'CARDIO COACH',
        mainValue: _todayGpsDistKm.toStringAsFixed(2),
        mainUnit: 'km',
        subtitle: _todayGpsSessions.isEmpty
            ? 'No sessions today'
            : '${_todayGpsSessions.length} session${_todayGpsSessions.length > 1 ? 's' : ''} · ${_fmtDur(_todayGpsDurSec)}',
        progress: (_todayGpsDistKm / 5).clamp(0.0, 1.0),
        progressLabel: '${(_todayGpsDistKm / 5 * 100).clamp(0, 100).toInt()}% of 5 km target',
        tile1Icon: Icons.directions_run_rounded,
        tile1Value: '${_todayGpsSessions.length}',
        tile1Label: 'Sessions',
        tile2Icon: Icons.speed_rounded,
        tile2Value: _avgPace(_todayGpsDurSec, _todayGpsDistKm),
        tile2Label: 'Avg pace',
        actionLabel: 'Start Activity',
        onAction: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ActivityTrackerScreen()))
            .then((_) => _fetchStats()),
      ),

      // 9. Gaming placeholder
      _CardData(
        id: 'gaming',
        color: NudgeTokens.purpleDim,
        icon: Icons.sports_esports_rounded,
        label: 'GAMING',
        mainValue: '--',
        mainUnit: '',
        subtitle: 'Health Connect gaming sessions\ncoming soon',
        progress: 0,
        progressLabel: '',
        tile1Icon: Icons.gamepad_rounded,
        tile1Value: '--',
        tile1Label: 'Sessions',
        tile2Icon: Icons.timer_outlined,
        tile2Value: '--',
        tile2Label: 'Play time',
        actionLabel: 'Coming Soon',
        onAction: null,
        isPlaceholder: true,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = _currentDate.year == now.year &&
        _currentDate.month == now.month &&
        _currentDate.day == now.day;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
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

            // ── Cards (vertical full-screen swipe) ─────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : PageView(
                      controller: _pageCtrl,
                      scrollDirection: Axis.vertical,
                      children: _cards
                          .map((card) => _ActivityCard(
                                data: card,
                                key: ValueKey(card.id),
                              ))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card data model ────────────────────────────────────────────────────────────

class _CardData {
  final String id;
  final Color color;
  final IconData icon;
  final String label;
  final String mainValue;
  final String mainUnit;
  final String subtitle;
  final double progress;
  final String progressLabel;
  final IconData tile1Icon;
  final String tile1Value;
  final String tile1Label;
  final IconData tile2Icon;
  final String tile2Value;
  final String tile2Label;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool isPlaceholder;

  const _CardData({
    required this.id,
    required this.color,
    required this.icon,
    required this.label,
    required this.mainValue,
    required this.mainUnit,
    required this.subtitle,
    required this.progress,
    required this.progressLabel,
    required this.tile1Icon,
    required this.tile1Value,
    required this.tile1Label,
    required this.tile2Icon,
    required this.tile2Value,
    required this.tile2Label,
    required this.actionLabel,
    required this.onAction,
    this.isPlaceholder = false,
  });
}

// ── Full-screen activity card ─────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  final _CardData data;

  const _ActivityCard({required this.data, super.key});

  @override
  Widget build(BuildContext context) {
    final pct = (data.progress * 100).clamp(0, 100).toInt();

    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            data.color.withValues(alpha: 0.18),
            NudgeTokens.bg,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: data.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(data.icon, color: data.color, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  data.label,
                  style: GoogleFonts.outfit(
                    color: data.color,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.8,
                  ),
                ),
                const Spacer(),
                Text(
                  '$pct%',
                  style: GoogleFonts.outfit(
                    color: data.isPlaceholder ? NudgeTokens.textLow : data.color,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),

            // ── Main metric ───────────────────────────────────────────────
            const Spacer(),
            if (data.isPlaceholder) ...[
              Center(
                child: Column(
                  children: [
                    Icon(data.icon, color: NudgeTokens.textLow, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      data.subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          color: NudgeTokens.textLow, fontSize: 15, height: 1.6),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Center(
                child: Column(
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: data.mainValue,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 64,
                              height: 1.0,
                            ),
                          ),
                          if (data.mainUnit.isNotEmpty)
                            TextSpan(
                              text: ' ${data.mainUnit}',
                              style: GoogleFonts.outfit(
                                color: NudgeTokens.textMid,
                                fontWeight: FontWeight.w600,
                                fontSize: 22,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          color: NudgeTokens.textMid, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(),

            // ── Progress bar ──────────────────────────────────────────────
            if (!data.isPlaceholder && data.progressLabel.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: data.progress,
                  minHeight: 6,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(data.color),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                data.progressLabel,
                style: const TextStyle(color: NudgeTokens.textLow, fontSize: 11),
              ),
              const SizedBox(height: 16),
            ] else
              const SizedBox(height: 28),

            // ── Stat tiles ────────────────────────────────────────────────
            Row(
              children: [
                _StatTile(
                  icon: data.tile1Icon,
                  value: data.tile1Value,
                  label: data.tile1Label,
                  color: data.color,
                ),
                const SizedBox(width: 10),
                _StatTile(
                  icon: data.tile2Icon,
                  value: data.tile2Value,
                  label: data.tile2Label,
                  color: data.color,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Action button ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: data.onAction,
                icon: Icon(
                  data.isPlaceholder ? Icons.lock_clock_rounded : Icons.add_rounded,
                  size: 18,
                  color: data.isPlaceholder ? NudgeTokens.textLow : Colors.black,
                ),
                label: Text(
                  data.actionLabel,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: data.isPlaceholder ? NudgeTokens.textLow : Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      data.isPlaceholder ? NudgeTokens.surface : data.color,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat tile ─────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: const TextStyle(color: NudgeTokens.textLow, fontSize: 11),
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
