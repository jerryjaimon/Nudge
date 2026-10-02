import 'dart:convert';
import 'package:flutter/services.dart';
import '../storage.dart';
import '../services/indian_bank_sms_parser.dart';
import '../models/category_budget.dart';
import '../models/savings_jar.dart';
import '../models/jar_transfer.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class FinanceService extends ChangeNotifier {
  static final FinanceService instance = FinanceService._();
  FinanceService._();
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

  // ── Category Budgets & Savings Jars (New) ──────────────────────────────────

  /// 2a. Get spending per category for a given month
  static Map<String, double> getSpendingByCategory(int year, int month) {
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    final all = _loadAll();
    final out = <String, double>{};

    for (var e in all) {
      final date = (e['date'] as String?) ?? '';
      if (date.startsWith(prefix)) {
        final amount = (e['amount'] as num?)?.toDouble() ?? 0.0;
        if (amount < 0) {
          // Only count expenses
          final cat = (e['category'] as String?) ?? 'Uncategorized';
          out[cat] = (out[cat] ?? 0.0) + amount.abs();
        }
      }
    }
    return out;
  }

  /// 2b. Check overspend for all categories
  static List<CategoryBudget> getOverspentCategories(int year, int month) {
    final spending = getSpendingByCategory(year, month);
    final budgets = AppStorage.categoryBudgetBox.values.where((b) => !b.isArchived).toList();
    final overspent = <CategoryBudget>[];

    for (var b in budgets) {
      final spent = spending[b.name] ?? 0.0;
      if (spent > b.monthlyLimit) {
        overspent.add(b);
      }
    }
    return overspent;
  }

  /// 2c. Calculate surplus per category for a given month
  static Map<String, double> getCategorySurplus(int year, int month) {
    final spending = getSpendingByCategory(year, month);
    final budgets = AppStorage.categoryBudgetBox.values.where((b) => !b.isArchived).toList();
    final surplus = <String, double>{};

    for (var b in budgets) {
      final spent = spending[b.name] ?? 0.0;
      final diff = b.monthlyLimit - spent;
      if (diff > 0) {
        surplus[b.name] = diff;
      }
    }
    return surplus;
  }

  /// 2d. End-of-month rollover
  static Future<void> processMonthlyRollover(int prevYear, int prevMonth) async {
    final rolloverKey = 'last_rollover_${prevYear}_$prevMonth';
    if (AppStorage.settingsBox.get(rolloverKey, defaultValue: false) == true) {
      return;
    }

    final spending = getSpendingByCategory(prevYear, prevMonth);
    final budgets = AppStorage.categoryBudgetBox.values
        .where((b) => !b.isArchived && b.rolloverEnabled)
        .toList();

    for (var b in budgets) {
      final spent = spending[b.name] ?? 0.0;
      final surplus = b.monthlyLimit - spent;
      if (surplus > 0) {
        final jars = AppStorage.savingsJarBox.values.toList();
        SavingsJar jar;
        try {
          jar = jars.firstWhere((j) => j.categoryId == b.id);
        } catch (_) {
          jar = SavingsJar(
            categoryId: b.id,
            balance: 0.0,
            lastUpdated: DateTime.now(),
          );
        }
        jar.balance += surplus;
        jar.lastUpdated = DateTime.now();
        await AppStorage.savingsJarBox.put(jar.categoryId, jar);
      }
    }

    await AppStorage.settingsBox.put(rolloverKey, true);
    instance.notifyListeners();
  }

  /// 2e. Transfer from jar
  static Future<void> transferFromJar({
    required String categoryId,
    required double amount,
    required JarTransferDirection direction,
    String? note,
  }) async {
    final jar = AppStorage.savingsJarBox.get(categoryId);
    if (jar == null || jar.balance < amount) return;

    jar.balance -= amount;
    jar.lastUpdated = DateTime.now();
    await jar.save();

    if (direction == JarTransferDirection.toMonthlyBudget) {
      final now = DateTime.now();
      final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final budgets = Map<String, dynamic>.from(
          AppStorage.financeBox.get('budgets', defaultValue: <String, dynamic>{}) as Map);
      final current = (budgets[monthKey] as num?)?.toDouble() ?? 0.0;
      budgets[monthKey] = current + amount;
      await AppStorage.financeBox.put('budgets', budgets);
    }

    final transfer = JarTransfer(
      id: const Uuid().v4(),
      categoryId: categoryId,
      amount: amount,
      direction: direction,
      date: DateTime.now(),
      note: note,
    );
    await AppStorage.jarTransferBox.put(transfer.id, transfer);

    instance.notifyListeners();
  }

  /// 2f. Spending pace for a category
  static String getCategoryPace(String categoryName, int year, int month) {
    final spending = getSpendingByCategory(year, month);
    final spent = spending[categoryName] ?? 0.0;

    final budgets = AppStorage.categoryBudgetBox.values.where((b) => b.name == categoryName).toList();
    if (budgets.isEmpty) return 'on_track';
    final limit = budgets.first.monthlyLimit;
    if (limit <= 0) return 'on_track';

    final now = DateTime.now();
    int dayOfMonth;
    int daysInMonth;

    if (now.year == year && now.month == month) {
      dayOfMonth = now.day;
      daysInMonth = DateTime(year, month + 1, 0).day;
    } else {
      // For past months, we consider the full month
      dayOfMonth = DateTime(year, month + 1, 0).day;
      daysInMonth = dayOfMonth;
    }

    final expectedSpend = limit * (dayOfMonth / daysInMonth);

    if (spent > limit) return 'over';
    if (spent > expectedSpend * 1.1) return 'at_risk';
    return 'on_track';
  }

  /// Part 8 — Default Categories Seeding
  static Future<void> seedDefaultCategories() async {
    final done = AppStorage.settingsBox.get('categoriesSeedDone', defaultValue: false) as bool;
    if (done) return;

    if (AppStorage.categoryBudgetBox.isEmpty) {
      final defaults = [
        {'name': 'Groceries', 'icon': '🛒', 'colourHex': '#39D98A'},
        {'name': 'Transport', 'icon': '🚌', 'colourHex': '#5AC8FA'},
        {'name': 'Eating Out', 'icon': '🍕', 'colourHex': '#FFBF00'},
        {'name': 'Bills', 'icon': '⚡', 'colourHex': '#7C4DFF'},
        {'name': 'Health', 'icon': '💊', 'colourHex': '#FF4D6A'},
        {'name': 'Entertainment', 'icon': '🎬', 'colourHex': '#FF9F0A'},
        {'name': 'Shopping', 'icon': '👗', 'colourHex': '#30D158'},
        {'name': 'Other', 'icon': '📦', 'colourHex': '#8E8E93'},
      ];

      for (var d in defaults) {
        final b = CategoryBudget(
          id: const Uuid().v4(),
          name: d['name']!,
          icon: d['icon']!,
          colourHex: d['colourHex']!,
          monthlyLimit: 0.0,
          createdAt: DateTime.now(),
        );
        await AppStorage.categoryBudgetBox.put(b.id, b);
      }
    }

    await AppStorage.settingsBox.put('categoriesSeedDone', true);
    instance.notifyListeners();
  }
}
