// lib/screens/protected/protected_gate.dart
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'protected_habits_screen.dart';

class ProtectedGateScreen extends StatefulWidget {
  const ProtectedGateScreen({super.key});

  @override
  State<ProtectedGateScreen> createState() => _ProtectedGateScreenState();
}

class _ProtectedGateScreenState extends State<ProtectedGateScreen> {
  final _auth = LocalAuthentication();
  bool _checking = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _unlock();
  }

  Future<void> _unlock() async {
    setState(() {
      _checking = true;
      _error = null;
    });

    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();

      if (!canCheck || !supported) {
        setState(() {
          _checking = false;
          _error = 'Biometrics not available on this device.';
        });
        return;
      }

      final ok = await _auth.authenticate(
        localizedReason: 'Unlock Protected Habits',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (!mounted) return;

      if (ok) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ProtectedHabitsScreen()),
        );
      } else {
        setState(() {
          _checking = false;
          _error = 'Not authenticated.';
        });
      }
    } catch (e) {
      setState(() {
        _checking = false;
        _error = 'Auth error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Protected')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: const Color(0xFF101722),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fingerprint_rounded, size: 44, color: Colors.white.withOpacity(0.90)),
                const SizedBox(height: 12),
                Text(
                  _checking ? 'Authenticating…' : 'Locked',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? 'Use fingerprint to continue.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.75)),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _checking ? null : _unlock,
                    icon: const Icon(Icons.lock_open_rounded),
                    label: const Text('Unlock'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
