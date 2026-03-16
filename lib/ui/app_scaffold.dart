// lib/ui/app_scaffold.dart
import 'package:flutter/material.dart';
import '../app.dart' show NudgeTokens;

class AppScaffold extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final Widget child;
  final Color? accentColor;

  const AppScaffold({
    super.key,
    required this.title,
    this.actions = const [],
    required this.child,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NudgeTokens.bg,
      appBar: AppBar(
        backgroundColor: NudgeTokens.bg,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        actions: actions,
        titleSpacing: 0,
        title: Row(
          children: [
            if (accentColor != null) ...[
              Container(
                width: 3,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: NudgeTokens.textHigh,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: NudgeTokens.border),
        ),
      ),
      body: SafeArea(child: child),
    );
  }
}
