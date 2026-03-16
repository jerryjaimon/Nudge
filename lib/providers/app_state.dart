import 'package:flutter/material.dart';
import '../models/card_model.dart';
import '../models/card_type.dart';
import '../services/storage_service.dart';

enum LightState { red, orange, green, grey }

enum CardStatus {
  notDue,
  due,
  critical,
  completed,
  counter,
}

class AppState extends ChangeNotifier {
  List<TrackerCard> _cards = [];
  List<TrackerCard> get cards => _cards;

  AppState() {
    _loadCards();
  }

  /// Public helper so UI can tint cards without duplicating logic.
  CardStatus statusFor(TrackerCard card) {
    if (card.type == CardType.counter) return CardStatus.counter;
    if (_isCompletedForPeriod(card)) return CardStatus.completed;
    if (_isCritical(card)) return CardStatus.critical;
    if (_isDue(card)) return CardStatus.due;
    return CardStatus.notDue;
  }

  int weeklyProgress(TrackerCard card) => _getWeeklyProgress(card);

  void _loadCards() {
    _cards = StorageService.getAllCards();
    _reconcileStreaks();
    _sortCards();
    notifyListeners();
  }

  void _reconcileStreaks() {
    // Keeps streaks honest if the user hasn't opened the app for a while.
    final now = DateTime.now();
    for (final card in _cards) {
      if (card.type == CardType.counter) continue;

      if (card.frequency == Frequency.daily) {
        if (card.lastCompleted == null) {
          if (card.currentStreak != 0) {
            card.currentStreak = 0;
            card.save();
          }
          continue;
        }
        final last = card.lastCompleted!;
        final isToday = _isSameDay(last, now);
        final isYesterday = _isSameDay(last, now.subtract(const Duration(days: 1)));

        if (!isToday && !isYesterday && card.currentStreak != 0) {
          card.currentStreak = 0;
          card.save();
        }
      }

      if (card.frequency == Frequency.weekly) {
        if (card.lastCompleted == null) continue;
        // If we haven't completed a target week in more than 1 week, streak is broken.
        final lastKey = _weekKey(card.lastCompleted!);
        final currentKey = _weekKey(now);
        final gap = _weekGap(lastKey, currentKey);
        if (gap > 1 && card.currentStreak != 0) {
          card.currentStreak = 0;
          card.save();
        }
      }
    }
  }

  void _sortCards() {
    _cards.sort((a, b) {
      final aCritical = _isCritical(a);
      final bCritical = _isCritical(b);
      if (aCritical && !bCritical) return -1;
      if (!aCritical && bCritical) return 1;

      final aDue = _isDue(a);
      final bDue = _isDue(b);
      if (aDue && !bDue) return -1;
      if (!aDue && bDue) return 1;

      final aPassive = a.type != CardType.habit;
      final bPassive = b.type != CardType.habit;

      if (aPassive && !bPassive) return 1; // Habits first
      if (!aPassive && bPassive) return -1;

      return 0;
    });
  }

  LightState get lightState {
    if (_cards.isEmpty) return LightState.grey;

    bool anyDue = false;
    bool allDueDone = true;

    for (final card in _cards) {
      if (card.type == CardType.counter) continue;

      if (_isDue(card)) {
        anyDue = true;
        if (_isCritical(card)) return LightState.orange;
        if (!_isCompletedForPeriod(card)) allDueDone = false;
      }
    }

    if (!anyDue) return LightState.grey;
    if (!allDueDone) return LightState.red;
    return LightState.green;
  }

  bool _isDue(TrackerCard card) {
    if (card.type == CardType.counter) return false;
    if (_isCompletedForPeriod(card)) return false;

    if (card.frequency == Frequency.daily) return !card.isCompletedToday;
    if (card.frequency == Frequency.weekly) return _getWeeklyProgress(card) < card.target;

    return false;
  }

  // Orange: “last valid day” (kept mainly for weekly tension)
  bool _isCritical(TrackerCard card) {
    if (card.type == CardType.counter) return false;
    if (_isCompletedForPeriod(card)) return false;

    final now = DateTime.now();

    // Daily: show as red when due (keeps red/orange distinct)
    if (card.frequency == Frequency.daily) return false;

    if (card.frequency == Frequency.weekly) {
      final needed = card.target - _getWeeklyProgress(card);
      final daysLeft = _daysRemainingInWeek(now);
      return needed >= daysLeft;
    }

    return false;
  }

