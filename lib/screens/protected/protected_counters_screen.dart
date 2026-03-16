// lib/screens/protected/protected_counters_screen.dart
import 'package:flutter/material.dart';
import '../../app.dart' show NudgeTokens;

class ProtectedCountersScreen extends StatelessWidget {
  const ProtectedCountersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: const Text('Protected Counters'),
      ),
      body: const Center(
        child: Text(
          'Protected Counters Content Placeholder',
          style: TextStyle(color: NudgeTokens.textLow),
        ),
      ),
    );
  }
}

