import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app.dart' show NudgeTokens;
import '../../storage.dart';
import '../../utils/finance_service.dart';
import '../../models/savings_jar.dart';
import '../../models/jar_transfer.dart';
import 'category_budget_settings_screen.dart';

class SavingsJarScreen extends StatefulWidget {
  const SavingsJarScreen({super.key});

  @override
  State<SavingsJarScreen> createState() => _SavingsJarScreenState();
}

class _SavingsJarScreenState extends State<SavingsJarScreen> {
  @override
  Widget build(BuildContext context) {
    final jars = AppStorage.savingsJarBox.values.where((j) => j.balance > 0).toList();
    final total = jars.fold(0.0, (sum, j) => sum + j.balance);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Jars'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: NudgeTokens.border),
        ),
      ),
      body: jars.isEmpty
          ? _EmptyJars()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Total Summary Pill
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: NudgeTokens.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: NudgeTokens.green.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: NudgeTokens.green, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          'Total in jars: £${total.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: NudgeTokens.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Jar Cards
                ...jars.map((j) => _JarCard(jar: j, onUpdate: () => setState(() {}))),
              ],
            ),
    );
  }
}

class _JarCard extends StatefulWidget {
  final SavingsJar jar;
  final VoidCallback onUpdate;
  const _JarCard({required this.jar, required this.onUpdate});

  @override
  State<_JarCard> createState() => _JarCardState();
}

class _JarCardState extends State<_JarCard> {
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final budget = AppStorage.categoryBudgetBox.get(widget.jar.categoryId);
    if (budget == null) return const SizedBox();

    final colour = _hexToColor(budget.colourHex);
    final goal = widget.jar.goalAmount ?? 0.0;
    final fillPct = goal > 0 ? (widget.jar.balance / goal).clamp(0.0, 1.0) : (widget.jar.balance / 500).clamp(0.1, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Jar Visual
                SizedBox(
                  width: 80,
                  height: 100,
                  child: CustomPaint(
                    painter: _JarPainter(fillPct: fillPct, colour: colour),
                  ),
                ),
                const SizedBox(width: 20),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(budget.icon, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(budget.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('£${widget.jar.balance.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w900, color: colour)),
                      if (goal > 0) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: fillPct,
                            minHeight: 6,
                            backgroundColor: NudgeTokens.elevated,
                            valueColor: AlwaysStoppedAnimation(colour),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('£${widget.jar.balance.toStringAsFixed(0)} of £${goal.toStringAsFixed(0)} goal', style: const TextStyle(color: NudgeTokens.textLow, fontSize: 11)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showTransferSheet(JarTransferDirection.toMonthlyBudget),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: NudgeTokens.blue,
                      side: const BorderSide(color: NudgeTokens.blue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Add to budget'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showTransferSheet(JarTransferDirection.toExternalSavings),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: NudgeTokens.green,
                      side: const BorderSide(color: NudgeTokens.green),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Move to savings'),
                  ),
                ),
              ],
            ),
          ),

          // History Toggle
          _HistorySection(
            categoryId: widget.jar.categoryId,
            isExpanded: _showHistory,
            onToggle: () => setState(() => _showHistory = !_showHistory),
          ),
        ],
      ),
    );
  }

  void _showTransferSheet(JarTransferDirection direction) {
     showModalBottomSheet(
       context: context,
       isScrollControlled: true,
       backgroundColor: NudgeTokens.surface,
       shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
       builder: (_) => _TransferSheet(jar: widget.jar, direction: direction, onSaved: widget.onUpdate),
     );
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return NudgeTokens.blue;
    }
  }
}

class _TransferSheet extends StatefulWidget {
  final SavingsJar jar;
  final JarTransferDirection direction;
  final VoidCallback onSaved;
  const _TransferSheet({required this.jar, required this.direction, required this.onSaved});

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.jar.balance.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final isToBudget = widget.direction == JarTransferDirection.toMonthlyBudget;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isToBudget ? 'Add to Month\'s Budget' : 'Move to External Savings',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Transferring from ${AppStorage.categoryBudgetBox.get(widget.jar.categoryId)?.name ?? 'Jar'}',
            style: const TextStyle(color: NudgeTokens.textLow, fontSize: 13),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              labelText: 'Transfer Amount',
              prefixText: '£ ',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'e.g. Spent on maintenance'),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _confirm,
              style: FilledButton.styleFrom(backgroundColor: isToBudget ? NudgeTokens.blue : NudgeTokens.green),
              child: const Text('Confirm Transfer'),
            ),
          ),
        ],
      ),
    );
  }

  void _confirm() async {
    final amount = double.tryParse(_amountCtrl.text) ?? 0.0;
    if (amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    if (amount > widget.jar.balance) {
      setState(() => _error = 'Cannot exceed jar balance (£${widget.jar.balance.toStringAsFixed(2)})');
      return;
    }

    await FinanceService.transferFromJar(
      categoryId: widget.jar.categoryId,
      amount: amount,
      direction: widget.direction,
      note: _noteCtrl.text.trim(),
    );

    widget.onSaved();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('£${amount.toStringAsFixed(2)} transferred')));
    }
  }
}

