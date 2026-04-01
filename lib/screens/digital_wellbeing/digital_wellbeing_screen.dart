import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:uuid/uuid.dart';
import '../../app.dart' show NudgeTokens;
import '../../storage.dart';
import '../../utils/usage_service.dart';
import '../../utils/detox_service.dart' show DetoxSchedule;

const _kGoalMs = 3 * 60 * 60 * 1000; // 3-hour daily goal

const _kAppColors = [
  NudgeTokens.blue,
  NudgeTokens.purple,
  NudgeTokens.green,
  NudgeTokens.amber,
  Color(0xFFFF7B54),
  Color(0xFF9B59B6),
  NudgeTokens.red,
  Color(0xFF26C6DA),
];

const _doomApps = {
  'com.zhiliaoapp.musically',
  'com.ss.android.ugc.trill',
  'com.instagram.android',
  'com.twitter.android',
  'com.facebook.katana',
  'com.reddit.frontpage',
  'com.snapchat.android',
  'com.google.android.youtube',
  'com.facebook.orca',
  'com.pinterest',
  'com.linkedin.android',
  'com.tumblr',
  'com.whatsapp',
  'org.telegram.messenger',
  'com.discord',
  'com.netflix.mediaclient',
  'com.amazon.avod.thirdpartyclient',
  'com.google.android.apps.youtube.music',
  'com.spotify.music',
};

// ── Main screen ───────────────────────────────────────────────────────────────

class DigitalWellbeingScreen extends StatefulWidget {
  /// 0 = Screen Time, 1 = Detox
  final int initialTab;
  const DigitalWellbeingScreen({super.key, this.initialTab = 0});

  @override
  State<DigitalWellbeingScreen> createState() => _DigitalWellbeingScreenState();
}

