// lib/services/indian_bank_sms_parser.dart
//
// Three-stage SMS parser for Indian bank transaction messages.
//   Stage 1 — Cleaner:    Strip noise (extra whitespace, special chars).
//   Stage 2 — Classifier: TRANSACTION | OTP | MARKETING.
//   Stage 3 — Extractor:  Bank-specific or generic regex templates.
//
// Supported banks/wallets (sender IDs):
//   HDFC, ICICI, SBI, Axis, Kotak, Yes Bank, IDFC First,
//   IndusInd, PNB, BOI, Canara, Federal, RBL,
//   PayTM, Amazon Pay, Google Pay, PhonePe, MobiKwik.
//

import 'dart:convert';

enum SmsType { transaction, otp, marketing, unknown }
enum TxDirection { debit, credit }

class ClassifyResult {
  final SmsType type;
  final String reason;
  const ClassifyResult(this.type, this.reason);
}

class ParsedSmsTransaction {
  final double amount;
  final TxDirection direction; // debit or credit
  final String merchant; // payee / info label
  final String bank; // which bank sent it
  final DateTime date; // from SMS timestamp
  final double? balance; // available balance, if present
  final String? reference; // UPI ref / txn ID
  final String rawBody; // original SMS text

  const ParsedSmsTransaction({
    required this.amount,
    required this.direction,
    required this.merchant,
    required this.bank,
    required this.date,
    this.balance,
    this.reference,
    required this.rawBody,
  });

  Map<String, dynamic> toMap() => {
        'amount': direction == TxDirection.debit ? -amount : amount,
        'merchant': merchant,
        'category': 'Uncategorized',
        'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'note': 'SMS: $bank',
        'id': '${date.millisecondsSinceEpoch}_${amount}_sms',
        'source': 'sms',
      };
}

class IndianBankSmsParser {
  // ── Stage 1: Cleaner ──────────────────────────────────────────────────────

  static String clean(String body) {
    // Collapse whitespace
    var s = body.replaceAll(RegExp(r'\r\n|\r|\n'), ' ').replaceAll(RegExp(r'\s+'), ' ');
    // Remove zero-width chars
    s = s.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    return s.trim();
  }

  // ── Keyword lists (shared by classify + classifyWithReason) ─────────────

  static const _promoKeywords = [
    'offer', 'cashback', 'reward', 'congratulation', 'win',
    'discount', 'exciting', 'exclusive', 'invite', 'upgrade',
    'apply now', 'click here', 'limited time',
  ];

  static const _txKeywords = [
    'debited', 'credited', 'debit', 'credit',
    'spent', 'payment', 'paid', 'purchase',
    'transferred', 'transfer', 'withdrawn', 'withdrawal',
    'upi', 'neft', 'imps', 'rtgs',
    'transaction', 'txn', 'a/c', 'account',
  ];

  // ── Stage 2: Classifier ───────────────────────────────────────────────────

  static SmsType classify(String sender, String body) {
    return classifyWithReason(sender, body).type;
  }

  /// Like [classify] but also returns a human-readable reason string.
  static ClassifyResult classifyWithReason(String sender, String body) {
    final lower = body.toLowerCase();

    if (_isOtp(lower)) {
      return const ClassifyResult(SmsType.otp,
          'Contains OTP keyword or digit code with expiry language');
    }

    final hasPromo = _promoKeywords.any((k) => lower.contains(k));
    final hasTx = _hasTransactionWord(lower);
    if (hasPromo && !hasTx) {
      final match = _promoKeywords.firstWhere((k) => lower.contains(k));
      return ClassifyResult(SmsType.marketing,
          'Promo keyword "$match" found; no transaction words present');
    }

    if (hasTx) {
      final match = _txKeywords.firstWhere((w) => lower.contains(w));
      return ClassifyResult(SmsType.transaction,
          'Transaction keyword "$match" found');
    }
    if (RegExp(r'(inr|rs\.?|₹)\s*[\d,]+', caseSensitive: false).hasMatch(lower)) {
      return const ClassifyResult(SmsType.transaction,
          'Amount pattern (INR / Rs / ₹ + number) found');
    }

    return const ClassifyResult(SmsType.unknown, 'No matching pattern found');
  }

  static bool _isOtp(String lower) {
    if (lower.contains('otp') ||
        lower.contains('one time password') ||
        lower.contains('verification code') ||
        lower.contains('passcode')) { return true; }
    if (RegExp(r'\b\d{4,8}\b').hasMatch(lower) &&
        (lower.contains('valid') ||
            lower.contains('expire') ||
            lower.contains('do not share'))) {
      return true;
    }
    return false;
  }

