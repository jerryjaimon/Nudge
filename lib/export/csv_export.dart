// lib/export/csv_export.dart
import 'package:hive/hive.dart';
import '../storage.dart';

class CsvExport {
  static String _csvEscape(String s) {
    final needs = s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r');
    if (!needs) return s;
    return '"${s.replaceAll('"', '""')}"';
  }

  static String _row(List<dynamic> cols) {
    return cols.map((c) => _csvEscape((c ?? '').toString())).join(',');
  }

  static String _isoOrEmpty(dynamic v) => (v is String) ? v : '';

  static Future<String> exportPomodoroLogs() async {
    final Box b = await AppStorage.getPomodoroBox();
    final raw = (b.get('logs', defaultValue: <dynamic>[]) as List);
    final logs = raw.map((e) => (e as Map).cast<String, dynamic>()).toList();

    final header = _row([
      'id',
      'at',
      'kind',
      'projectId',
      'minutes',
      'day',
      'note',
      'workMinSetting',
      'breakMinSetting',
    ]);

    final rows = <String>[header];

    for (final l in logs) {
      final meta = (l['meta'] is Map) ? (l['meta'] as Map).cast<String, dynamic>() : <String, dynamic>{};
      rows.add(_row([
        l['id'],
        _isoOrEmpty(l['at']),
        l['kind'],
        l['projectId'],
        l['minutes'],
        meta['day'] ?? '',
        meta['note'] ?? '',
        meta['workMinSetting'] ?? '',
        meta['breakMinSetting'] ?? '',
      ]));
    }

    return rows.join('\n');
  }

  static Future<String> exportPomodoroProjects() async {
    final Box b = await AppStorage.getPomodoroBox();
    final raw = (b.get('projects', defaultValue: <dynamic>[]) as List);
    final list = raw.map((e) => (e as Map).cast<String, dynamic>()).toList();

    final header = _row(['id', 'name', 'createdAt', 'updatedAt']);
    final rows = <String>[header];

    for (final p in list) {
      rows.add(_row([
        p['id'],
        p['name'],
        _isoOrEmpty(p['createdAt']),
        _isoOrEmpty(p['updatedAt']),
      ]));
    }

    return rows.join('\n');
  }

  static Future<String> exportGymWorkouts() async {
    final Box b = await AppStorage.getGymBox();
    final raw = (b.get('workouts', defaultValue: <dynamic>[]) as List);
    final list = raw.map((e) => (e as Map).cast<String, dynamic>()).toList();

    final header = _row([
      'workoutId',
      'dayIso',
      'createdAt',
      'updatedAt',
      'sessionMinutes',
      'calories',
      'note',
      'exerciseName',
      'setIndex',
      'reps',
      'weight',
    ]);

    final rows = <String>[header];

    for (final w in list) {
      final exercises = (w['exercises'] as List?) ?? <dynamic>[];
      for (final exAny in exercises) {
        final ex = (exAny as Map).cast<String, dynamic>();
        final name = ex['name'] ?? '';
        final sets = (ex['sets'] as List?) ?? <dynamic>[];
        for (int i = 0; i < sets.length; i++) {
          final s = (sets[i] as Map).cast<String, dynamic>();
          rows.add(_row([
            w['id'],
            w['dayIso'],
            _isoOrEmpty(w['createdAt']),
            _isoOrEmpty(w['updatedAt']),
            w['sessionMinutes'] ?? '',
            w['calories'] ?? '',
            w['note'] ?? '',
            name,
            i + 1,
            s['reps'] ?? '',
            s['weight'] ?? '',
          ]));
        }
        if (sets.isEmpty) {
          rows.add(_row([
            w['id'],
            w['dayIso'],
            _isoOrEmpty(w['createdAt']),
            _isoOrEmpty(w['updatedAt']),
            w['sessionMinutes'] ?? '',
            w['calories'] ?? '',
            w['note'] ?? '',
            name,
            '',
            '',
            '',
          ]));
        }
      }

      if (exercises.isEmpty) {
        rows.add(_row([
          w['id'],
          w['dayIso'],
          _isoOrEmpty(w['createdAt']),
          _isoOrEmpty(w['updatedAt']),
          w['sessionMinutes'] ?? '',
          w['calories'] ?? '',
          w['note'] ?? '',
          '',
          '',
          '',
          '',
        ]));
      }
    }

    return rows.join('\n');
  }

  static Future<String> exportGymCardio() async {
    final Box b = await AppStorage.getGymBox();
    final raw = (b.get('workouts', defaultValue: <dynamic>[]) as List);
    final list = raw.map((e) => (e as Map).cast<String, dynamic>()).toList();

    final header = _row([
      'workoutId',
      'dayIso',
      'activity',
      'minutes',
      'distanceKm',
    ]);

    final rows = <String>[header];

    for (final w in list) {
      final cardio = (w['cardio'] as List?) ?? <dynamic>[];
      for (final cAny in cardio) {
        final c = (cAny as Map).cast<String, dynamic>();
        rows.add(_row([
          w['id'],
          w['dayIso'],
          c['activity'] ?? '',
          c['minutes'] ?? '',
          c['distanceKm'] ?? '',
        ]));
      }
      if (cardio.isEmpty) {
        rows.add(_row([w['id'], w['dayIso'], '', '', '']));
      }
    }

    return rows.join('\n');
  }

