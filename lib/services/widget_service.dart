// lib/services/widget_service.dart
//
// Computes summary stats from Hive and pushes them to Android home screen
// widgets via the home_widget package SharedPreferences bridge.
// Call WidgetService.updateAll() after any significant data change.

import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import '../storage.dart';
import 'package:usage_stats/usage_stats.dart';
import '../utils/usage_service.dart';
import '../utils/usage_service.dart';

class WidgetService {
  static Future<void> updateAll() async {
    await Future.wait([
      _updateGym(),
      _updateFinance(),
      _updateHabits(),
      _updatePomodoro(),
      _updateFood(),
      _updateBackup(),
      _updateDayTracker(),
      _updateScreenTime(),
    ]);
  }

  // ── Gym ─────────────────────────────────────────────────────────────────────

  static Future<void> _updateGym() async {
    try {
      final workouts = (AppStorage.gymBox.get('workouts', defaultValue: <dynamic>[]) as List);
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      // Build set of workout dates
      final dates = <DateTime>{};
      int thisWeek = 0;
      final weekStart = todayDate.subtract(Duration(days: todayDate.weekday - 1));
      for (final w in workouts) {
        try {
          final d = DateTime.parse((w as Map)['date'] as String);
          final day = DateTime(d.year, d.month, d.day);
          dates.add(day);
          if (!day.isBefore(weekStart)) thisWeek++;
        } catch (_) {}
      }

      // Streak (consecutive days ending today or yesterday)
      int streak = 0;
      var check = todayDate;
      // Allow today OR yesterday as streak start
      if (!dates.contains(check)) check = check.subtract(const Duration(days: 1));
      while (dates.contains(check)) {
        streak++;
        check = check.subtract(const Duration(days: 1));
      }

      // Last workout label
      String last = '—';
      if (dates.isNotEmpty) {
        final latest = dates.reduce((a, b) => a.isAfter(b) ? a : b);
        final diff = todayDate.difference(latest).inDays;
        if (diff == 0) last = 'Today';
        else if (diff == 1) last = 'Yesterday';
        else last = '${diff}d ago';
      }

      await HomeWidget.saveWidgetData<String>('gym_streak', '$streak');
      await HomeWidget.saveWidgetData<String>('gym_last', last);
      await HomeWidget.saveWidgetData<String>(
          'gym_week', '$thisWeek session${thisWeek == 1 ? '' : 's'} this week');
      await HomeWidget.updateWidget(androidName: 'GymWidget');
    } catch (_) {}
  }

  // ── Finance ──────────────────────────────────────────────────────────────────

  static Future<void> _updateFinance() async {
    try {
      final expenses = (AppStorage.financeBox.get('expenses', defaultValue: <dynamic>[]) as List);
      final budgetMap = (AppStorage.financeBox.get('budgets', defaultValue: <String, dynamic>{}) as Map);
      final now = DateTime.now();

      double spent = 0;
      for (final e in expenses) {
        try {
          final em = e as Map;
          final date = DateTime.parse(em['date'] as String);
          if (date.year == now.year && date.month == now.month) {
            spent += (em['amount'] as num?)?.toDouble() ?? 0;
          }
        } catch (_) {}
      }

      // Budget: try monthly key first, then fallback to AppStorage setting
      final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      double budget = (budgetMap[monthKey] as num?)?.toDouble() ??
          (budgetMap['monthly'] as num?)?.toDouble() ??
          AppStorage.financeBudget;

      final percent = budget > 0 ? ((spent / budget) * 100).round().clamp(0, 100) : 0;
      final remaining = budget > 0
          ? '${(budget - spent).abs().toStringAsFixed(0)} ${spent > budget ? 'over budget' : 'remaining'}'
          : 'No budget set';

      await HomeWidget.saveWidgetData<String>('finance_spent', spent.toStringAsFixed(0));
      await HomeWidget.saveWidgetData<String>('finance_budget_label', '/ ${budget.toStringAsFixed(0)}');
      await HomeWidget.saveWidgetData<int>('finance_percent', percent as int);
      await HomeWidget.saveWidgetData<String>('finance_remaining', remaining);
      await HomeWidget.updateWidget(androidName: 'FinanceWidget');
    } catch (_) {}
  }

  // ── Habits ───────────────────────────────────────────────────────────────────

