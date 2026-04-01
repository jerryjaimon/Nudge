// lib/screens/auth/backup_check_screen.dart
//
// Shown after sign-in when the user has never completed onboarding.
// Checks Firestore for an existing backup:
//   • Found  → offer to restore (skips onboarding) or start fresh
//   • Not found → navigate directly to OnboardingScreen

import 'dart:io';
import 'package:flutter/material.dart';
import '../../app.dart' show NudgeTokens;
import '../../services/firebase_backup_service.dart';
import '../../services/google_drive_backup_service.dart';
import '../onboarding_screen.dart';
import '../../storage.dart';

class BackupCheckScreen extends StatefulWidget {
  final bool fromSettings;
  const BackupCheckScreen({super.key, this.fromSettings = false});

  @override
  State<BackupCheckScreen> createState() => _BackupCheckScreenState();
}

class _BackupCheckScreenState extends State<BackupCheckScreen> {
  bool _checking = true;
  
  // Backup existence
  bool _hasFirebaseBackup = false;
  bool _hasDriveBackup = false;

  // Restore state
  bool _restoring = false;
  String? _restoreError;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final fb = await FirebaseBackupService.checkBackupExists();
    final gd = await GoogleDriveBackupService.checkBackupExists();
    if (!mounted) return;
    if (!fb && !gd) {
      if (widget.fromSettings) {
        Navigator.of(context).pop();
      } else {
        _goToOnboarding();
      }
      return;
    }
    setState(() {
      _checking = false;
      _hasFirebaseBackup = fb;
      _hasDriveBackup = gd;
    });
  }

  void _goToOnboarding() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  Future<void> _doRestore(bool useDrive) async {
    // Ask passphrase
    final passphrase = await _askPassphrase();
    if (passphrase == null || passphrase.isEmpty) return;

    setState(() {
      _restoring = true;
      _restoreError = null;
    });

    try {
      final count = useDrive 
        ? await GoogleDriveBackupService.restore(passphrase)
        : await FirebaseBackupService.restore(passphrase);
      AppStorage.hasSeenOnboarding = true;
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: NudgeTokens.surface,
          title: const Text('Restore complete', style: TextStyle(color: Colors.white)),
          content: Text(
            '$count data sources restored. The app will now close — reopen it to load your data.',
            style: const TextStyle(color: NudgeTokens.textMid, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => exit(0),
              child: const Text('Close App',
                  style: TextStyle(color: NudgeTokens.green, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _restoring = false;
        _restoreError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<String?> _askPassphrase() async {
    final ctrl = TextEditingController();
    bool obscure = true;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: NudgeTokens.surface,
          title: const Text('Enter your passphrase', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the passphrase you chose when the backup was created.',
                style: TextStyle(color: NudgeTokens.textMid, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                obscureText: obscure,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Passphrase',
                  labelStyle: const TextStyle(color: NudgeTokens.textLow),
                  enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white24),
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: NudgeTokens.purple),
                      borderRadius: BorderRadius.circular(10)),
                  suffixIcon: IconButton(
                    icon: Icon(
                        obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: NudgeTokens.textLow),
                    onPressed: () => setS(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Restore',
                  style: TextStyle(color: NudgeTokens.green, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: NudgeTokens.bg,
        body: Center(child: CircularProgressIndicator(color: NudgeTokens.purple)),
      );
    }

    return Scaffold(
      backgroundColor: NudgeTokens.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              const Spacer(),

              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [NudgeTokens.purple, NudgeTokens.gymB],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 32),
              ),

              const SizedBox(height: 24),

              const Text(
                'Welcome back.',
                style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              const Text(
                'We found a backup linked to your account.\nRestore it now to pick up right where you left off.',
                style: TextStyle(color: NudgeTokens.textMid, fontSize: 15, height: 1.5),
              ),

              const SizedBox(height: 32),

              // What will be restored
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: NudgeTokens.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('What gets restored',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 10),
                    for (final item in [
                      ('Gym workouts & routines', Icons.fitness_center_rounded),
                      ('Food & nutrition logs', Icons.restaurant_rounded),
                      ('Finance & budgets', Icons.account_balance_wallet_rounded),
                      ('Books, movies & habits', Icons.auto_stories_rounded),
                      ('Pomodoro sessions', Icons.timer_rounded),
                      ('App preferences & API keys', Icons.settings_rounded),
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          Icon(item.$2, size: 15, color: NudgeTokens.purple),
                          const SizedBox(width: 10),
                          Text(item.$1,
                              style: const TextStyle(color: NudgeTokens.textMid, fontSize: 13)),
                        ]),
                      ),
                  ],
                ),
              ),

              if (_restoreError != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: NudgeTokens.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: NudgeTokens.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: NudgeTokens.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_restoreError!,
                          style: const TextStyle(color: NudgeTokens.red, fontSize: 12)),
                    ),
                  ]),
                ),
              ],

              const Spacer(),

              // Restore buttons
              if (_hasDriveBackup)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _restoring ? null : () => _doRestore(true),
                    icon: _restoring
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add_to_drive_rounded, size: 18),
                    label: Text(_restoring ? 'Restoring…' : 'Restore from Google Drive'),
                    style: FilledButton.styleFrom(
                      backgroundColor: NudgeTokens.blue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),

              if (_hasDriveBackup && _hasFirebaseBackup)
                const SizedBox(height: 12),

              if (_hasFirebaseBackup)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _restoring ? null : () => _doRestore(false),
                    icon: _restoring
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.cloud_download_rounded, size: 18),
                    label: Text(_restoring ? 'Restoring…' : 'Restore from Firebase'),
                    style: FilledButton.styleFrom(
                      backgroundColor: NudgeTokens.purple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              // Start fresh button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _restoring
                      ? null
                      : () {
                          if (widget.fromSettings) {
                            Navigator.of(context).pop();
                          } else {
                            _goToOnboarding();
                          }
                        },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Start fresh instead',
                    style: TextStyle(color: NudgeTokens.textMid, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
            ),
          ],
        ),
      ),
    );
  }
}
