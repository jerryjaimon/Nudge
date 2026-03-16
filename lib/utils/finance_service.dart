import 'dart:convert';
import 'package:flutter/services.dart';
import '../storage.dart';
import '../services/indian_bank_sms_parser.dart';

class FinanceService {
  static const MethodChannel _channel = MethodChannel('com.example.nudge/finance');

  // ── Data source setting ───────────────────────────────────────────────────

  /// 'notification' | 'sms' | 'both'
  static String get dataSource =>
      (AppStorage.settingsBox.get('finance_source') as String?) ?? 'notification';

  static Future<void> setDataSource(String source) async {
    await AppStorage.settingsBox.put('finance_source', source);
  }

  // ── Notification sync (Revolut / UK banks) ────────────────────────────────

  static Future<void> syncPendingExpenses() async {
    try {
      await cleanupIrrelevantData();

      final String? jsonStr = await _channel.invokeMethod<String>('getPendingExpenses');
      if (jsonStr == null || jsonStr == '[]') return;

      final List<dynamic> pending = jsonDecode(jsonStr);
      if (pending.isEmpty) return;

      final all = _loadAll();

      for (var p in pending) {
        final map = p as Map<String, dynamic>;
        final title = map['title'] as String? ?? '';
        final text = map['text'] as String? ?? '';
        final ts = map['timestamp'] as String? ?? DateTime.now().toIso8601String();

        final lowerTitle = title.toLowerCase();
        final lowerText = text.toLowerCase();

        if (lowerText.contains('funds added') ||
            lowerTitle.contains('funds added') ||
            lowerText.contains('top-up') ||
            lowerTitle.contains('top-up') ||
            lowerText.contains('cashback') ||
            lowerText.contains('reward')) {
          continue;
        }

        double amount = 0.0;
        String merchant = 'Bank';

        final amountMatch = RegExp(r'[\$£€]\s?(\d+(?:\.\d{2})?)').firstMatch(text);
        if (amountMatch != null) {
          amount = double.tryParse(amountMatch.group(1)!) ?? 0.0;
        } else {
          final fallbackMatch = RegExp(r'(\d+\.\d{2})').firstMatch(text);
          if (fallbackMatch != null) {
            amount = double.tryParse(fallbackMatch.group(1)!) ?? 0.0;
          }
        }
        if (amount == 0.0) continue;

        final atMatch = RegExp(r' at (.+)').firstMatch(text);
        if (atMatch != null) {
          merchant = atMatch.group(1)!.trim();
        } else if (text.toLowerCase().startsWith('paid ')) {
          final toMatch = RegExp(r'paid (.+)').firstMatch(text.toLowerCase());
          if (toMatch != null) {
            merchant = toMatch
                .group(1)!
                .replaceAll(RegExp(r'[\$£€]\s?(\d+(?:\.\d{2})?)'), '')
                .trim();
          }
        }

        final isIncome = lowerTitle.contains('received') ||
            lowerText.contains('received') ||
            lowerTitle.contains('refund') ||
            lowerText.contains('refund') ||
            lowerTitle.contains('sent you') ||
            lowerText.contains('sent you');
        if (isIncome) continue;

        amount = -amount.abs();

        final isDuplicate = all.any((e) =>
            e['merchant'] == merchant &&
            (e['amount'] as num).toDouble() == amount &&
            e['date'] == ts);
        if (isDuplicate) continue;

        // Auto-suggest category from merchant history
        final cat = suggestCategory(merchant) ?? 'Uncategorized';

        all.insert(0, {
          'id': '${DateTime.now().microsecondsSinceEpoch}_$amount',
          'amount': amount,
          'merchant': merchant,
          'date': ts,
          'note': 'Auto: $title - $text',
          'category': cat,
          'source': 'notification',
        });
      }

      await AppStorage.financeBox.put('expenses', all);
    } catch (e) {
      // ignore
    }
  }

  // ── SMS sync (Indian banks) ───────────────────────────────────────────────

