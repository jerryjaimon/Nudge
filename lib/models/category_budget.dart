import 'package:hive/hive.dart';

part 'category_budget.g.dart';

@HiveType(typeId: 10)
class CategoryBudget extends HiveObject {
  @HiveField(0)
  String id; // UUID, generated at creation

  @HiveField(1)
  String name; // e.g. "Groceries"

  @HiveField(2)
  String icon; // emoji string e.g. "🛒"

  @HiveField(3)
  String colourHex; // e.g. "#39D98A" (NudgeTokens colours)

  @HiveField(4)
  double monthlyLimit; // e.g. 200.0

  @HiveField(5)
  bool rolloverEnabled; // if true, carry surplus forward

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  bool isArchived; // soft delete

  CategoryBudget({
    required this.id,
    required this.name,
    required this.icon,
    required this.colourHex,
    required this.monthlyLimit,
    this.rolloverEnabled = false,
    required this.createdAt,
    this.isArchived = false,
  });
}
