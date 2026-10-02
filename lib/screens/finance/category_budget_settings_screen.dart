import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../app.dart' show NudgeTokens;
import '../../storage.dart';
import '../../utils/finance_service.dart';
import '../../models/category_budget.dart';
import 'category_overview_screen.dart';

class CategoryBudgetSettingsScreen extends StatefulWidget {
  const CategoryBudgetSettingsScreen({super.key});

  @override
  State<CategoryBudgetSettingsScreen> createState() => _CategoryBudgetSettingsScreenState();
}

class _CategoryBudgetSettingsScreenState extends State<CategoryBudgetSettingsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  final List<String> _dismissedBanners = [];

  @override
  void initState() {
    super.initState();
    FinanceService.seedDefaultCategories();
  }

  void _bumpMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  String _monthLabel() {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[_month.month - 1]} ${_month.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentMonth = _month.year == DateTime.now().year && _month.month == DateTime.now().month;
    final overspent = FinanceService.getOverspentCategories(_month.year, _month.month)
        .where((b) => !_dismissedBanners.contains(b.id))
        .toList();

    final categories = AppStorage.categoryBudgetBox.values
        .where((b) => !b.isArchived)
        .toList();

    final spending = FinanceService.getSpendingByCategory(_month.year, _month.month);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Budgets'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: NudgeTokens.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Overspend Banners
          if (isCurrentMonth)
            ...overspent.map((b) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: NudgeTokens.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NudgeTokens.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: NudgeTokens.red, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${b.name} is over budget this month',
                          style: const TextStyle(color: NudgeTokens.red, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _dismissedBanners.add(b.id)),
                        child: const Icon(Icons.close_rounded, color: NudgeTokens.red, size: 18),
                      ),
                    ],
                  ),
                )),

          // Month Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: NudgeTokens.card,
              border: Border.all(color: NudgeTokens.border),
            ),
            child: Row(
              children: [
                _NavBtn(icon: Icons.chevron_left_rounded, onTap: () => _bumpMonth(-1)),
                Expanded(
                  child: Text(
                    _monthLabel(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: NudgeTokens.textHigh,
                    ),
                  ),
                ),
                _NavBtn(icon: Icons.chevron_right_rounded, onTap: () => _bumpMonth(1)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (categories.isEmpty)
             _EmptyState(onAdd: _showAddEditSheet)
          else
            ...categories.map((b) {
              final spent = spending[b.name] ?? 0.0;
              final pct = b.monthlyLimit > 0 ? (spent / b.monthlyLimit).clamp(0.0, 1.0) : 0.0;
              final pace = FinanceService.getCategoryPace(b.name, _month.year, _month.month);

              return _CategoryTile(
                budget: b,
                spent: spent,
                pct: pct,
                pace: pace,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryOverviewScreen(category: b))),
                onEdit: () => _showAddEditSheet(existing: b),
              );
            }),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FilledButton.icon(
        onPressed: () => _showAddEditSheet(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Category'),
        style: FilledButton.styleFrom(
          backgroundColor: NudgeTokens.finB,
          foregroundColor: const Color(0xFF001A0E),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
    );
  }

  void _showAddEditSheet({CategoryBudget? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NudgeTokens.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddEditCategorySheet(existing: existing, onSaved: () => setState(() {})),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final CategoryBudget budget;
  final double spent;
  final double pct;
  final String pace;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _CategoryTile({
    required this.budget,
    required this.spent,
    required this.pct,
    required this.pace,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    Color barColor = NudgeTokens.blue;
    if (pct >= 0.8) {
      barColor = NudgeTokens.red;
    } else if (pct >= 0.5) {
      barColor = NudgeTokens.amber;
    }

    final paceColor = pace == 'over' ? NudgeTokens.red : (pace == 'at_risk' ? NudgeTokens.amber : NudgeTokens.green);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _hexToColor(budget.colourHex).withValues(alpha: 0.15),
                      border: Border.all(color: _hexToColor(budget.colourHex).withValues(alpha: 0.3)),
                    ),
                    child: Center(child: Text(budget.icon, style: const TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(budget.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        Row(
                          children: [
                            Text(
                              '£${spent.toStringAsFixed(0)} spent of £${budget.monthlyLimit.toStringAsFixed(0)}',
                              style: const TextStyle(color: NudgeTokens.textLow, fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: paceColor.withValues(alpha: 0.1),
                              ),
                              child: Text(
                                pace.replaceAll('_', ' ').toUpperCase(),
                                style: TextStyle(color: paceColor, fontSize: 9, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: NudgeTokens.elevated,
                  valueColor: AlwaysStoppedAnimation(barColor),
                ),
              ),
            ],
          ),
        ),
      ),
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

class _AddEditCategorySheet extends StatefulWidget {
  final CategoryBudget? existing;
  final VoidCallback onSaved;
  const _AddEditCategorySheet({this.existing, required this.onSaved});

  @override
  State<_AddEditCategorySheet> createState() => _AddEditCategorySheetState();
}

class _AddEditCategorySheetState extends State<_AddEditCategorySheet> {
  final _nameCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();
  String _icon = '🛒';
  String _colourHex = '#5AC8FA';
  bool _rollover = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameCtrl.text = widget.existing!.name;
      _limitCtrl.text = widget.existing!.monthlyLimit.toStringAsFixed(0);
      _icon = widget.existing!.icon;
      _colourHex = widget.existing!.colourHex;
      _rollover = widget.existing!.rolloverEnabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(widget.existing == null ? 'Add Category' : 'Edit Category', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800)),
              const Spacer(),
              if (widget.existing != null)
                 IconButton(
                   onPressed: _archive,
                   icon: const Icon(Icons.delete_outline_rounded, color: NudgeTokens.red),
                 ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Category Name',
              errorText: _error,
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          const Text('Icon', style: TextStyle(color: NudgeTokens.textLow, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: GridView.count(
              crossAxisCount: 6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: _icons.map((i) => GestureDetector(
                onTap: () => setState(() => _icon = i),
                child: Container(
                  decoration: BoxDecoration(
                    color: _icon == i ? NudgeTokens.finB.withValues(alpha: 0.2) : NudgeTokens.elevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _icon == i ? NudgeTokens.finB : NudgeTokens.border),
                  ),
                  child: Center(child: Text(i, style: const TextStyle(fontSize: 20))),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Colour', style: TextStyle(color: NudgeTokens.textLow, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _colours.map((c) => GestureDetector(
              onTap: () => setState(() => _colourHex = c),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(int.parse(c.replaceFirst('#', '0xFF'))),
                  border: Border.all(color: _colourHex == c ? Colors.white : Colors.transparent, width: 2),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _limitCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Monthly Limit', prefixText: '£ '),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Rollover enabled', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: const Text('Carry surplus to savings jar at end of month', style: TextStyle(fontSize: 11, color: NudgeTokens.textLow)),
            value: _rollover,
            activeThumbColor: NudgeTokens.finB,
            onChanged: (v) => setState(() => _rollover = v),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(backgroundColor: NudgeTokens.finB),
              child: const Text('Save Category'),
            ),
          ),
        ],
      ),
    );
  }

  void _save() async {
    final name = _nameCtrl.text.trim();
    final limit = double.tryParse(_limitCtrl.text) ?? 0.0;

    if (name.isEmpty) {
      setState(() => _error = 'Enter a name');
      return;
    }

    if (limit <= 0) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid monthly limit')));
       return;
    }

    // Unique name check
    final existing = AppStorage.categoryBudgetBox.values.any((b) => b.name.toLowerCase() == name.toLowerCase() && b.id != widget.existing?.id);
    if (existing) {
      setState(() => _error = 'Name must be unique');
      return;
    }

    final id = widget.existing?.id ?? const Uuid().v4();
    final b = CategoryBudget(
      id: id,
      name: name,
      icon: _icon,
      colourHex: _colourHex,
      monthlyLimit: limit,
      rolloverEnabled: _rollover,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    await AppStorage.categoryBudgetBox.put(id, b);
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  void _archive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NudgeTokens.card,
        title: const Text('Archive Category?'),
        content: const Text('This will hide the category from budgets. Historical data remains.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Archive', style: TextStyle(color: NudgeTokens.red))),
        ],
      ),
    );
    if (confirmed == true && widget.existing != null) {
      widget.existing!.isArchived = true;
      await widget.existing!.save();
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    }
  }

  static const _icons = ['🛒', '🚌', '🍕', '⚡', '🏠', '💊', '🎬', '👔', '✈️', '🐶', '📚', '🎮', '💇', '🏋️', '🚇', '⛽', '🎁', '☕', '👗', '📦'];
  static const _colours = ['#39D98A','#5AC8FA','#FFBF00','#7C4DFF','#FF4D6A','#FF9F0A','#30D158','#8E8E93','#FF3B30','#AF52DE'];
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.category_outlined, size: 64, color: NudgeTokens.textLow.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('No categories yet', style: TextStyle(color: NudgeTokens.textLow, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextButton(onPressed: onAdd, child: const Text('Add your first category')),
        ],
      ),
    );
  }
}

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
