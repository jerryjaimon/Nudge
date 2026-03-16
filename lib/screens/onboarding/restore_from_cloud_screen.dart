import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app.dart' show NudgeTokens;
import '../../services/firebase_backup_service.dart';
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
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _passphraseCtrl.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
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
      await FirebaseBackupService.restore(pass);
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
    return Scaffold(
      backgroundColor: NudgeTokens.bg,
      body: SafeArea(
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
              SizedBox(
                width: double.infinity,
                height: 54,
                child: _busy
                    ? const Center(
                        child: CircularProgressIndicator(color: NudgeTokens.purple),
                      )
                    : FilledButton(
                        onPressed: _restore,
                        style: FilledButton.styleFrom(
                          backgroundColor: NudgeTokens.purple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Restore backup',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
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
    );
  }
}

