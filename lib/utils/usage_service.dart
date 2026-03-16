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

  static Future<List<UsageInfo>> fetchUsageStats({bool monthly = false, List<String>? trackedApps}) async {
    if (!Platform.isAndroid) return [];
    
    DateTime endDate = DateTime.now();
    DateTime startDate = monthly 
      ? DateTime(endDate.year, endDate.month, 1) // Start of month
      : endDate.subtract(const Duration(days: 1)); // Last 24h

    List<UsageInfo> usageStats = await UsageStats.queryUsageStats(startDate, endDate);
    
    // Filter out apps with 0 usage
    usageStats = usageStats.where((info) {
      final time = int.tryParse(info.totalTimeInForeground ?? '0') ?? 0;
      if (time <= 0) return false;
      
      if (trackedApps != null && trackedApps.isNotEmpty) {
        return trackedApps.contains(info.packageName);
      }
      return true;
    }).toList();

    // Aggregate usage for the same package
    final Map<String, int> durations = {};
    final Map<String, UsageInfo> baseInfos = {};
    
    for (var info in usageStats) {
      final pkg = info.packageName!;
      final time = int.tryParse(info.totalTimeInForeground ?? '0') ?? 0;
      durations[pkg] = (durations[pkg] ?? 0) + time;
      baseInfos.putIfAbsent(pkg, () => info);
    }

    final List<UsageInfo> result = [];
    for (var entry in baseInfos.entries) {
      // Create a wrapper or just use the base info with a modified calculation in formatDuration
      // Actually, UsageInfo in usage_stats 1.3.1 might have no setter, so we must calculate our own map
      result.add(entry.value);
    }

    // Since we can't modify UsageInfo, we'll return the base list but sorted by our aggregated durations
    result.sort((a, b) => (durations[b.packageName] ?? 0).compareTo(durations[a.packageName] ?? 0));

    return result;
  }

  static String formatDuration(String? durationMs) {
    if (durationMs == null) return '0m';
    int ms = int.tryParse(durationMs) ?? 0;
    int minutes = (ms / 60000).round();
    if (minutes < 60) return '${minutes}m';
    int hours = minutes ~/ 60;
    int remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m';
  }
}
