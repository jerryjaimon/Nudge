// lib/utils/ai_data_sanitiser.dart
//
// Strips sensitive fields from data before it is sent to any AI model.
// Call sanitiseForAI() on structured maps, sanitisePrompt() on raw text.

class AiDataSanitiser {
  // ── Hard exclusions — always removed regardless of caller ─────────────────
  static const _hardExcludeKeys = {
    'mood', 'mood_entries', 'journal', 'journal_text', 'journal_entry',
    'sms', 'sms_content', 'raw_sms', 'message_body',
    'gps_route', 'gps_routes', 'route_points', 'polyline', 'gps_path',
    'blood_glucose', 'blood_pressure', 'blood_oxygen', 'spo2',
    'heart_rate_raw', 'ecg', 'hba1c',
  };

  // ── Soft exclusions — stripped by default, callers may not opt back in ────
  static const _softExcludeKeys = {
    'name', 'full_name', 'first_name', 'last_name', 'display_name',
    'account_number', 'iban', 'sort_code', 'card_number',
    'amount', 'transaction_amount', 'exact_amount',
    'steps', 'step_count',          // precise counts — use ranges instead
    'lat', 'lng', 'latitude', 'longitude', 'coordinates', 'location',
    'event_date', 'specific_date',
  };

  /// Recursively sanitise a [Map] before it is embedded in an AI prompt.
  /// Returns a new map with sensitive fields removed.
  static Map<String, dynamic> sanitiseForAI(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    for (final entry in data.entries) {
      final key = entry.key.toLowerCase();

      if (_hardExcludeKeys.contains(key)) continue;
      if (_softExcludeKeys.contains(key)) continue;

      final value = entry.value;
      if (value is Map<String, dynamic>) {
        result[entry.key] = sanitiseForAI(value);
      } else if (value is List) {
        result[entry.key] = _sanitiseList(value);
      } else {
        result[entry.key] = value;
      }
    }
    return result;
  }

  static List<dynamic> _sanitiseList(List<dynamic> list) {
    return list.map((item) {
      if (item is Map<String, dynamic>) return sanitiseForAI(item);
      if (item is List) return _sanitiseList(item);
      return item;
    }).toList();
  }

  /// Light-touch sanitise a free-text [prompt].
  /// Removes patterns that look like GPS coordinates, account numbers, etc.
  static String sanitisePrompt(String prompt) {
    // GPS coords: (12.3456, 78.9012) or 12.345678, 78.901234
    prompt = prompt.replaceAll(
      RegExp(r'\b-?\d{1,3}\.\d{5,}\b'),
      '[LOCATION]',
    );
    // Card/account numbers: 16-digit sequences
    prompt = prompt.replaceAll(
      RegExp(r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b'),
      '[ACCOUNT]',
    );
    return prompt;
  }
}
