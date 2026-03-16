// lib/storage.dart
import 'package:hive/hive.dart';

class AppStorage {
  static const String moviesBoxName = 'movies_box';
  static const String booksBoxName = 'books_box';
  static const String settingsBoxName = 'settings_box';
  static const String protectedBoxName = 'protected_box';
  static const String pomodoroBoxName = 'pomodoro_box';
  static const String gymBoxName = 'gym_box';
  static const String financeBoxName = 'finance_box';
  static const String foodBoxName = 'food_box';
  static const String foodLibraryBoxName = 'food_library_box';
  static const String aiLogsBoxName = 'ai_logs_box';

  static Box? _moviesBox;
  static Box? _booksBox;
  static Box? _settingsBox;
  static Box? _protectedBox;
  static Box? _pomodoroBox;
  static Box? _gymBox;
  static Box? _financeBox;
  static Box? _foodBox;
  static Box? _foodLibraryBox;
  static Box? _aiLogsBox;

  static Box get moviesBox => _moviesBox ??= Hive.box(moviesBoxName);
  static Box get booksBox => _booksBox ??= Hive.box(booksBoxName);
  static Box get settingsBox => _settingsBox ??= Hive.box(settingsBoxName);
  static Box get protectedBox => _protectedBox ??= Hive.box(protectedBoxName);
  static Box get pomodoroBox => _pomodoroBox ??= Hive.box(pomodoroBoxName);
  static Box get gymBox => _gymBox ??= Hive.box(gymBoxName);
  static Box get financeBox => _financeBox ??= Hive.box(financeBoxName);
  static Box get foodBox => _foodBox ??= Hive.box(foodBoxName);
  static Box get foodLibraryBox => _foodLibraryBox ??= Hive.box(foodLibraryBoxName);
  static Box get aiLogsBox => _aiLogsBox ??= Hive.box(aiLogsBoxName);

  static Future<Box> getMoviesBox() async {
    if (_moviesBox != null) return _moviesBox!;
    if (Hive.isBoxOpen(moviesBoxName)) return _moviesBox = Hive.box(moviesBoxName);
    return _moviesBox = await Hive.openBox(moviesBoxName);
  }

  static Future<Box> getBooksBox() async {
    if (_booksBox != null) return _booksBox!;
    if (Hive.isBoxOpen(booksBoxName)) return _booksBox = Hive.box(booksBoxName);
    return _booksBox = await Hive.openBox(booksBoxName);
  }

  static Future<Box> getSettingsBox() async {
    if (_settingsBox != null) return _settingsBox!;
    if (Hive.isBoxOpen(settingsBoxName)) return _settingsBox = Hive.box(settingsBoxName);
    return _settingsBox = await Hive.openBox(settingsBoxName);
  }

  static Future<Box> getProtectedBox() async {
    if (_protectedBox != null) return _protectedBox!;
    if (Hive.isBoxOpen(protectedBoxName)) return _protectedBox = Hive.box(protectedBoxName);
    return _protectedBox = await Hive.openBox(protectedBoxName);
  }

  static Future<Box> getPomodoroBox() async {
    if (_pomodoroBox != null) return _pomodoroBox!;
    if (Hive.isBoxOpen(pomodoroBoxName)) return _pomodoroBox = Hive.box(pomodoroBoxName);
    return _pomodoroBox = await Hive.openBox(pomodoroBoxName);
  }

  static Future<Box> getGymBox() async {
    if (_gymBox != null) return _gymBox!;
    if (Hive.isBoxOpen(gymBoxName)) return _gymBox = Hive.box(gymBoxName);
    return _gymBox = await Hive.openBox(gymBoxName);
  }

  static Future<Box> getFinanceBox() async {
    if (_financeBox != null) return _financeBox!;
    if (Hive.isBoxOpen(financeBoxName)) return _financeBox = Hive.box(financeBoxName);
    return _financeBox = await Hive.openBox(financeBoxName);
  }

  static Future<Box> getFoodBox() async {
    if (_foodBox != null) return _foodBox!;
    if (Hive.isBoxOpen(foodBoxName)) return _foodBox = Hive.box(foodBoxName);
    return _foodBox = await Hive.openBox(foodBoxName);
  }

  static Future<Box> getFoodLibraryBox() async {
    if (_foodLibraryBox != null) return _foodLibraryBox!;
    if (Hive.isBoxOpen(foodLibraryBoxName)) return _foodLibraryBox = Hive.box(foodLibraryBoxName);
    return _foodLibraryBox = await Hive.openBox(foodLibraryBoxName);
  }