  static Future<void> _updateHabits() async {
    try {
      final habits = (AppStorage.protectedBox.get('habits', defaultValue: <dynamic>[]) as List);
      final logs = (AppStorage.protectedBox.get('habit_logs', defaultValue: <dynamic, dynamic>{}) as Map);
      final now = DateTime.now();
      final todayKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      int done = 0;
      final total = habits.length;
      for (final h in habits) {
        try {
          final id = (h as Map)['id'] as String?;
          if (id == null) continue;
          final habitLogs = logs[id] as Map? ?? {};
          final count = (habitLogs[todayKey] as num?)?.toInt() ?? 0;
          if (count > 0) done++;
        } catch (_) {}
      }

      final percent = total > 0 ? ((done / total) * 100).round() : 0;

      await HomeWidget.saveWidgetData<String>('habits_done', '$done');
      await HomeWidget.saveWidgetData<String>('habits_total', '/ $total habit${total == 1 ? '' : 's'}');
      await HomeWidget.saveWidgetData<int>('habits_percent', percent);
      await HomeWidget.saveWidgetData<String>('habits_label',
          done == total && total > 0 ? 'all done today!' : 'completed today');
      await HomeWidget.updateWidget(androidName: 'HabitsWidget');
    } catch (_) {}
  }

  // ── Pomodoro ─────────────────────────────────────────────────────────────────

  static Future<void> _updatePomodoro() async {
    try {
      final logs = (AppStorage.pomodoroBox.get('logs', defaultValue: <dynamic>[]) as List);
      final now = DateTime.now();
      final todayPrefix =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      int totalMin = 0;
      int sessions = 0;
      for (final log in logs) {
        try {
          final lm = log as Map;
          final dateStr = (lm['date'] ?? lm['start'] ?? lm['timestamp'] ?? '') as String;
          if (dateStr.startsWith(todayPrefix)) {
            totalMin += ((lm['duration_min'] ?? lm['minutes'] ?? 0) as num).toInt();
            sessions++;
          }
        } catch (_) {}
      }

      final timeLabel = totalMin >= 60
          ? '${totalMin ~/ 60}h ${totalMin % 60}m'
          : '${totalMin}m';

      await HomeWidget.saveWidgetData<String>('pomo_time', timeLabel);
      await HomeWidget.saveWidgetData<String>(
          'pomo_sessions', '$sessions session${sessions == 1 ? '' : 's'}');
      await HomeWidget.updateWidget(androidName: 'PomodoroWidget');
    } catch (_) {}
  }

  // ── Backup ───────────────────────────────────────────────────────────────────

  static Future<void> _updateBackup() async {
    try {
      final lastAt = AppStorage.settingsBox.get('last_backup_at') as String?;
      final autoEnabled =
          AppStorage.settingsBox.get('auto_backup_enabled', defaultValue: false) as bool;

      String lastLabel = 'Never';
      String statusLabel = 'Not backed up';

      if (lastAt != null) {
        final dt = DateTime.tryParse(lastAt);
        if (dt != null) {
          final diff = DateTime.now().difference(dt);
          if (diff.inMinutes < 1) {
            lastLabel = 'Just now';
          } else if (diff.inHours < 1) {
            lastLabel = '${diff.inMinutes}m ago';
          } else if (diff.inDays < 1) {
            lastLabel = '${diff.inHours}h ago';
          } else {
            lastLabel = '${diff.inDays}d ago';
          }
          statusLabel = diff.inHours < 24 ? 'Backed up today' : 'Backup overdue';
        }
      }

      await HomeWidget.saveWidgetData<String>('backup_last', lastLabel);
      await HomeWidget.saveWidgetData<String>('backup_status', statusLabel);
      await HomeWidget.saveWidgetData<String>('backup_auto', autoEnabled ? 'ON' : 'OFF');
      await HomeWidget.updateWidget(androidName: 'BackupWidget');
    } catch (_) {}
  }

  // ── Day Tracker ──────────────────────────────────────────────────────────────