  static Future<String> exportProtectedHabits() async {
    final Box b = await AppStorage.getProtectedBox();
    final raw = (b.get('habits', defaultValue: <dynamic>[]) as List);
    final list = raw.map((e) => (e as Map).cast<String, dynamic>()).toList();

    final header = _row(['id', 'name', 'note', 'iconCode', 'createdAt', 'updatedAt']);
    final rows = <String>[header];

    for (final h in list) {
      rows.add(_row([
        h['id'],
        h['name'],
        h['note'] ?? '',
        h['iconCode'] ?? '',
        _isoOrEmpty(h['createdAt']),
        _isoOrEmpty(h['updatedAt']),
      ]));
    }

    return rows.join('\n');
  }

  static Future<String> exportProtectedHabitLogs() async {
    final Box b = await AppStorage.getProtectedBox();
    final raw = b.get('habit_logs', defaultValue: <String, dynamic>{});
    final logs = (raw as Map).cast<String, dynamic>();

    final header = _row(['habitId', 'dayIso', 'count']);
    final rows = <String>[header];

    for (final entry in logs.entries) {
      final habitId = entry.key;
      final per = (entry.value is Map) ? (entry.value as Map).cast<String, dynamic>() : <String, dynamic>{};
      for (final d in per.entries) {
        final dayIso = d.key;
        final v = d.value;
        final n = (v is num) ? v.toInt() : 0;
        rows.add(_row([habitId, dayIso, n]));
      }
      if (per.isEmpty) rows.add(_row([habitId, '', '']));
    }

    return rows.join('\n');
  }

  // If your Movies/Books schemas differ, export will still work “best-effort”.
  static Future<String> exportMoviesRaw() async {
    final Box b = await AppStorage.getMoviesBox();
    final raw = (b.get('movies', defaultValue: <dynamic>[]) as List);
    final list = raw.map((e) => (e as Map).cast<String, dynamic>()).toList();

    final header = _row([
      'id',
      'title',
      'type',
      'language',
      'runtimeMin',
      'releaseYear',
      'watchDay',
      'rewatch',
      'createdAt',
      'updatedAt',
    ]);
    final rows = <String>[header];

    for (final m in list) {
      rows.add(_row([
        m['id'],
        m['title'] ?? '',
        m['type'] ?? '',
        m['language'] ?? '',
        m['runtimeMin'] ?? '',
        m['releaseYear'] ?? '',
        m['watchDay'] ?? '',
        m['rewatch'] ?? '',
        _isoOrEmpty(m['createdAt']),
        _isoOrEmpty(m['updatedAt']),
      ]));
    }

    return rows.join('\n');
  }

  static Future<String> exportBooksRaw() async {
    final Box b = await AppStorage.getBooksBox();
    final booksRaw = (b.get('books', defaultValue: <dynamic>[]) as List);
    final books = booksRaw.map((e) => (e as Map).cast<String, dynamic>()).toList();

    final header = _row([
      'id',
      'title',
      'author',
      'genre',
      'totalPages',
      'startDay',
      'endDay',
      'createdAt',
      'updatedAt',
    ]);
    final rows = <String>[header];

    for (final bk in books) {
      rows.add(_row([
        bk['id'],
        bk['title'] ?? '',
        bk['author'] ?? '',
        bk['genre'] ?? '',
        bk['totalPages'] ?? '',
        bk['startDay'] ?? '',
        bk['endDay'] ?? '',
        _isoOrEmpty(bk['createdAt']),
        _isoOrEmpty(bk['updatedAt']),
      ]));
    }

    return rows.join('\n');
  }

  static Future<String> exportHealthHistory() async {
    final Box b = await AppStorage.getGymBox();
    final raw = (b.get('health_history', defaultValue: <dynamic>[]) as List);
    final history = raw.map((e) => (e as Map).cast<String, dynamic>()).toList();

    final header = _row([
      'dayIso',
      'steps',
      'calories',
      'distance',
    ]);
    final rows = <String>[header];

    for (final h in history) {
      rows.add(_row([
        h['dayIso'] ?? '',
        h['steps'] ?? '',
        h['calories'] ?? '',
        h['distance'] ?? '',
      ]));
    }

    return rows.join('\n');
  }

  static Future<String> exportLocalHealthLogs() async {
    final Box b = await AppStorage.getGymBox();
    final raw = (b.get('local_health_logs', defaultValue: <dynamic>[]) as List);
    final logs = raw.map((e) => (e as Map).cast<String, dynamic>()).toList();

    final header = _row([
      'dayIso',
      'timestamp',
      'steps',
      'calories',
    ]);
    final rows = <String>[header];

    for (final l in logs) {
      rows.add(_row([
        l['dayIso'] ?? '',
        l['timestamp'] ?? '',
        l['steps'] ?? '',
        l['calories'] ?? '',
      ]));
    }

    return rows.join('\n');
  }
}
