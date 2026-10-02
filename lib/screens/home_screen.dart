import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app.dart' show NudgeTokens;
import '../utils/nudge_theme_extension.dart';
import '../storage.dart';
import '../utils/health_service.dart';
import '../utils/usage_service.dart';
import 'movies/movies_screen.dart';
import 'books/books_screen.dart';
import 'habits/my_habits_screen.dart';
import 'trackers/day_tracker_screen.dart';
import 'pomodoro/pomodoro_screen.dart';
import 'gym/gym_screen.dart';
import 'finance/finance_screen.dart';
import 'settings_screen.dart';
import 'activity/activity_summary_screen.dart';
import 'health/running_coach_list_screen.dart';
import '../utils/ai_analysis_service.dart';
import 'food/food_screen.dart';
import 'package:usage_stats/usage_stats.dart';
import '../widgets/water_tracker_card.dart';
import '../widgets/daily_progress_rings.dart';
import 'digital_wellbeing/digital_wellbeing_screen.dart';
import '../services/health_center_service.dart';
import 'health/health_center_screen.dart';
import '../utils/streak_service.dart';
import '../utils/notification_service.dart';

// ── Root scaffold ─────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;
  int _activityRefreshKey = 0;

  void _onTabTap(int i) {
    setState(() {
      // Bump the key each time the Activity tab is tapped so the screen
      // rebuilds and re-fetches fresh data.
      if (i == 1) _activityRefreshKey++;
      _tabIndex = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<NudgeThemeExtension>()!;
    return Scaffold(
      backgroundColor: theme.scaffoldBg ?? NudgeTokens.bg,
      extendBody: true,
      body: IndexedStack(
        index: _tabIndex,
        children: [
          const _HomeTab(),
          ActivitySummaryScreen(key: ValueKey(_activityRefreshKey)),
          const _ModulesTab(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _NudgeNavBar(
        currentIndex: _tabIndex,
        onTap: _onTabTap,
      ),
    );
  }
}

// ── Home tab ──────────────────────────────────────────────────────────────────

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with WidgetsBindingObserver {
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchStats();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _fetchStats();
  }

  Future<void> _fetchStats() async {
    final water = await HealthService.getTodayWater();
    final finBox = await AppStorage.getFinanceBox();
    final now2 = DateTime.now();
    final monthKey =
        '${now2.year}-${now2.month.toString().padLeft(2, '0')}';
    final allExpenses = (finBox
            .get('expenses', defaultValue: <dynamic>[]) as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .where((e) => (e['date'] as String? ?? '').startsWith(monthKey))
        .toList();
    final spent = allExpenses.fold<double>(0.0, (s, e) {
      final a = (e['amount'] as num?)?.toDouble() ?? 0.0;
      return s + (a < 0 ? -a : 0);
    });
    final budgets =
        finBox.get('budgets', defaultValue: <String, dynamic>{}) as Map;
    final budget = (budgets[monthKey] is num)
        ? (budgets[monthKey] as num).toDouble()
        : 0.0;

    final healthStats = await HealthCenterService.getTodayStats();

    // ── Streak logic ────────────────────────────────────────────────────────
    final gymSets = (healthStats['workoutsToday'] ?? 0) as num;
    final caloriesIn = (healthStats['caloriesIn'] ?? 0.0) as num;
    final waterTotal =
        (water['total'] as num?) ?? 0;
    final pomMin = (healthStats['pomMinutes'] ?? 0) as num;

    final hasActivityToday = gymSets > 0 ||
        caloriesIn > 0 ||
        waterTotal > 0 ||
        pomMin > 0;

    if (hasActivityToday) {
      StreakService.markToday();
      if (AppStorage.reminderEnabled) {
        NotificationService().cancelStreakReminder();
      }
    }

    final streak = StreakService.currentStreak;

    if (mounted) {
      setState(() {
        _stats = healthStats;
        _stats['gymSets'] = healthStats['gymSetsToday'] ?? 0;
        _stats['todayCalories'] = caloriesIn;
        _stats['totalScreentime'] = UsageService.formatDuration(
            (healthStats['totalScreentimeMs'] ?? 0).toString());
        _stats['healthStats'] = {
          'caloriesIn': caloriesIn,
          'caloriesTarget': healthStats['caloriesTarget'],
        };
        _stats['financeSpent'] = spent;
        _stats['financeBudget'] = budget;
        _stats['water'] = water;
        _stats['monthlyUsage'] = healthStats['monthlyUsage'] ?? [];
        _stats['appStreak'] = streak;
        _loading = false;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Header
          SliverToBoxAdapter(child: _buildHeader()),

          // 2. Progress rings summary
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            sliver: SliverToBoxAdapter(child: _buildProgressRings()),
          ),

          // 3. Daily stats strip
          SliverToBoxAdapter(child: _buildDailyStats()),

          // 4. AI Insights card
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(child: _AiInsightsCard(stats: _stats)),
          ),

          // 5. Weekly snapshot
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(child: _WeeklySnapshot(stats: _stats)),
          ),

          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.bottom + 110)),
        ],
      ),
    );
  }

  Widget _buildProgressRings() {
    final caloriesBurned =
        (_stats['caloriesBurned'] as num?)?.toDouble() ?? 0.0;
    final gymSets = (_stats['gymSets'] as num?)?.toDouble() ?? 0.0;
    final pomMin = (_stats['pomMinutes'] as num?)?.toDouble() ?? 0.0;
    final caloriesIn = ((_stats['healthStats'] as Map?)?['caloriesIn'] as num?)
            ?.toDouble() ??
        0.0;
    final caloriesTarget =
        ((_stats['healthStats'] as Map?)?['caloriesTarget'] as num?)
                ?.toDouble() ??
            2000.0;

    return DailyProgressRings(
      moveProgress: (caloriesBurned / 500).clamp(0.0, 1.5),
      exerciseProgress: (gymSets / 20).clamp(0.0, 1.5),
      focusProgress: (pomMin / 60).clamp(0.0, 1.5),
      habitProgress:
          caloriesTarget > 0 ? (caloriesIn / caloriesTarget).clamp(0.0, 1.5) : 0.0,
      habitsDone: caloriesIn.toInt(),
      habitsTotal: caloriesTarget.toInt(),
      moveValueText: '${caloriesBurned.toInt()} kcal out',
      exerciseValueText: '${gymSets.toInt()} sets',
      focusValueText: '${pomMin.toInt()} min focus',
      habitValueText: '${caloriesIn.toInt()} / ${caloriesTarget.toInt()} kcal',
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dayName = days[now.weekday - 1];
    final dateStr = '${now.day} ${months[now.month - 1]}';

    final hour = now.hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nudge',
                style: GoogleFonts.outfit(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$greeting · $dayName, $dateStr',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: NudgeTokens.textLow,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Streak chip
          if (!_loading && ((_stats['appStreak'] as int?) ?? 0) > 0) ...[
            _StreakChip(streak: (_stats['appStreak'] as int)),
            const SizedBox(width: 10),
          ],
          if (_loading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: NudgeTokens.textLow),
            )
          else
            GestureDetector(
              onTap: _fetchStats,
              child: const Icon(Icons.refresh_rounded,
                  color: NudgeTokens.textLow, size: 22),
            ),
        ],
      ),
    );
  }

  Widget _buildDailyStats() {
    final chips = <_StatChipData>[];

    if (AppStorage.enabledModules.contains('gym')) {
      chips.add(_StatChipData(
        icon: Icons.fitness_center_rounded,
        color: NudgeTokens.gymB,
        value: '${_stats['gymSets'] ?? 0}',
        label: 'sets',
      ));
    }

    if (AppStorage.enabledModules.contains('food')) {
      chips.add(_StatChipData(
        icon: Icons.restaurant_rounded,
        color: NudgeTokens.foodB,
        value: '${(_stats['todayCalories'] as double? ?? 0.0).toInt()}',
        label: 'kcal in',
      ));
    }

    final caloriesBurned =
        (_stats['caloriesBurned'] as num?)?.toInt() ?? 0;
    if (AppStorage.enabledModules.contains('health') && caloriesBurned > 0) {
      chips.add(_StatChipData(
        icon: Icons.local_fire_department_rounded,
        color: NudgeTokens.red,
        value: '$caloriesBurned',
        label: 'kcal out',
      ));
    }

    final waterMl = (_stats['water'] as Map?)?['total'];
    if (AppStorage.enabledModules.contains('health') && waterMl != null) {
      chips.add(_StatChipData(
        icon: Icons.water_drop_rounded,
        color: NudgeTokens.blue,
        value: '${(waterMl as num).toInt()}',
        label: 'ml water',
      ));
    }

    final pomMin = (_stats['pomMinutes'] as num?)?.toInt() ?? 0;
    if (AppStorage.enabledModules.contains('pomodoro')) {
      chips.add(_StatChipData(
        icon: Icons.timer_rounded,
        color: NudgeTokens.pomB,
        value: '${pomMin}m',
        label: 'focus',
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: chips.length,
        itemBuilder: (_, i) => _DailyStatChip(data: chips[i]),
      ),
    );
  }

}

