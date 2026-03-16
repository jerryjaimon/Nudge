import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart' as gai;
import '../storage.dart';

/// Whether to use Google Search grounding (needed for movie auto-fill).
/// Pass this as [typeOverride] when grounded search is required.
enum GeminiGenType { standard, grounded }

/// Unified Gemini gateway.
///
/// Two modes selectable in Settings:
///   - REST (default) — plain HTTP POST to the Gemini REST API, no SDK.
///   - SDK (fallback)  — uses the google_generative_ai package.
///
/// Grounded calls (Google Search tool) always use REST regardless of mode,
/// because the SDK grounding setup is more complex.
class GeminiService {
  static const _base = 'https://generativelanguage.googleapis.com/v1beta/models';

  // ── Stored preferences ───────────────────────────────────────────────────

  /// true  → use google_generative_ai SDK
  /// false → use HTTP REST (default)
  static bool get useSdk =>
      AppStorage.settingsBox.get('gemini_use_sdk', defaultValue: false) as bool;

  static String get storedModel =>
      AppStorage.settingsBox.get('gemini_model', defaultValue: 'gemini-2.5-flash') as String;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Generate text from [prompt] (plus optional [images]).
  ///
  /// [jsonMode]     – request JSON-only output.
  /// [typeOverride] – force grounded search regardless of mode setting.
  static Future<String?> generate({
    required String prompt,
    List<({String mimeType, Uint8List bytes})>? images,
    bool jsonMode = false,
    GeminiGenType? typeOverride,
  }) async {
    final apiKey = AppStorage.activeGeminiKey;
    if (apiKey.isEmpty) return null;

    final grounded = (typeOverride ?? GeminiGenType.standard) == GeminiGenType.grounded;

    // Grounded always uses REST — SDK path is for standard calls only.
    if (grounded || !useSdk) {
      return _restGenerate(
        prompt: prompt,
        images: images,
        jsonMode: jsonMode,
        grounded: grounded,
        apiKey: apiKey,
      );
    } else {
      return _sdkGenerate(
        prompt: prompt,
        images: images,
        jsonMode: jsonMode,
        apiKey: apiKey,
      );
    }
  }

  /// Validate an API key by sending a minimal test prompt via REST.
  static Future<bool> validateKey(String apiKey, String model) async {
    if (apiKey.isEmpty) return false;
    try {
      final body = {
        'contents': [
          {
            'parts': [
              {'text': "Reply with 'ok'."}
            ]
          }
        ]
      };
      final res = await http.post(
        Uri.parse('$_base/$model:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (res.statusCode != 200) {
        print('GEMINI API KEY VALIDATION FAILED: Status ${res.statusCode} - ${res.body}');
        debugPrint('GeminiService.validateKey Failed ($model) Status ${res.statusCode}: ${res.body}');
        AppStorage.logAiError('Key Validation Failed ($model) Status ${res.statusCode}: ${res.body}');
      }
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('GeminiService.validateKey error: $e');
      AppStorage.logAiError('Key Validation Error ($model): $e');
      return false;
    }
  }

  // ── REST implementation ───────────────────────────────────────────────────

  static Future<String?> _restGenerate({
    required String prompt,
    required String apiKey,
    List<({String mimeType, Uint8List bytes})>? images,
    bool jsonMode = false,
    bool grounded = false,
  }) async {
    final model = storedModel;

    // Build content parts
    final List<Map<String, dynamic>> parts = [
      {'text': prompt}
    ];
    if (images != null) {
      for (final img in images) {
        parts.add({
          'inlineData': {
            'mimeType': img.mimeType,
            'data': base64Encode(img.bytes),
          }
        });
      }
    }

    final body = <String, dynamic>{
      'contents': [
        {'parts': parts}
      ],
    };

    if (jsonMode) {
      body['generationConfig'] = {'responseMimeType': 'application/json'};
    }

    if (grounded) {
      body['tools'] = [
        {'googleSearch': {}}
      ];
    }

    try {
      final res = await http.post(
        Uri.parse('$_base/$model:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (res.statusCode != 200) {
        debugPrint('GeminiService REST ${res.statusCode}: ${res.body}');
        AppStorage.logAiError('REST Error ${res.statusCode}: ${res.body}');
        return null;
      }

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;

      final contentParts = candidates[0]['content']?['parts'] as List?;
      if (contentParts == null) return null;

      // Find the first actual text part (skip thought parts if any)
      for (final p in contentParts) {
        final map = p as Map<String, dynamic>;
        if (map['thought'] != true && map['text'] != null) {
          return map['text'] as String;
        }
      }
      // Fallback: first part with text
      for (final p in contentParts) {
        final map = p as Map<String, dynamic>;
        if (map['text'] != null) return map['text'] as String;
      }
      return null;
    } catch (e) {
      debugPrint('GeminiService REST error: $e');
      AppStorage.logAiError('REST Exception: $e');
      return null;
    }
  }

  // ── SDK implementation (fallback) ─────────────────────────────────────────

  static Future<String?> _sdkGenerate({
    required String prompt,
    required String apiKey,
    List<({String mimeType, Uint8List bytes})>? images,
    bool jsonMode = false,
  }) async {
    try {
      final model = gai.GenerativeModel(
        model: storedModel,
        apiKey: apiKey,
        generationConfig: jsonMode
            ? gai.GenerationConfig(responseMimeType: 'application/json')
            : null,
      );

      gai.GenerateContentResponse response;
      if (images != null && images.isNotEmpty) {
        final parts = <gai.Part>[gai.TextPart(prompt)];
        for (final img in images) {
          parts.add(gai.DataPart(img.mimeType, img.bytes));
        }
        response = await model.generateContent([gai.Content.multi(parts)]);
      } else {
        response = await model.generateContent([gai.Content.text(prompt)]);
      }

      return response.text;
    } catch (e) {
      debugPrint('GeminiService SDK error: $e');
      AppStorage.logAiError('SDK Exception: $e');
      return null;
    }
  }
}