  static bool _hasTransactionWord(String lower) =>
      _txKeywords.any((w) => lower.contains(w));

  // ── Stage 3: Extractor ────────────────────────────────────────────────────

  static ParsedSmsTransaction? extract(String sender, String body, DateTime date) {
    final cleaned = clean(body);
    final bank = _bankFromSender(sender);

    // Try bank-specific template first, fall back to generic
    return _bankSpecific(bank, cleaned, date, body) ??
        _generic(bank, cleaned, date, body);
  }

  // ── Bank-specific templates ───────────────────────────────────────────────

  static ParsedSmsTransaction? _bankSpecific(
      String bank, String msg, DateTime date, String raw) {
    switch (bank) {
      case 'HDFC':
        return _parseHdfc(msg, date, raw);
      case 'ICICI':
        return _parseIcici(msg, date, raw);
      case 'SBI':
        return _parseSbi(msg, date, raw);
      case 'Axis':
        return _parseAxis(msg, date, raw);
      case 'Kotak':
        return _parseKotak(msg, date, raw);
      default:
        return null;
    }
  }

  // HDFC: "INR 1,234.00 debited from A/c XX1234 on 15-03-24. Info: AMAZON. Avl Bal: INR 5,678.00"
  static ParsedSmsTransaction? _parseHdfc(String msg, DateTime date, String raw) {
    final amt = _extractAmount(msg);
    if (amt == null) return null;
    final dir = _extractDirection(msg);
    final info = _extractAfter(msg, RegExp(r'Info:\s*', caseSensitive: false));
    final bal = _extractBalance(msg);
    return ParsedSmsTransaction(
      amount: amt, direction: dir,
      merchant: _cleanMerchant(info ?? 'HDFC'),
      bank: 'HDFC', date: date, balance: bal, rawBody: raw,
    );
  }

  // ICICI: "Dear Customer, INR 500.00 debited from ICICI Bank A/c XXXX1234 on 15-Mar-24 10:30:00. Info: UPI/123/MERCHANT. Avl Bal: INR 1234.56"
  static ParsedSmsTransaction? _parseIcici(String msg, DateTime date, String raw) {
    final amt = _extractAmount(msg);
    if (amt == null) return null;
    final dir = _extractDirection(msg);
    final info = _extractAfter(msg, RegExp(r'Info:\s*', caseSensitive: false));
    // UPI ref typically after last slash in info
    String? merchant = info;
    if (merchant != null && merchant.contains('/')) {
      merchant = merchant.split('/').last;
    }
    final bal = _extractBalance(msg);
    return ParsedSmsTransaction(
      amount: amt, direction: dir,
      merchant: _cleanMerchant(merchant ?? 'ICICI'),
      bank: 'ICICI', date: date, balance: bal, rawBody: raw,
    );
  }

  // SBI: "Rs 500.00 debited from A/c No. XX1234 on 15/03/24. Bal Rs 1234.56. -SBI"
  static ParsedSmsTransaction? _parseSbi(String msg, DateTime date, String raw) {
    final amt = _extractAmount(msg);
    if (amt == null) return null;
    final dir = _extractDirection(msg);
    final bal = _extractBalance(msg);
    // SBI often doesn't include merchant — extract "to" recipient for UPI
    final to = _extractAfter(msg, RegExp(r'\bto\b\s*', caseSensitive: false));
    return ParsedSmsTransaction(
      amount: amt, direction: dir,
      merchant: _cleanMerchant(to ?? 'SBI'),
      bank: 'SBI', date: date, balance: bal, rawBody: raw,
    );
  }

  // Axis: "INR 1234.00 has been debited from your account XXXX1234 on 15-03-2024. Merchant: Amazon. Avl Bal: INR 5678.00"
  static ParsedSmsTransaction? _parseAxis(String msg, DateTime date, String raw) {
    final amt = _extractAmount(msg);
    if (amt == null) return null;
    final dir = _extractDirection(msg);
    final merchant = _extractAfter(msg, RegExp(r'Merchant:\s*', caseSensitive: false)) ??
        _extractAfter(msg, RegExp(r'\bat\s+', caseSensitive: false));
    final bal = _extractBalance(msg);
    return ParsedSmsTransaction(
      amount: amt, direction: dir,
      merchant: _cleanMerchant(merchant ?? 'Axis'),
      bank: 'Axis', date: date, balance: bal, rawBody: raw,
    );
  }

