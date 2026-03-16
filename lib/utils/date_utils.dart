// lib/utils/date_utils.dart
import 'package:intl/intl.dart';

class D {
  static final _fmt = DateFormat('yyyy-MM-dd');
  static final _human = DateFormat('EEE, d MMM');

  static String key(DateTime dt) => _fmt.format(DateTime(dt.year, dt.month, dt.day));
  static DateTime parseKey(String k) => DateTime.parse(k);
  static String human(DateTime dt) => _human.format(DateTime(dt.year, dt.month, dt.day));

  static DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static DateTime startOfWeek(DateTime dt) {
    final d = DateTime(dt.year, dt.month, dt.day);
    final wd = d.weekday; // Mon=1..Sun=7
    return d.subtract(Duration(days: wd - 1));
  }
}