// ── Modules tab (old home — full module grid) ─────────────────────────────────

class _ModulesTab extends StatefulWidget {
  const _ModulesTab();
  @override
  State<_ModulesTab> createState() => _ModulesTabState();
}

class _ModulesTabState extends State<_ModulesTab> with WidgetsBindingObserver {
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  Timer? _screenTimeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchStats();
    // Refresh screen time every 3 minutes so it stays current
    _screenTimeTimer = Timer.periodic(const Duration(minutes: 3), (_) => _fetchStats());
  }

  @override
  void dispose() {
    _screenTimeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _fetchStats();
  }

  Future<void> _fetchStats() async {
    final water = await HealthService.getTodayWater();
    final finBox = await AppStorage.getFinanceBox();
    final now2 = DateTime.now();
    final monthKey = '${now2.year}-${now2.month.toString().padLeft(2, '0')}';
    final allExpenses = (finBox.get('expenses', defaultValue: <dynamic>[]) as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .where((e) => (e['date'] as String? ?? '').startsWith(monthKey))
        .toList();
    final spent = allExpenses.fold<double>(0.0, (s, e) {
      final a = (e['amount'] as num?)?.toDouble() ?? 0.0;
      return s + (a < 0 ? -a : 0);
    });
    final budgets = finBox.get('budgets', defaultValue: <String, dynamic>{}) as Map;
    final budget = (budgets[monthKey] is num) ? (budgets[monthKey] as num).toDouble() : 0.0;
    final healthStats = await HealthCenterService.getTodayStats();
    final caloriesIn = (healthStats['caloriesIn'] ?? 0.0) as num;
    if (mounted) {
      setState(() {
        _stats = healthStats;
        _stats['gymSets'] = healthStats['gymSetsToday'] ?? 0;
        _stats['todayCalories'] = caloriesIn;
        _stats['totalScreentime'] = UsageService.formatDuration(
            (healthStats['totalScreentimeMs'] ?? 0).toString());
        _stats['healthStats'] = {
          'caloriesIn': caloriesIn,
          'caloriesTarget': healthStats['caloriesTarget'],
        };
        _stats['financeSpent'] = spent;
        _stats['financeBudget'] = budget;
        _stats['water'] = water;
        _stats['monthlyUsage'] = healthStats['monthlyUsage'] ?? [];
        _loading = false;
      });
    }
  }

  String _healthStatus() {
    final hs = _stats['healthStats'] as Map<String, dynamic>?;
    if (hs == null) return 'Set up profile';
    final eaten = (hs['caloriesIn'] as num?)?.toInt() ?? 0;
    final target = (hs['caloriesTarget'] as num?)?.toInt() ?? 0;
    if (target == 0) return 'Set up profile';
    return '$eaten / $target kcal';
  }

  String _financeStatus() {
    final spent = (_stats['financeSpent'] as double?) ?? 0.0;
    final budget = (_stats['financeBudget'] as double?) ?? 0.0;
    if (budget > 0) {
      final remaining = budget - spent;
      final abs = remaining.abs();
      return remaining >= 0 ? '£${abs.toStringAsFixed(0)} left' : '-£${abs.toStringAsFixed(0)} over';
    }
    if (spent > 0) return '£${spent.toStringAsFixed(0)} spent';
    return 'No expenses';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            sliver: SliverToBoxAdapter(
              child: Text('Apps', style: GoogleFonts.outfit(
                fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
            ),
          ),
          ..._buildSections(context),
          if (AppStorage.enabledModules.contains('health'))
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              sliver: SliverToBoxAdapter(child: WaterTrackerCard(onRefresh: _fetchStats)),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _ScreenTimeCard(stats: _stats, loading: _loading),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.bottom + 110)),
        ],
      ),
    );
  }

  List<Widget> _buildSections(BuildContext context) {
    final slivers = <Widget>[];
    final healthCards = <Widget>[];
    if (AppStorage.enabledModules.contains('health')) {
      healthCards.add(_ModuleCard(
        title: 'Health', status: _loading ? '…' : _healthStatus(),
        icon: Icons.monitor_heart_rounded, accentA: NudgeTokens.healthA, accentB: NudgeTokens.healthB,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HealthCenterScreen())).then((_) => _fetchStats()),
      ));
    }
    if (AppStorage.enabledModules.contains('gym')) {
      healthCards.add(_ModuleCard(
        title: 'Gym', status: _loading ? '…' : '${_stats['gymSets'] ?? 0} sets today',
        icon: Icons.fitness_center_rounded, accentA: NudgeTokens.gymA, accentB: NudgeTokens.gymB,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GymScreen())).then((_) => _fetchStats()),
      ));
    }
    if (AppStorage.enabledModules.contains('food')) {
      healthCards.add(_ModuleCard(
        title: 'Food', status: _loading ? '…' : '${(_stats['todayCalories'] as double? ?? 0.0).toInt()} kcal today',
        icon: Icons.restaurant_rounded, accentA: NudgeTokens.foodA, accentB: NudgeTokens.foodB,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FoodScreen())).then((_) => _fetchStats()),
      ));
    }
    if (AppStorage.enabledModules.contains('health')) {
      final steps = (_stats['steps'] as num?)?.toInt() ?? 0;
      healthCards.add(_ModuleCard(
        title: 'Cardio Coach', status: _loading ? '…' : (steps > 0 ? '$steps steps' : 'No sessions'),
        icon: Icons.route_rounded, accentA: NudgeTokens.purple, accentB: NudgeTokens.purple,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RunningCoachListScreen())).then((_) => _fetchStats()),
      ));
    }
    if (healthCards.isNotEmpty) {
      slivers.add(_sectionLabel('HEALTH & FITNESS'));
      slivers.add(_moduleGrid(healthCards));
    }
    final prodCards = <Widget>[];
    if (AppStorage.enabledModules.contains('pomodoro')) {
      prodCards.add(_ModuleCard(
        title: 'Pomodoro', status: _loading ? '…' : '${((_stats['pomMinutes'] as num? ?? 0) / 60).toStringAsFixed(1)} hrs today',
        icon: Icons.timer_rounded, accentA: NudgeTokens.pomA, accentB: NudgeTokens.pomB,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PomodoroScreen())).then((_) => _fetchStats()),
      ));
    }
    if (AppStorage.enabledModules.contains('my_habits')) {
      prodCards.add(_ModuleCard(
        title: 'My Habits', status: _loading ? '…' : 'Daily tracker',
        icon: Icons.checklist_rounded, accentA: NudgeTokens.purple, accentB: NudgeTokens.green,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyHabitsScreen())).then((_) => _fetchStats()),
      ));
    }
    prodCards.add(_ModuleCard(
      title: 'Day Trackers', status: 'Year progress',
      icon: Icons.grid_view_rounded, accentA: NudgeTokens.purple.withValues(alpha: 0.3), accentB: NudgeTokens.purple,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DayTrackerScreen())).then((_) => _fetchStats()),
    ));
    if (prodCards.isNotEmpty) {
      slivers.add(_sectionLabel('PRODUCTIVITY'));
      slivers.add(_moduleGrid(prodCards));
    }
    final entertainCards = <Widget>[];
    if (AppStorage.enabledModules.contains('movies')) {
      entertainCards.add(_ModuleCard(
        title: 'Movies', status: _loading ? '…' : '${_stats['moviesCount'] ?? 0} this month',
        icon: Icons.local_movies_rounded, accentA: NudgeTokens.moviesA, accentB: NudgeTokens.moviesB,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MoviesScreen())).then((_) => _fetchStats()),
      ));
    }
    if (AppStorage.enabledModules.contains('books')) {
      entertainCards.add(_ModuleCard(
        title: 'Books', status: _loading ? '…' : '${_stats['booksCount'] ?? 0} active',
        icon: Icons.menu_book_rounded, accentA: NudgeTokens.booksA, accentB: NudgeTokens.booksB,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BooksScreen())).then((_) => _fetchStats()),
      ));
    }
    if (entertainCards.isNotEmpty) {
      slivers.add(_sectionLabel('ENTERTAINMENT'));
      slivers.add(_moduleGrid(entertainCards));
    }
    final finCards = <Widget>[];
    if (AppStorage.enabledModules.contains('finance')) {
      finCards.add(_ModuleCard(
        title: 'Finance', status: _loading ? '…' : _financeStatus(),
        icon: Icons.account_balance_wallet_rounded, accentA: NudgeTokens.finA, accentB: NudgeTokens.finB,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FinanceScreen())).then((_) => _fetchStats()),
      ));
    }
    if (AppStorage.enabledModules.contains('detox')) {
      finCards.add(_ModuleCard(
        title: 'Digital Wellbeing', status: 'Screen Time & Detox',
        icon: Icons.phone_android_rounded, accentA: NudgeTokens.blue.withValues(alpha: 0.15), accentB: NudgeTokens.purple,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DigitalWellbeingScreen())).then((_) => _fetchStats()),
      ));
    }
    if (finCards.isNotEmpty) {
      slivers.add(_sectionLabel('FINANCE & WELLBEING'));
      slivers.add(_moduleGrid(finCards));
    }
    return slivers;
  }

  Widget _sectionLabel(String text) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    sliver: SliverToBoxAdapter(
      child: Text(text, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: NudgeTokens.textLow, letterSpacing: 1.2)),
    ),
  );

  Widget _moduleGrid(List<Widget> cards) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    sliver: SliverGrid.count(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.05, children: cards),
  );
}