  // Kotak: "Rs 500 debited from Kotak Ac XX1234 on 15-Mar-24. Bal Rs 1234.56. UPI ref 12345678"
  static ParsedSmsTransaction? _parseKotak(String msg, DateTime date, String raw) {
    final amt = _extractAmount(msg);
    if (amt == null) return null;
    final dir = _extractDirection(msg);
    final bal = _extractBalance(msg);
    final to = _extractAfter(msg, RegExp(r'\bto\b\s*', caseSensitive: false));
    return ParsedSmsTransaction(
      amount: amt, direction: dir,
      merchant: _cleanMerchant(to ?? 'Kotak'),
      bank: 'Kotak', date: date, balance: bal, rawBody: raw,
    );
  }

  // ── Generic fallback ──────────────────────────────────────────────────────

  static ParsedSmsTransaction? _generic(
      String bank, String msg, DateTime date, String raw) {
    final amt = _extractAmount(msg);
    if (amt == null) return null;
    final dir = _extractDirection(msg);
    // Try to find merchant in common positions
    String? merchant = _extractAfter(msg, RegExp(r'Info:\s*', caseSensitive: false)) ??
        _extractAfter(msg, RegExp(r'Merchant:\s*', caseSensitive: false)) ??
        _extractAfter(msg, RegExp(r'\bat\s+', caseSensitive: false)) ??
        _extractAfter(msg, RegExp(r'\bto\s+', caseSensitive: false)) ??
        _extractAfter(msg, RegExp(r'UPI/\w+/', caseSensitive: false));
    final bal = _extractBalance(msg);
    return ParsedSmsTransaction(
      amount: amt, direction: dir,
      merchant: _cleanMerchant(merchant ?? bank),
      bank: bank, date: date, balance: bal, rawBody: raw,
    );
  }

  // ── Field extractors ──────────────────────────────────────────────────────

