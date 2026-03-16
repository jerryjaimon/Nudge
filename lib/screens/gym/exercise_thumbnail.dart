import 'package:flutter/material.dart';
import '../../app.dart' show NudgeTokens;
import 'exercise_db.dart';
import 'exercise_illustration.dart';

class ExerciseThumbnail extends StatelessWidget {
  final String exerciseName;
  final double size;

  const ExerciseThumbnail({
    super.key,
    required this.exerciseName,
    this.size = 44,
    // iconSize kept for API compatibility but no longer used
    // ignore: unused_element
    double iconSize = 22,
  });

  List<Color> _gradient(String category) {
    switch (category) {
      case 'Chest':     return [const Color(0xFF3A1010), const Color(0xFF5A1A1A)];
      case 'Back':      return [const Color(0xFF0A1A2A), const Color(0xFF0D2540)];
      case 'Legs':      return [const Color(0xFF2A1A04), const Color(0xFF3D2506)];
      case 'Shoulders': return [const Color(0xFF1A0A2A), const Color(0xFF280F40)];
      case 'Arms':      return [const Color(0xFF041A1F), const Color(0xFF062530)];
      case 'Core':      return [const Color(0xFF041A14), const Color(0xFF06281E)];
      case 'Cardio':    return [const Color(0xFF1F0A16), const Color(0xFF2E0F20)];
      default:          return [NudgeTokens.gymA, NudgeTokens.gymB];
    }
  }

  @override
  Widget build(BuildContext context) {
    String category = '';
    for (final entry in ExerciseDB.categories.entries) {
      if (entry.value.contains(exerciseName)) {
        category = entry.key;
        break;
      }
    }

    final grad = _gradient(category);
    final accent = ExerciseIllustration.accentFor(category);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.25),
        gradient: LinearGradient(
          colors: grad,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.15),
            blurRadius: size * 0.2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.25),
        child: Padding(
          padding: EdgeInsets.all(size * 0.12),
          child: ExerciseIllustration(
            exerciseName: exerciseName,
            size: size * 0.76,
          ),
        ),
      ),
    );
  }
}
