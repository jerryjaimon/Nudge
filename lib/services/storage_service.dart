import 'package:hive_flutter/hive_flutter.dart';
import '../models/card_model.dart';
import '../models/card_type.dart';

class StorageService {
  static const String _boxName = 'tracker_cards';

  static Future<void> init() async {
    await Hive.initFlutter();

    // Guard against double-registration during hot-restart.
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(CardTypeAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(FrequencyAdapter());
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TrackerCardAdapter());

    await Hive.openBox<TrackerCard>(_boxName);
  }

  static Box<TrackerCard> get box => Hive.box<TrackerCard>(_boxName);

  static Future<void> saveCard(TrackerCard card) async {
    await box.put(card.id, card);
  }

  static Future<void> deleteCard(String id) async {
    await box.delete(id);
  }

  static List<TrackerCard> getAllCards() {
    return box.values.toList();
  }
}
