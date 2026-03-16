import 'package:hive/hive.dart';

part 'card_type.g.dart';

@HiveType(typeId: 1)
enum CardType {
  @HiveField(0)
  habit,
  @HiveField(1)
  counter,
  @HiveField(2)
  weight,
  @HiveField(3)
  movie,
  @HiveField(4)
  time,
}

@HiveType(typeId: 2)
enum Frequency {
  @HiveField(0)
  daily,
  @HiveField(1)
  weekly,
}
