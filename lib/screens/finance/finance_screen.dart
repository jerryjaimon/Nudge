import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/finance_service.dart';
import '../../storage.dart';
import '../../app.dart' show NudgeTokens;
import 'add_expense_sheet.dart';
import 'budget_editor_sheet.dart';
import 'raw_notification_screen.dart';
import 'package:nudge/utils/nudge_theme_extension.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> with WidgetsBindingObserver {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncAll();
    }
  }

  Future<void> _syncAll() async {
    await FinanceService.syncAll();
    if (mounted) setState(() {});
  }

  String get _monthKey =>
      '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  String _monthLabel() {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[_month.month - 1]} ${_month.year}';
  }

  void _bumpMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  List<Map<String, dynamic>> _expenses() {
    final raw = AppStorage.financeBox.get('expenses', defaultValue: <dynamic>[]) as List;
    final all = raw.map((e) => (e as Map).cast<String, dynamic>()).toList();
    return all
        .where((e) => (e['date'] as String? ?? '').startsWith(_monthKey))
        .toList()
      ..sort((a, b) =>
          (b['date'] as String? ?? '').compareTo(a['date'] as String? ?? ''));
  }

  double _budget() {
    final budgets = AppStorage.financeBox
        .get('budgets', defaultValue: <String, dynamic>{}) as Map;
    final v = budgets[_monthKey];
    return (v is num) ? v.toDouble() : 0.0;
  }

  double _totalSpent() {
    return _expenses().fold(0.0, (sum, e) {
      final a = (e['amount'] as num?)?.toDouble() ?? 0.0;
      return sum + (a < 0 ? -a : 0); // only expenses (negative amounts)
    });
  }

  Future<void> _openAddExpense({Map<String, dynamic>? initial}) async {
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NudgeTokens.elevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => AddExpenseSheet(initial: initial),
    );
    if (res == null) return;

    final action = (res['__action'] as String?) ?? 'save';
    final all = _allExpenses();

    if (action == 'delete') {
      final id = res['id']?.toString();
      if (id != null) all.removeWhere((e) => e['id']?.toString() == id);
      await AppStorage.financeBox.put('expenses', all);
      setState(() {});
      return;
    }

    final cleaned = Map<String, dynamic>.from(res)..remove('__action');
    final id = cleaned['id']?.toString();
    if (id == null) return;

    final idx = all.indexWhere((e) => e['id']?.toString() == id);
    if (idx >= 0) {
      all[idx] = cleaned;
    } else {
      all.insert(0, cleaned);
    }
    await AppStorage.financeBox.put('expenses', all);
    setState(() {});
  }

  List<Map<String, dynamic>> _allExpenses() {
    final raw = AppStorage.financeBox.get('expenses', defaultValue: <dynamic>[]) as List;
    return raw.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<void> _clearAllFinanceData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NudgeTokens.elevated,
        title: const Text('Clear All Finance Data?', style: TextStyle(color: Colors.white)),
        content: const Text('This will delete all your expenses and pending notifications. This cannot be undone.', style: TextStyle(color: NudgeTokens.textLow)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: NudgeTokens.textLow))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear', style: TextStyle(color: NudgeTokens.red))),
        ],
      ),
    );
    
    if (confirmed == true) {
      await AppStorage.financeBox.put('expenses', []);
      await FinanceService.clearFinanceData();
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Finance data cleared')));
      }
    }
  }

  void _openSourceSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: NudgeTokens.elevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _SourceSettingsSheet(onChanged: _syncAll),
    );
  }

  Future<void> _openBudgetEditor() async {
    final current = _budget();
    final res = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NudgeTokens.elevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => BudgetEditorSheet(
        monthLabel: _monthLabel(),
        currentBudget: current,
      ),
    );
    if (res == null) return;

    final budgets = Map<String, dynamic>.from(AppStorage.financeBox
        .get('budgets', defaultValue: <String, dynamic>{}) as Map);
    budgets[_monthKey] = res;
    await AppStorage.financeBox.put('budgets', budgets);
    setState(() {});
  }

  // Group expenses by date string
  Map<String, List<Map<String, dynamic>>> _grouped() {
    final expenses = _expenses();
    final out = <String, List<Map<String, dynamic>>>{};
    for (final e in expenses) {
      final date = (e['date'] as String?) ?? '';
      out.putIfAbsent(date, () => []).add(e);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final budget = _budget();
    final spent = _totalSpent();
    final remaining = budget - spent;
    final pct = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final grouped = _grouped();
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final isCurrentMonth = _month.year == DateTime.now().year &&
        _month.month == DateTime.now().month;

    Color barColor;
    if (pct < 0.5) {
      barColor = NudgeTokens.finB;
    } else if (pct < 0.8) {
      barColor = NudgeTokens.amber;
    } else {
      barColor = NudgeTokens.red;
    }

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              width: 3,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: NudgeTokens.finB,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Finance'),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: NudgeTokens.border),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RawNotificationScreen())),
            icon: const Icon(Icons.bug_report_rounded),
            tooltip: 'Debug Log',
          ),
          IconButton(
            onPressed: _openSourceSettings,
            icon: const Icon(Icons.sensors_rounded),
            tooltip: 'Data Source',
          ),
          IconButton(
            onPressed: () => _clearAllFinanceData(),
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear Data',
          ),
          IconButton(
            onPressed: _openBudgetEditor,
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Set Budget',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          // Month selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: NudgeTokens.card,
              border: Border.all(color: NudgeTokens.border),
            ),
            child: Row(
              children: [
                _NavBtn(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => _bumpMonth(-1)),
                Expanded(
                  child: Text(
                    _monthLabel(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh)),
                    ),
                  ),
                ),
                _NavBtn(
                    icon: Icons.chevron_right_rounded,
                    onTap: () => _bumpMonth(1)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Budget summary card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  NudgeTokens.finA,
                  NudgeTokens.finB.withValues(alpha: 0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                  color: NudgeTokens.finB.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            budget > 0 ? 'Budget' : 'No budget set',
                            style: const TextStyle(
                              color: NudgeTokens.textLow,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (budget > 0)
                            Text(
                              _formatAmount(budget),
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: NudgeTokens.textMid,
                              ),
                            ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _openBudgetEditor,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: NudgeTokens.finB.withValues(alpha: 0.12),
                          border: Border.all(
                              color: NudgeTokens.finB.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          budget > 0 ? 'Edit' : 'Set Budget',
                          style: const TextStyle(
                            color: NudgeTokens.finB,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Large spent / remaining
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatAmount(spent),
                          style: GoogleFonts.outfit(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh)),
                            letterSpacing: -1,
                          ),
                        ),
                        const Text(
                          'spent this month',
                          style: TextStyle(
                            color: NudgeTokens.textLow,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (budget > 0) ...[
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            remaining >= 0
                                ? _formatAmount(remaining)
                                : '-${_formatAmount(-remaining)}',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: remaining >= 0
                                  ? NudgeTokens.finB
                                  : NudgeTokens.red,
                            ),
                          ),
                          Text(
                            remaining >= 0 ? 'remaining' : 'over budget',
                            style: TextStyle(
                              color: remaining >= 0
                                  ? NudgeTokens.textLow
                                  : NudgeTokens.red,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                if (budget > 0) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor:
                          NudgeTokens.elevated.withValues(alpha: 0.6),
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(pct * 100).toStringAsFixed(1)}% of budget used',
                    style: TextStyle(
                      color: barColor.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Category Breakdown
          if (sortedDates.isNotEmpty) ...[
             const Padding(
               padding: EdgeInsets.only(left: 4, bottom: 12),
               child: Text('SPENDING BY CATEGORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: NudgeTokens.textLow, letterSpacing: 1.5)),
             ),
             _CategoryBreakdown(expenses: grouped.values.expand((l) => l).toList()),
             const SizedBox(height: 24),
          ],

          // Transaction list
          if (sortedDates.isEmpty)
            _EmptyFinance(
              onAdd: () => _openAddExpense(),
              hasBudget: budget > 0,
            )
          else
            ...sortedDates.map((date) {
              final items = grouped[date]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _formatDate(date, isCurrentMonth),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: NudgeTokens.textLow,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: NudgeTokens.card,
                      border: Border.all(color: NudgeTokens.border),
                    ),
                    child: Column(
                      children: List.generate(items.length, (i) {
                        final item = items[i];
                        final isLast = i == items.length - 1;
                        return _TransactionRow(
                          item: item,
                          isLast: isLast,
                          onTap: () => _openAddExpense(initial: item),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: () => _openAddExpense(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Expense'),
            style: FilledButton.styleFrom(
              backgroundColor: NudgeTokens.finB,
              foregroundColor: const Color(0xFF001A0E),
            ),
          ),
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    // Show 2 decimal places
    if (amount % 1 == 0) {
      return '£${amount.toStringAsFixed(0)}';
    }
    return '£${amount.toStringAsFixed(2)}';
  }

  String _formatDate(String iso, bool isCurrentMonth) {
    try {
      final parts = iso.split('-');
      if (parts.length < 3) return iso;
      final d = DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final day = DateTime(d.year, d.month, d.day);
      if (day == today) return 'TODAY';
      if (day == yesterday) return 'YESTERDAY';
      const months = [
        'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
        'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
      ];
      return '${d.day} ${months[d.month - 1]}';
    } catch (_) {
      return iso;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: NudgeTokens.elevated,
          border: Border.all(color: NudgeTokens.border),
        ),
        child: Icon(icon, size: 20, color: NudgeTokens.textMid),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isLast;
  final VoidCallback onTap;

  const _TransactionRow(
      {required this.item, required this.isLast, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final merchant = (item['merchant'] as String?) ?? 'Unknown';
    final note = (item['note'] as String?) ?? '';
    final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
    final isExpense = amount < 0;
    final amountAbs = amount.abs();
    final amountStr = amountAbs % 1 == 0
        ? '£${amountAbs.toStringAsFixed(0)}'
        : '£${amountAbs.toStringAsFixed(2)}';

    // Pick a color for the merchant initial circle
    final colorIdx = merchant.codeUnits.fold(0, (s, c) => s + c) % _dotColors.length;
    final dotColor = _dotColors[colorIdx];

    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(16))
          : BorderRadius.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor.withValues(alpha: 0.12),
                    border: Border.all(
                        color: dotColor.withValues(alpha: 0.2)),
                  ),
                  child: Center(
                    child: Text(
                      merchant.isNotEmpty
                          ? merchant[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: dotColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        merchant,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh)),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item['category'] != null || (note.isNotEmpty && note != merchant))
                        Text(
                          [
                            if (item['category'] != null) item['category'],
                            if (note.isNotEmpty && note != merchant) note
                          ].join(' • '),
                          style: const TextStyle(
                            fontSize: 11,
                            color: NudgeTokens.textLow,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isExpense ? '-$amountStr' : '+$amountStr',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: isExpense ? (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh)) : NudgeTokens.finB,
                  ),
                ),
              ],
            ),
          ),
          if (!isLast)
            Padding(
              padding: const EdgeInsets.only(left: 64),
              child: Container(height: 1, color: NudgeTokens.border),
            ),
        ],
      ),
    );
  }

  static const _dotColors = [
    NudgeTokens.purple,
    NudgeTokens.finB,
    NudgeTokens.blue,
    NudgeTokens.amber,
    NudgeTokens.red,
    NudgeTokens.green,
  ];
}

class _EmptyFinance extends StatelessWidget {
  final VoidCallback onAdd;
  final bool hasBudget;

  const _EmptyFinance({required this.onAdd, required this.hasBudget});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: NudgeTokens.card,
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: NudgeTokens.finB.withValues(alpha: 0.1),
              border: Border.all(
                  color: NudgeTokens.finB.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.receipt_long_rounded,
                size: 24, color: NudgeTokens.finB),
          ),
          const SizedBox(height: 14),
          const Text(
            'No expenses yet',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: NudgeTokens.textMid,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasBudget
                ? 'Tap Add Expense to start tracking'
                : 'Set a budget and start adding expenses',
            style: const TextStyle(
              fontSize: 12,
              color: NudgeTokens.textLow,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  final List<Map<String, dynamic>> expenses;
  const _CategoryBreakdown({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final map = <String, double>{};
    for (var e in expenses) {
      final a = (e['amount'] as num?)?.toDouble() ?? 0.0;
      if (a < 0) { // expense
        final c = (e['category'] as String?) ?? 'General';
        map[c] = (map[c] ?? 0.0) - a; // add positive magnitude
      }
    }
    if (map.isEmpty) return const SizedBox();

    final sorted = map.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
    final total = sorted.fold<double>(0.0, (s, e) => s + e.value);

    return Column(
      children: sorted.map((e) {
        final pct = total > 0 ? (e.value / total) : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                flex: 3, 
                child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: NudgeTokens.textMid), maxLines: 1, overflow: TextOverflow.ellipsis)
              ),
              Expanded(
                flex: 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: NudgeTokens.card,
                    valueColor: const AlwaysStoppedAnimation(NudgeTokens.finB),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 60,
                child: Text('£${e.value.toStringAsFixed(0)}', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh)))),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Data source settings sheet ───────────────────────────────────────────────

class _SourceSettingsSheet extends StatefulWidget {
  final VoidCallback onChanged;
  const _SourceSettingsSheet({required this.onChanged});

  @override
  State<_SourceSettingsSheet> createState() => _SourceSettingsSheetState();
}

class _SourceSettingsSheetState extends State<_SourceSettingsSheet> {
  String _source = FinanceService.dataSource;
  bool _hasNotifPerm = false;
  bool _hasSmsPerm = false;

  @override
  void initState() {
    super.initState();
    _checkPerms();
  }

  Future<void> _checkPerms() async {
    final notif = await FinanceService.checkNotificationPermission();
    final sms = await FinanceService.checkSmsPermission();
    if (mounted) setState(() { _hasNotifPerm = notif; _hasSmsPerm = sms; });
  }

  Future<void> _select(String src) async {
    await FinanceService.setDataSource(src);
    setState(() => _source = src);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: NudgeTokens.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('DATA SOURCE',
                style: TextStyle(color: NudgeTokens.textLow, fontSize: 11,
                    fontWeight: FontWeight.w800, letterSpacing: 1.4)),
            const SizedBox(height: 6),
            const Text(
              'Choose how Nudge reads your bank transactions.',
              style: TextStyle(color: NudgeTokens.textLow, fontSize: 12),
            ),
            const SizedBox(height: 20),
            _SourceTile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Revolut, Monzo, Starling — UK banks',
              selected: _source == 'notification',
              hasPermission: _hasNotifPerm,
              onTap: () => _select('notification'),
              onGrant: () async {
                await FinanceService.requestNotificationPermission();
                _checkPerms();
              },
            ),
            const SizedBox(height: 10),
            _SourceTile(
              icon: Icons.sms_outlined,
              title: 'SMS',
              subtitle: 'HDFC, ICICI, SBI, Axis, Kotak & more',
              selected: _source == 'sms',
              hasPermission: _hasSmsPerm,
              onTap: () => _select('sms'),
              onGrant: () async {
                await FinanceService.requestSmsPermission();
                _checkPerms();
              },
            ),
            const SizedBox(height: 10),
            _SourceTile(
              icon: Icons.merge_type_rounded,
              title: 'Both',
              subtitle: 'Notifications + SMS combined',
              selected: _source == 'both',
              hasPermission: _hasNotifPerm || _hasSmsPerm,
              onTap: () => _select('both'),
              onGrant: () async {
                await FinanceService.requestNotificationPermission();
                await FinanceService.requestSmsPermission();
                _checkPerms();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool hasPermission;
  final VoidCallback onTap;
  final VoidCallback onGrant;

  const _SourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.hasPermission,
    required this.onTap,
    required this.onGrant,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? NudgeTokens.finB.withValues(alpha: 0.08) : NudgeTokens.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? NudgeTokens.finB.withValues(alpha: 0.5) : NudgeTokens.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? NudgeTokens.finB : NudgeTokens.textLow, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: selected ? NudgeTokens.finB : Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  Text(subtitle,
                      style: const TextStyle(color: NudgeTokens.textLow, fontSize: 11)),
                ],
              ),
            ),
            if (!hasPermission)
              TextButton(
                onPressed: onGrant,
                style: TextButton.styleFrom(
                    foregroundColor: NudgeTokens.amber,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Text('Grant', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              )
            else if (selected)
              const Icon(Icons.check_circle_rounded, color: NudgeTokens.finB, size: 18),
          ],
        ),
      ),
    );
  }
}
