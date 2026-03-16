import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'card_type.dart';

part 'card_model.g.dart';

@HiveType(typeId: 0)
class TrackerCard extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String emoji;

  @HiveField(15)
  int? iconCodePoint; // Material Icon code point

  @HiveField(3)
  final CardType type;

  @HiveField(4)
  int count; // For counters

  @HiveField(5)
  int target; // For habits: times per week/day

  @HiveField(6)
  final Frequency frequency;

  @HiveField(7)
  int currentStreak;

  @HiveField(8)
  int bestStreak;

  @HiveField(9)
  DateTime? lastCompleted;

  @HiveField(10)
  List<DateTime> history; // To track completion dates for weekly logic

  @HiveField(11)
  int totalMinutes; // For smart counters (movies/series)

  @HiveField(12)
  List<double> weightHistory; // For weight tracking

  @HiveField(13)
  int durationSeconds; // For time tracking

  @HiveField(14)
  String metadata; // Generic JSON storage (e.g. Movie Poster URL)

  TrackerCard({
    required this.id,
    required this.title,
    required this.emoji,
    required this.type,
    this.count = 0,
    this.target = 1,
    this.frequency = Frequency.daily,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.lastCompleted,
    List<DateTime>? history,
    this.totalMinutes = 0,
    List<double>? weightHistory,
    this.durationSeconds = 0,
    this.metadata = '',
    this.iconCodePoint,
  }) : history = history ?? [],
       weightHistory = weightHistory ?? [];

  factory TrackerCard.create({
    required String title,
    required String emoji,
    required CardType type,
    int? iconCodePoint,
    int target = 1,
    Frequency frequency = Frequency.daily,
  }) {
    return TrackerCard(
      id: const Uuid().v4(),
      title: title,
      emoji: emoji,
      iconCodePoint: iconCodePoint,
      type: type,
      target: target,
      frequency: frequency,
    );
  }

  // Domain Logic Helper: Check if done today (for daily) or this week (for weekly)
  bool get isCompletedToday {
    if (type == CardType.counter) return false;
    if (lastCompleted == null) return false;
    
    final now = DateTime.now();
    return _isSameDay(lastCompleted!, now);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
