import 'dart:io';
import 'package:flutter/material.dart';
import '../../app.dart' show NudgeTokens;
import '../../services/firebase_backup_service.dart';
import '../../services/auth_service.dart';
import '../../services/auto_backup_service.dart';
import '../auth/sign_in_screen.dart';
import '../auth/backup_check_screen.dart';
import '../export/export_screen.dart';
import 'settings_widgets.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  bool _autoBackupEnabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _autoBackupEnabled = AutoBackupService.isEnabled;
    });
  }

  Future<String?> _askPassphrase({required bool isRestore}) async {
    final ctrl = TextEditingController();
    bool obscure = true;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) => AlertDialog(
        backgroundColor: NudgeTokens.surface,
        title: Text(isRestore ? 'Restore Passphrase' : 'Backup Passphrase',
            style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRestore
                  ? 'Enter the passphrase you used when backing up.'
                  : 'Your data is encrypted with this passphrase. You\'ll need it to restore.',
              style: const TextStyle(color: NudgeTokens.textMid, fontSize: 13),
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
                enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: NudgeTokens.purple), borderRadius: BorderRadius.circular(10)),
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: NudgeTokens.textLow),
                  onPressed: () => setState(() => obscure = !obscure),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(isRestore ? 'Restore' : 'Backup',
                style: TextStyle(color: isRestore ? NudgeTokens.red : NudgeTokens.green, fontWeight: FontWeight.bold)),
          ),
        ],
      )),
    );
  }

  Future<void> _runBackup() async {
    final passphrase = await _askPassphrase(isRestore: false);
    if (passphrase == null || passphrase.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseBackupService.backup(passphrase);
      setState(() {});
      messenger.showSnackBar(const SnackBar(content: Text('Backup complete. Keep your passphrase safe.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    }
  }

  Future<void> _runRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NudgeTokens.surface,
        title: const Text('Restore from backup?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will overwrite your current data with the backup.\n\nThe app will close automatically so changes take effect.',
          style: TextStyle(color: NudgeTokens.textMid, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore', style: TextStyle(color: NudgeTokens.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final passphrase = await _askPassphrase(isRestore: true);
    if (passphrase == null || passphrase.isEmpty) return;

    try {
      final count = await FirebaseBackupService.restore(passphrase);
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: NudgeTokens.surface,
          title: const Text('Restore complete', style: TextStyle(color: Colors.white)),
          content: Text('$count data sources restored. The app will now close.'),
          actions: [
            TextButton(onPressed: () => exit(0), child: const Text('Close App', style: TextStyle(color: NudgeTokens.green, fontWeight: FontWeight.bold))),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Sync')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          const SectionHeader(title: 'Account'),
          StreamBuilder(
            stream: AuthService.authStateChanges,
            builder: (context, snapshot) {
              if (AuthService.isSignedIn) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: NudgeTokens.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: NudgeTokens.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: NudgeTokens.purple.withValues(alpha: 0.2),
                        backgroundImage: AuthService.photoUrl != null ? NetworkImage(AuthService.photoUrl!) : null,
                        child: AuthService.photoUrl == null ? Text(AuthService.displayName.isNotEmpty ? AuthService.displayName[0].toUpperCase() : '?', style: const TextStyle(color: NudgeTokens.purple, fontWeight: FontWeight.w800, fontSize: 16)) : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AuthService.displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
                            Text(AuthService.email, style: const TextStyle(fontSize: 12, color: NudgeTokens.textLow)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: NudgeTokens.surface,
                              title: const Text('Sign out?'),
                              content: const Text('Your local data will not be deleted.', style: TextStyle(color: NudgeTokens.textMid)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out', style: TextStyle(color: NudgeTokens.red))),
                              ],
                            ),
                          );
                          if (ok == true) await AuthService.signOut();
                        },
                        child: const Text('Sign out', style: TextStyle(color: NudgeTokens.textLow, fontSize: 12)),
                      ),
                    ],
                  ),
                );
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: NudgeTokens.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: NudgeTokens.purple.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: NudgeTokens.purple.withValues(alpha: 0.12), shape: BoxShape.circle), child: const Icon(Icons.person_outline_rounded, color: NudgeTokens.purple, size: 20)),
                    const SizedBox(width: 14),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('No account', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)), Text('Sign in to enable cloud backup', style: TextStyle(fontSize: 12, color: NudgeTokens.textLow))])),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SignInScreen(onDone: () {
                        if (AuthService.isSignedIn) {
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BackupCheckScreen(fromSettings: true)));
                        } else {
                          Navigator.pop(context);
                        }
                      }))),
                      child: const Text('Sign in', style: TextStyle(color: NudgeTokens.purple, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              );
            },
          ),
          
          const SizedBox(height: 12),
          const SectionHeader(title: 'Cloud Backup'),
          SettingTile(
            icon: Icons.cloud_upload_rounded,
            title: 'Backup to Cloud',
            subtitle: FirebaseBackupService.lastBackupLabel(),
            onTap: _runBackup,
            trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow),
          ),
          SettingTile(
            icon: Icons.cloud_download_rounded,
            title: 'Restore from Cloud',
            subtitle: 'Overwrites local data with cloud backup',
            onTap: _runRestore,
            trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow),
          ),
          SettingTile(
            icon: Icons.nightlight_round,
            title: 'Nightly Auto-Backup',
            subtitle: _autoBackupEnabled ? 'Runs at 2 AM every night' : 'Disabled — tap to enable',
            color: _autoBackupEnabled ? NudgeTokens.green : null,
            onTap: () async {
              if (_autoBackupEnabled) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: NudgeTokens.surface,
                    title: const Text('Disable auto-backup?', style: TextStyle(color: Colors.white)),
                    content: const Text('The stored passphrase will be removed.', style: TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Disable', style: TextStyle(color: NudgeTokens.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await AutoBackupService.disable();
                  setState(() => _autoBackupEnabled = false);
                }
              } else {
                if (!AuthService.isSignedIn) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in with Google first.')));
                  return;
                }
                final passphrase = await _askPassphrase(isRestore: false);
                if (passphrase == null || passphrase.isEmpty) return;
                await AutoBackupService.enable(passphrase);
                setState(() => _autoBackupEnabled = true);
                // Battery optimization check...
                final batteryOk = await AutoBackupService.isBatteryOptimizationDisabled();
                if (!batteryOk && mounted) {
                   showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: NudgeTokens.surface,
                      title: const Text('Allow background activity', style: TextStyle(color: Colors.white)),
                      content: const Text('Android may prevent the 2 AM backup from running. Tap "Allow" to disable battery optimisation.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
                        TextButton(onPressed: () async { Navigator.pop(ctx); await AutoBackupService.openBatteryOptimizationSettings(); }, child: const Text('Allow', style: TextStyle(color: NudgeTokens.green))),
                      ],
                    ),
                  );
                }
              }
            },
            trailing: Switch(value: _autoBackupEnabled, onChanged: null, activeColor: NudgeTokens.green),
          ),

          const SizedBox(height: 24),
          const SectionHeader(title: 'Local Data'),
          SettingTile(
            icon: Icons.upload_file_rounded,
            title: 'Export Data',
            subtitle: 'Download your local records',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExportScreen())),
            trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow),
          ),
        ],
      ),
    );
  }
}