  static Future<void> _updateDayTracker() async {
    try {
      final box = await AppStorage.getSettingsBox();
      final raw = box.get('day_trackers', defaultValue: <dynamic>[]) as List;
      if (raw.isEmpty) {
        await HomeWidget.saveWidgetData<String>('trackers_list_json', '[]');
        await HomeWidget.updateWidget(androidName: 'DayTrackerWidget');
        return;
      }

      final today = DateTime.now();
      final todayDay = DateTime(today.year, today.month, today.day);

      final outList = <Map<String, dynamic>>[];

      for (final item in raw) {
        try {
          final tMap = (item as Map).cast<String, dynamic>();
          final title = (tMap['title'] as String?) ?? 'Tracker';
          final isDateBased = (tMap['isDateBased'] as bool?) ?? false;
          final colorVal = (tMap['color'] as int?) ?? 0xFF7C4DFF;

          int current, total;
          if (isDateBased) {
            final startStr = tMap['startDate'] as String?;
            final endStr = tMap['endDate'] as String?;
            final start = startStr != null ? DateTime.tryParse(startStr) : null;
            final end = endStr != null ? DateTime.tryParse(endStr) : null;
            if (start != null && end != null) {
              final startDay = DateTime(start.year, start.month, start.day);
              final endDay = DateTime(end.year, end.month, end.day);
              total = endDay.difference(startDay).inDays;
              current = todayDay.difference(startDay).inDays.clamp(0, total);
            } else {
              current = 0;
              total = 365;
            }
          } else {
            current = (tMap['currentDay'] as int?) ?? 0;
            total = (tMap['totalDays'] as int?) ?? 100;
          }

          final pctInt = total > 0 ? ((current / total) * 100).round().clamp(0, 100) : 0;
          
          outList.add({
            'title': title,
            'current': current,
            'total': total,
            'color': colorVal,
            'pct_int': pctInt,
          });
        } catch (_) {}
      }

      final jsonStr = jsonEncode(outList);
      await HomeWidget.saveWidgetData<String>('trackers_list_json', jsonStr);
      await HomeWidget.updateWidget(androidName: 'DayTrackerWidget');
    } catch (_) {}
  }

  // ── Food ─────────────────────────────────────────────────────────────────────

  static Future<void> _updateFood() async {
    try {
      final entries = (AppStorage.foodBox.get('food', defaultValue: <dynamic>[]) as List);
      final now = DateTime.now();
      final todayPrefix =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      int calories = 0;
      for (final e in entries) {
        try {
          final em = e as Map;
          final date = (em['date'] ?? em['timestamp'] ?? '') as String;
          if (date.startsWith(todayPrefix)) {
            calories += ((em['calories'] ?? em['kcal'] ?? 0) as num).toInt();
          }
        } catch (_) {}
      }

      const goal = 2000;
      final percent = ((calories / goal) * 100).round().clamp(0, 100);

      await HomeWidget.saveWidgetData<String>('food_calories', '$calories');
      await HomeWidget.saveWidgetData<int>('food_percent', percent);
      await HomeWidget.saveWidgetData<String>('food_goal_label', 'of $goal kcal goal');
      await HomeWidget.updateWidget(androidName: 'FoodWidget');
    } catch (_) {}
  }

  // ── Screen Time ──────────────────────────────────────────────────────────────

  static Future<void> _updateScreenTime() async {
    try {
      if (!AppStorage.enabledModules.contains('detox')) return;
      
      final hasPermission = await UsageService.checkPermission();
      if (!hasPermission) {
        await HomeWidget.saveWidgetData<String>('screentime_total', 'No Access');
        await HomeWidget.saveWidgetData<String>('screentime_apps', 'Grant permission in app');
        await HomeWidget.updateWidget(androidName: 'ScreenTimeWidget');
        return;
      }

      final trackedList = (AppStorage.settingsBox.get(
        'tracked_apps',
        defaultValue: <String>[],
      ) as List).cast<String>();

      final usage = await UsageService.fetchUsageStats(trackedApps: trackedList);

      int ms = 0;
      for (final info in usage) {
        ms += int.tryParse(info.totalTimeInForeground ?? '0') ?? 0;
      }
      final totalTimeStr = UsageService.formatDuration(ms.toString());

      final topApps = usage.take(3).toList();
      final appsList = <Map<String, dynamic>>[];
      
      for (final app in topApps) {
        final pkg = app.packageName;
        if (pkg == null) continue;
        final appName = await UsageService.resolveAppName(pkg);
        final timeMs = int.tryParse(app.totalTimeInForeground ?? '0') ?? 0;
        appsList.add({
          'name': appName,
          'timeMs': timeMs,
          'timeStr': UsageService.formatDuration(timeMs.toString()),
        });
      }

      final outMap = {
        'totalMs': ms,
        'totalStr': totalTimeStr,
        'apps': appsList,
      };

      await HomeWidget.saveWidgetData<String>('screentime_json', jsonEncode(outMap));
      await HomeWidget.updateWidget(androidName: 'ScreenTimeWidget');
    } catch (_) {}
  }
}

