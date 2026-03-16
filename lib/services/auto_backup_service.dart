// lib/services/auto_backup_service.dart
//
// Schedules a nightly (2 AM) background backup via WorkManager.
// The passphrase is stored in Flutter Secure Storage (Android Keystore —
// hardware-backed encryption, inaccessible to other apps).

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';
import '../storage.dart';
import 'firebase_backup_service.dart';

const _passphraseKey = 'nudge_backup_passphrase';
const _taskName     = 'nudge_nightly_backup';
const _taskTag      = 'nightlyBackup';

// ── Background entry point ────────────────────────────────────────────────────
// Must be a top-level function annotated with @pragma so the compiler keeps it
// in release builds.

@pragma('vm:entry-point')
void callbackDispatcher() {
  // Must be called before executeTask so Flutter plugins are available
  // in the background isolate that WorkManager spins up.
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().executeTask((task, _) async {
    try {
      await Hive.initFlutter();
      await AppStorage.init();
      await Firebase.initializeApp();

      const storage = FlutterSecureStorage();
      final passphrase = await storage.read(key: _passphraseKey);
      if (passphrase == null || passphrase.isEmpty) return true;

      await FirebaseBackupService.backup(passphrase);
    } catch (_) {
      // Silently fail — will retry next night.
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
    await _schedule();
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

  // ── Scheduling ──────────────────────────────────────────────────────────────

  static Future<void> _schedule() async {
    final now    = DateTime.now();
    var   target = DateTime(now.year, now.month, now.day, 2, 0); // 2 AM
    if (!target.isAfter(now)) target = target.add(const Duration(days: 1));
    final delay = target.difference(now);

    await Workmanager().registerPeriodicTask(
      _taskName,
      _taskTag,
      frequency: const Duration(hours: 24),
      initialDelay: delay,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  /// Re-schedules the task (call on app launch if auto-backup is enabled).
  static Future<void> rescheduleIfEnabled() async {
    if (isEnabled) await _schedule();
  }
}
