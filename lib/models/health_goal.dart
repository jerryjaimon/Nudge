// lib/models/health_goal.dart

class HealthGoal {
  final String id;
  final String title;
  final String description; // Detailed text for AI to understand
  final String category; // 'weight', 'fitness', 'nutrition', 'lifestyle'
  final double targetValue;
  final double currentValue; // Initial value or current state
  final String unit;
  final DateTime startDate;
  final DateTime targetDate;
  final bool isCompleted;

  HealthGoal({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.targetValue,
    this.currentValue = 0,
    required this.unit,
    required this.startDate,
    required this.targetDate,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category,
    'targetValue': targetValue,
    'currentValue': currentValue,
    'unit': unit,
    'startDate': startDate.toIso8601String(),
    'targetDate': targetDate.toIso8601String(),
    'isCompleted': isCompleted,
  };

  factory HealthGoal.fromJson(Map<String, dynamic> json) => HealthGoal(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    category: json['category'],
    targetValue: (json['targetValue'] as num).toDouble(),
    currentValue: (json['currentValue'] as num).toDouble(),
    unit: json['unit'],
    startDate: DateTime.parse(json['startDate']),
    targetDate: DateTime.parse(json['targetDate']),
    isCompleted: json['isCompleted'] ?? false,
  );

  HealthGoal copyWith({
    double? currentValue,
    bool? isCompleted,
  }) => HealthGoal(
    id: id,
    title: title,
    description: description,
    category: category,
    targetValue: targetValue,
    currentValue: currentValue ?? this.currentValue,
    unit: unit,
    startDate: startDate,
    targetDate: targetDate,
    isCompleted: isCompleted ?? this.isCompleted,
  );
}