  static Future<bool> checkSmsPermission() async {
    try {
      return await _channel.invokeMethod<bool>('checkSmsPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestSmsPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestSmsPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> syncSmsTransactions({int lookbackDays = 30}) async {
    try {
      final String? jsonStr = await _channel.invokeMethod<String>(
        'getSmsTransactions',
        {'lookbackDays': lookbackDays},
      );
      if (jsonStr == null || jsonStr == '[]') return;

      final parsed = IndianBankSmsParser.parseBatch(jsonStr);
      if (parsed.isEmpty) return;

      final all = _loadAll();

      for (final tx in parsed) {
        final map = tx.toMap();
        // Dedup: same amount + direction + date
        final isDup = all.any((e) {
          final ea = (e['amount'] as num?)?.toDouble() ?? 0;
          final ta = (map['amount'] as num?)?.toDouble() ?? 0;
          return ea == ta && (e['date'] as String?) == map['date'];
        });
        if (isDup) continue;

        // Merchant-based category suggestion
        final cat = suggestCategory(map['merchant'] as String? ?? '') ?? 'Uncategorized';
        map['category'] = cat;

        all.insert(0, map);
      }

      await AppStorage.financeBox.put('expenses', all);
    } catch (e) {
      // ignore
    }
  }

  /// Sync both or either source based on [dataSource] setting.
  static Future<void> syncAll() async {
    final src = dataSource;
    if (src == 'notification' || src == 'both') {
      await syncPendingExpenses();
    }
    if (src == 'sms' || src == 'both') {
      await syncSmsTransactions();
    }
  }

  // ── Category suggestion from merchant history ────────────────────────────

  /// Returns the most-used category for [merchant] from existing expenses,
  /// or null if never seen before.
  static String? suggestCategory(String merchant) {
    if (merchant.isEmpty) return null;
    final all = _loadAll();
    final lm = merchant.toLowerCase();

    final counts = <String, int>{};
    for (final e in all) {
      final em = ((e['merchant'] as String?) ?? '').toLowerCase();
      if (em == lm) {
        final cat = (e['category'] as String?) ?? '';
        if (cat.isNotEmpty && cat != 'Uncategorized') {
          counts[cat] = (counts[cat] ?? 0) + 1;
        }
      }
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  // ── Permissions ───────────────────────────────────────────────────────────

  static Future<bool> requestNotificationPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> checkNotificationPermission() async {
    try {
      return await _channel.invokeMethod<bool>('checkPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── Debug helpers ─────────────────────────────────────────────────────────

  /// Returns all SMS from the past [lookbackDays] with classifier output.
  /// Does NOT save anything — purely for the debug screen.
  static Future<List<Map<String, dynamic>>> debugSms({int lookbackDays = 30}) async {
    try {
      final String? jsonStr = await _channel.invokeMethod<String>(
        'getSmsTransactions',
        {'lookbackDays': lookbackDays},
      );
      if (jsonStr == null || jsonStr == '[]') return [];
      return IndianBankSmsParser.debugBatch(jsonStr);
    } catch (_) {
      return [];
    }
  }

  // ── Raw notifications (debug) ─────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getRawNotifications() async {
    try {
      final String? jsonStr = await _channel.invokeMethod<String>('getRawNotifications');
      if (jsonStr == null || jsonStr == '[]') return [];
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (e) {
      return [];
    }
  }

  // ── Clear / cleanup ───────────────────────────────────────────────────────

  static Future<bool> clearFinanceData() async {
    try {
      return await _channel.invokeMethod<bool>('clearFinanceData') ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> cleanupIrrelevantData() async {
    try {
      final all = _loadAll();
      final before = all.length;
      all.removeWhere((e) {
        final note = (e['note'] as String? ?? '').toLowerCase();
        final merchant = (e['merchant'] as String? ?? '').toLowerCase();
        return note.contains('job bot') ||
            note.contains('lilscott job hunt') ||
            note.contains('funds added') ||
            note.contains('top-up') ||
            merchant.contains('job bot') ||
            merchant.contains('lilscott');
      });
      if (all.length != before) {
        await AppStorage.financeBox.put('expenses', all);
      }
    } catch (e) {
      // ignore
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static List<Map<String, dynamic>> _loadAll() {
    final raw = AppStorage.financeBox.get('expenses', defaultValue: <dynamic>[]) as List;
    return raw.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }
}