  /// Extracts the first monetary amount found (INR/Rs/₹/₹)
  static double? _extractAmount(String msg) {
    // Patterns: INR 1,234.56 | Rs.1234 | Rs 1,234.56 | ₹1234.56
    final match = RegExp(
      r'(?:INR|Rs\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(msg);
    if (match == null) return null;
    final raw = match.group(1)!.replaceAll(',', '');
    return double.tryParse(raw);
  }

  /// Available balance extraction
  static double? _extractBalance(String msg) {
    final match = RegExp(
      r'(?:Avl\.?\s*Bal\.?|Bal\.?|Available Balance)\s*:?\s*(?:INR|Rs\.?|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(msg);
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', ''));
  }

  /// Returns text immediately after a pattern, up to the next period/comma/newline
  static String? _extractAfter(String msg, RegExp pattern) {
    final match = pattern.firstMatch(msg);
    if (match == null) return null;
    final rest = msg.substring(match.end);
    // Take until period, comma, newline, or end
    final end = RegExp(r'[.,\n]').firstMatch(rest);
    return end == null ? rest.trim() : rest.substring(0, end.start).trim();
  }

  static TxDirection _extractDirection(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('credited') ||
        lower.contains('credit') ||
        lower.contains('received') ||
        lower.contains('refund') ||
        lower.contains('cashback') ||
        lower.contains('added')) {
      // Check if "not" precedes it
      if (!RegExp(r'\bnot\s+credit', caseSensitive: false).hasMatch(msg)) {
        return TxDirection.credit;
      }

    }
    return TxDirection.debit;
  }

  // ── Bank identification ───────────────────────────────────────────────────

  static String _bankFromSender(String sender) {
    final s = sender.toUpperCase();
    // Standard 2-char country prefix + 6-char bank code (e.g., AD-HDFCBK)
    if (s.contains('HDFC')) return 'HDFC';
    if (s.contains('ICICI') || s.contains('ICICIB')) return 'ICICI';
    if (s.contains('SBIN') || s.contains('SBIIN') || s.contains('SBICRD')) return 'SBI';
    if (s.contains('UTIB') || s.contains('AXIS')) return 'Axis';
    if (s.contains('KKBK') || s.contains('KOTAK')) return 'Kotak';
    if (s.contains('YESBN') || s.contains('YESBK')) return 'Yes Bank';
    if (s.contains('IDFCB') || s.contains('IDFCF')) return 'IDFC First';
    if (s.contains('INDBN') || s.contains('INDUS')) return 'IndusInd';
    if (s.contains('PUNBK') || s.contains('PNBHF')) return 'PNB';
    if (s.contains('BOIIND') || s.contains('BOIOF')) return 'Bank of India';
    if (s.contains('CNRB') || s.contains('CANAR')) return 'Canara';
    if (s.contains('FEDRAL') || s.contains('FDRLB')) return 'Federal';
    if (s.contains('RBLBK') || s.contains('RATNA')) return 'RBL';
    if (s.contains('PAYTM')) return 'Paytm';
    if (s.contains('AMAZON') || s.contains('AMZNPAY')) return 'Amazon Pay';
    if (s.contains('GPAY') || s.contains('GOOGL')) return 'Google Pay';
    if (s.contains('PHONEPE') || s.contains('PHPE')) return 'PhonePe';
    if (s.contains('MOBIKWIK') || s.contains('MBK')) return 'MobiKwik';
    if (s.contains('AIRTEL')) return 'Airtel Money';
    if (s.contains('JIO')) return 'Jio Pay';
    return 'Bank';
  }

  /// Clean up merchant names — remove UPI ref noise
  static String _cleanMerchant(String raw) {
    var m = raw.trim();
    // Remove trailing ref numbers e.g. "Amazon 4071234567"
    m = m.replaceAll(RegExp(r'\s+\d{8,}$'), '');
    // Remove "VPA" noise
    m = m.replaceAll(RegExp(r'\bVPA\b', caseSensitive: false), '').trim();
    // Truncate at next UPI@ or phone number
    final atIdx = m.indexOf('@');
    if (atIdx > 0) m = m.substring(0, atIdx).trim();
    // Remove leading/trailing punctuation
    m = m.replaceAll(RegExp(r'^[.\-\s]+|[.\-\s]+$'), '');
    return m.isEmpty ? 'Unknown' : m;
  }

  // ── Batch parser (called from FinanceService) ─────────────────────────────

  /// Parse a raw JSON list of SMS messages from the Android method channel.
  /// Returns only valid debit/credit transactions, deduplicated.
  static List<ParsedSmsTransaction> parseBatch(String jsonStr) {
    final List<dynamic> raw;
    try {
      raw = jsonDecode(jsonStr) as List;
    } catch (_) {
      return [];
    }

    final seen = <String>{};
    final results = <ParsedSmsTransaction>[];

    for (final item in raw) {
      if (item is! Map) continue;
      final sender = (item['sender'] as String?) ?? '';
      final body = (item['body'] as String?) ?? '';
      final ts = (item['timestamp'] as String?) ?? '';

      final date = DateTime.tryParse(ts) ?? DateTime.now();
      final cleaned = clean(body);
      final type = classify(sender, cleaned);

      if (type != SmsType.transaction) continue;

      final parsed = extract(sender, cleaned, date);
      if (parsed == null) continue;
      if (parsed.amount <= 0) continue;

      // Dedup key: amount + direction + date
      final key =
          '${parsed.amount}_${parsed.direction.name}_${date.year}${date.month}${date.day}';
      if (seen.contains(key)) continue;
      seen.add(key);

      results.add(parsed);
    }

    return results;
  }

  // ── Debug batch (returns all messages with classifier output) ─────────────

  /// Returns every SMS from [jsonStr] with classifier label, reason, and
  /// extracted fields (if transaction). Does NOT filter or deduplicate.
  static List<Map<String, dynamic>> debugBatch(String jsonStr) {
    final List<dynamic> raw;
    try {
      raw = jsonDecode(jsonStr) as List;
    } catch (_) {
      return [];
    }

    return raw.map((item) {
      if (item is! Map) return <String, dynamic>{};
      final sender = (item['sender'] as String?) ?? '';
      final body = (item['body'] as String?) ?? '';
      final ts = (item['timestamp'] as String?) ?? '';
      final date = DateTime.tryParse(ts) ?? DateTime.now();
      final cleaned = clean(body);
      final result = classifyWithReason(sender, cleaned);
      final bank = _bankFromSender(sender);

      Map<String, dynamic>? extracted;
      if (result.type == SmsType.transaction) {
        final tx = extract(sender, cleaned, date);
        if (tx != null) {
          extracted = {
            'amount': tx.amount,
            'direction': tx.direction.name,
            'merchant': tx.merchant,
            'bank': tx.bank,
            'balance': tx.balance,
          };
        }
      }

      return <String, dynamic>{
        'sender': sender,
        'body': body,
        'timestamp': ts,
        'bank': bank,
        'classification': result.type.name,
        'reason': result.reason,
        'extracted': extracted,
      };
    }).where((m) => m.isNotEmpty).toList();
  }
}