class _DigitalWellbeingScreenState extends State<DigitalWellbeingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  // ── Screen Time state ──────────────────────────────────────────────────────
  late DateTime _selected;
  final Map<String, Map<String, int>> _cache = {}; // dateKey → {pkg: ms}
  List<int> _weeklyTotals = List.filled(7, 0);
  Map<String, List<int>> _weeklyPerApp = {}; // pkg → 7-day ms list (idx 0=6d ago, 6=today)
  List<String> _trackedApps = [];
  bool _hasPermission = false;
  bool _stLoading = true;
  bool _showWeekly = false; // daily ↔ weekly toggle

  // ── Detox state ────────────────────────────────────────────────────────────
  List<DetoxSchedule> _schedules = [];
  bool _detoxLoading = true;
  static const _detoxKey = 'detox_schedules';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = DateTime(now.year, now.month, now.day);
    _tab = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _tab.addListener(() => setState(() {}));
    _initScreenTime();
    _loadDetox();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ── Screen Time logic ─────────────────────────────────────────────────────

  Future<void> _initScreenTime() async {
    _trackedApps =
        (AppStorage.settingsBox.get('tracked_apps', defaultValue: <String>[]) as List)
            .cast<String>();
    _hasPermission = await UsageService.checkPermission();
    if (_hasPermission) await _loadWeekly();
    if (mounted) setState(() => _stLoading = false);
  }

  Future<void> _saveTrackedApps(List<String> apps) async {
    _trackedApps = apps;
    await AppStorage.settingsBox.put('tracked_apps', apps);
  }

  void _openTrackerSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AppTrackerSheet(
        selected: List.from(_trackedApps),
        onSave: (apps) async {
          await _saveTrackedApps(apps);
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Future<void> _loadWeekly() async {
    final now = DateTime.now();
    final totals = <int>[];
    final perApp = <String, List<int>>{};

    for (int i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      // Always fetch ALL apps — tracked/untracked split happens in UI
      final stats = await UsageService.fetchDayStats(day);
      _cache[_dateKey(day)] = stats;
      totals.add(stats.values.fold(0, (a, b) => a + b));
      stats.forEach((pkg, ms) {
        perApp.putIfAbsent(pkg, () => List.filled(7, 0));
        perApp[pkg]![6 - i] = ms;
      });
    }

    if (mounted) {
      setState(() {
        _weeklyTotals = totals;
        _weeklyPerApp = perApp;
      });
    }
  }

  String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  Map<String, int> get _selectedDayStats => _cache[_dateKey(_selected)] ?? {};

  bool get _isToday {
    final now = DateTime.now();
    return _selected.year == now.year &&
        _selected.month == now.month &&
        _selected.day == now.day;
  }

  int? get _selectedWeekIndex {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(_selected).inDays;
    if (diff >= 0 && diff <= 6) return 6 - diff;
    return null;
  }

  Future<void> _navigateDate(int delta) async {
    final newDate = _selected.add(Duration(days: delta));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (newDate.isAfter(today)) return;
    setState(() => _selected = newDate);
    final key = _dateKey(newDate);
    if (!_cache.containsKey(key)) {
      final stats = await UsageService.fetchDayStats(newDate);
      if (mounted) setState(() => _cache[key] = stats);
    }
  }

  // ── Detox logic ───────────────────────────────────────────────────────────

  Future<void> _loadDetox() async {
    final box = await AppStorage.getSettingsBox();
    final raw = box.get(_detoxKey, defaultValue: <dynamic>[]) as List;
    if (mounted) {
      setState(() {
        _schedules = raw
            .map((e) => DetoxSchedule.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
        _detoxLoading = false;
      });
    }
  }

  Future<void> _saveDetox() async {
    final box = await AppStorage.getSettingsBox();
    await box.put(_detoxKey, _schedules.map((s) => s.toJson()).toList());
  }

  void _addSchedule() async {
    final result = await showModalBottomSheet<DetoxSchedule>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _EditScheduleSheet(),
    );
    if (result != null) {
      setState(() => _schedules.add(result));
      await _saveDetox();
    }
  }

  void _editSchedule(int idx) async {
    final result = await showModalBottomSheet<DetoxSchedule>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditScheduleSheet(schedule: _schedules[idx]),
    );
    if (result != null) {
      setState(() => _schedules[idx] = result);
      await _saveDetox();
    }
  }

  void _deleteSchedule(int idx) async {
    setState(() => _schedules.removeAt(idx));
    await _saveDetox();
  }

  bool _isScheduleActive(DetoxSchedule s) {
    final now = DateTime.now();
    if (!s.days.contains(now.weekday)) return false;
    final cur = now.hour * 60 + now.minute;
    final st = s.startTime.hour * 60 + s.startTime.minute;
    final en = s.endTime.hour * 60 + s.endTime.minute;
    if (st <= en) return cur >= st && cur <= en;
    return cur >= st || cur <= en; // overnight
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NudgeTokens.bg,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
              child: Row(children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
                Expanded(
                  child: Text(
                    'Digital Wellbeing',
                    style: GoogleFonts.outfit(
                        fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: NudgeTokens.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: NudgeTokens.border),
              ),
              child: TabBar(
                controller: _tab,
                indicator: BoxDecoration(
                  color: _tab.index == 0 ? NudgeTokens.blue : NudgeTokens.purple,
                  borderRadius: BorderRadius.circular(11),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: NudgeTokens.textLow,
                labelStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700),
                unselectedLabelStyle:
                    GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w500),
                padding: const EdgeInsets.all(4),
                tabs: const [Tab(text: 'Screen Time'), Tab(text: 'Detox')],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [_buildScreenTimeBody(), _buildDetoxBody()],
            ),
          ),
        ],
      ),
      floatingActionButton: _tab.index == 1
          ? FloatingActionButton(
              onPressed: _addSchedule,
              backgroundColor: NudgeTokens.purple,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  // ── Screen Time body ──────────────────────────────────────────────────────

  Widget _buildScreenTimeBody() {
    if (_stLoading) {
      return const Center(child: CircularProgressIndicator(color: NudgeTokens.blue));
    }
    if (!_hasPermission) {
      return _PermissionView(onGranted: () async {
        setState(() {
          _stLoading = true;
          _hasPermission = true;
        });
        await _loadWeekly();
        if (mounted) setState(() => _stLoading = false);
      });
    }

    return Column(
      children: [
        // Daily / Weekly toggle + filter
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Row(
            children: [
              _ViewChip(
                label: 'Daily',
                selected: !_showWeekly,
                onTap: () => setState(() => _showWeekly = false),
              ),
              const SizedBox(width: 8),
              _ViewChip(
                label: 'Weekly',
                selected: _showWeekly,
                onTap: () => setState(() => _showWeekly = true),
              ),
              const Spacer(),
              IconButton(
                onPressed: _openTrackerSheet,
                icon: Icon(
                  Icons.tune_rounded,
                  color: _trackedApps.isNotEmpty
                      ? NudgeTokens.blue
                      : NudgeTokens.textLow,
                  size: 20,
                ),
                tooltip: 'Manage tracked apps',
              ),
            ],
          ),
        ),
        Expanded(
          child: _showWeekly ? _buildWeeklyView() : _buildDailyView(),
        ),
      ],
    );
  }

  // ── Daily view ────────────────────────────────────────────────────────────

  Widget _buildDailyView() {
    final dayStats = _selectedDayStats;
    final totalMs = dayStats.values.fold(0, (a, b) => a + b);
    final hasTracked = _trackedApps.isNotEmpty;
    final trackedMs = hasTracked
        ? dayStats.entries
            .where((e) => _trackedApps.contains(e.key))
            .fold(0, (a, b) => a + b.value)
        : 0;

    final trackedList = hasTracked
        ? (dayStats.entries
            .where((e) => _trackedApps.contains(e.key))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        : <MapEntry<String, int>>[];
    final otherList = (hasTracked
        ? dayStats.entries.where((e) => !_trackedApps.contains(e.key))
        : dayStats.entries)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    Widget appCard(MapEntry<String, int> entry, Color color) {
      final weeklyData = _weeklyPerApp[entry.key] ?? List.filled(7, 0);
      final weekTotal = weeklyData.fold(0, (a, b) => a + b);
      final daysWithData = weeklyData.where((v) => v > 0).length;
      final avgMs = daysWithData > 0 ? weekTotal ~/ daysWithData : 0;
      return _AppCalorieCard(
        packageName: entry.key,
        ms: entry.value,
        totalMs: totalMs,
        weekTotal: weekTotal,
        avgMs: avgMs,
        color: color,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AppDetailScreen(
              packageName: entry.key,
              weeklyMs: weeklyData,
              selectedDayMs: entry.value,
              selectedDate: _selected,
              color: color,
            ),
          ),
        ),
      );
    }

    SliverToBoxAdapter sectionHeader(String label, int count, Color color) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Row(children: [
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: 1.5)),
            const Spacer(),
            Text('$count app${count == 1 ? '' : 's'}',
                style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: NudgeTokens.textLow)),
          ]),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _DateNavBar(
            selected: _selected,
            isToday: _isToday,
            onPrev: () => _navigateDate(-1),
            onNext: () => _navigateDate(1),
            onToday: () {
              final now = DateTime.now();
              setState(() => _selected = DateTime(now.year, now.month, now.day));
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _DayHeroCard(
                totalMs: totalMs, isToday: _isToday, trackedMs: trackedMs),
          ),
        ),
        if (dayStats.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.phone_android_rounded,
                    color: NudgeTokens.textLow, size: 36),
                const SizedBox(height: 12),
                Text('No usage data for this day',
                    style: GoogleFonts.outfit(
                        color: NudgeTokens.textLow, fontSize: 13)),
              ]),
            ),
          )
        else if (hasTracked) ...[
          // TRACKED APPS section
          if (trackedList.isNotEmpty) ...[
            sectionHeader('TRACKED APPS', trackedList.length, NudgeTokens.blue),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => appCard(
                      trackedList[i], _kAppColors[i % _kAppColors.length]),
                  childCount: trackedList.length,
                ),
              ),
            ),
          ],
          // OTHER APPS section
          if (otherList.isNotEmpty) ...[
            sectionHeader('OTHER APPS', otherList.length, NudgeTokens.textLow),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => appCard(
                      otherList[i],
                      _kAppColors[
                          (trackedList.length + i) % _kAppColors.length]),
                  childCount: otherList.length,
                ),
              ),
            ),
          ] else
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ] else ...[
          // ALL APPS (no tracked apps configured)
          sectionHeader(
              _isToday ? "TODAY'S APPS" : '${_fmtDateLabel(_selected)} APPS',
              otherList.length,
              NudgeTokens.textLow),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) =>
                    appCard(otherList[i], _kAppColors[i % _kAppColors.length]),
                childCount: otherList.length,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Weekly view ───────────────────────────────────────────────────────────

  Widget _buildWeeklyView() {
    final weekTotal = _weeklyTotals.fold(0, (a, b) => a + b);
    final weeklyRanked = _weeklyPerApp.entries.toList()
      ..sort((a, b) {
        final aW = a.value.fold(0, (s, v) => s + v);
        final bW = b.value.fold(0, (s, v) => s + v);
        return bW.compareTo(aW);
      });

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: _WeeklyBarsCard(
              weeklyTotals: _weeklyTotals,
              weekTotal: weekTotal,
              selectedIndex: _selectedWeekIndex,
              onTapDay: (idx) {
                final now = DateTime.now();
                final day = DateTime(now.year, now.month, now.day)
                    .subtract(Duration(days: 6 - idx));
                setState(() => _selected = day);
              },
            ),
          ),
        ),
        // Weekly stats strip
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _WeeklyStatsStrip(
              weeklyTotals: _weeklyTotals,
              weekTotal: weekTotal,
            ),
          ),
        ),
        // Inline selected-day breakdown (when a bar is tapped)
        if (_selectedWeekIndex != null) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(children: [
                Text(
                  'APPS ON ${_fmtDateLabel(_selected).toUpperCase()}',
                  style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: NudgeTokens.blue,
                      letterSpacing: 1.5),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _showWeekly = false),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Full Day',
                        style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: NudgeTokens.blue)),
                    const Icon(Icons.chevron_right_rounded,
                        color: NudgeTokens.blue, size: 14),
                  ]),
                ),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final dayStats = _cache[_dateKey(_selected)] ?? {};
                  final sorted = dayStats.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
                  if (i >= sorted.length) return null;
                  final e = sorted[i];
                  final color = _kAppColors[i % _kAppColors.length];
                  final weeklyData = _weeklyPerApp[e.key] ?? List.filled(7, 0);
                  final wkTotal = weeklyData.fold(0, (a, b) => a + b);
                  final daysWithData = weeklyData.where((v) => v > 0).length;
                  final avgMs = daysWithData > 0 ? wkTotal ~/ daysWithData : 0;
                  final totalMs =
                      dayStats.values.fold(0, (a, b) => a + b);
                  return _AppCalorieCard(
                    packageName: e.key,
                    ms: e.value,
                    totalMs: totalMs,
                    weekTotal: wkTotal,
                    avgMs: avgMs,
                    color: color,
                    onTap: () => Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) => AppDetailScreen(
                          packageName: e.key,
                          weeklyMs: weeklyData,
                          selectedDayMs: e.value,
                          selectedDate: _selected,
                          color: color,
                        ),
                      ),
                    ),
                  );
                },
                childCount: (_cache[_dateKey(_selected)] ?? {}).length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              'TOP APPS THIS WEEK',
              style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: NudgeTokens.textLow,
                  letterSpacing: 1.5),
            ),
          ),
        ),
        if (weeklyRanked.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text('No data this week',
                  style: GoogleFonts.outfit(color: NudgeTokens.textLow)),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  if (i >= weeklyRanked.length) return null;
                  final e = weeklyRanked[i];
                  final appWeekTotal = e.value.fold(0, (a, b) => a + b);
                  final color = _kAppColors[i % _kAppColors.length];
                  return _WeeklyAppRow(
                    packageName: e.key,
                    weeklyMs: e.value,
                    weekTotal: appWeekTotal,
                    color: color,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AppDetailScreen(
                          packageName: e.key,
                          weeklyMs: e.value,
                          selectedDayMs: e.value.isNotEmpty ? e.value.last : 0,
                          selectedDate: _selected,
                          color: color,
                        ),
                      ),
                    ),
                  );
                },
                childCount: weeklyRanked.length,
              ),
            ),
          ),
      ],
    );
  }

  String _fmtDateLabel(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  // ── Detox body ────────────────────────────────────────────────────────────

  Widget _buildDetoxBody() {
    if (_detoxLoading) {
      return const Center(child: CircularProgressIndicator(color: NudgeTokens.purple));
    }
    if (_schedules.isEmpty) {
      return _DetoxEmptyState();
    }

    final anyActive = _schedules.any(_isScheduleActive);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        if (anyActive)
          _ActiveBlockingBanner(),
        const SizedBox(height: 4),
        ..._schedules.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildScheduleTile(e.value, e.key),
            )),
      ],
    );
  }

  static const _dayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  Widget _buildScheduleTile(DetoxSchedule s, int idx) {
    final isActive = _isScheduleActive(s);
    String fmtTime(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: () => _editSchedule(idx),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive
              ? NudgeTokens.green.withValues(alpha: 0.06)
              : NudgeTokens.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? NudgeTokens.green.withValues(alpha: 0.3)
                : NudgeTokens.border,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(
              isActive ? Icons.shield_rounded : Icons.block_rounded,
              color: isActive ? NudgeTokens.green : NudgeTokens.red,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(s.name,
                  style: GoogleFonts.outfit(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: NudgeTokens.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Active Now',
                    style: GoogleFonts.outfit(
                        color: NudgeTokens.green,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              )
            else
              IconButton(
                onPressed: () => _deleteSchedule(idx),
                icon: const Icon(Icons.delete_outline_rounded,
                    color: NudgeTokens.textLow, size: 18),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.access_time_rounded, color: NudgeTokens.textLow, size: 14),
            const SizedBox(width: 4),
            Text('${fmtTime(s.startTime)} – ${fmtTime(s.endTime)}',
                style: GoogleFonts.outfit(color: NudgeTokens.textMid, fontSize: 13)),
            const SizedBox(width: 16),
            ...List.generate(7, (d) {
              final active = s.days.contains(d + 1);
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(_dayLabels[d],
                    style: GoogleFonts.outfit(
                      color: active ? NudgeTokens.purple : NudgeTokens.textLow,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 12,
                    )),
              );
            }),
          ]),
          if (s.blockedApps.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${s.blockedApps.length} app${s.blockedApps.length > 1 ? 's' : ''} blocked',
              style: GoogleFonts.outfit(color: NudgeTokens.textLow, fontSize: 12),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Detox empty state ─────────────────────────────────────────────────────────

class _DetoxEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 100),
      child: Column(
        children: [
          const Text('🌿', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 20),
          Text(
            'Build your focus streak',
            style: GoogleFonts.outfit(
                fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Set up a blocking schedule and protect your\ntime every single day. Don\'t break the streak! 🔥',
            style: GoogleFonts.outfit(
                fontSize: 14, color: NudgeTokens.textMid, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          // Motivational tip cards
          _TipCard(
            emoji: '⏰',
            title: 'Night Mode',
            body: 'Block distractions from 10 PM – 7 AM and protect your sleep.',
          ),
          const SizedBox(height: 12),
          _TipCard(
            emoji: '📵',
            title: 'Deep Work',
            body: 'Schedule focus blocks during work hours — no doomscrolling.',
          ),
          const SizedBox(height: 12),
          _TipCard(
            emoji: '🏆',
            title: 'Stay Consistent',
            body: 'Every day you follow your schedule strengthens the habit.',
          ),
          const SizedBox(height: 32),
          Text(
            'Tap  +  below to create your first schedule',
            style: GoogleFonts.outfit(
                color: NudgeTokens.textLow, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String body;

  const _TipCard({required this.emoji, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NudgeTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: GoogleFonts.outfit(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 3),
            Text(body,
                style: GoogleFonts.outfit(
                    color: NudgeTokens.textMid, fontSize: 12, height: 1.5)),
          ]),
        ),
      ]),
    );
  }
}

// ── Active blocking banner ────────────────────────────────────────────────────

class _ActiveBlockingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: NudgeTokens.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NudgeTokens.green.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Text('🛡️', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Shield is active!',
                style: GoogleFonts.outfit(
                    color: NudgeTokens.green,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
            Text('A blocking schedule is running right now. Stay focused! 💪',
                style: GoogleFonts.outfit(
                    color: NudgeTokens.textMid, fontSize: 12, height: 1.4)),
          ]),
        ),
      ]),
    );
  }
}

