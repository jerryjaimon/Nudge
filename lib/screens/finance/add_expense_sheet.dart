// lib/screens/finance/add_expense_sheet.dart
import 'package:flutter/material.dart';
import '../../app.dart' show NudgeTokens;
import '../../storage.dart';
import '../../utils/finance_service.dart';
import 'package:nudge/utils/nudge_theme_extension.dart';

class AddExpenseSheet extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const AddExpenseSheet({super.key, this.initial});

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _amountCtrl = TextEditingController();
  final _merchantCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late DateTime _date;
  bool _isExpense = true; // true = expense (negative), false = income (positive)
  String _category = 'General';
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _categories = (AppStorage.financeBox.get('categories',
            defaultValue: <String>['Food', 'Shopping', 'Bills', 'Transport', 'General']) as List)
        .cast<String>();
    // Ensure 'Food' is always present and is the first default
    if (!_categories.contains('Food')) _categories.insert(0, 'Food');

    if (init != null) {
      final amount = (init['amount'] as num?)?.toDouble() ?? 0.0;
      _isExpense = amount <= 0;
      _amountCtrl.text = amount.abs().toStringAsFixed(2);
      _merchantCtrl.text = (init['merchant'] as String?) ?? '';
      _noteCtrl.text = (init['note'] as String?) ?? '';
      final dateStr = (init['date'] as String?) ?? '';
      // Use full ISO parse so auto-synced timestamps (2024-03-15T10:30:00Z) are preserved
      _date = _parseDate(dateStr) ?? DateTime.now();
      _category = (init['category'] as String?) ?? 'Food';
    } else {
      _date = DateTime.now();
      _category = 'Food'; // sensible default for manual entry
    }

    // When merchant changes, auto-suggest category from transaction history
    _merchantCtrl.addListener(_onMerchantChanged);
  }

  void _onMerchantChanged() {
    final merchant = _merchantCtrl.text.trim();
    if (merchant.length < 2) return;
    final suggested = FinanceService.suggestCategory(merchant);
    if (suggested != null && suggested != _category && _categories.contains(suggested)) {
      setState(() => _category = suggested);
    }
  }

  @override
  void dispose() {
    _merchantCtrl.removeListener(_onMerchantChanged);
    _amountCtrl.dispose();
    _merchantCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  DateTime? _parseDate(String iso) {
    if (iso.isEmpty) return null;
    // Try full ISO8601 first (handles "2024-03-15T10:30:00.000Z" from auto-sync)
    final full = DateTime.tryParse(iso);
    if (full != null) return DateTime(full.year, full.month, full.day);
    // Fallback: bare date "2024-03-15"
    try {
      final p = iso.split('-');
      return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    } catch (_) {
      return null;
    }
  }

  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          dialogTheme: const DialogThemeData(backgroundColor: NudgeTokens.elevated),
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(surface: NudgeTokens.elevated),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  // Parse a pasted Revolut notification text and fill in the fields
  void _parseRevolutText(String text) {
    if (text.trim().isEmpty) return;

    // Extract amount: £12.50, €23, $5.99
    final amountMatch =
        RegExp(r'[£€\$]\s*(\d+(?:[.,]\d{1,2})?)').firstMatch(text);
    if (amountMatch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find an amount in that text.')),
      );
      return;
    }
    final amountStr = amountMatch.group(1)!.replaceAll(',', '.');
    final amount = double.tryParse(amountStr) ?? 0.0;

    // Extract merchant — "at X" or "to X"
    String? merchant;
    final atMatch =
        RegExp(r'\bat\s+([^\.]+?)(?:\s*$|\.|,)', caseSensitive: false)
            .firstMatch(text);
    final toMatch =
        RegExp(r'\bto\s+([^\.]+?)(?:\s*$|\.|,)', caseSensitive: false)
            .firstMatch(text);
    if (atMatch != null) {
      merchant = atMatch.group(1)?.trim();
    } else if (toMatch != null) {
      merchant = toMatch.group(1)?.trim();
    }

    // Is it a refund?
    final isRefund = text.toLowerCase().contains('refund') ||
        text.toLowerCase().contains('cashback');

    setState(() {
      _amountCtrl.text = amount.toStringAsFixed(2);
      if (merchant != null && merchant.isNotEmpty) {
        _merchantCtrl.text = merchant;
      }
      _noteCtrl.text = text.trim();
      _isExpense = !isRefund;
    });
  }

  void _subtractAmount() {
    final cur = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final subCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NudgeTokens.card,
        title: const Text('Subtract Amount', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: subCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Amount to subtract', hintStyle: TextStyle(color: NudgeTokens.textLow)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: NudgeTokens.textLow))),
          FilledButton(
            onPressed: () {
              final sub = double.tryParse(subCtrl.text.replaceAll(',', '.')) ?? 0.0;
              setState(() {
                _amountCtrl.text = (cur - sub).clamp(0.0, 999999.0).toStringAsFixed(2);
              });
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: NudgeTokens.red),
            child: const Text('Subtract'),
          ),
        ],
      ),
    );
  }

  void _save() {
    final amountStr = _amountCtrl.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(amountStr) ?? 0.0;
    if (amount == 0.0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter an amount.')));
      return;
    }
    final merchant = _merchantCtrl.text.trim().isEmpty
        ? 'Unknown'
        : _merchantCtrl.text.trim();

    final init = widget.initial;
    final id = init?['id']?.toString() ??
        '${DateTime.now().millisecondsSinceEpoch}';

    Navigator.pop(context, {
      'id': id,
      'amount': _isExpense ? -amount : amount,
      'merchant': merchant,
      'category': _category,
      'date': _isoDate(_date),
      'createdAt': init?['createdAt'] ?? DateTime.now().toIso8601String(),
    });
  }

  Future<String?> _promptNewCategory() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NudgeTokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Category', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Category name', isDense: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), style: TextButton.styleFrom(foregroundColor: NudgeTokens.textLow), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), style: FilledButton.styleFrom(backgroundColor: NudgeTokens.finB), child: const Text('Add')),
        ],
      )
    );
  }

  void _delete() {
    final id = widget.initial?['id']?.toString();
    if (id == null) return;
    Navigator.pop(context, {'__action': 'delete', 'id': id});
  }

  String _dateLabel() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(_date.year, _date.month, _date.day);
    if (d == today) return 'Today';
    if (d == yesterday) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${_date.day} ${months[_date.month - 1]} ${_date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 0, bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Text(
                  isEditing ? 'Edit Expense' : 'Add Expense',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                if (isEditing)
                  IconButton(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: NudgeTokens.red),
                    tooltip: 'Delete',
                  ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const SizedBox(height: 16),

            // Expense / Income toggle
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: NudgeTokens.elevated,
                border: Border.all(color: NudgeTokens.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TypeBtn(
                      label: 'Expense',
                      active: _isExpense,
                      activeColor: NudgeTokens.red,
                      onTap: () => setState(() => _isExpense = true),
                      isFirst: true,
                    ),
                  ),
                  Expanded(
                    child: _TypeBtn(
                      label: 'Income',
                      active: !_isExpense,
                      activeColor: NudgeTokens.finB,
                      onTap: () => setState(() => _isExpense = false),
                      isFirst: false,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Amount
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: !isEditing,
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '£  ',
                prefixStyle: TextStyle(
                  color: _isExpense ? NudgeTokens.red : NudgeTokens.finB,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded, color: NudgeTokens.red, size: 20),
                  onPressed: _subtractAmount,
                  tooltip: 'Subtract',
                ),
              ),
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),

            // Merchant
            TextField(
              controller: _merchantCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Merchant / Payee (optional)', hintText: 'e.g. Tesco, Amazon'),
            ),
            const SizedBox(height: 12),

            // Note
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'e.g. coffee with team',
              ),
            ),
            const SizedBox(height: 14),

            // Category
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: NudgeTokens.elevated,
                border: Border.all(color: NudgeTokens.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _categories.contains(_category) ? _category : _categories.first,
                  isExpanded: true,
                  dropdownColor: NudgeTokens.card,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: NudgeTokens.textLow),
                  items: [
                    ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14)))),
                    const DropdownMenuItem(value: '__ADD_NEW__', child: Text('+ Add Category', style: TextStyle(fontSize: 14, color: NudgeTokens.finB, fontWeight: FontWeight.bold))),
                  ],
                  onChanged: (val) async {
                    if (val == '__ADD_NEW__') {
                       final newCat = await _promptNewCategory();
                       if (newCat != null && newCat.isNotEmpty && !_categories.contains(newCat)) {
                         setState(() {
                           _categories.add(newCat);
                           _category = newCat;
                         });
                         await AppStorage.financeBox.put('categories', _categories);
                       }
                    } else if (val != null) {
                       setState(() => _category = val);
                    }
                  }
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Date picker
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: NudgeTokens.elevated,
                  border: Border.all(color: NudgeTokens.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 16, color: NudgeTokens.textLow),
                    const SizedBox(width: 10),
                    Text(
                      _dateLabel(),
                      style: TextStyle(
                        color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh)),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded,
                        size: 18, color: NudgeTokens.textLow),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      _isExpense ? NudgeTokens.finB : NudgeTokens.finB,
                ),
                child: Text(isEditing ? 'Save Changes' : 'Add Expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  final bool isFirst;

  const _TypeBtn({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.horizontal(
            left: isFirst ? const Radius.circular(9) : Radius.zero,
            right: isFirst ? Radius.zero : const Radius.circular(9),
          ),
          color: active
              ? activeColor.withValues(alpha: 0.15)
              : Colors.transparent,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? activeColor : NudgeTokens.textLow,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
