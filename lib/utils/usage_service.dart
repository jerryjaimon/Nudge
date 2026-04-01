import 'package:usage_stats/usage_stats.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'dart:io';
import 'dart:typed_data';

class UsageService {
  static final Map<String, String> _labelCache = {};
  static final Map<String, Uint8List?> _iconCache = {};

  static Future<String> resolveAppName(String packageName) async {
    if (_labelCache.containsKey(packageName)) return _labelCache[packageName]!;
    
    try {
      AppInfo? app = await InstalledApps.getAppInfo(packageName);
      if (app != null) {
        _labelCache[packageName] = app.name;
        if (app.icon != null) _iconCache[packageName] = app.icon;
        return app.name;
      }
    } catch (_) {}
    
    final name = packageName.split('.').last;
    return name[0].toUpperCase() + name.substring(1);
  }

  static Future<Uint8List?> resolveAppIcon(String packageName) async {
    if (_iconCache.containsKey(packageName)) return _iconCache[packageName];
    
    try {
      AppInfo? app = await InstalledApps.getAppInfo(packageName);
      if (app != null && app.icon != null) {
        _iconCache[packageName] = app.icon;
        _labelCache[packageName] = app.name;
        return app.icon;
      }
    } catch (_) {}
    
    _iconCache[packageName] = null;
    return null;
  }

  static Future<bool> checkPermission() async {
    if (!Platform.isAndroid) return true;
    bool? isPermissionGranted = await UsageStats.checkUsagePermission();
    return isPermissionGranted ?? false;
  }

  static Future<void> requestPermission() async {
    if (!Platform.isAndroid) return;
    await UsageStats.grantUsagePermission();
  }

  /// Fetch per-package usage (ms) for a single day (midnight → midnight).
  /// Deduplicates by keeping the entry with the latest lastTimeStamp per package,
  /// preventing double-counting when Android returns multiple buckets for the same app.
  static Future<Map<String, int>> fetchDayStats(DateTime date, {List<String>? trackedApps}) async {
    if (!Platform.isAndroid) return {};
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final raw = await UsageStats.queryUsageStats(start, end);
    final best = <String, UsageInfo>{};
    for (final s in raw) {
      final pkg = s.packageName;
      if (pkg == null || pkg.isEmpty) continue;
      final ms = int.tryParse(s.totalTimeInForeground ?? '0') ?? 0;
      if (ms <= 0) continue;
      if (trackedApps != null && trackedApps.isNotEmpty && !trackedApps.contains(pkg)) continue;
      final existing = best[pkg];
      if (existing == null) {
        best[pkg] = s;
      } else {
        final existingTs = int.tryParse(existing.lastTimeStamp ?? '0') ?? 0;
        final currentTs = int.tryParse(s.lastTimeStamp ?? '0') ?? 0;
        if (currentTs > existingTs) best[pkg] = s;
      }
    }
    final result = <String, int>{};
    for (final entry in best.entries) {
      result[entry.key] = int.tryParse(entry.value.totalTimeInForeground ?? '0') ?? 0;
    }
    return result;
  }

  static String formatDurationMs(int ms) {
    final minutes = (ms / 60000).round();
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    return rem == 0 ? '${hours}h' : '${hours}h ${rem}m';
  }

  static Future<List<UsageInfo>> fetchUsageStats({bool monthly = false, List<String>? trackedApps}) async {
    if (!Platform.isAndroid) return [];

    DateTime now = DateTime.now();
    DateTime startDate = monthly
      ? DateTime(now.year, now.month, 1)
      : DateTime(now.year, now.month, now.day);

    // Query stats for the interval.
    List<UsageInfo> usageStats = await UsageStats.queryUsageStats(startDate, now);
    
    // Deduplicate by package name. Android often returns multiple buckets (yesterday/today)
    // if the query interval spans a boundary. We only want the most accurate/recent total
    // for our specific interval.
    final Map<String, UsageInfo> bestInfos = {};
    
    for (var info in usageStats) {
      final pkg = info.packageName;
      if (pkg == null || pkg.isEmpty) continue;
      
      final time = int.tryParse(info.totalTimeInForeground ?? '0') ?? 0;
      if (time <= 0) continue;
      
      if (trackedApps != null && trackedApps.isNotEmpty && !trackedApps.contains(pkg)) continue;

      // If we already have info for this app, keep the one with the LATEST activity.
      // This ensures that if we get both "yesterday's bucket" and "today's bucket", 
      // we pick the one that represents the current day's usage.
      final existing = bestInfos[pkg];
      if (existing == null) {
        bestInfos[pkg] = info;
      } else {
        final existingEnd = int.tryParse(existing.lastTimeStamp ?? '0') ?? 0;
        final currentEnd = int.tryParse(info.lastTimeStamp ?? '0') ?? 0;
        if (currentEnd > existingEnd) {
          bestInfos[pkg] = info;
        }
      }
    }

    final List<UsageInfo> result = bestInfos.values.toList();
    result.sort((a, b) {
      final tA = int.tryParse(a.totalTimeInForeground ?? '0') ?? 0;
      final tB = int.tryParse(b.totalTimeInForeground ?? '0') ?? 0;
      return tB.compareTo(tA);
    });

    return result;
  }

  static String formatDuration(String? durationMs) {
    if (durationMs == null) return '0m';
    int ms = int.tryParse(durationMs) ?? 0;
    return formatDurationMs(ms);
  }
}