// ── View chip toggle ──────────────────────────────────────────────────────────

class _ViewChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ViewChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? NudgeTokens.blue : NudgeTokens.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? NudgeTokens.blue
                  : NudgeTokens.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : NudgeTokens.textMid,
          ),
        ),
      ),
    );
  }
}

// ── Permission view ───────────────────────────────────────────────────────────

class _PermissionView extends StatelessWidget {
  final VoidCallback onGranted;
  const _PermissionView({required this.onGranted});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const Spacer(),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: NudgeTokens.blue.withValues(alpha: 0.12),
            ),
            child: const Icon(Icons.phone_android_rounded,
                color: NudgeTokens.blue, size: 36),
          ),
          const SizedBox(height: 24),
          Text('Screen Time',
              style: GoogleFonts.outfit(
                  fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 12),
          const Text(
            'Grant Usage Access so Nudge can show how much time you spend on each app.',
            textAlign: TextAlign.center,
            style: TextStyle(color: NudgeTokens.textMid, fontSize: 15, height: 1.6),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: NudgeTokens.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () async {
                await UsageService.requestPermission();
                final granted = await UsageService.checkPermission();
                if (granted) onGranted();
              },
              child: Text('Grant Access',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

// ── Date nav bar ──────────────────────────────────────────────────────────────

class _DateNavBar extends StatelessWidget {
  final DateTime selected;
  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const _DateNavBar({
    required this.selected,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final label =
        '${days[selected.weekday - 1]}, ${months[selected.month - 1]} ${selected.day}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: Row(children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left_rounded,
              color: NudgeTokens.textMid, size: 26),
        ),
        Expanded(
          child: Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
        if (!isToday)
          GestureDetector(
            onTap: onToday,
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: NudgeTokens.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('TODAY',
                  style: GoogleFonts.outfit(
                      color: NudgeTokens.blue,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8)),
            ),
          ),
        IconButton(
          onPressed: isToday ? null : onNext,
          icon: Icon(Icons.chevron_right_rounded,
              color: isToday
                  ? NudgeTokens.textLow.withValues(alpha: 0.25)
                  : NudgeTokens.textMid,
              size: 26),
        ),
      ]),
    );
  }
}

