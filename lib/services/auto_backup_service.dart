// lib/services/auto_backup_service.dart
//
// Schedules a nightly (2 AM) background backup via WorkManager.
// The passphrase is stored in Flutter Secure Storage (Android Keystore —
// hardware-backed encryption, inaccessible to other apps).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';
import '../storage.dart';
import 'firebase_backup_service.dart';
import 'google_drive_backup_service.dart';

const _backupChannel = MethodChannel('com.example.nudge/backup');

const _passphraseKey = 'nudge_backup_passphrase';
const _taskName     = 'nudge_nightly_backup';
const _taskTag      = 'nightlyBackup';

// ── Background entry point ────────────────────────────────────────────────────
// Must be a top-level function annotated with @pragma so the compiler keeps it
// in release builds.

@pragma('vm:entry-point')
void callbackDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().executeTask((task, inputData) async {
    try {
      await Hive.initFlutter();
      await AppStorage.init();

      // Guard against duplicate-app exception when the background isolate
      // is spawned while the foreground app is still alive.
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      // Disable Firestore offline persistence in the background isolate to
      // avoid conflicts with the foreground app's cache.
      FirebaseFirestore.instance.settings =
          const Settings(persistenceEnabled: false);

      const storage = FlutterSecureStorage();
      final passphrase = await storage.read(key: _passphraseKey);
      if (passphrase == null || passphrase.isEmpty) return true;

      // UID is passed via inputData — FirebaseAuth.currentUser is unreliable
      // in a background isolate that cold-initialises Firebase.
      final uid = inputData?['uid'] as String?;
      if (uid == null || uid.isEmpty) return true;

      // Firebase Backup
      try {
        await FirebaseBackupService.backupWithUid(passphrase, uid);
      } catch (e) {
        try {
          await AppStorage.logAiError('AutoBackup Firebase failed: $e');
        } catch (_) {}
      }

      // Google Drive Backup
      try {
        await GoogleDriveBackupService.backupWithUid(passphrase, uid);
      } catch (e) {
        try {
          await AppStorage.logAiError('AutoBackup Drive failed: $e');
        } catch (_) {}
      }
    } catch (e) {
      return false;
    }
    return true;
  });
}

// ── AutoBackupService ─────────────────────────────────────────────────────────

class AutoBackupService {
  static const _storage = FlutterSecureStorage();

  static bool get isEnabled =>
      AppStorage.settingsBox.get('auto_backup_enabled', defaultValue: false) as bool;

  /// Stores [passphrase] in secure storage and schedules the nightly task.
  static Future<void> enable(String passphrase) async {
    await _storage.write(key: _passphraseKey, value: passphrase);
    await AppStorage.settingsBox.put('auto_backup_enabled', true);
    await _schedule(forceReplace: true);
  }

  /// Removes the stored passphrase and cancels the scheduled task.
  static Future<void> disable() async {
    await _storage.delete(key: _passphraseKey);
    await AppStorage.settingsBox.put('auto_backup_enabled', false);
    await Workmanager().cancelByUniqueName(_taskName);
  }

  /// Returns the stored passphrase (null if auto-backup is disabled).
  static Future<String?> getStoredPassphrase() =>
      _storage.read(key: _passphraseKey);

  /// Returns true if battery optimization is already disabled for Nudge.
  static Future<bool> isBatteryOptimizationDisabled() async {
    try {
      return await _backupChannel
              .invokeMethod<bool>('isBatteryOptimizationDisabled') ??
          false;
    } catch (_) {
      return true; // non-Android or old API — assume fine
    }
  }

  /// Opens the system dialog to request disabling battery optimization.
  static Future<void> openBatteryOptimizationSettings() async {
    try {
      await _backupChannel.invokeMethod('openBatteryOptimizationSettings');
    } catch (_) {}
  }

  // ── Scheduling ──────────────────────────────────────────────────────────────

  static Future<void> _schedule({bool forceReplace = false}) async {
    // UID must be passed as inputData so the background isolate can write to
    // Firestore without relying on FirebaseAuth being available there.
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return; // not signed in — skip scheduling

    final now    = DateTime.now();
    var   target = DateTime(now.year, now.month, now.day, 2, 0); // 2 AM
    if (!target.isAfter(now)) target = target.add(const Duration(days: 1));
    final delay = target.difference(now);

    await Workmanager().registerPeriodicTask(
      _taskName,
      _taskTag,
      frequency: const Duration(hours: 24),
      initialDelay: delay,
      inputData: {'uid': uid},
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: forceReplace
          ? ExistingPeriodicWorkPolicy.replace
          : ExistingPeriodicWorkPolicy.keep,
    );
  }

  /// Re-schedules the task (call on app launch if auto-backup is enabled).
  ///
  /// Firebase Auth restores user state asynchronously after initializeApp().
  /// We wait up to 5 s for the first auth event before checking the UID,
  /// otherwise the UID is null and _schedule() silently bails.
  static Future<void> rescheduleIfEnabled() async {
    if (!isEnabled) return;
    await FirebaseAuth.instance
        .authStateChanges()
        .first
        .timeout(const Duration(seconds: 5), onTimeout: () => null);
    await _schedule();
  }
}