  bool _isCompletedForPeriod(TrackerCard card) {
    if (card.frequency == Frequency.daily) return card.isCompletedToday;
    return _getWeeklyProgress(card) >= card.target;
  }

  int _getWeeklyProgress(TrackerCard card) {
    final now = DateTime.now();
    final currentKey = _weekKey(now);
    final uniqueDays = <String>{};

    for (final date in card.history) {
      if (_weekKey(date) != currentKey) continue;
      uniqueDays.add(_dayKey(date));
    }

    return uniqueDays.length;
  }

  int _getWeeklyProgressForWeek(TrackerCard card, String weekKey) {
    final uniqueDays = <String>{};
    for (final date in card.history) {
      if (_weekKey(date) != weekKey) continue;
      uniqueDays.add(_dayKey(date));
    }
    return uniqueDays.length;
  }

  int _daysRemainingInWeek(DateTime date) => 7 - date.weekday + 1;

  String _dayKey(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  /// ISO-like week key (year + week index) with Monday as first day.
  String _weekKey(DateTime date) {
    final thursday = date.add(Duration(days: 4 - (date.weekday == 7 ? 0 : date.weekday)));
    final yearStart = DateTime(thursday.year, 1, 1);
    final week = (thursday.difference(yearStart).inDays / 7).floor() + 1;
    return "${thursday.year}-W${week.toString().padLeft(2, '0')}";
  }

  int _weekGap(String a, String b) {
    if (a == b) return 0;
    final ay = int.parse(a.split('-W')[0]);
    final aw = int.parse(a.split('-W')[1]);
    final by = int.parse(b.split('-W')[0]);
    final bw = int.parse(b.split('-W')[1]);
    return (by - ay) * 53 + (bw - aw);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ACTIONS

  Future<void> addCard(TrackerCard card) async {
    await StorageService.saveCard(card);
    _loadCards();
  }

  Future<void> deleteCard(String id) async {
    await StorageService.deleteCard(id);
    _loadCards();
  }

  Future<void> incrementCounter(TrackerCard card, {int minutes = 0}) async {
    card.count++;
    if (minutes > 0) card.totalMinutes += minutes;
    await card.save();
    notifyListeners();
  }

  Future<void> toggleHabit(TrackerCard card) async {
    // No undo. If already complete for the period, ignore.
    if (card.frequency == Frequency.daily && _isCompletedForPeriod(card)) return;
    if (card.frequency == Frequency.weekly && _getWeeklyProgress(card) >= card.target) return;

    final now = DateTime.now();

    // Same-day double taps are ignored (daily & weekly).
    if (card.history.isNotEmpty && _isSameDay(card.history.last, now)) return;

    card.lastCompleted = now;
    card.history.add(now);

    if (card.frequency == Frequency.daily) {
      final prev = card.history.length >= 2 ? card.history[card.history.length - 2] : null;
      final wasYesterday = prev != null && _isSameDay(prev, now.subtract(const Duration(days: 1)));
      card.currentStreak = wasYesterday ? (card.currentStreak + 1) : 1;
    } else {
      // Weekly streak = consecutive weeks where target was met.
      if (_getWeeklyProgress(card) == card.target) {
        final prevWeekKey = _weekKey(now.subtract(const Duration(days: 7)));
        final prevMet = _getWeeklyProgressForWeek(card, prevWeekKey) >= card.target;
        card.currentStreak = prevMet ? (card.currentStreak + 1) : 1;
        card.lastCompleted = now; // marks the “week completed” moment
      }
    }

    if (card.currentStreak > card.bestStreak) card.bestStreak = card.currentStreak;

    await card.save();
    _loadCards();
  }

  Future<void> addWeightEntry(TrackerCard card, double weight) async {
    card.weightHistory.add(weight);
    await card.save();
    notifyListeners();
  }

  Future<void> addMediaEntry(TrackerCard card, int minutes, String title) async {
    card.totalMinutes += minutes;
    card.count++;
    await card.save();
    notifyListeners();
  }

  Future<void> addTimeEntry(TrackerCard card, int seconds) async {
    card.durationSeconds += seconds;
    await card.save();
    notifyListeners();
  }
}