// ── Day hero card ─────────────────────────────────────────────────────────────

class _DayHeroCard extends StatelessWidget {
  final int totalMs;
  final bool isToday;
  final int trackedMs;

  const _DayHeroCard(
      {required this.totalMs, required this.isToday, this.trackedMs = 0});

  @override
  Widget build(BuildContext context) {
    final progress = (totalMs / _kGoalMs).clamp(0.0, 1.0);
    final pct = (progress * 100).toInt();
    final overGoal = totalMs > _kGoalMs;
    final color = overGoal ? NudgeTokens.red : NudgeTokens.blue;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(
              isToday ? 'TODAY' : 'SCREEN TIME',
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: NudgeTokens.textLow,
                  letterSpacing: 1.4),
            ),
            const Spacer(),
            Text('goal: 3h',
                style: const TextStyle(fontSize: 11, color: NudgeTokens.textLow)),
          ]),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                UsageService.formatDurationMs(totalMs),
                style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: overGoal ? NudgeTokens.red : Colors.white,
                    height: 1),
              ),
              const SizedBox(width: 8),
              Text('on screen',
                  style: const TextStyle(color: NudgeTokens.textLow, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: NudgeTokens.elevated,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            overGoal
                ? '$pct%  ·  ${UsageService.formatDurationMs(totalMs - _kGoalMs)} over goal'
                : '$pct%  ·  ${UsageService.formatDurationMs(_kGoalMs - totalMs)} remaining',
            style: const TextStyle(fontSize: 11, color: NudgeTokens.textLow),
          ),
          // Bottom stats
          const SizedBox(height: 14),
          Divider(height: 1, color: NudgeTokens.border),
          const SizedBox(height: 12),
          if (trackedMs > 0)
            Row(children: [
              Expanded(
                child: _statTile(
                    'TRACKED',
                    UsageService.formatDurationMs(trackedMs),
                    NudgeTokens.blue),
              ),
              Container(width: 1, height: 32, color: NudgeTokens.border),
              Expanded(
                child: _statTile(
                    'TOTAL',
                    UsageService.formatDurationMs(totalMs),
                    NudgeTokens.textMid),
              ),
            ])
          else
            Row(children: [
              Expanded(
                child: _statTile('STATUS',
                    overGoal ? 'Over limit 🔴' : 'On track 🟢',
                    overGoal ? NudgeTokens.red : NudgeTokens.green),
              ),
              Container(width: 1, height: 32, color: NudgeTokens.border),
              Expanded(
                child: _statTile('DAILY GOAL', '3h 0m', NudgeTokens.textMid),
              ),
            ]),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: NudgeTokens.textLow,
                letterSpacing: 1.1)),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// ── App calorie-style card (daily list) ───────────────────────────────────────