  static Future<Box> getAiLogsBox() async {
    if (_aiLogsBox != null) return _aiLogsBox!;
    if (Hive.isBoxOpen(aiLogsBoxName)) return _aiLogsBox = Hive.box(aiLogsBoxName);
    return _aiLogsBox = await Hive.openBox(aiLogsBoxName);
  }

  static Future<void> init() async {
    _moviesBox = await Hive.openBox(moviesBoxName);
    _booksBox = await Hive.openBox(booksBoxName);
    _settingsBox = await Hive.openBox(settingsBoxName);
    _protectedBox = await Hive.openBox(protectedBoxName);
    _pomodoroBox = await Hive.openBox(pomodoroBoxName);
    _gymBox = await Hive.openBox(gymBoxName);
    _financeBox = await Hive.openBox(financeBoxName);
    _foodBox = await Hive.openBox(foodBoxName);
    _foodLibraryBox = await Hive.openBox(foodLibraryBoxName);
    _aiLogsBox = await Hive.openBox(aiLogsBoxName);

    // Movies
    if (!_moviesBox!.containsKey('movies')) {
      await _moviesBox!.put('movies', <dynamic>[]);
    }

    // Books
    if (!_booksBox!.containsKey('books')) {
      await _booksBox!.put('books', <dynamic>[]);
    }
    if (!_booksBox!.containsKey('logs')) {
      await _booksBox!.put('logs', <dynamic>[]);
    }

    // Protected habits (IMPORTANT: do NOT overwrite existing logs)
    if (!_protectedBox!.containsKey('habits')) {
      await _protectedBox!.put('habits', <dynamic>[]);
    }
    if (!_protectedBox!.containsKey('habit_logs')) {
      await _protectedBox!.put('habit_logs', <String, dynamic>{}); // habitId -> {dayIso: count}
    }

    // Pomodoro
    if (!_pomodoroBox!.containsKey('projects')) {
      await _pomodoroBox!.put('projects', <dynamic>[]);
    }
    if (!_pomodoroBox!.containsKey('logs')) {
      await _pomodoroBox!.put('logs', <dynamic>[]);
    }
    if (!_pomodoroBox!.containsKey('timer_work_min')) {
      await _pomodoroBox!.put('timer_work_min', 50);
    }
    if (!_pomodoroBox!.containsKey('timer_break_min')) {
      await _pomodoroBox!.put('timer_break_min', 17);
    }
    if (!_pomodoroBox!.containsKey('timer_sound')) {
      await _pomodoroBox!.put('timer_sound', true);
    }
    if (!_pomodoroBox!.containsKey('active_project_id')) {
      await _pomodoroBox!.put('active_project_id', '');
    }
    // Keep as null when no session
    if (!_pomodoroBox!.containsKey('active_session')) {
      await _pomodoroBox!.put('active_session', null);
    }

    // Gym
    if (!_gymBox!.containsKey('workouts')) {
      await _gymBox!.put('workouts', <dynamic>[]);
    }
    if (!_gymBox!.containsKey('profile')) {
      await _gymBox!.put('profile', <String, dynamic>{'weightKg': 70.0, 'heightCm': 170.0});
    }
    if (!_gymBox!.containsKey('streak_settings')) {
      await _gymBox!.put('streak_settings', <String, dynamic>{'targetDaysPerWeek': 3});
    }
    // Custom exercises
    if (!_gymBox!.containsKey('custom_exercises')) {
      await _gymBox!.put('custom_exercises', <dynamic>[]);
    }
    // Weigh-ins
    if (!_gymBox!.containsKey('weigh_ins')) {
      await _gymBox!.put('weigh_ins', <dynamic>[]);
    }
    // Routines: list of {id, name, exercises: [name, sets: [{reps, weight}]]}
    if (!_gymBox!.containsKey('routines')) {
      await _gymBox!.put('routines', <dynamic>[]);
    }

    // Finance
    if (!_financeBox!.containsKey('expenses')) {
      await _financeBox!.put('expenses', <dynamic>[]);
    }
    if (!_financeBox!.containsKey('budgets')) {
      await _financeBox!.put('budgets', <String, dynamic>{});
    }

    // Food
    if (!_foodBox!.containsKey('food')) {
      await _foodBox!.put('food', <dynamic>[]);
    }

    // Settings
    if (!_settingsBox!.containsKey('theme')) {
      await _settingsBox!.put('theme', 'dark');
    }
    if (!_settingsBox!.containsKey('gemini_api_key')) {
      await _settingsBox!.put('gemini_api_key', '');
    }

    // Migration for enabled modules — ensure all exist if the key is present but incomplete
    if (_settingsBox!.containsKey('enabled_modules')) {
      final current = (_settingsBox!.get('enabled_modules') as List).cast<String>().toSet();
      final defaults = {'gym', 'food', 'finance', 'movies', 'books', 'detox', 'health', 'pomodoro', 'habits'};
      if (!current.containsAll(defaults)) {
        current.addAll(defaults);
        await _settingsBox!.put('enabled_modules', current.toList());
      }
    }
  }
  static String get activeGeminiKey {
    final index = settingsBox.get('active_gemini_key_index', defaultValue: 1) as int;
    return index == 2
        ? settingsBox.get('gemini_api_key_2', defaultValue: '') as String
        : settingsBox.get('gemini_api_key_1', defaultValue: '') as String;
  }

