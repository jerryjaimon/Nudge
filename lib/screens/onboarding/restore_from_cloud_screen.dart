import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app.dart' show NudgeTokens;
import '../../services/firebase_backup_service.dart';
import '../../services/google_drive_backup_service.dart';
import '../../storage.dart';
import '../../widgets/orbit_animation.dart';

class RestoreFromCloudScreen extends StatefulWidget {
  final VoidCallback onRestored;
  final VoidCallback onSkip;

  const RestoreFromCloudScreen({
    super.key,
    required this.onRestored,
    required this.onSkip,
  });

  @override
  State<RestoreFromCloudScreen> createState() => _RestoreFromCloudScreenState();
}

class _RestoreFromCloudScreenState extends State<RestoreFromCloudScreen> {
  final _passphraseCtrl = TextEditingController();
  bool _checking = true;
  bool _hasFirebaseBackup = false;
  bool _hasDriveBackup = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final fb = await FirebaseBackupService.checkBackupExists();
    final gd = await GoogleDriveBackupService.checkBackupExists();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _hasFirebaseBackup = fb;
      _hasDriveBackup = gd;
    });
  }

  @override
  void dispose() {
    _passphraseCtrl.dispose();
    super.dispose();
  }

  Future<void> _restore(bool useDrive) async {
    final pass = _passphraseCtrl.text.trim();
    if (pass.isEmpty) {
      setState(() => _error = 'Enter your passphrase to decrypt your backup.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (useDrive) {
        await GoogleDriveBackupService.restore(pass);
      } else {
        await FirebaseBackupService.restore(pass);
      }
      // Ensure any missing keys are restored after a full box clear.
      await AppStorage.init();
      if (!mounted) return;
      widget.onRestored();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
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
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
                child: Column(
                  children: [
              const SizedBox(height: 18),
              const OrbitAnimation(size: 250),
              const SizedBox(height: 26),
              Text(
                'Restore from Firebase',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'We found an encrypted backup for this account.\nEnter your passphrase to decrypt it on-device.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  height: 1.5,
                  color: NudgeTokens.textMid,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passphraseCtrl,
                enabled: !_busy,
                obscureText: true,
                style: GoogleFonts.outfit(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Passphrase',
                  labelStyle: GoogleFonts.outfit(color: NudgeTokens.textLow),
                  filled: true,
                  fillColor: NudgeTokens.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: NudgeTokens.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: NudgeTokens.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: NudgeTokens.purple),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_error != null)
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: NudgeTokens.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const Spacer(),
              if (_hasDriveBackup)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: _busy
                      ? const Center(child: CircularProgressIndicator(color: NudgeTokens.blue))
                      : FilledButton.icon(
                          onPressed: () => _restore(true),
                          icon: const Icon(Icons.add_to_drive_rounded, size: 18),
                          label: Text(
                            'Restore from Google Drive',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: NudgeTokens.blue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                ),
              if (_hasDriveBackup && _hasFirebaseBackup)
                const SizedBox(height: 12),
              if (_hasFirebaseBackup)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: _busy
                      ? const Center(child: CircularProgressIndicator(color: NudgeTokens.purple))
                      : FilledButton.icon(
                          onPressed: () => _restore(false),
                          icon: const Icon(Icons.cloud_download_rounded, size: 18),
                          label: Text(
                            'Restore from Firebase',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: NudgeTokens.purple,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                ),
              if (!_hasDriveBackup && !_hasFirebaseBackup) 
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: null,
                    style: FilledButton.styleFrom(
                      backgroundColor: NudgeTokens.elevated,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      'No backup found',
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white30),
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: _busy ? null : widget.onSkip,
                child: Text(
                  'Start fresh instead',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: NudgeTokens.textLow,
                    fontWeight: FontWeight.w700,
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

