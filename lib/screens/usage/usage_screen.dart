import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:usage_stats/usage_stats.dart';
import '../../app.dart' show NudgeTokens;
import '../../utils/usage_service.dart';
import '../../storage.dart';

const _kGoalMs = 3 * 60 * 60 * 1000; // 3 hours in milliseconds

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

class UsageScreen extends StatefulWidget {
  const UsageScreen({super.key});

  @override
  State<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends State<UsageScreen> {
  List<UsageInfo> _usage = [];
  List<int> _weeklyMs = List<int>.filled(7, 0);
  bool _loading = true;
  bool _hasPermission = false;
  String _totalTime = '0m';
  int _totalMs = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _hasPermission = await UsageService.checkPermission();
    if (_hasPermission) await _fetch();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetch() async {
    final trackedList = (AppStorage.settingsBox.get(
          'tracked_apps',
          defaultValue: <String>[],
        ) as List)
        .cast<String>();

    final usage = await UsageService.fetchUsageStats(trackedApps: trackedList);

    // Build daily totals for the last 7 days
    final weeklyMs = List<int>.filled(7, 0);
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      try {
        final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
        final nextDay = day.add(const Duration(days: 1));
        final stats = await UsageStats.queryUsageStats(day, nextDay);
        int dayMs = 0;
        for (final s in stats) {
          final t = int.tryParse(s.totalTimeInForeground ?? '0') ?? 0;
          if (t <= 0) continue;
          if (trackedList.isEmpty || trackedList.contains(s.packageName)) dayMs += t;
        }
        weeklyMs[6 - i] = dayMs;
      } catch (_) {}
    }

    int ms = 0;
    for (final info in usage) {
      ms += int.tryParse(info.totalTimeInForeground ?? '0') ?? 0;
    }

    if (mounted) {
      setState(() {
        _usage = usage;
        _totalMs = ms;
        _weeklyMs = weeklyMs;
        _totalTime = UsageService.formatDuration(ms.toString());
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: NudgeTokens.bg,
        body: Center(child: CircularProgressIndicator(color: NudgeTokens.blue)),
      );
    }

    if (!_hasPermission) {
      return _PermissionScreen(onGranted: () {
        setState(() {
          _loading = true;
          _hasPermission = true;
        });
        _fetch();
      });
    }

    return Scaffold(
      backgroundColor: NudgeTokens.bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _HeroHeader(totalTime: _totalTime, totalMs: _totalMs),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: _WeeklyBars(weeklyMs: _weeklyMs),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                "Today's Apps".toUpperCase(),
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: NudgeTokens.textLow,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          if (_usage.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.app_shortcut_rounded,
                        color: NudgeTokens.textLow, size: 40),
                    SizedBox(height: 12),
                    Text(
                      'No apps tracked today.\nManage tracked apps in Settings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: NudgeTokens.textLow, height: 1.6),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _AppUsageTile(
                    info: _usage[index],
                    totalMs: _totalMs,
                    color: _kAppColors[index % _kAppColors.length],
                  ),
                  childCount: _usage.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Permission Screen ──────────────────────────────────────────────────────────

class _PermissionScreen extends StatelessWidget {
  final VoidCallback onGranted;

  const _PermissionScreen({required this.onGranted});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NudgeTokens.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: NudgeTokens.blue.withValues(alpha: 0.12),
                ),
                child: const Icon(Icons.phone_android_rounded,
                    color: NudgeTokens.blue, size: 36),
              ),
              const SizedBox(height: 24),
              Text(
                'Screen Time',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Grant Usage Access so Nudge can show how much time you spend on each app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: NudgeTokens.textMid,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: NudgeTokens.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    await UsageService.requestPermission();
                    final granted = await UsageService.checkPermission();
                    if (granted) onGranted();
                  },
                  child: Text(
                    'Grant Access',
                    style: GoogleFonts.outfit(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hero Header ────────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final String totalTime;
  final int totalMs;

  const _HeroHeader({required this.totalTime, required this.totalMs});

  @override
  Widget build(BuildContext context) {
    final progress = (totalMs / _kGoalMs).clamp(0.0, 1.0);
    final goalPercent = (progress * 100).round();
    final now = DateTime.now();
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dateLabel = '${dayNames[now.weekday - 1]}, ${monthNames[now.month - 1]} ${now.day}';
    final overGoal = totalMs > _kGoalMs;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 60, 20, 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            NudgeTokens.blue.withValues(alpha: 0.18),
            NudgeTokens.bg,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NudgeTokens.blue.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: NudgeTokens.blue.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_android_rounded,
                  color: NudgeTokens.blue, size: 16),
              const SizedBox(width: 6),
              Text(
                'Screen Time',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: NudgeTokens.blue,
                ),
              ),
              const Spacer(),
              Text(
                dateLabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: NudgeTokens.textLow,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            totalTime,
            style: GoogleFonts.outfit(
              fontSize: 52,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$goalPercent% of 3h daily goal',
            style: TextStyle(
              fontSize: 13,
              color: overGoal
                  ? NudgeTokens.red.withValues(alpha: 0.9)
                  : NudgeTokens.textMid,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(
                overGoal ? NudgeTokens.red : NudgeTokens.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Weekly Bar Chart ──────────────────────────────────────────────────────────

class _WeeklyBars extends StatelessWidget {
  final List<int> weeklyMs;

  const _WeeklyBars({required this.weeklyMs});

  @override
  Widget build(BuildContext context) {
    final maxMs = weeklyMs.isEmpty ? 1 : weeklyMs.reduce((a, b) => a > b ? a : b);
    final safeMax = maxMs < 1 ? 1 : maxMs;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NudgeTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This Week',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: NudgeTokens.textMid,
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 100),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final ms = i < weeklyMs.length ? weeklyMs[i] : 0;
                final frac = ms / safeMax;
                final isToday = i == 6;

                final daysAgo = 6 - i;
                final dayDate =
                    DateTime.now().subtract(Duration(days: daysAgo));
                final label = ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                    [dayDate.weekday - 1];

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: (80 * frac + 4).clamp(4.0, 80.0),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: isToday
                              ? NudgeTokens.blue
                              : NudgeTokens.blue.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isToday ? FontWeight.w900 : FontWeight.w600,
                          color: isToday
                              ? NudgeTokens.blue
                              : NudgeTokens.textLow,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ── App Tile ──────────────────────────────────────────────────────────────────

class _AppUsageTile extends StatelessWidget {
  final UsageInfo info;
  final int totalMs;
  final Color color;

  const _AppUsageTile({
    required this.info,
    required this.totalMs,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pkg = info.packageName ?? '';
    final timeMs = int.tryParse(info.totalTimeInForeground ?? '0') ?? 0;
    final frac = totalMs > 0 ? timeMs / totalMs : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                FutureBuilder<Uint8List?>(
                  future: UsageService.resolveAppIcon(pkg),
                  builder: (context, snapshot) {
                    return Container(
                      width: 42,
                      height: 42,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withValues(alpha: 0.18)),
                      ),
                      child: snapshot.data != null
                          ? Image.memory(snapshot.data!, fit: BoxFit.contain)
                          : Icon(Icons.android_rounded,
                              size: 20, color: color.withValues(alpha: 0.6)),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<String>(
                        future: UsageService.resolveAppName(pkg),
                        builder: (context, snapshot) {
                          return Text(
                            snapshot.data ?? pkg.split('.').last,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                      const SizedBox(height: 2),
                      Text(
                        UsageService.formatDuration(timeMs.toString()),
                        style: TextStyle(
                          color: color.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(frac * 100).toInt()}%',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 5,
                backgroundColor: color.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