class _AppCalorieCard extends StatelessWidget {
  final String packageName;
  final int ms;
  final int totalMs;
  final int weekTotal;
  final int avgMs;
  final Color color;
  final VoidCallback onTap;

  const _AppCalorieCard({
    required this.packageName,
    required this.ms,
    required this.totalMs,
    required this.weekTotal,
    required this.avgMs,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final frac = totalMs > 0 ? (ms / totalMs).clamp(0.0, 1.0) : 0.0;
    final pct = (frac * 100).toInt();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: NudgeTokens.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: NudgeTokens.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(children: [
                FutureBuilder<Uint8List?>(
                  future: UsageService.resolveAppIcon(packageName),
                  builder: (ctx, snap) => Container(
                    width: 36, height: 36,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: color.withValues(alpha: 0.2)),
                    ),
                    child: snap.data != null
                        ? Image.memory(snap.data!, fit: BoxFit.contain)
                        : Icon(Icons.android_rounded,
                            size: 16, color: color.withValues(alpha: 0.7)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FutureBuilder<String>(
                    future: UsageService.resolveAppName(packageName),
                    builder: (ctx, snap) => Text(
                      snap.data ?? packageName.split('.').last,
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$pct%',
                      style: GoogleFonts.outfit(
                          fontSize: 12, fontWeight: FontWeight.w800, color: color)),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded,
                    color: NudgeTokens.textLow, size: 16),
              ]),
            ),
            // Big time
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    UsageService.formatDurationMs(ms),
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: color,
                        height: 1),
                  ),
                  const SizedBox(width: 6),
                  Text('today',
                      style: const TextStyle(
                          color: NudgeTokens.textLow, fontSize: 12)),
                ],
              ),
            ),
            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: frac,
                  minHeight: 7,
                  backgroundColor: NudgeTokens.elevated,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('$pct% of today\'s total usage',
                  style: const TextStyle(fontSize: 11, color: NudgeTokens.textLow)),
            ),
            // Bottom stats
            Divider(height: 1, color: NudgeTokens.border),
            IntrinsicHeight(
              child: Row(children: [
                Expanded(
                  child: _statTile('THIS WEEK', UsageService.formatDurationMs(weekTotal), color),
                ),
                VerticalDivider(width: 1, color: NudgeTokens.border),
                Expanded(
                  child: _statTile(
                      'AVG / DAY',
                      avgMs > 0 ? UsageService.formatDurationMs(avgMs) : '—',
                      NudgeTokens.textMid),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: NudgeTokens.textLow,
                letterSpacing: 1.1)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// ── Weekly bars card ──────────────────────────────────────────────────────────

class _WeeklyBarsCard extends StatelessWidget {
  final List<int> weeklyTotals;
  final int weekTotal;
  final int? selectedIndex;
  final ValueChanged<int> onTapDay;

  const _WeeklyBarsCard({
    required this.weeklyTotals,
    required this.weekTotal,
    required this.selectedIndex,
    required this.onTapDay,
  });

  @override
  Widget build(BuildContext context) {
    final maxMs = weeklyTotals.isEmpty ? 1 : weeklyTotals.reduce((a, b) => a > b ? a : b);
    final safeMax = maxMs < 1 ? 1 : maxMs;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('This Week',
              style: GoogleFonts.outfit(
                  fontSize: 13, fontWeight: FontWeight.w700, color: NudgeTokens.textMid)),
          const Spacer(),
          Text(UsageService.formatDurationMs(weekTotal),
              style: GoogleFonts.outfit(
                  fontSize: 12, fontWeight: FontWeight.w700, color: NudgeTokens.textLow)),
        ]),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (i) {
            final ms = i < weeklyTotals.length ? weeklyTotals[i] : 0;
            final frac = ms / safeMax;
            final isSelected = selectedIndex == i;
            final isToday = i == 6;
            final now = DateTime.now();
            final d = DateTime(now.year, now.month, now.day)
                .subtract(Duration(days: 6 - i));
            final label = ['M', 'T', 'W', 'T', 'F', 'S', 'S'][d.weekday - 1];

            final barColor = isSelected
                ? NudgeTokens.blue
                : isToday
                    ? NudgeTokens.blue.withValues(alpha: 0.55)
                    : NudgeTokens.blue.withValues(alpha: 0.2);

            return Expanded(
              child: GestureDetector(
                onTap: () => onTapDay(i),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (isSelected && ms > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        UsageService.formatDurationMs(ms),
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: NudgeTokens.blue),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Container(
                    height: (80 * frac + 4).clamp(4.0, 80.0),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(4),
                      border: isSelected
                          ? Border.all(color: NudgeTokens.blue)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected || isToday ? FontWeight.w900 : FontWeight.w600,
                        color: isSelected
                            ? NudgeTokens.blue
                            : isToday
                                ? NudgeTokens.textMid
                                : NudgeTokens.textLow,
                      )),
                ]),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text('Tap a bar to see that day\'s apps',
              style: GoogleFonts.outfit(
                  fontSize: 10, color: NudgeTokens.textLow, fontStyle: FontStyle.italic)),
        ),
      ]),
    );
  }
}

// ── Weekly stats strip ────────────────────────────────────────────────────────

class _WeeklyStatsStrip extends StatelessWidget {
  final List<int> weeklyTotals;
  final int weekTotal;

  const _WeeklyStatsStrip({required this.weeklyTotals, required this.weekTotal});