class _HistorySection extends StatelessWidget {
  final String categoryId;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _HistorySection({required this.categoryId, required this.isExpanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final transfers = AppStorage.jarTransferBox.values
        .where((t) => t.categoryId == categoryId)
        .toList()
      ..sort((a,b) => b.date.compareTo(a.date));

    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(isExpanded ? 'Hide history' : 'Show history', style: const TextStyle(color: NudgeTokens.textLow, fontSize: 11, fontWeight: FontWeight.w700)),
                Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 16, color: NudgeTokens.textLow),
              ],
            ),
          ),
        ),
        if (isExpanded)
           Container(
             padding: const EdgeInsets.all(16),
             color: NudgeTokens.elevated.withValues(alpha: 0.3),
             child: transfers.isEmpty
                 ? const Center(child: Text('No transfers yet', style: TextStyle(color: NudgeTokens.textLow, fontSize: 11)))
                 : Column(
                     children: transfers.map((t) => Padding(
                       padding: const EdgeInsets.only(bottom: 8),
                       child: Row(
                         children: [
                           Icon(
                             t.direction == JarTransferDirection.toMonthlyBudget ? Icons.arrow_upward_rounded : Icons.arrow_forward_rounded,
                             size: 14,
                             color: t.direction == JarTransferDirection.toMonthlyBudget ? NudgeTokens.blue : NudgeTokens.green,
                           ),
                           const SizedBox(width: 10),
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(t.direction == JarTransferDirection.toMonthlyBudget ? ' To monthly budget' : ' To external savings', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                 if (t.note != null && t.note!.isNotEmpty) Text(t.note!, style: const TextStyle(fontSize: 10, color: NudgeTokens.textLow)),
                               ],
                             ),
                           ),
                           Column(
                             crossAxisAlignment: CrossAxisAlignment.end,
                             children: [
                               Text('£${t.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                               Text('${t.date.day}/${t.date.month}', style: const TextStyle(fontSize: 10, color: NudgeTokens.textLow)),
                             ],
                           ),
                         ],
                       ),
                     )).toList(),
                   ),
           ),
      ],
    );
  }
}

class _JarPainter extends CustomPainter {
  final double fillPct;
  final Color colour;
  _JarPainter({required this.fillPct, required this.colour});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = NudgeTokens.textLow.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final fillPaint = Paint()
      ..color = colour.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final path = Path();
    // Glass jar shape
    path.moveTo(size.width * 0.2, size.height * 0.1); // top left neck
    path.lineTo(size.width * 0.8, size.height * 0.1); // top right neck
    path.quadraticBezierTo(size.width * 0.95, size.height * 0.1, size.width * 0.95, size.height * 0.3); // shoulder
    path.lineTo(size.width * 0.95, size.height * 0.85); // side
    path.quadraticBezierTo(size.width * 0.95, size.height * 0.95, size.width * 0.8, size.height * 0.95); // bottom right
    path.lineTo(size.width * 0.2, size.height * 0.95); // bottom
    path.quadraticBezierTo(size.width * 0.05, size.height * 0.95, size.width * 0.05, size.height * 0.85); // bottom left
    path.lineTo(size.width * 0.05, size.height * 0.3); // side left
    path.quadraticBezierTo(size.width * 0.05, size.height * 0.1, size.width * 0.2, size.height * 0.1); // shoulder left
    path.close();

    // Clip and draw fill
    canvas.save();
    canvas.clipPath(path);
    final fillHeight = size.height * 0.85 * fillPct;
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.95 - fillHeight, size.width, fillHeight), fillPaint);
    canvas.restore();

    canvas.drawPath(path, paint);

    // Lid
    final lidPaint = Paint()..color = Colors.brown.withValues(alpha: 0.8)..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromLTRBR(size.width * 0.15, 0, size.width * 0.85, size.height * 0.12, const Radius.circular(4)), lidPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _EmptyJars extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            height: 120,
            child: CustomPaint(painter: _JarPainter(fillPct: 0.0, colour: NudgeTokens.textLow)),
          ),
          const SizedBox(height: 24),
          const Text('No savings yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Enable rollover on a category\nto start saving surplus cash.', textAlign: TextAlign.center, style: TextStyle(color: NudgeTokens.textLow, fontSize: 13)),
          const SizedBox(height: 32),
           FilledButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryBudgetSettingsScreen())),
            style: FilledButton.styleFrom(backgroundColor: NudgeTokens.finB),
            child: const Text('Set up categories'),
          ),
        ],
      ),
    );
  }
}
