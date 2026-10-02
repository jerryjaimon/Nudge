import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app.dart' show NudgeTokens;
import '../../utils/finance_service.dart';
import '../../models/category_budget.dart';
import '../../storage.dart';
import 'add_expense_sheet.dart';
import 'savings_jar_screen.dart';
import 'savings_jar_screen.dart';

class CategoryOverviewScreen extends StatefulWidget {
  final CategoryBudget category;
  const CategoryOverviewScreen({super.key, required this.category});

  @override
  State<CategoryOverviewScreen> createState() => _CategoryOverviewScreenState();
}

class _CategoryOverviewScreenState extends State<CategoryOverviewScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final spending = FinanceService.getSpendingByCategory(_month.year, _month.month);
    final spent = spending[widget.category.name] ?? 0.0;
    final limit = widget.category.monthlyLimit;
    final pct = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final pace = FinanceService.getCategoryPace(widget.category.name, _month.year, _month.month);

    final transactions = _loadFilteredTransactions();
    final jar = AppStorage.savingsJarBox.get(widget.category.id);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.category.icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text(widget.category.name),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _openAddExpense(),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Entry',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card with Progress Arc
          _HeaderCard(
            spent: spent,
            limit: limit,
            pct: pct,
            pace: pace,
            colour: _hexToColor(widget.category.colourHex),
          ),
          const SizedBox(height: 24),

          // Monthly History Chart
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text('6-MONTH HISTORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: NudgeTokens.textLow, letterSpacing: 1.5)),
          ),
          _HistoryChart(categoryName: widget.category.name, limit: limit, colour: _hexToColor(widget.category.colourHex)),
          const SizedBox(height: 24),

          // Savings Jar Card (if exists)
          if (jar != null && jar.balance > 0) ...[
            _JarLinkCard(balance: jar.balance, colour: _hexToColor(widget.category.colourHex)),
            const SizedBox(height: 24),
          ],

          // Transactions
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text('TRANSACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: NudgeTokens.textLow, letterSpacing: 1.5)),
          ),
          if (transactions.isEmpty)
             const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Text('No transactions for this month', style: TextStyle(color: NudgeTokens.textLow))))
          else
            _TransactionGroup(transactions: transactions, onEdit: _openAddExpense),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _loadFilteredTransactions() {
    final raw = AppStorage.financeBox.get('expenses', defaultValue: []) as List;
    final prefix = '${_month.year}-${_month.month.toString().padLeft(2, '0')}';
    return raw.map((e) => (e as Map).cast<String, dynamic>())
        .where((e) => (e['category'] as String?)?.toLowerCase() == widget.category.name.toLowerCase() && (e['date'] as String? ?? '').startsWith(prefix))
        .toList()
      ..sort((a,b) => (b['date'] as String? ?? '').compareTo(a['date'] as String? ?? ''));
  }

  Future<void> _openAddExpense({Map<String, dynamic>? initial}) async {
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NudgeTokens.elevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => AddExpenseSheet(initial: initial != null ? (Map.from(initial)..['category'] = widget.category.name) : {'category': widget.category.name}),
    );
    if (res == null) return;
    
    // Refresh
    setState(() {});
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return NudgeTokens.blue;
    }
  }
}

class _HeaderCard extends StatelessWidget {
  final double spent;
  final double limit;
  final double pct;
  final String pace;
  final Color colour;

  const _HeaderCard({required this.spent, required this.limit, required this.pct, required this.pace, required this.colour});

  @override
  Widget build(BuildContext context) {
    final paceColor = pace == 'over' ? NudgeTokens.red : (pace == 'at_risk' ? NudgeTokens.amber : NudgeTokens.green);
    // HeaderCard is only relevant for the current month

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: pct,
                    strokeWidth: 10,
                    strokeCap: StrokeCap.round,
                    backgroundColor: NudgeTokens.elevated,
                    valueColor: AlwaysStoppedAnimation(colour),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('£${spent.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900)),
                    Text('of £${limit.toStringAsFixed(0)}', style: const TextStyle(color: NudgeTokens.textLow, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                 decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: paceColor.withValues(alpha: 0.1)),
                 child: Text(pace.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: paceColor, fontSize: 11, fontWeight: FontWeight.w800)),
               ),
               const SizedBox(width: 12),
               const Text('12 days left', style: TextStyle(color: NudgeTokens.textLow, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryChart extends StatelessWidget {
  final String categoryName;
  final double limit;
  final Color colour;
  const _HistoryChart({required this.categoryName, required this.limit, required this.colour});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final data = <BarChartGroupData>[];
    
    for (int i = 5; i >= 0; i--) {
       final d = DateTime(now.year, now.month - i);
       final spending = FinanceService.getSpendingByCategory(d.year, d.month);
       final val = spending[categoryName] ?? 0.0;
       
       data.add(BarChartGroupData(
         x: 5 - i,
         barRods: [
           BarChartRodData(
             toY: val,
             color: val > limit ? NudgeTokens.red : colour,
             width: 16,
             borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
             backDrawRodData: BackgroundBarChartRodData(show: true, toY: limit, color: NudgeTokens.elevated),
           ),
         ],
       ));
    }

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: limit > 0 ? limit * 1.5 : 100,
          barGroups: data,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                   final d = DateTime(now.year, now.month - (5 - val.toInt()));
                   const months = ['J','F','M','A','M','J','J','A','S','O','N','D'];
                   return Padding(
                     padding: const EdgeInsets.only(top: 8),
                     child: Text(months[d.month - 1], style: const TextStyle(color: NudgeTokens.textLow, fontSize: 10, fontWeight: FontWeight.bold)),
                   );
                }
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JarLinkCard extends StatelessWidget {
  final double balance;
  final Color colour;
  const _JarLinkCard({required this.balance, required this.colour});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colour.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(shape: BoxShape.circle, color: colour.withValues(alpha: 0.15)),
            child: Text('🍯', style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Surplus in Jar', style: TextStyle(color: NudgeTokens.textLow, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                Text('£${balance.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: colour)),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavingsJarScreen())),
            style: FilledButton.styleFrom(backgroundColor: colour, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 16), textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            child: const Text('View Jar'),
          ),
        ],
      ),
    );
  }
}

class _TransactionGroup extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;
  final Function({Map<String, dynamic>? initial}) onEdit;
  const _TransactionGroup({required this.transactions, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Column(
        children: List.generate(transactions.length, (i) {
          final t = transactions[i];
          final isLast = i == transactions.length - 1;
          final merchant = (t['merchant'] as String?) ?? 'Unknown';
          final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;

          return InkWell(
            onTap: () => onEdit(initial: t),
            borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(20)) : (i == 0 ? const BorderRadius.vertical(top: Radius.circular(20)) : BorderRadius.zero),
            child: Column(
              children: [
                 Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                   child: Row(
                     children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: NudgeTokens.elevated),
                          child: Center(child: Text(merchant.isNotEmpty ? merchant[0] : '?', style: const TextStyle(fontWeight: FontWeight.bold))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                               Text(merchant, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                               Text(_formatDate(t['date']), style: const TextStyle(color: NudgeTokens.textLow, fontSize: 11)),
                            ],
                          ),
                        ),
                        Text('£${amount.abs().toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                     ],
                   ),
                 ),
                 if (!isLast) Divider(indent: 64, height: 1, color: NudgeTokens.border),
              ],
            ),
          );
        }),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    final s = date.toString();
    if (s.length < 10) return s;
    return s.substring(0, 10);
  }
}
