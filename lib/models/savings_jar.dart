import 'package:hive/hive.dart';

part 'savings_jar.g.dart';

@HiveType(typeId: 11)
class SavingsJar extends HiveObject {
  @HiveField(0)
  String categoryId; // FK -> CategoryBudget.id

  @HiveField(1)
  double balance; // total accumulated surplus in jar

  @HiveField(2)
  double? goalAmount; // optional savings target

  @HiveField(3)
  DateTime lastUpdated;

  SavingsJar({
    required this.categoryId,
    required this.balance,
    this.goalAmount,
    required this.lastUpdated,
  });
}
