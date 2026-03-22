// lib/screens/settings/developer_options_screen.dart
import 'package:flutter/material.dart';
import '../../app.dart' show NudgeTokens;
import '../../storage.dart';

class DeveloperOptionsScreen extends StatefulWidget {
  const DeveloperOptionsScreen({super.key});

  @override
  State<DeveloperOptionsScreen> createState() => _DeveloperOptionsScreenState();
}

class _DeveloperOptionsScreenState extends State<DeveloperOptionsScreen> {
  bool _seeding = false;
  String _status = '';

  Future<void> _seedAll() async {
    setState(() { _seeding = true; _status = 'Seeding data…'; });
    try {
      await _seedGym();
      setState(() => _status = 'Gym ✓ — seeding Finance…');
      await _seedFinance();
      setState(() => _status = 'Finance ✓ — seeding Food…');
      await _seedFood();
      setState(() => _status = 'Food ✓ — seeding Pomodoro…');
      await _seedPomodoro();
      setState(() => _status = 'Pomodoro ✓ — seeding Habits…');
      await _seedHabits();
      setState(() => _status = 'Habits ✓ — seeding Movies & Books…');
      await _seedMovies();
      await _seedBooks();
      setState(() { _seeding = false; _status = 'All modules seeded!'; });
    } catch (e) {
      setState(() { _seeding = false; _status = 'Error: $e'; });
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NudgeTokens.surface,
        title: const Text('Clear all test data?',
            style: TextStyle(color: NudgeTokens.red, fontWeight: FontWeight.w800)),
        content: const Text('This will delete ALL data in every module.',
            style: TextStyle(color: NudgeTokens.textMid, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear', style: TextStyle(color: NudgeTokens.red))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() { _seeding = true; _status = 'Clearing…'; });
    await AppStorage.gymBox.put('workouts', <dynamic>[]);
    await AppStorage.gymBox.put('weigh_ins', <dynamic>[]);
    await AppStorage.financeBox.put('expenses', <dynamic>[]);
    await AppStorage.foodBox.put('food', <dynamic>[]);
    await AppStorage.pomodoroBox.put('projects', <dynamic>[]);
    await AppStorage.pomodoroBox.put('logs', <dynamic>[]);
    await AppStorage.protectedBox.put('habits', <dynamic>[]);
    await AppStorage.protectedBox.put('habit_logs', <String, dynamic>{});
    await AppStorage.moviesBox.put('movies', <dynamic>[]);
    await AppStorage.booksBox.put('books', <dynamic>[]);
    setState(() { _seeding = false; _status = 'All data cleared.'; });
  }

  // ── Gym ─────────────────────────────────────────────────────────────────────

  Future<void> _seedGym() async {
    final now = DateTime.now();
    final workouts = <Map<String, dynamic>>[];
    // 3 weeks of workouts, ~4 per week
    final schedule = [1, 3, 5, 7, 8, 10, 12, 14, 15, 17, 19, 21];
    final plans = [
      {
        'name': 'Push',
        'exercises': [
          {'name': 'Bench Press', 'sets': [
            {'reps': 8, 'weight': 80.0, 'done': true},
            {'reps': 8, 'weight': 82.5, 'done': true},
            {'reps': 6, 'weight': 85.0, 'done': true},
          ]},
          {'name': 'Incline Dumbbell Press', 'sets': [
            {'reps': 10, 'weight': 30.0, 'done': true},
            {'reps': 10, 'weight': 32.5, 'done': true},
            {'reps': 8,  'weight': 32.5, 'done': true},
          ]},
          {'name': 'Overhead Press', 'sets': [
            {'reps': 8, 'weight': 55.0, 'done': true},
            {'reps': 8, 'weight': 57.5, 'done': true},
            {'reps': 6, 'weight': 60.0, 'done': true},
          ]},
          {'name': 'Lateral Raises', 'sets': [
            {'reps': 15, 'weight': 12.0, 'done': true},
            {'reps': 15, 'weight': 12.0, 'done': true},
            {'reps': 12, 'weight': 14.0, 'done': true},
          ]},
          {'name': 'Tricep Rope Pushdown', 'sets': [
            {'reps': 12, 'weight': 25.0, 'done': true},
            {'reps': 12, 'weight': 27.5, 'done': true},
            {'reps': 10, 'weight': 27.5, 'done': true},
          ]},
        ],
      },
      {
        'name': 'Pull',
        'exercises': [
          {'name': 'Deadlift', 'sets': [
            {'reps': 5, 'weight': 120.0, 'done': true},
            {'reps': 5, 'weight': 125.0, 'done': true},
            {'reps': 3, 'weight': 130.0, 'done': true},
          ]},
          {'name': 'Barbell Row', 'sets': [
            {'reps': 8, 'weight': 70.0, 'done': true},
            {'reps': 8, 'weight': 75.0, 'done': true},
            {'reps': 6, 'weight': 75.0, 'done': true},
          ]},
          {'name': 'Lat Pulldown', 'sets': [
            {'reps': 10, 'weight': 60.0, 'done': true},
            {'reps': 10, 'weight': 65.0, 'done': true},
            {'reps': 8,  'weight': 65.0, 'done': true},
          ]},
          {'name': 'Bicep Curl (Barbell)', 'sets': [
            {'reps': 12, 'weight': 32.5, 'done': true},
            {'reps': 10, 'weight': 35.0, 'done': true},
            {'reps': 10, 'weight': 35.0, 'done': true},
          ]},
          {'name': 'Face Pulls', 'sets': [
            {'reps': 15, 'weight': 20.0, 'done': true},
            {'reps': 15, 'weight': 22.5, 'done': true},
            {'reps': 12, 'weight': 22.5, 'done': true},
          ]},
        ],
      },
      {
        'name': 'Legs',
        'exercises': [
          {'name': 'Squat', 'sets': [
            {'reps': 5, 'weight': 100.0, 'done': true},
            {'reps': 5, 'weight': 105.0, 'done': true},
            {'reps': 3, 'weight': 110.0, 'done': true},
          ]},
          {'name': 'Romanian Deadlift', 'sets': [
            {'reps': 10, 'weight': 70.0, 'done': true},
            {'reps': 10, 'weight': 72.5, 'done': true},
            {'reps': 8,  'weight': 75.0, 'done': true},
          ]},
          {'name': 'Leg Press', 'sets': [
            {'reps': 12, 'weight': 140.0, 'done': true},
            {'reps': 12, 'weight': 150.0, 'done': true},
            {'reps': 10, 'weight': 160.0, 'done': true},
          ]},
          {'name': 'Leg Extension', 'sets': [
            {'reps': 15, 'weight': 50.0, 'done': true},
            {'reps': 15, 'weight': 55.0, 'done': true},
            {'reps': 12, 'weight': 55.0, 'done': true},
          ]},
          {'name': 'Calf Raises', 'sets': [
            {'reps': 20, 'weight': 60.0, 'done': true},
            {'reps': 20, 'weight': 60.0, 'done': true},
            {'reps': 15, 'weight': 70.0, 'done': true},
          ]},
        ],
      },
    ];

    for (int i = 0; i < schedule.length; i++) {
      final daysAgo = schedule[i];
      final day = now.subtract(Duration(days: daysAgo));
      final dayIso = '${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}';
      final plan = plans[i % plans.length];
      final started = day.copyWith(hour: 7, minute: 30);
      workouts.add({
        'id': 'dev_${dayIso}_$i',
        'dayIso': dayIso,
        'createdAt': started.toIso8601String(),
        'updatedAt': started.add(const Duration(hours: 1, minutes: 15)).toIso8601String(),
        'startedAt': started.toIso8601String(),
        'durationSeconds': 4200 + (i * 120),
        'note': i % 3 == 0 ? 'Felt strong today. PRd on main lift.' : '',
        'calories': 350 + (i * 15),
        'exercises': plan['exercises'],
        'cardio': <dynamic>[],
      });
    }

    // Weigh-ins for past 3 weeks
    final weighIns = <Map<String, dynamic>>[];
    final weights = [81.2, 80.8, 80.5, 80.9, 80.3, 80.1, 79.8, 79.6, 80.0, 79.5, 79.2, 79.4, 79.0, 78.8];
    for (int i = 0; i < weights.length; i++) {
      final day = now.subtract(Duration(days: i * 1 + 1));
      final dayIso = '${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}';
      weighIns.add({'dayIso': dayIso, 'weightKg': weights[i]});
    }

    final existing = (AppStorage.gymBox.get('workouts', defaultValue: <dynamic>[]) as List)
        .cast<dynamic>().where((w) => !(w as Map)['id'].toString().startsWith('dev_')).toList();
    await AppStorage.gymBox.put('workouts', [...existing, ...workouts]);
    final existingW = (AppStorage.gymBox.get('weigh_ins', defaultValue: <dynamic>[]) as List).cast<dynamic>().toList();
    await AppStorage.gymBox.put('weigh_ins', [...existingW, ...weighIns]);
  }

  // ── Finance ──────────────────────────────────────────────────────────────────

  Future<void> _seedFinance() async {
    final now = DateTime.now();
    final categories = ['Food', 'Transport', 'Entertainment', 'Shopping', 'Utilities', 'Health'];
    final merchants = {
      'Food': ['Tesco', 'Lidl', 'Pret A Manger', 'Nandos', 'Uber Eats', 'Deliveroo'],
      'Transport': ['TfL', 'Uber', 'Shell', 'National Rail', 'Bolt'],
      'Entertainment': ['Netflix', 'Spotify', 'Cinema', 'Steam', 'YouTube Premium'],
      'Shopping': ['Amazon', 'ASOS', 'Zara', 'H&M', 'Apple Store'],
      'Utilities': ['EDF Energy', 'Thames Water', 'BT Internet', 'Council Tax'],
      'Health': ['Gym Membership', 'Pharmacy', 'Dentist', 'Holland & Barrett'],
    };
    final amounts = {
      'Food': [4.5, 8.2, 12.5, 22.0, 15.3, 18.9, 6.7],
      'Transport': [3.5, 12.0, 45.0, 28.5, 8.0],
      'Entertainment': [13.99, 9.99, 12.5, 14.99, 10.99],
      'Shopping': [29.99, 45.0, 65.0, 19.99, 120.0],
      'Utilities': [85.0, 35.0, 42.5, 110.0],
      'Health': [55.0, 8.5, 95.0, 22.0],
    };
    final expenses = <Map<String, dynamic>>[];
    for (int i = 0; i < 45; i++) {
      final day = now.subtract(Duration(days: i));
      final cat = categories[i % categories.length];
      final merchantList = merchants[cat]!;
      final amountList = amounts[cat]!;
      expenses.add({
        'id': 'dev_exp_$i',
        'date': day.toIso8601String(),
        'amount': amountList[i % amountList.length],
        'category': cat,
        'merchant': merchantList[i % merchantList.length],
        'note': '',
        'source': 'manual',
      });
    }
    final existing = (AppStorage.financeBox.get('expenses', defaultValue: <dynamic>[]) as List)
        .cast<dynamic>().where((e) => !(e as Map)['id'].toString().startsWith('dev_')).toList();
    await AppStorage.financeBox.put('expenses', [...existing, ...expenses]);
    // Set a budget
    await AppStorage.settingsBox.put('target_budget', 1500.0);
  }

  // ── Food ─────────────────────────────────────────────────────────────────────

  Future<void> _seedFood() async {
    final now = DateTime.now();
    final meals = <Map<String, dynamic>>[];
    final mealData = [
      // breakfast, lunch, dinner, snack
      [
        {'name': 'Oats with Banana', 'kcal': 380, 'protein': 12.0, 'carbs': 68.0, 'fat': 7.0, 'meal': 'Breakfast'},
        {'name': 'Chicken Rice Bowl', 'kcal': 520, 'protein': 42.0, 'carbs': 55.0, 'fat': 9.0, 'meal': 'Lunch'},
        {'name': 'Salmon with Vegetables', 'kcal': 490, 'protein': 38.0, 'carbs': 30.0, 'fat': 22.0, 'meal': 'Dinner'},
        {'name': 'Greek Yogurt', 'kcal': 180, 'protein': 15.0, 'carbs': 20.0, 'fat': 3.5, 'meal': 'Snack'},
      ],
      [
        {'name': 'Scrambled Eggs Toast', 'kcal': 420, 'protein': 22.0, 'carbs': 40.0, 'fat': 16.0, 'meal': 'Breakfast'},
        {'name': 'Tuna Wrap', 'kcal': 450, 'protein': 34.0, 'carbs': 48.0, 'fat': 10.0, 'meal': 'Lunch'},
        {'name': 'Beef Stir Fry', 'kcal': 580, 'protein': 40.0, 'carbs': 45.0, 'fat': 20.0, 'meal': 'Dinner'},
        {'name': 'Protein Shake', 'kcal': 160, 'protein': 30.0, 'carbs': 8.0, 'fat': 2.5, 'meal': 'Snack'},
      ],
    ];

    for (int day = 0; day < 14; day++) {
      final date = now.subtract(Duration(days: day));
      final dayIso = '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
      final plan = mealData[day % mealData.length];
      for (int m = 0; m < plan.length; m++) {
        final entry = Map<String, dynamic>.from(plan[m]);
        entry['id'] = 'dev_food_${day}_$m';
        entry['date'] = dayIso;
        entry['servings'] = 1.0;
        meals.add(entry);
      }
    }

    final existing = (AppStorage.foodBox.get('food', defaultValue: <dynamic>[]) as List)
        .cast<dynamic>().where((e) => !(e as Map)['id'].toString().startsWith('dev_')).toList();
    await AppStorage.foodBox.put('food', [...existing, ...meals]);
    // Set calorie goal
    await AppStorage.settingsBox.put('calorie_goal', 2200);
  }

  // ── Pomodoro ─────────────────────────────────────────────────────────────────

  Future<void> _seedPomodoro() async {
    final now = DateTime.now();
    const projectId = 'dev_proj_1';
    // Project
    final projects = [
      {
        'id': projectId,
        'name': 'Side Project — Nudge',
        'color': 0xFF7C4DFF,
        'totalSessions': 28,
        'totalMinutes': 1400,
        'createdAt': now.subtract(const Duration(days: 21)).toIso8601String(),
      },
      {
        'id': 'dev_proj_2',
        'name': 'Study — Algorithms',
        'color': 0xFF39D98A,
        'totalSessions': 14,
        'totalMinutes': 700,
        'createdAt': now.subtract(const Duration(days: 14)).toIso8601String(),
      },
    ];
    final logs = <Map<String, dynamic>>[];
    for (int i = 0; i < 21; i++) {
      final day = now.subtract(Duration(days: i));
      final sessions = i % 3 == 0 ? 4 : (i % 3 == 1 ? 3 : 2);
      for (int s = 0; s < sessions; s++) {
        logs.add({
          'id': 'dev_pom_${i}_$s',
          'projectId': s % 2 == 0 ? projectId : 'dev_proj_2',
          'date': day.toIso8601String(),
          'durationMinutes': 50,
          'type': 'work',
        });
      }
    }
    final existingP = (AppStorage.pomodoroBox.get('projects', defaultValue: <dynamic>[]) as List)
        .cast<dynamic>().where((p) => !(p as Map)['id'].toString().startsWith('dev_')).toList();
    final existingL = (AppStorage.pomodoroBox.get('logs', defaultValue: <dynamic>[]) as List)
        .cast<dynamic>().where((l) => !(l as Map)['id'].toString().startsWith('dev_')).toList();
    await AppStorage.pomodoroBox.put('projects', [...existingP, ...projects]);
    await AppStorage.pomodoroBox.put('logs', [...existingL, ...logs]);
  }

  // ── Habits ───────────────────────────────────────────────────────────────────

  Future<void> _seedHabits() async {
    final now = DateTime.now();
    const habits = [
      {'id': 'dev_h1', 'name': 'Morning Run', 'icon': '🏃', 'color': 0xFF39D98A, 'target': 1},
      {'id': 'dev_h2', 'name': 'Read 20 mins', 'icon': '📚', 'color': 0xFF5AC8FA, 'target': 1},
      {'id': 'dev_h3', 'name': 'No Sugar', 'icon': '🚫', 'color': 0xFFFF4D6A, 'target': 1},
      {'id': 'dev_h4', 'name': 'Meditate', 'icon': '🧘', 'color': 0xFF7C4DFF, 'target': 1},
      {'id': 'dev_h5', 'name': 'Drink 2L Water', 'icon': '💧', 'color': 0xFF5AC8FA, 'target': 1},
    ];
    final logs = <String, dynamic>{};
    for (final habit in habits) {
      final habitId = habit['id'] as String;
      logs[habitId] = <String, dynamic>{};
      for (int day = 0; day < 30; day++) {
        final date = now.subtract(Duration(days: day));
        final dayIso = '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
        // ~80% completion rate, slight variability per habit
        final seed = (day + habits.indexOf(habit)) % 5;
        if (seed != 0) {
          (logs[habitId] as Map)[dayIso] = 1;
        }
      }
    }

    final existingH = (AppStorage.protectedBox.get('habits', defaultValue: <dynamic>[]) as List)
        .cast<dynamic>().where((h) => !(h as Map)['id'].toString().startsWith('dev_')).toList();
    final existingL = Map<String, dynamic>.from(
        AppStorage.protectedBox.get('habit_logs', defaultValue: <String, dynamic>{}) as Map);
    // Merge logs
    for (final entry in logs.entries) {
      if (!existingL.containsKey(entry.key)) {
        existingL[entry.key] = entry.value;
      }
    }
    await AppStorage.protectedBox.put('habits', [...existingH, ...habits]);
    await AppStorage.protectedBox.put('habit_logs', existingL);
  }

  // ── Movies ───────────────────────────────────────────────────────────────────

  Future<void> _seedMovies() async {
    final movies = [
      {'id': 'dev_m1', 'title': 'Dune: Part Two', 'year': 2024, 'rating': 9, 'status': 'watched', 'genre': 'Sci-Fi'},
      {'id': 'dev_m2', 'title': 'Oppenheimer', 'year': 2023, 'rating': 10, 'status': 'watched', 'genre': 'Drama'},
      {'id': 'dev_m3', 'title': 'The Substance', 'year': 2024, 'rating': 8, 'status': 'watched', 'genre': 'Horror'},
      {'id': 'dev_m4', 'title': 'Alien: Romulus', 'year': 2024, 'rating': 7, 'status': 'watched', 'genre': 'Sci-Fi'},
      {'id': 'dev_m5', 'title': 'Gladiator II', 'year': 2024, 'rating': 0, 'status': 'want_to_watch', 'genre': 'Action'},
      {'id': 'dev_m6', 'title': 'Mickey 17', 'year': 2025, 'rating': 0, 'status': 'want_to_watch', 'genre': 'Sci-Fi'},
    ];
    final existing = (AppStorage.moviesBox.get('movies', defaultValue: <dynamic>[]) as List)
        .cast<dynamic>().where((m) => !(m as Map)['id'].toString().startsWith('dev_')).toList();
    await AppStorage.moviesBox.put('movies', [...existing, ...movies]);
  }

  // ── Books ────────────────────────────────────────────────────────────────────

  Future<void> _seedBooks() async {
    final books = [
      {'id': 'dev_b1', 'title': 'Atomic Habits', 'author': 'James Clear', 'pages': 320, 'currentPage': 320, 'status': 'read', 'rating': 9},
      {'id': 'dev_b2', 'title': 'Deep Work', 'author': 'Cal Newport', 'pages': 304, 'currentPage': 304, 'status': 'read', 'rating': 10},
      {'id': 'dev_b3', 'title': 'The Pragmatic Programmer', 'author': 'Hunt & Thomas', 'pages': 352, 'currentPage': 200, 'status': 'reading', 'rating': 0},
      {'id': 'dev_b4', 'title': 'Clean Code', 'author': 'Robert C. Martin', 'pages': 431, 'currentPage': 0, 'status': 'want_to_read', 'rating': 0},
      {'id': 'dev_b5', 'title': 'Thinking, Fast and Slow', 'author': 'Daniel Kahneman', 'pages': 499, 'currentPage': 0, 'status': 'want_to_read', 'rating': 0},
    ];
    final existing = (AppStorage.booksBox.get('books', defaultValue: <dynamic>[]) as List)
        .cast<dynamic>().where((b) => !(b as Map)['id'].toString().startsWith('dev_')).toList();
    await AppStorage.booksBox.put('books', [...existing, ...books]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Options'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Warning banner
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: NudgeTokens.amber.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: NudgeTokens.amber.withValues(alpha: 0.35)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: NudgeTokens.amber, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Test data is marked with "dev_" IDs. You can clear it independently without touching real data.',
                    style: TextStyle(color: NudgeTokens.amber, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),

          // Status
          if (_status.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: NudgeTokens.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NudgeTokens.border),
              ),
              child: Row(
                children: [
                  if (_seeding) ...[
                    const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: NudgeTokens.purple),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(_status,
                        style: const TextStyle(color: NudgeTokens.textMid, fontSize: 13)),
                  ),
                ],
              ),
            ),

          // Seed All button
          _DevTile(
            icon: Icons.science_rounded,
            iconColor: NudgeTokens.purple,
            title: 'Seed All Modules',
            subtitle: 'Gym, Finance, Food, Pomodoro, Habits, Movies, Books',
            onTap: _seeding ? null : _seedAll,
          ),
          const SizedBox(height: 8),

          // Individual seeds
          const _SectionLabel('Individual Modules'),
          _DevTile(
            icon: Icons.fitness_center_rounded,
            iconColor: NudgeTokens.gymB,
            title: 'Seed Gym',
            subtitle: '12 workouts over 3 weeks + weigh-ins',
            onTap: _seeding ? null : () async {
              setState(() { _seeding = true; _status = 'Seeding Gym…'; });
              await _seedGym();
              setState(() { _seeding = false; _status = 'Gym seeded.'; });
            },
          ),
          _DevTile(
            icon: Icons.account_balance_wallet_rounded,
            iconColor: NudgeTokens.amber,
            title: 'Seed Finance',
            subtitle: '45 expenses across 6 categories over 45 days',
            onTap: _seeding ? null : () async {
              setState(() { _seeding = true; _status = 'Seeding Finance…'; });
              await _seedFinance();
              setState(() { _seeding = false; _status = 'Finance seeded.'; });
            },
          ),
          _DevTile(
            icon: Icons.restaurant_rounded,
            iconColor: const Color(0xFFFF9800),
            title: 'Seed Food',
            subtitle: '14 days of meals (breakfast, lunch, dinner, snack)',
            onTap: _seeding ? null : () async {
              setState(() { _seeding = true; _status = 'Seeding Food…'; });
              await _seedFood();
              setState(() { _seeding = false; _status = 'Food seeded.'; });
            },
          ),
          _DevTile(
            icon: Icons.timer_rounded,
            iconColor: NudgeTokens.purple,
            title: 'Seed Pomodoro',
            subtitle: '2 projects, 21 days of sessions',
            onTap: _seeding ? null : () async {
              setState(() { _seeding = true; _status = 'Seeding Pomodoro…'; });
              await _seedPomodoro();
              setState(() { _seeding = false; _status = 'Pomodoro seeded.'; });
            },
          ),
          _DevTile(
            icon: Icons.checklist_rounded,
            iconColor: NudgeTokens.green,
            title: 'Seed Habits',
            subtitle: '5 habits with 30 days of logs (~80% completion)',
            onTap: _seeding ? null : () async {
              setState(() { _seeding = true; _status = 'Seeding Habits…'; });
              await _seedHabits();
              setState(() { _seeding = false; _status = 'Habits seeded.'; });
            },
          ),
          _DevTile(
            icon: Icons.local_movies_rounded,
            iconColor: NudgeTokens.blue,
            title: 'Seed Movies & Books',
            subtitle: '6 movies + 5 books',
            onTap: _seeding ? null : () async {
              setState(() { _seeding = true; _status = 'Seeding Movies & Books…'; });
              await _seedMovies();
              await _seedBooks();
              setState(() { _seeding = false; _status = 'Movies & Books seeded.'; });
            },
          ),
          const SizedBox(height: 24),

          // Clear
          _DevTile(
            icon: Icons.delete_sweep_rounded,
            iconColor: NudgeTokens.red,
            title: 'Clear All Test Data',
            subtitle: 'Removes all data (including non-dev_ entries)',
            onTap: _seeding ? null : _clearAll,
            danger: true,
          ),
        ],
      ),
    );
  }
}

// ─── Dev tile ─────────────────────────────────────────────────────────────────

class _DevTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool danger;

  const _DevTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: danger ? NudgeTokens.red.withValues(alpha: 0.06) : NudgeTokens.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: danger ? NudgeTokens.red.withValues(alpha: 0.25) : NudgeTokens.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: danger ? NudgeTokens.red : Colors.white,
                        )),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: NudgeTokens.textLow,
                        )),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: danger ? NudgeTokens.red.withValues(alpha: 0.5) : NudgeTokens.textLow,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: NudgeTokens.textLow,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
