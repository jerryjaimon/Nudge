// lib/screens/gym/calories.dart
class Calories {
  // Very rough MET values (good enough for a tracker, not medical advice).
  static const Map<String, double> cardioMET = {
    'Walking': 3.5,
    'Walking (Incline)': 5.0,
    'Jogging': 7.0,
    'Running': 9.8,
    'Cycling (Light)': 5.5,
    'Cycling (Moderate)': 7.5,
    'Cycling (Hard)': 10.0,
    'Rowing (Moderate)': 7.0,
    'Elliptical': 6.5,
    'Stair Climber': 8.5,
    'Jump Rope': 12.0,
    'Swimming': 8.0,
    'HIIT': 11.0,
  };

  // Strength training MET (general lifting)
  static const double strengthMET = 3.5;

  // Calories/min = (MET * 3.5 * weightKg) / 200
  static double caloriesForMET({
    required double met,
    required double weightKg,
    required double minutes,
  }) {
    final calsPerMin = (met * 3.5 * weightKg) / 200.0;
    return calsPerMin * minutes;
  }

  static double strengthCalories({
    required double weightKg,
    required double minutes,
  }) {
    return caloriesForMET(met: strengthMET, weightKg: weightKg, minutes: minutes);
  }

  static double cardioCalories({
    required String activity,
    required double weightKg,
    required double minutes,
  }) {
    final met = cardioMET[activity] ?? 6.0;
    return caloriesForMET(met: met, weightKg: weightKg, minutes: minutes);
  }
}
