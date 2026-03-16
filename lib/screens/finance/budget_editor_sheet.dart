// lib/screens/finance/budget_editor_sheet.dart
import 'package:flutter/material.dart';
import '../../app.dart' show NudgeTokens;

class BudgetEditorSheet extends StatefulWidget {
  final String monthLabel;
  final double currentBudget;

  const BudgetEditorSheet({
    super.key,
    required this.monthLabel,
    required this.currentBudget,
  });

  @override
  State<BudgetEditorSheet> createState() => _BudgetEditorSheetState();
}

class _BudgetEditorSheetState extends State<BudgetEditorSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.currentBudget > 0
          ? widget.currentBudget.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final v = double.tryParse(_ctrl.text.trim().replaceAll(',', '.')) ?? 0.0;
    if (v <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid budget amount.')),
      );
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set Budget',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      widget.monthLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: NudgeTokens.textLow,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monthly budget',
              prefixText: '£  ',
              prefixStyle: TextStyle(
                color: NudgeTokens.finB,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          const Text(
            'This budget applies to the selected month only.',
            style: TextStyle(
              fontSize: 11,
              color: NudgeTokens.textLow,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: NudgeTokens.finB,
                foregroundColor: const Color(0xFF001A0E),
              ),
              child: const Text('Save Budget'),
            ),
          ),
        ],
      ),
    );
  }
}
