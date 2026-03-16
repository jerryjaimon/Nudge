// lib/utils/data_seeder.dart
import 'dart:math';
import 'package:hive/hive.dart';
import '../screens/gym/exercise_db.dart';

class DataSeeder {
  static Future<void> seedGymWorkouts(Box gymBox) async {
    final workouts = <Map<String, dynamic>>[];
    final now = DateTime.now();
    final random = Random();

    // Seed 300 days of workouts (approx 1 year with some gaps)
    for (int i = 0; i < 365; i++) {
      // 80% chance of working out on a given day
      if (random.nextDouble() > 0.8) continue;

      final day = now.subtract(Duration(days: i));
      final dayIso = _isoDay(day);
      
      final dayWorkouts = _generateRandomWorkout(dayIso, random);
      workouts.add(dayWorkouts);
    }

    await gymBox.put('workouts', workouts);
  }

  static String _isoDay(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  static Map<String, dynamic> _generateRandomWorkout(String dayIso, Random random) {
    final exercises = <Map<String, dynamic>>[];
    
    // Pick 4-6 random exercises
    final exerciseCount = 4 + random.nextInt(3);
    final selectedNames = (List.from(ExerciseDB.allExercises)..shuffle()).take(exerciseCount).toList();

    for (final name in selectedNames) {
      final sets = <Map<String, dynamic>>[];
      final setCount = 3 + random.nextInt(3);
      
      // Base weight for this exercise on this day
      double baseWeight = 20.0 + random.nextInt(80).toDouble();
      
      for (int s = 0; s < setCount; s++) {
        sets.add({
          'reps': 8 + random.nextInt(5),
          'weight': baseWeight + (random.nextInt(5) * 2.5),
        });
      }
      
      exercises.add({
        'name': name,
        'sets': sets,
      });
    }

    final cardio = <Map<String, dynamic>>[];
    if (random.nextBool()) {
      cardio.add({
        'activity': random.nextBool() ? 'Running' : 'Cycling',
        'minutes': 15 + random.nextInt(30),
        'distanceKm': 2.0 + random.nextInt(8).toDouble(),
      });
    }

    return {
      'id': '${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(10000)}',
      'dayIso': dayIso,
      'createdAt': dayIso,
      'updatedAt': dayIso,
      'exercises': exercises,
      'cardio': cardio,
      'calories': 200.0 + random.nextInt(400),
      'note': 'Seeded workout data for day $dayIso',
    };
  }
}
