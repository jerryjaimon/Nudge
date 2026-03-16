// lib/screens/protected/protected_counters_gate.dart
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../ui/app_scaffold.dart';
import 'protected_counters_screen.dart';

class ProtectedCountersGate extends StatefulWidget {
  const ProtectedCountersGate({super.key});

  @override
  State<ProtectedCountersGate> createState() => _ProtectedCountersGateState();
}

class _ProtectedCountersGateState extends State<ProtectedCountersGate> {
  final _auth = LocalAuthentication();
  bool _unlocked = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _unlock();
  }

  Future<void> _unlock() async {
    setState(() {
      _error = null;
    });

    try {
      final can = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!can) {
        setState(() => _error = 'Biometrics not available on this device.');
        return;
      }

      final ok = await _auth.authenticate(
        localizedReason: 'Unlock protected counters',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!mounted) return;
      setState(() => _unlocked = ok);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unlock failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Protected Counters',
      actions: [
        IconButton(onPressed: _unlock, icon: const Icon(Icons.fingerprint_rounded)),
      ],
      child: _unlocked
          ? const ProtectedCountersScreen()
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
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
                      const Icon(Icons.lock_rounded, size: 36),
                      const SizedBox(height: 10),
                      Text(
                        'Locked',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _error ?? 'Use fingerprint to unlock your counters.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.70)),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _unlock,
                        icon: const Icon(Icons.fingerprint_rounded),
                        label: const Text('Unlock'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