// ── Bottom nav bar ─────────────────────────────────────────────────────────────

class _NudgeNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _NudgeNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<NudgeThemeExtension>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: (theme.scaffoldBg ?? NudgeTokens.bg).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavBarItem(
                    icon: Icons.grid_view_rounded,
                    label: 'Home',
                    isSelected: currentIndex == 0,
                    onTap: () => onTap(0)),
                _NavBarItem(
                    icon: Icons.local_activity_rounded,
                    label: 'Activity',
                    isSelected: currentIndex == 1,
                    onTap: () => onTap(1)),
                _NavBarItem(
                    icon: Icons.apps_rounded,
                    label: 'Apps',
                    isSelected: currentIndex == 2,
                    onTap: () => onTap(2)),
                _NavBarItem(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    isSelected: currentIndex == 3,
                    onTap: () => onTap(3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? NudgeTokens.purple : NudgeTokens.textLow;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: color,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Daily stat chip ────────────────────────────────────────────────────────────

class _StatChipData {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _StatChipData(
      {required this.icon,
      required this.color,
      required this.value,
      required this.label});
}

class _DailyStatChip extends StatelessWidget {
  final _StatChipData data;
  const _DailyStatChip({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: data.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 14, color: data.color),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(data.value,
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1)),
              Text(data.label,
                  style: GoogleFonts.outfit(
                      fontSize: 10, color: NudgeTokens.textLow)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Module card ───────────────────────────────────────────────────────────────

class _ModuleCard extends StatelessWidget {
  final String title;
  final String status;
  final IconData icon;
  final Color accentA;
  final Color accentB;
  final VoidCallback onTap;
  final Widget? metrics;

  const _ModuleCard({
    required this.title,
    required this.status,
    required this.icon,
    required this.accentA,
    required this.accentB,
    required this.onTap,
    this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: accentB.withValues(alpha: 0.12),
        highlightColor: accentB.withValues(alpha: 0.06),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentB.withValues(alpha: 0.14),
                NudgeTokens.card,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: accentB.withValues(alpha: 0.22)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    color: accentB.withValues(alpha: 0.18),
                    border: Border.all(
                        color: accentB.withValues(alpha: 0.3)),
                  ),
                  child: Icon(icon, size: 19, color: accentB),
                ),
                metrics != null ? Expanded(child: metrics!) : const Spacer(),
                // Title
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                // Status
                Text(
                  status,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: NudgeTokens.textLow,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── AI Insights card ──────────────────────────────────────────────────────────

class _AiInsightsCard extends StatefulWidget {
  final Map<String, dynamic> stats;
  const _AiInsightsCard({required this.stats});
  @override
  State<_AiInsightsCard> createState() => _AiInsightsCardState();
}

class _AiInsightsCardState extends State<_AiInsightsCard> {
  bool _generating = false;

  Future<void> _generateAndView() async {
    setState(() => _generating = true);
    final report = await AiAnalysisService.generateWeeklyReport();
    if (!mounted) return;
    setState(() => _generating = false);
    if (report != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _AiReportScreen(content: report, timestamp: DateTime.now().toIso8601String()),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reports = AiAnalysisService.getSavedReports();
    final lastReport = reports.isNotEmpty ? reports.first : null;
    final snippet = lastReport != null
        ? (lastReport['content'] as String).replaceAll('\n', ' ')
        : null;
    final preview = snippet != null && snippet.length > 160
        ? '${snippet.substring(0, 160)}…'
        : snippet;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [NudgeTokens.purple.withValues(alpha: 0.18), NudgeTokens.card],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NudgeTokens.purple.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: NudgeTokens.purple.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 16, color: NudgeTokens.purple),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('AI Progress Summary',
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            if (_generating)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: NudgeTokens.purple)),
          ]),
          if (preview != null) ...[
            const SizedBox(height: 10),
            Text(preview,
                style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.textMid, height: 1.5),
                maxLines: 3, overflow: TextOverflow.ellipsis),
          ] else ...[
            const SizedBox(height: 8),
            Text('Generate your weekly AI-powered health summary.',
                style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.textLow)),
          ],
          const SizedBox(height: 14),
          Row(children: [
            if (lastReport != null)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => _AiReportScreen(content: lastReport['content'], timestamp: lastReport['timestamp']),
                  )),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NudgeTokens.purple,
                    side: BorderSide(color: NudgeTokens.purple.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text('View Report', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            if (lastReport != null) const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _generating ? null : _generateAndView,
                style: FilledButton.styleFrom(
                  backgroundColor: NudgeTokens.purple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(_generating ? 'Generating…' : 'New Report',
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── AI Report full-screen viewer ──────────────────────────────────────────────

class _AiReportScreen extends StatelessWidget {
  final String content;
  final String timestamp;
  const _AiReportScreen({required this.content, required this.timestamp});

  @override
  Widget build(BuildContext context) {
    final ts = DateTime.tryParse(timestamp);
    final label = ts != null
        ? '${ts.day}/${ts.month}/${ts.year} ${ts.hour.toString().padLeft(2,'0')}:${ts.minute.toString().padLeft(2,'0')}'
        : '';
    return Scaffold(
      backgroundColor: NudgeTokens.bg,
      appBar: AppBar(
        backgroundColor: NudgeTokens.surface,
        surfaceTintColor: Colors.transparent,
        title: Text('AI Progress Report', style: GoogleFonts.outfit(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
        bottom: label.isNotEmpty
            ? PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(label, style: GoogleFonts.outfit(fontSize: 11, color: NudgeTokens.textLow)),
                ),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(content, style: GoogleFonts.outfit(fontSize: 14, color: NudgeTokens.textMid, height: 1.7)),
      ),
    );
  }
}

// ── Weekly snapshot ───────────────────────────────────────────────────────────

class _WeeklySnapshot extends StatefulWidget {
  final Map<String, dynamic> stats;
  const _WeeklySnapshot({required this.stats});
  @override
  State<_WeeklySnapshot> createState() => _WeeklySnapshotState();
}

class _WeeklySnapshotState extends State<_WeeklySnapshot> {
  List<Map<String, dynamic>> _days = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final box = await AppStorage.getGymBox();
    final history = (box.get('health_history', defaultValue: <dynamic>[]) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final now = DateTime.now();
    final days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      final iso = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
      final entry = history.firstWhere((h) => h['dayIso'] == iso, orElse: () => <String, dynamic>{});
      return {
        'iso': iso,
        'label': _dayLabel(d),
        'isToday': i == 6,
        'gym': (entry['gymSets'] as num?)?.toInt() ?? 0,
        'food': (entry['foodCalories'] as num?)?.toDouble() ?? 0.0,
        'focus': (entry['pomMinutes'] as num?)?.toDouble() ?? 0.0,
        'steps': (entry['steps'] as num?)?.toInt() ?? 0,
      };
    });

    // Today's live data supplements history
    if (days.isNotEmpty) {
      final today = days.last;
      today['gym'] = (widget.stats['gymSetsToday'] as num?)?.toInt() ?? (today['gym'] as int);
      today['food'] = (widget.stats['caloriesIn'] as num?)?.toDouble() ?? (today['food'] as double);
      today['focus'] = (widget.stats['pomMinutes'] as num?)?.toDouble() ?? (today['focus'] as double);
      today['steps'] = (widget.stats['steps'] as num?)?.toInt() ?? (today['steps'] as int);
    }

    if (mounted) setState(() { _days = days; _loading = false; });
  }

  String _dayLabel(DateTime d) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return labels[d.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.calendar_view_week_rounded, size: 15, color: NudgeTokens.textLow),
            const SizedBox(width: 8),
            Text('THIS WEEK', style: GoogleFonts.outfit(
                fontSize: 11, fontWeight: FontWeight.w800, color: NudgeTokens.textLow, letterSpacing: 1.1)),
          ]),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: NudgeTokens.textLow)))
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _days.map((day) => _DayColumn(day: day)).toList(),
            ),
          const SizedBox(height: 14),
          // Legend
          Row(children: [
            _Dot(color: NudgeTokens.gymB), const SizedBox(width: 4),
            Text('Gym', style: GoogleFonts.outfit(fontSize: 10, color: NudgeTokens.textLow)),
            const SizedBox(width: 12),
            _Dot(color: NudgeTokens.foodB), const SizedBox(width: 4),
            Text('Food', style: GoogleFonts.outfit(fontSize: 10, color: NudgeTokens.textLow)),
            const SizedBox(width: 12),
            _Dot(color: NudgeTokens.pomB), const SizedBox(width: 4),
            Text('Focus', style: GoogleFonts.outfit(fontSize: 10, color: NudgeTokens.textLow)),
            const SizedBox(width: 12),
            _Dot(color: NudgeTokens.green), const SizedBox(width: 4),
            Text('Steps', style: GoogleFonts.outfit(fontSize: 10, color: NudgeTokens.textLow)),
          ]),
        ],
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  final Map<String, dynamic> day;
  const _DayColumn({required this.day});

  @override
  Widget build(BuildContext context) {
    final isToday = day['isToday'] as bool;
    final gym = (day['gym'] as int) > 0;
    final food = (day['food'] as double) > 200;
    final focus = (day['focus'] as double) > 10;
    final steps = (day['steps'] as int) > 2000;

    return Column(
      children: [
        _Dot(color: gym ? NudgeTokens.gymB : NudgeTokens.border),
        const SizedBox(height: 3),
        _Dot(color: food ? NudgeTokens.foodB : NudgeTokens.border),
        const SizedBox(height: 3),
        _Dot(color: focus ? NudgeTokens.pomB : NudgeTokens.border),
        const SizedBox(height: 3),
        _Dot(color: steps ? NudgeTokens.green : NudgeTokens.border),
        const SizedBox(height: 8),
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: isToday
              ? BoxDecoration(color: NudgeTokens.purple, borderRadius: BorderRadius.circular(6))
              : null,
          child: Text(day['label'] as String,
              style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                  color: isToday ? Colors.white : NudgeTokens.textLow)),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) => Container(
      width: 8, height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

// ── Streak chip ───────────────────────────────────────────────────────────────

class _StreakChip extends StatelessWidget {
  final int streak;
  const _StreakChip({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: NudgeTokens.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NudgeTokens.amber.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: NudgeTokens.amber,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Screen time card ──────────────────────────────────────────────────────────

class _ScreenTimeCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  final bool loading;

  const _ScreenTimeCard({required this.stats, required this.loading});

  @override
  Widget build(BuildContext context) {
    final usage = stats['usage'] as List<UsageInfo>? ?? [];
    final total = stats['totalScreentime'] as String? ?? '0m';

    int totalMs = 0;
    for (final u in usage) {
      totalMs += int.tryParse(u.totalTimeInForeground ?? '0') ?? 0;
    }

    if (loading || usage.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                borderRadius: BorderRadius.circular(10),
                color: NudgeTokens.blue.withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.phone_android_rounded,
                  size: 16, color: NudgeTokens.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Screen Time',
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Colors.white)),
                  Text(
                    loading
                        ? 'Loading…'
                        : 'No apps tracked — configure in Settings',
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: NudgeTokens.textLow),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const DigitalWellbeingScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NudgeTokens.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: NudgeTokens.blue.withValues(alpha: 0.1),
                  ),
                  child: const Icon(Icons.phone_android_rounded,
                      size: 15, color: NudgeTokens.blue),
                ),
                const SizedBox(width: 10),
                Text('Screen Time',
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.white)),
                const Spacer(),
                Text(total,
                    style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: NudgeTokens.blue)),
              ],
            ),
            const SizedBox(height: 12),
            ...usage.map((u) {
              final timeMs =
                  int.tryParse(u.totalTimeInForeground ?? '0') ?? 0;
              final frac = totalMs > 0 ? timeMs / totalMs : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FutureBuilder<String>(
                  future: UsageService.resolveAppName(u.packageName!),
                  builder: (context, snap) {
                    final name = snap.data ??
                        (u.packageName?.split('.').last ?? '');
                    return Row(
                      children: [
                        Expanded(
                          child: Text(name,
                              style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: NudgeTokens.textMid),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 80,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: frac,
                              minHeight: 4,
                              backgroundColor: NudgeTokens.elevated,
                              valueColor: const AlwaysStoppedAnimation(
                                  NudgeTokens.blue),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          UsageService.formatDuration(
                              u.totalTimeInForeground),
                          style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: NudgeTokens.textLow),
                        ),
                      ],
                    );
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
