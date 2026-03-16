import 'package:flutter/material.dart';
import '../../utils/finance_service.dart';
import '../../app.dart' show NudgeTokens;

// ── Banking filter helpers (mirrors RevolutNotificationService.kt logic) ────

bool _isBankingPkg(String pkg, String title) {
  final p = pkg.toLowerCase();
  final t = title.toLowerCase();
  return p.contains('revolut') || p.contains('monzo') ||
      p.contains('starling') || p.contains('chase') ||
      p.contains('hsbc') || p.contains('barclays') ||
      p.contains('hdfc') || p.contains('icici') ||
      p.contains('sbi') || p.contains('axisbank') ||
      p.contains('kotak') || p.contains('yesbank') ||
      p.contains('idfcfirst') || p.contains('indusind') ||
      p.contains('federalbank') || p.contains('rbl') ||
      p.contains('paytm') || p.contains('phonepe') ||
      p.contains('gpay') || p.contains('amazonpay') ||
      t.contains('hdfc') || t.contains('icici') ||
      t.contains('sbi') || t.contains('revolut') || t.contains('monzo');
}

bool _hasMonetaryKeyword(String text) {
  final t = text.toLowerCase();
  return t.contains('spent') || t.contains('payment') || t.contains('paid') ||
      t.contains('debited') || t.contains('credited') ||
      t.contains('£') || t.contains('\$') ||
      t.contains('₹') || t.contains('inr') || t.contains('rs.');
}

// ── Screen ───────────────────────────────────────────────────────────────────

class RawNotificationScreen extends StatefulWidget {
  const RawNotificationScreen({super.key});

  @override
  State<RawNotificationScreen> createState() => _RawNotificationScreenState();
}

class _RawNotificationScreenState extends State<RawNotificationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Map<String, dynamic>> _notifs = [];
  List<Map<String, dynamic>> _sms = [];
  bool _loadingNotifs = true;
  bool _loadingSms = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _fetch();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loadingNotifs = true;
      _loadingSms = true;
    });
    final notifsFuture = FinanceService.getRawNotifications();
    final smsFuture = FinanceService.debugSms(lookbackDays: 30);

    final notifs = await notifsFuture;
    setState(() {
      _notifs = notifs.reversed.toList();
      _loadingNotifs = false;
    });

    final sms = await smsFuture;
    setState(() {
      _sms = sms;
      _loadingSms = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance Debug', style: TextStyle(fontSize: 16)),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: 'Notifications (${_notifs.length})'),
            Tab(text: 'SMS (${_sms.length})'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetch,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _NotifTab(logs: _notifs, loading: _loadingNotifs),
          _SmsTab(messages: _sms, loading: _loadingSms),
        ],
      ),
    );
  }
}

// ── Notification tab ─────────────────────────────────────────────────────────

class _NotifTab extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  final bool loading;
  const _NotifTab({required this.logs, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (logs.isEmpty) {
      return const Center(
          child: Text('No notifications captured yet.',
              style: TextStyle(color: NudgeTokens.textLow)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final log = logs[i];
        final pkg = log['pkg'] as String? ?? '';
        final title = log['title'] as String? ?? '';
        final text = log['text'] as String? ?? '';
        final time = log['time'] as String? ?? '';
        final banking = _isBankingPkg(pkg, title);
        final monetary = _hasMonetaryKeyword(text);
        final saved = banking && monetary;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: NudgeTokens.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: saved
                  ? NudgeTokens.green.withValues(alpha: 0.4)
                  : NudgeTokens.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Text(pkg,
                        style: const TextStyle(
                            fontSize: 11,
                            color: NudgeTokens.amber,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text(time,
                      style: const TextStyle(
                          fontSize: 10, color: NudgeTokens.textLow)),
                ],
              ),
              const SizedBox(height: 6),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: NudgeTokens.textHigh)),
              const SizedBox(height: 4),
              Text(text,
                  style: const TextStyle(
                      fontSize: 12, color: NudgeTokens.textMid)),
              const SizedBox(height: 8),
              // Classifier badges
              Wrap(
                spacing: 6,
                children: [
                  _Badge(
                      label: banking ? 'BANKING ✓' : 'NOT BANKING',
                      color: banking ? NudgeTokens.green : NudgeTokens.textLow),
                  _Badge(
                      label: monetary ? 'MONETARY ✓' : 'NO AMOUNT',
                      color: monetary ? NudgeTokens.blue : NudgeTokens.textLow),
                  if (saved)
                    const _Badge(label: 'SAVED', color: NudgeTokens.green),
                  if (!saved)
                    const _Badge(label: 'FILTERED OUT', color: NudgeTokens.red),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── SMS tab ───────────────────────────────────────────────────────────────────

class _SmsTab extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  final bool loading;
  const _SmsTab({required this.messages, required this.loading});

  Color _classColor(String cls) {
    switch (cls) {
      case 'transaction':
        return NudgeTokens.green;
      case 'otp':
        return NudgeTokens.blue;
      case 'marketing':
        return NudgeTokens.amber;
      default:
        return NudgeTokens.textLow;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (messages.isEmpty) {
      return const Center(
          child: Text('No SMS fetched (check SMS permission).',
              style: TextStyle(color: NudgeTokens.textLow)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: messages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final msg = messages[i];
        final sender = msg['sender'] as String? ?? '';
        final body = msg['body'] as String? ?? '';
        final ts = msg['timestamp'] as String? ?? '';
        final bank = msg['bank'] as String? ?? '';
        final cls = msg['classification'] as String? ?? 'unknown';
        final reason = msg['reason'] as String? ?? '';
        final extracted = msg['extracted'] as Map<String, dynamic>?;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: NudgeTokens.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cls == 'transaction'
                  ? NudgeTokens.green.withValues(alpha: 0.35)
                  : NudgeTokens.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(sender,
                        style: const TextStyle(
                            fontSize: 11,
                            color: NudgeTokens.amber,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (bank.isNotEmpty && bank != 'Bank')
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _Badge(label: bank, color: NudgeTokens.purple),
                    ),
                  const SizedBox(width: 6),
                  Text(ts.length > 16 ? ts.substring(0, 16) : ts,
                      style: const TextStyle(
                          fontSize: 10, color: NudgeTokens.textLow)),
                ],
              ),
              const SizedBox(height: 6),
              // Body (truncated)
              Text(body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: NudgeTokens.textMid)),
              const SizedBox(height: 8),
              // Classification badge + reason
              _Badge(label: cls.toUpperCase(), color: _classColor(cls)),
              const SizedBox(height: 4),
              Text(reason,
                  style: const TextStyle(
                      fontSize: 11, color: NudgeTokens.textLow,
                      fontStyle: FontStyle.italic)),
              // Extracted fields (only for transactions)
              if (extracted != null) ...[
                const SizedBox(height: 8),
                const Divider(color: NudgeTokens.border, height: 1),
                const SizedBox(height: 8),
                _ExtractedRow('Amount',
                    '${extracted['direction'] == 'debit' ? '-' : '+'}₹${extracted['amount']}'),
                _ExtractedRow('Merchant', extracted['merchant']?.toString() ?? ''),
                _ExtractedRow('Bank', extracted['bank']?.toString() ?? ''),
                if (extracted['balance'] != null)
                  _ExtractedRow('Balance', '₹${extracted['balance']}'),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Small widgets ─────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _ExtractedRow extends StatelessWidget {
  final String label;
  final String value;
  const _ExtractedRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11, color: NudgeTokens.textLow)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 11,
                    color: NudgeTokens.textHigh,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