  static Future<void> logAiError(String message) async {
    final box = await getAiLogsBox();
    final logs = (box.get('errors', defaultValue: <dynamic>[]) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    logs.insert(0, {
      'timestamp': DateTime.now().toIso8601String(),
      'message': message,
    });
    // Keep only last 50 logs
    if (logs.length > 50) logs.removeRange(50, logs.length);
    await box.put('errors', logs);
  }

  static bool get hasSeenOnboarding {
    if (settingsBox.get('has_seen_onboarding', defaultValue: false) as bool) return true;
    
    // Treat existing users with actual user data as having already onboarded
    final hasData = (gymBox.get('workouts', defaultValue: []) as List).isNotEmpty ||
        (moviesBox.get('movies', defaultValue: []) as List).isNotEmpty ||
        (booksBox.get('books', defaultValue: []) as List).isNotEmpty ||
        (financeBox.get('expenses', defaultValue: []) as List).isNotEmpty ||
        (foodBox.get('food', defaultValue: []) as List).isNotEmpty ||
        (protectedBox.get('habits', defaultValue: []) as List).isNotEmpty;
        
    if (hasData) {
      settingsBox.put('has_seen_onboarding', true); // persist so we don't check again
      return true;
    }
    return false;
  }
  static set hasSeenOnboarding(bool value) => settingsBox.put('has_seen_onboarding', value);

  static List<String> get enabledModules => (settingsBox.get('enabled_modules', defaultValue: ['gym', 'food', 'finance', 'movies', 'books', 'detox', 'health', 'pomodoro', 'habits']) as List).cast<String>();
  static set enabledModules(List<String> modules) => settingsBox.put('enabled_modules', modules);

  static int get waterGoal => settingsBox.get('target_water_ml', defaultValue: 2000) as int;
  static set waterGoal(int value) => settingsBox.put('target_water_ml', value);

  static double get financeBudget => settingsBox.get('target_budget', defaultValue: 0.0) as double;
  static set financeBudget(double value) => settingsBox.put('target_budget', value);

  static int get gymGoalDays => (gymBox.get('streak_settings', defaultValue: {}) as Map)['targetDaysPerWeek'] ?? 3;
  static set gymGoalDays(int value) {
    final settings = Map<String, dynamic>.from(gymBox.get('streak_settings', defaultValue: {}));
    settings['targetDaysPerWeek'] = value;
    gymBox.put('streak_settings', settings);
  }

  static bool get isHomeListView => settingsBox.get('is_home_list_view', defaultValue: false) as bool;
  static set isHomeListView(bool value) => settingsBox.put('is_home_list_view', value);

  // ── Daily reminder / streak notification ────────────────────────────────────

  /// Whether the daily data-entry reminder is enabled at all.
  static bool get reminderEnabled =>
      settingsBox.get('reminder_enabled', defaultValue: false) as bool;
  static set reminderEnabled(bool v) => settingsBox.put('reminder_enabled', v);

  /// Hour of day (0-23) at which to fire the reminder.
  static int get reminderHour =>
      settingsBox.get('reminder_hour', defaultValue: 20) as int;
  static set reminderHour(int v) => settingsBox.put('reminder_hour', v);

  /// Minute (0-59) at which to fire the reminder.
  static int get reminderMinute =>
      settingsBox.get('reminder_minute', defaultValue: 0) as int;
  static set reminderMinute(int v) => settingsBox.put('reminder_minute', v);

  /// If true the notification is non-dismissable (ongoing) until the user logs
  /// data. If false it is a regular clearable notification.
  static bool get reminderPersistent =>
      settingsBox.get('reminder_persistent', defaultValue: false) as bool;
  static set reminderPersistent(bool v) =>
      settingsBox.put('reminder_persistent', v);

  /// Wipes all data across all local storage boxes
  static Future<void> clearAll() async {
    await moviesBox.clear();
    await booksBox.clear();
    await protectedBox.clear();
    await pomodoroBox.clear();
    await gymBox.clear();
    await financeBox.clear();
    await foodBox.clear();
    await foodLibraryBox.clear();
    await aiLogsBox.clear();
    await settingsBox.clear();
    
    // Re-initialize core structures so the app doesn't crash on empty state getters
    await init();
  }
}
