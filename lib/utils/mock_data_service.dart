import 'dart:math';
import '../storage.dart';
import '../screens/gym/exercise_db.dart';

class MockDataService {
  static Future<void> populate() async {
    // 1. Wipe everything first
    await AppStorage.clearAll();

    final rand = Random();
    final now = DateTime.now();
    final todayIso = _isoDay(now);

    // 2. Set basic settings and bypass onboarding
    AppStorage.hasSeenOnboarding = true;
    AppStorage.waterGoal = 2500;
    AppStorage.financeBudget = 2000.0;
    AppStorage.gymGoalDays = 4;
    await AppStorage.settingsBox.put('theme', 'neon');
    await AppStorage.settingsBox.put('health_connect_enabled', true);
    
    // Set typical macro targets
    await AppStorage.settingsBox.put('macro_cals', 2150.0);
    await AppStorage.settingsBox.put('macro_protein', 160.0);
    await AppStorage.settingsBox.put('macro_fat', 70.0);
    await AppStorage.settingsBox.put('macro_carbs', 220.0);
    await AppStorage.settingsBox.put('macro_fibre', 32.0);

    // 3. Populate Gym Profile & Settings
    await AppStorage.gymBox.put('profile', <String, dynamic>{
        'name': 'Test User',
        'weightKg': 78.5, 
        'heightCm': 180.0,
        'age': 28,
        'gender': 'male',
        'goal': 'lose',
        'activityLevel': 'moderate',
        'targetWeightKg': 72.0,
    });
    
    // 4. Generate Weigh-ins (Last 6 months)
    final weighIns = <Map<String, dynamic>>[];
    double currentWeight = 85.0;
    for (int i = 180; i >= 0; i -= 7) {
      final wDate = now.subtract(Duration(days: i));
      weighIns.add({
        'dayIso': _isoDay(wDate),
        'weight': (currentWeight + (rand.nextDouble() * 0.5 - 0.2)).clamp(70.0, 100.0),
        'note': 'Weekly weigh-in',
        'timestamp': wDate.millisecondsSinceEpoch,
      });
      currentWeight -= 0.35;
    }
    await AppStorage.gymBox.put('weigh_ins', weighIns);

    // 5. Generate Gym Workouts (Last 30 days)
    final workouts = <Map<String, dynamic>>[];
    for (int i = 30; i >= 0; i--) {
      if (rand.nextDouble() > 0.5) { // 50% chance
        final wDate = now.subtract(Duration(days: i));
        workouts.add(_generateRandomWorkout(_isoDay(wDate), rand));
      }
    }
    // Force one today
    workouts.add(_generateRandomWorkout(todayIso, rand));
    await AppStorage.gymBox.put('workouts', workouts);

    // 6. Generate Health History & Local logs (Activity Rings)
    final healthHistory = <Map<String, dynamic>>[];
    final hcSessions = <String, List<Map<String, dynamic>>>{}; // iso -> sessions
    
    for (int i = 30; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final iso = _isoDay(d);
      
      final steps = 4000 + rand.nextInt(8000).toDouble();
      final calBurned = 200 + rand.nextInt(400).toDouble();
      final dist = (steps * 0.0007);
      
      healthHistory.add({
        'dayIso': iso,
        'steps': steps,
        'walkingDistKm': dist,
        'runningCal': 0.0,
        'runningDistKm': 0.0,
        'workoutCal': calBurned,
        'workoutTimeMin': 45 + rand.nextInt(30),
        'calories': calBurned,
      });

      // Add a random run session for some days
      if (i % 3 == 0) {
          final runStart = DateTime(d.year, d.month, d.day, 7 + rand.nextInt(2), rand.nextInt(60));
          final runEnd = runStart.add(Duration(minutes: 20 + rand.nextInt(20)));
          hcSessions[iso] = [{
            'startTime': runStart.toIso8601String(),
            'endTime': runEnd.toIso8601String(),
            'durationMin': runEnd.difference(runStart).inMinutes.toDouble(),
            'type': 'Running',
            'calories': 150 + rand.nextInt(200),
            'distanceKm': 3.0 + rand.nextInt(4),
            'sourceName': 'Garmin Connect',
          }];
      }
    }
    await AppStorage.gymBox.put('health_history', healthHistory);
    await AppStorage.gymBox.put('hc_sessions', hcSessions);
    
    // Local logs for Today
    await AppStorage.gymBox.put('local_health_logs', [{
        'dayIso': todayIso,
        'timestamp': now.toIso8601String(),
        'steps': 5420.0,
        'calories': 280.0,
    }]);

    // Water logs
    final waterLogs = <Map<String, dynamic>>[];
    for (int i = 14; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        final amount = 1500 + rand.nextInt(1500).toDouble();
        waterLogs.add({
            'dayIso': _isoDay(d),
            'localAmount': amount,
            'healthConnectAmount': 0.0,
            'totalAmount': amount,
        });
    }
    await AppStorage.gymBox.put('water_logs', waterLogs);

    // 7. Generate Finance (Last 30 days)
    final expenses = <Map<String, dynamic>>[];
    final merchants = ['Tesco', 'Starbucks', 'Amazon', 'Netflix', 'Uber', 'Steam', 'Spotify', 'Local Pub', 'Gym', 'Restaurant'];
    final categories = ['Groceries', 'Food', 'Shopping', 'Entertainment', 'Transport', 'Entertainment', 'Entertainment', 'Food', 'Fitness', 'Food'];
    for (int i = 30; i >= 0; i--) {
      int txCount = rand.nextInt(3) + 1;
      for (int t = 0; t < txCount; t++) {
        final fDate = now.subtract(Duration(days: i, hours: rand.nextInt(12)));
        int randIdx = rand.nextInt(merchants.length);
        double amount = -(5.0 + rand.nextDouble() * 45.0);
        expenses.insert(0, {
          'id': 'exp_${i}_$t',
          'amount': amount,
          'merchant': merchants[randIdx],
          'date': fDate.toIso8601String(),
          'category': categories[randIdx],
        });
      }
    }
    await AppStorage.financeBox.put('expenses', expenses);
    // Set budget for current month and last month
    final lastMonth = now.subtract(const Duration(days: 30));
    final budgets = {
        '${now.year}-${now.month.toString().padLeft(2, '0')}': 2000.0,
        '${lastMonth.year}-${lastMonth.month.toString().padLeft(2, '0')}': 1800.0,
    };
    await AppStorage.financeBox.put('budgets', budgets);

    // 8. Generate Food (Last 7 days)
    final foods = <Map<String, dynamic>>[];
    final mealNames = ['Chicken Salad', 'Protein Shake', 'Steak and Rice', 'Oatmeal', 'Eggs on Toast', 'Salmon and Veggies'];
    final mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
    for (int i = 7; i >= 0; i--) {
      for (int m = 0; m < 3; m++) {
        final fDate = now.subtract(Duration(days: i, hours: 8 + (m * 4)));
        int p = 20 + rand.nextInt(30);
        int c = 30 + rand.nextInt(50);
        int f = 10 + rand.nextInt(20);
        int calories = (p * 4) + (c * 4) + (f * 9);
        
        foods.insert(0, {
          'id': 'food_${i}_$m',
          'name': mealNames[rand.nextInt(mealNames.length)],
          'servingsConsumed': 1.0,
          'caloriesPerServing': calories.toDouble(),
          'proteinPerServing': p.toDouble(),
          'carbsPerServing': c.toDouble(),
          'fatPerServing': f.toDouble(),
          'mealType': mealTypes[m % mealTypes.length],
          'timestamp': fDate.toIso8601String(), // Correct key used by FoodService
        });
      }
    }
    await AppStorage.foodBox.put('food', foods);

    // 9. Generate Movies & Books
    final movies = <Map<String, dynamic>>[];
    for (int i = 0; i < 8; i++) {
        movies.add({
            'id': 'm_$i',
            'title': 'Test Movie $i',
            'type': 'Movie',
            'watchDay': _isoDay(now.subtract(Duration(days: i * 3))),
            'runtimeMin': 100 + rand.nextInt(60),
        });
    }
    await AppStorage.moviesBox.put('movies', movies);

    final books = <Map<String, dynamic>>[];
    final bookNames = ['Deep Work', 'Atomic Habits', 'The Hobbit'];
    for (int i = 0; i < bookNames.length; i++) {
        books.add({
            'id': 'b_$i',
            'title': bookNames[i],
            'author': 'Test Author',
            'pagesRead': 50 + rand.nextInt(100),
            'totalPages': 300,
            'startAt': now.subtract(const Duration(days: 20)).toIso8601String(),
        });
    }
    await AppStorage.booksBox.put('books', books);

    // 10. Generate Habits & Pomodoro
    final habits = <Map<String, dynamic>>[];
    final habitLogs = <String, dynamic>{};
    final hConfigs = [('Meditate', 63604), ('No Sugar', 103), ('Steps 10k', 101)];
    for (int i = 0; i < hConfigs.length; i++) {
        final hId = 'h_$i';
        habits.add({
            'id': hId, 'name': hConfigs[i].$1, 'iconCode': hConfigs[i].$2,
            'target': 1, 'type': 'build', 'streak': 12,
        });
        final logs = <String, int>{};
        for (int d = 30; d >= 0; d--) {
            if (rand.nextDouble() > 0.2) logs[_isoDay(now.subtract(Duration(days: d)))] = 1;
        }
        habitLogs[hId] = logs;
    }
    await AppStorage.protectedBox.put('habits', habits);
    await AppStorage.protectedBox.put('habit_logs', habitLogs);

    final pomLogs = <Map<String, dynamic>>[];
    for (int i = 5; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        pomLogs.add({
            'startTime': DateTime(d.year, d.month, d.day, 10, 0).toIso8601String(),
            'durationMin': 25.0,
            'completed': true,
        });
    }
    await AppStorage.pomodoroBox.put('logs', pomLogs);
  }

  static String _isoDay(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  static Map<String, dynamic> _generateRandomWorkout(String dayIso, Random random) {
    final exercises = <Map<String, dynamic>>[];
    
    // Pick 3-5 random exercises
    final exerciseCount = 3 + random.nextInt(3);
    final allNames = ExerciseDB.allExercises.toList();
    allNames.shuffle();
    final selectedNames = allNames.take(exerciseCount).toList();

    for (final name in selectedNames) {
      final sets = <Map<String, dynamic>>[];
      final setCount = 3 + random.nextInt(2);
      
      double baseWeight = 20.0 + random.nextInt(60).toDouble();
      
      for (int s = 0; s < setCount; s++) {
        sets.add({
          'reps': 8 + random.nextInt(5),
          'weight': baseWeight,
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
        'minutes': 15 + random.nextInt(20),
        'distanceKm': 2.0 + random.nextInt(5).toDouble(),
      });
    }

    return {
      'id': 'test_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(1000)}',
      'dayIso': dayIso,
      'createdAt': dayIso,
      'updatedAt': dayIso,
      'exercises': exercises,
      'cardio': cardio,
      'calories': 250.0 + random.nextInt(300),
      'note': 'Test Gym Session',
    };
  }
}