  @override
  Widget build(BuildContext context) {
    final daysWithData = weeklyTotals.where((v) => v > 0).length;
    final avgDay = daysWithData > 0 ? weekTotal ~/ daysWithData : 0;
    final peak = weeklyTotals.isEmpty ? 0 : weeklyTotals.reduce((a, b) => a > b ? a : b);

    return Container(
      decoration: BoxDecoration(
        color: NudgeTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: IntrinsicHeight(
        child: Row(children: [
          Expanded(child: _cell('WEEK TOTAL', UsageService.formatDurationMs(weekTotal), NudgeTokens.blue)),
          VerticalDivider(width: 1, color: NudgeTokens.border),
          Expanded(child: _cell('AVG / DAY', UsageService.formatDurationMs(avgDay), NudgeTokens.textMid)),
          VerticalDivider(width: 1, color: NudgeTokens.border),
          Expanded(child: _cell('PEAK DAY', UsageService.formatDurationMs(peak), NudgeTokens.amber)),
        ]),
      ),
    );
  }

  Widget _cell(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: NudgeTokens.textLow,
                letterSpacing: 1.1)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// ── Weekly app row ────────────────────────────────────────────────────────────

class _WeeklyAppRow extends StatelessWidget {
  final String packageName;
  final List<int> weeklyMs;
  final int weekTotal;
  final Color color;
  final VoidCallback onTap;

  const _WeeklyAppRow({
    required this.packageName,
    required this.weeklyMs,
    required this.weekTotal,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final maxMs = weeklyMs.isEmpty ? 1 : weeklyMs.reduce((a, b) => a > b ? a : b);
    final safeMax = maxMs < 1 ? 1 : maxMs;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NudgeTokens.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NudgeTokens.border),
        ),
        child: Row(children: [
          FutureBuilder<Uint8List?>(
            future: UsageService.resolveAppIcon(packageName),
            builder: (ctx, snap) => Container(
              width: 38, height: 38,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: snap.data != null
                  ? Image.memory(snap.data!, fit: BoxFit.contain)
                  : Icon(Icons.android_rounded,
                      size: 16, color: color.withValues(alpha: 0.7)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FutureBuilder<String>(
                future: UsageService.resolveAppName(packageName),
                builder: (ctx, snap) => Text(
                  snap.data ?? packageName.split('.').last,
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              // Mini 7-day bars
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final ms = i < weeklyMs.length ? weeklyMs[i] : 0;
                  final frac = ms / safeMax;
                  return Expanded(
                    child: Container(
                      height: (22 * frac + 2).clamp(2.0, 22.0),
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        color: i == 6 ? color : color.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(UsageService.formatDurationMs(weekTotal),
                style: GoogleFonts.outfit(
                    fontSize: 14, fontWeight: FontWeight.w800, color: color)),
            Text('this week',
                style: const TextStyle(fontSize: 10, color: NudgeTokens.textLow)),
          ]),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow, size: 16),
        ]),
      ),
    );
  }
}

// ── Edit schedule sheet ───────────────────────────────────────────────────────

class _EditScheduleSheet extends StatefulWidget {
  final DetoxSchedule? schedule;
  const _EditScheduleSheet({this.schedule});

  @override
  State<_EditScheduleSheet> createState() => _EditScheduleSheetState();
}

class _EditScheduleSheetState extends State<_EditScheduleSheet> {
  late TextEditingController _nameCtrl;
  TimeOfDay _start = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 7, minute: 0);
  List<int> _days = [1, 2, 3, 4, 5, 6, 7];
  List<String> _blockedApps = [];
  List<AppInfo> _installedApps = [];
  bool _appsLoading = false;

  static const _dayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  @override
  void initState() {
    super.initState();
    final s = widget.schedule;
    _nameCtrl = TextEditingController(text: s?.name ?? 'Night Mode');
    if (s != null) {
      _start = s.startTime;
      _end = s.endTime;
      _days = List.from(s.days);
      _blockedApps = List.from(s.blockedApps);
    }
    _loadApps();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    setState(() => _appsLoading = true);
    try {
      final all = await InstalledApps.getInstalledApps(
          excludeSystemApps: false, withIcon: false);
      final apps = all
          .where((a) => a.name.isNotEmpty && a.packageName.isNotEmpty)
          .toList();
      apps.sort((a, b) {
        final aD = _doomApps.contains(a.packageName) ? 0 : 1;
        final bD = _doomApps.contains(b.packageName) ? 0 : 1;
        if (aD != bD) return aD - bD;
        return a.name.compareTo(b.name);
      });
      if (mounted) {
        setState(() {
          _installedApps = apps;
          _appsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _appsLoading = false);
    }
  }

  void _showAppPicker() {
    String search = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NudgeTokens.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          builder: (_, ctrl) {
            final filtered = search.isEmpty
                ? _installedApps
                : _installedApps
                    .where((a) =>
                        a.name.toLowerCase().contains(search.toLowerCase()) ||
                        a.packageName.toLowerCase().contains(search.toLowerCase()))
                    .toList();
            return Column(children: [
              const SizedBox(height: 12),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: NudgeTokens.textLow,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(children: [
                  Text('Block Apps',
                      style: GoogleFonts.outfit(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                  const Spacer(),
                  Text('${_blockedApps.length} selected',
                      style: GoogleFonts.outfit(
                          color: NudgeTokens.textMid, fontSize: 13)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (v) => setSt(() => search = v),
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search apps…',
                    hintStyle: GoogleFonts.outfit(
                        color: NudgeTokens.textLow, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: NudgeTokens.textLow, size: 20),
                    suffixIcon: search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                color: NudgeTokens.textLow, size: 18),
                            onPressed: () => setSt(() => search = ''),
                          )
                        : null,
                    filled: true,
                    fillColor: NudgeTokens.elevated,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              if (search.isEmpty &&
                  _installedApps.any((a) => _doomApps.contains(a.packageName)))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: NudgeTokens.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: NudgeTokens.red.withValues(alpha: 0.20)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: NudgeTokens.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Doomscrolling apps detected — recommended to block',
                          style: GoogleFonts.outfit(
                              color: NudgeTokens.textMid, fontSize: 12),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          final doom = _installedApps
                              .where(
                                  (a) => _doomApps.contains(a.packageName))
                              .map((a) => a.packageName)
                              .toList();
                          setSt(() {
                            for (final pkg in doom) {
                              if (!_blockedApps.contains(pkg)) {
                                _blockedApps.add(pkg);
                              }
                            }
                          });
                          setState(() {});
                        },
                        child: Text('Add all',
                            style: GoogleFonts.outfit(
                                color: NudgeTokens.red,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ),
                    ]),
                  ),
                ),
              Expanded(
                child: _appsLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: ctrl,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final app = filtered[i];
                          final pkg = app.packageName;
                          final selected = _blockedApps.contains(pkg);
                          final isDoom = _doomApps.contains(pkg);
                          return CheckboxListTile(
                            value: selected,
                            onChanged: (v) {
                              setSt(() {
                                if (v == true) {
                                  _blockedApps.add(pkg);
                                } else {
                                  _blockedApps.remove(pkg);
                                }
                              });
                              setState(() {});
                            },
                            title: Text(app.name,
                                style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14)),
                            subtitle: isDoom
                                ? Text('Doomscrolling',
                                    style: GoogleFonts.outfit(
                                        color: NudgeTokens.red, fontSize: 11))
                                : null,
                            secondary: isDoom
                                ? const Icon(Icons.warning_amber_rounded,
                                    color: NudgeTokens.red, size: 18)
                                : null,
                            activeColor: NudgeTokens.purple,
                            checkColor: Colors.white,
                            tileColor: Colors.transparent,
                          );
                        },
                      ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NudgeTokens.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Done',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked != null) {
      setState(() => isStart ? _start = picked : _end = picked);
    }
  }

  void _save() {
    Navigator.pop(
      context,
      DetoxSchedule(
        id: widget.schedule?.id ?? const Uuid().v4(),
        name: _nameCtrl.text.trim().isEmpty ? 'Schedule' : _nameCtrl.text.trim(),
        startTime: _start,
        endTime: _end,
        days: _days,
        blockedApps: _blockedApps,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: NudgeTokens.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: NudgeTokens.textLow,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Blocking Schedule',
                style: GoogleFonts.outfit(
                    fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              style: GoogleFonts.outfit(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Label',
                labelStyle: GoogleFonts.outfit(color: NudgeTokens.textLow),
                filled: true,
                fillColor: NudgeTokens.elevated,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _timeTile('Starts', _start, true)),
              const SizedBox(width: 12),
              Expanded(child: _timeTile('Ends', _end, false)),
            ]),
            const SizedBox(height: 16),
            Text('Days',
                style: GoogleFonts.outfit(
                    color: NudgeTokens.textMid,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final day = i + 1;
                final active = _days.contains(day);
                return GestureDetector(
                  onTap: () => setState(
                      () => active ? _days.remove(day) : _days.add(day)),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: active ? NudgeTokens.purple : NudgeTokens.elevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(_dayLabels[i],
                        style: GoogleFonts.outfit(
                            color: active ? Colors.white : NudgeTokens.textLow,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Blocked Apps',
                      style: GoogleFonts.outfit(
                          color: NudgeTokens.textMid,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  if (_blockedApps.isNotEmpty)
                    Text('${_blockedApps.length} selected',
                        style: GoogleFonts.outfit(
                            color: NudgeTokens.textLow, fontSize: 11)),
                ]),
                TextButton.icon(
                  onPressed: _showAppPicker,
                  icon: const Icon(Icons.apps_rounded, size: 16),
                  label: Text(_appsLoading ? 'Loading…' : 'Choose'),
                  style:
                      TextButton.styleFrom(foregroundColor: NudgeTokens.purple),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: NudgeTokens.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text('Save Schedule',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeTile(String label, TimeOfDay time, bool isStart) {
    return GestureDetector(
      onTap: () => _pickTime(isStart),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: NudgeTokens.elevated, borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Text(label,
              style: GoogleFonts.outfit(color: NudgeTokens.textLow, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
            style: GoogleFonts.outfit(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ]),
      ),
    );
  }
}

// ── App tracker selection sheet ───────────────────────────────────────────────

class _AppTrackerSheet extends StatefulWidget {
  final List<String> selected;
  final Future<void> Function(List<String>) onSave;

  const _AppTrackerSheet({required this.selected, required this.onSave});

  @override
  State<_AppTrackerSheet> createState() => _AppTrackerSheetState();
}

class _AppTrackerSheetState extends State<_AppTrackerSheet> {
  late List<String> _selected;
  List<AppInfo> _apps = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selected);
    _loadApps();
  }

  Future<void> _loadApps() async {
    try {
      final all = await InstalledApps.getInstalledApps(
          excludeSystemApps: true, withIcon: false);
      final apps = all
          .where((a) => a.name.isNotEmpty && a.packageName.isNotEmpty)
          .toList()
        ..sort((a, b) {
          final aD = _doomApps.contains(a.packageName) ? 0 : 1;
          final bD = _doomApps.contains(b.packageName) ? 0 : 1;
          if (aD != bD) return aD - bD;
          return a.name.compareTo(b.name);
        });
      if (mounted) setState(() { _apps = apps; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty
        ? _apps
        : _apps
            .where((a) =>
                a.name.toLowerCase().contains(_search.toLowerCase()) ||
                a.packageName.toLowerCase().contains(_search.toLowerCase()))
            .toList();

    return Container(
      decoration: const BoxDecoration(
        color: NudgeTokens.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Column(children: [
          const SizedBox(height: 12),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: NudgeTokens.textLow,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              Text('Track Apps',
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18)),
              const Spacer(),
              Text('${_selected.length} selected',
                  style: GoogleFonts.outfit(
                      color: NudgeTokens.textMid, fontSize: 13)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search apps…',
                hintStyle:
                    GoogleFonts.outfit(color: NudgeTokens.textLow, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: NudgeTokens.textLow, size: 20),
                filled: true,
                fillColor: NudgeTokens.elevated,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: NudgeTokens.blue))
                : ListView.builder(
                    controller: ctrl,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final app = filtered[i];
                      final pkg = app.packageName;
                      final isSelected = _selected.contains(pkg);
                      final isDoom = _doomApps.contains(pkg);
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (v) => setState(() {
                          if (v == true) _selected.add(pkg);
                          else _selected.remove(pkg);
                        }),
                        title: Text(app.name,
                            style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 14)),
                        subtitle: isDoom
                            ? Text('Doomscrolling',
                                style: GoogleFonts.outfit(
                                    color: NudgeTokens.red, fontSize: 11))
                            : null,
                        secondary: isDoom
                            ? const Icon(Icons.warning_amber_rounded,
                                color: NudgeTokens.red, size: 18)
                            : null,
                        activeColor: NudgeTokens.blue,
                        checkColor: Colors.white,
                        tileColor: Colors.transparent,
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await widget.onSave(_selected);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NudgeTokens.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text('Save',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// App Detail Screen
// ═══════════════════════════════════════════════════════════════════════════════

class AppDetailScreen extends StatelessWidget {
  final String packageName;
  final List<int> weeklyMs; // idx 0 = 6 days ago, idx 6 = today
  final int selectedDayMs;
  final DateTime selectedDate;
  final Color color;

  const AppDetailScreen({
    super.key,
    required this.packageName,
    required this.weeklyMs,
    required this.selectedDayMs,
    required this.selectedDate,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final maxMs = weeklyMs.isEmpty ? 1 : weeklyMs.reduce((a, b) => a > b ? a : b);
    final safeMax = maxMs < 1 ? 1 : maxMs;
    final weekTotal = weeklyMs.fold(0, (a, b) => a + b);
    final daysWithData = weeklyMs.where((v) => v > 0).length;
    final avgMs = daysWithData > 0 ? weekTotal ~/ daysWithData : 0;
    final progress = (selectedDayMs / _kGoalMs).clamp(0.0, 1.0);
    final pct = (progress * 100).toInt();
    final overGoal = selectedDayMs > _kGoalMs;

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;
    final dateLabel = isToday
        ? 'Today'
        : '${days[selectedDate.weekday - 1]}, ${months[selectedDate.month - 1]} ${selectedDate.day}';

    return Scaffold(
      backgroundColor: NudgeTokens.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: NudgeTokens.bg,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
            title: FutureBuilder<String>(
              future: UsageService.resolveAppName(packageName),
              builder: (ctx, snap) => Text(
                snap.data ?? packageName.split('.').last,
                style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
            actions: [
              FutureBuilder<Uint8List?>(
                future: UsageService.resolveAppIcon(packageName),
                builder: (ctx, snap) => Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: snap.data != null
                      ? Image.memory(snap.data!, width: 28, height: 28)
                      : const Icon(Icons.android_rounded,
                          color: NudgeTokens.textMid, size: 26),
                ),
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Usage on selected day ──────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: NudgeTokens.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: NudgeTokens.border),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(dateLabel.toUpperCase(),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: color,
                              letterSpacing: 1.4)),
                      const Spacer(),
                      Text('goal: 3h',
                          style: const TextStyle(
                              fontSize: 11, color: NudgeTokens.textLow)),
                    ]),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          UsageService.formatDurationMs(selectedDayMs),
                          style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              color: overGoal ? NudgeTokens.red : Colors.white,
                              height: 1),
                        ),
                        const SizedBox(width: 8),
                        const Text('on screen',
                            style: TextStyle(
                                color: NudgeTokens.textLow, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: NudgeTokens.elevated,
                        valueColor: AlwaysStoppedAnimation(
                            overGoal ? NudgeTokens.red : color),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      overGoal
                          ? '$pct%  ·  ${UsageService.formatDurationMs(selectedDayMs - _kGoalMs)} over 3h'
                          : '$pct% of 3h  ·  ${UsageService.formatDurationMs(_kGoalMs - selectedDayMs)} remaining',
                      style: const TextStyle(fontSize: 11, color: NudgeTokens.textLow),
                    ),
                    const SizedBox(height: 14),
                    Divider(height: 1, color: NudgeTokens.border),
                    const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(children: [
                        Expanded(
                          child: _statCell('THIS WEEK',
                              UsageService.formatDurationMs(weekTotal), color),
                        ),
                        VerticalDivider(width: 1, color: NudgeTokens.border),
                        Expanded(
                          child: _statCell('AVG / DAY',
                              avgMs > 0 ? UsageService.formatDurationMs(avgMs) : '—',
                              NudgeTokens.textMid),
                        ),
                        VerticalDivider(width: 1, color: NudgeTokens.border),
                        Expanded(
                          child: _statCell('PEAK DAY',
                              UsageService.formatDurationMs(safeMax), NudgeTokens.amber),
                        ),
                      ]),
                    ),
                  ]),
                ),

                const SizedBox(height: 20),

                // ── 7-day chart ──────────────────────────────────────────
                Text('LAST 7 DAYS',
                    style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: NudgeTokens.textLow,
                        letterSpacing: 1.5)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: NudgeTokens.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: NudgeTokens.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (i) {
                      final ms = i < weeklyMs.length ? weeklyMs[i] : 0;
                      final frac = ms / safeMax;
                      final isToday_ = i == 6;
                      final d = today.subtract(Duration(days: 6 - i));
                      final label = ['M', 'T', 'W', 'T', 'F', 'S', 'S'][d.weekday - 1];
                      return Expanded(
                        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                          if (ms > 0)
                            Text(
                              UsageService.formatDurationMs(ms),
                              style: TextStyle(
                                  fontSize: 8,
                                  color: isToday_ ? color : color.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w700),
                              textAlign: TextAlign.center,
                            ),
                          const SizedBox(height: 4),
                          Container(
                            height: (80 * frac + 4).clamp(4.0, 80.0),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: isToday_ ? color : color.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isToday_ ? color : NudgeTokens.textLow,
                                  fontWeight: isToday_
                                      ? FontWeight.w900
                                      : FontWeight.w600)),
                        ]),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Daily breakdown ───────────────────────────────────────
                Text('DAILY BREAKDOWN',
                    style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: NudgeTokens.textLow,
                        letterSpacing: 1.5)),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: NudgeTokens.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: NudgeTokens.border),
                  ),
                  child: Column(
                    children: List.generate(7, (i) {
                      final dayIdx = 6 - i; // most recent first
                      final ms = dayIdx < weeklyMs.length ? weeklyMs[dayIdx] : 0;
                      final d = today.subtract(Duration(days: i));
                      final isToday_ = i == 0;
                      final dayLabel = isToday_
                          ? 'Today'
                          : '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
                      final frac = ms / safeMax;
                      return Column(children: [
                        if (i > 0) Divider(height: 1, color: NudgeTokens.border),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(children: [
                            SizedBox(
                              width: 130,
                              child: Text(dayLabel,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: isToday_ ? color : NudgeTokens.textMid,
                                      fontWeight: isToday_
                                          ? FontWeight.w700
                                          : FontWeight.w500)),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: frac,
                                  minHeight: 6,
                                  backgroundColor: NudgeTokens.elevated,
                                  valueColor: AlwaysStoppedAnimation(
                                      isToday_
                                          ? color
                                          : color.withValues(alpha: 0.4)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 52,
                              child: Text(
                                ms > 0 ? UsageService.formatDurationMs(ms) : '—',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: ms > 0 ? color : NudgeTokens.textLow),
                              ),
                            ),
                          ]),
                        ),
                      ]);
                    }),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCell(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: NudgeTokens.textLow,
                letterSpacing: 1.1)),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}
