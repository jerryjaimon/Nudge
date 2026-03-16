import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../app.dart' show NudgeTokens;

class LightBar extends StatelessWidget {
  const LightBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final state = appState.lightState;

        Color color;
        String label;
        IconData icon;

        switch (state) {
          case LightState.red:
            color = NudgeTokens.red;
            label = 'NEEDS ATTENTION';
            icon = Icons.warning_amber_rounded;
            break;
          case LightState.orange:
            color = NudgeTokens.amber;
            label = 'IN PROGRESS';
            icon = Icons.timelapse_rounded;
            break;
          case LightState.green:
            color = NudgeTokens.green;
            label = 'ALL DONE';
            icon = Icons.check_circle_rounded;
            break;
          case LightState.grey:
          default:
            color = NudgeTokens.textLow;
            label = 'NO TASKS DUE';
            icon = Icons.circle_outlined;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: color.withValues(alpha: state == LightState.grey ? 0.06 : 0.10),
                border: Border.all(
                  color: color.withValues(alpha: state == LightState.grey ? 0.10 : 0.25),
                ),
                boxShadow: state != LightState.grey
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.15),
                          blurRadius: 12,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
