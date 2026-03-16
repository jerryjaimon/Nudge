// lib/utils/streak_service.dart
//
// Tracks which days the user logged at least one piece of data.
// Any module (gym, food, water, habits…) calls [markToday] when it saves data.
// The home screen computes the current streak from the log and shows it.

import '../storage.dart';

class StreakService {
  static const _kLogKey = 'streak_activity_log';

  // ── Write ───────────────────────────────────────────────────────────────────

  /// Marks today as an active day (idempotent).
  static void markToday() {
    final today = _dateKey(DateTime.now());
    final log = _getLogList();
    if (!log.contains(today)) {
      log.add(today);
      // Keep only the last 400 days to avoid unbounded growth
      if (log.length > 400) log.removeAt(0);
      AppStorage.settingsBox.put(_kLogKey, log);
    }
  }

  // ── Read ────────────────────────────────────────────────────────────────────

  /// Whether today has already been marked.
  static bool get isTodayMarked {
    return _getLogSet().contains(_dateKey(DateTime.now()));
  }

  /// Current streak in days.
  /// Counts consecutive days going backwards from today.
  /// If today is not yet marked, counting starts from yesterday
  /// (so the streak doesn't break just because you haven't opened the app yet today).
  static int get currentStreak {
    final log = _getLogSet();
    final today = DateTime.now();
    // Determine starting point
    DateTime check = log.contains(_dateKey(today))
        ? today
        : today.subtract(const Duration(days: 1));

    int streak = 0;
    while (log.contains(_dateKey(check))) {
      streak++;
      check = check.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Longest streak ever recorded.
  static int get longestStreak {
    final log = _getLogList()
      ..sort(); // ascending date strings sort correctly
    if (log.isEmpty) return 0;

    int best = 0;
    int run = 1;
    for (int i = 1; i < log.length; i++) {
      final prev = DateTime.parse(log[i - 1]);
      final curr = DateTime.parse(log[i]);
      if (curr.difference(prev).inDays == 1) {
        run++;
      } else {
        if (run > best) best = run;
        run = 1;
      }
    }
    return run > best ? run : best;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static List<String> _getLogList() {
    return (AppStorage.settingsBox.get(_kLogKey, defaultValue: <dynamic>[]) as List)
        .cast<String>();
  }

  static Set<String> _getLogSet() => Set<String>.from(_getLogList());

  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
