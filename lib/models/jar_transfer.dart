import 'package:hive/hive.dart';

part 'jar_transfer.g.dart';

@HiveType(typeId: 13) // Incrementing from 12 as per spec (Part 1, Hive types)
enum JarTransferDirection {
  @HiveField(0)
  toMonthlyBudget,
  @HiveField(1)
  toExternalSavings,
}

@HiveType(typeId: 12)
class JarTransfer extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String categoryId;

  @HiveField(2)
  double amount;

  @HiveField(3)
  JarTransferDirection direction;

  @HiveField(4)
  DateTime date;

  @HiveField(5)
  String? note;

  JarTransfer({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.direction,
    required this.date,
    this.note,
  });
}
