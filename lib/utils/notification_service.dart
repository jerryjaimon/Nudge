import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── Notification IDs ────────────────────────────────────────────────────────
  static const int _kStreakReminderId = 8001;

  // ── Channel IDs ─────────────────────────────────────────────────────────────
  static const String _kHabitChannelId = 'habit_reminders';
  static const String _kStreakChannelId = 'streak_reminders';

  // ── Init ────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      final dynamic timeZoneName = await FlutterTimezone.getLocalTimezone();
      final String tzString =
          timeZoneName is String ? timeZoneName : timeZoneName.identifier;
      tz.setLocalLocation(tz.getLocation(tzString));
    } catch (e) {
      debugPrint('Error setting timezone: $e');
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Notification tapped: ${details.payload}');
      },
    );

    _initialized = true;
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();
    }
  }

  // ── Habit reminders (existing) ──────────────────────────────────────────────

  Future<void> scheduleDailyReminder(
      int id, String title, String body, TimeOfDay time) async {
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfTime(time),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _kHabitChannelId,
          'Habit Reminders',
          channelDescription: 'Daily reminders to complete your habits',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    debugPrint('Scheduled daily reminder for $title at ${time.hour}:${time.minute}');
  }

  Future<void> cancelReminder(int id) async {
    await _notificationsPlugin.cancel(id);
    debugPrint('Cancelled reminder id: $id');
  }

  // ── Streak / daily data reminder ────────────────────────────────────────────

  /// Schedule (or reschedule) the daily streak reminder.
  ///
  /// [persistent] = true → the notification cannot be swiped away by the user;
  /// only [cancelStreakReminder] (called when data is logged) can dismiss it.
  ///
  /// [persistent] = false → standard notification the user can clear at will.
  Future<void> scheduleStreakReminder({
    required int hour,
    required int minute,
    required bool persistent,
  }) async {
    // Cancel any existing streak reminder first so we don't stack up duplicates
    await _notificationsPlugin.cancel(_kStreakReminderId);

    final details = AndroidNotificationDetails(
      _kStreakChannelId,
      'Daily Nudge Reminder',
      channelDescription: "Reminds you to log today's data and keep your streak",
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      // Persistent: stays in tray until app cancels it programmatically.
      // autoCancel: false means tapping the notification does NOT dismiss it.
      ongoing: persistent,
      autoCancel: !persistent,
    );

    await _notificationsPlugin.zonedSchedule(
      _kStreakReminderId,
      "Don't break your streak! 🔥",
      "Log something today — gym, food, water, or habits.",
      _nextInstanceOfTime(TimeOfDay(hour: hour, minute: minute)),
      NotificationDetails(android: details),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    debugPrint('Scheduled streak reminder at $hour:$minute (persistent=$persistent)');
  }

  /// Cancel the streak notification immediately (call after the user logs data).
  Future<void> cancelStreakReminder() async {
    await _notificationsPlugin.cancel(_kStreakReminderId);
    debugPrint('Streak reminder cancelled — data logged today');
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
