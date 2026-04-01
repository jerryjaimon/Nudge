import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app.dart' show NudgeTokens;
import '../../utils/food_service.dart';
import 'add_food_sheet.dart';
import 'edit_food_sheet.dart';

class FoodScreen extends StatefulWidget {
  const FoodScreen({super.key});

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  DateTime _currentDate = DateTime.now();
  List<Map<String, dynamic>> _entries = [];
  double _todayCals = 0.0;
  double _todayProt = 0.0;
  double _todayCarbs = 0.0;
  double _todayFat = 0.0;
  double _todayFibre = 0.0;
  
  Map<String, double> _goals = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _changeDate(int offset) {
    setState(() {
      _currentDate = _currentDate.add(Duration(days: offset));
    });
    _refresh();
  }

  Future<void> _refresh() async {
    final entries = await FoodService.getTodayEntries(date: _currentDate);
    final todayCals = await FoodService.getTodayCalories(date: _currentDate);
    
    double prot = 0;
    double carbs = 0;
    double fat = 0;
    double fibre = 0;
    
    for (var e in entries) {
      final servings = (e['servingsConsumed'] as num?)?.toDouble() ?? 1.0;
      prot += ((e['protein'] ?? e['proteinPerServing'] ?? 0) as num).toDouble() * servings;
      carbs += ((e['carbs'] ?? e['carbsPerServing'] ?? 0) as num).toDouble() * servings;
      fat += ((e['fat'] ?? e['fatPerServing'] ?? 0) as num).toDouble() * servings;
      fibre += ((e['fiber'] ?? e['fibre'] ?? e['fiberPerServing'] ?? 0) as num).toDouble() * servings;
    }
    
    final goals = FoodService.getMacroGoals();

    if (mounted) {
      setState(() {
        _entries = entries;
        _todayCals = todayCals;
        _todayProt = prot;
        _todayCarbs = carbs;
        _todayFat = fat;
        _todayFibre = fibre;
        _goals = goals;
      });
    }
  }

  Widget _buildDateSelector() {
    final now = DateTime.now();
    final isToday = _currentDate.year == now.year && _currentDate.month == now.month && _currentDate.day == now.day;
    final dateStr = isToday ? 'TODAY' : '${_currentDate.year}-${_currentDate.month.toString().padLeft(2, '0')}-${_currentDate.day.toString().padLeft(2, '0')}';

    return Container(
      color: NudgeTokens.bg,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, color: NudgeTokens.foodB),
            onPressed: () => _changeDate(-1),
          ),
          Text(
            dateStr,
            style: GoogleFonts.outfit(color: NudgeTokens.foodB, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1.5),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right_rounded, color: isToday ? NudgeTokens.foodB.withValues(alpha: 0.3) : NudgeTokens.foodB),
            onPressed: isToday ? null : () => _changeDate(1),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBars() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _MiniMacro('Protein', _todayProt, _goals['protein'] ?? 150, NudgeTokens.blue),
          _MiniMacro('Fat', _todayFat, _goals['fat'] ?? 65, NudgeTokens.red),
          _MiniMacro('Carbs', _todayCarbs, _goals['carbs'] ?? 200, NudgeTokens.amber),
          _MiniMacro('Fibre', _todayFibre, _goals['fibre'] ?? 30, NudgeTokens.green),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double goalCals = _goals['calories'] ?? 2000.0;
    final progress = (_todayCals / goalCals).clamp(0.0, 1.0);
    final now = DateTime.now();
    final isToday = _currentDate.year == now.year && _currentDate.month == now.month && _currentDate.day == now.day;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _addFood(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _HeaderCard(
                      today: _todayCals,
                      goal: goalCals,
                      progress: progress,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildMacroBars(),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      isToday ? 'TODAY\'S LOGS' : 'LOGS',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: NudgeTokens.textLow,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                if (_entries.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        isToday ? 'No food logged today.\nTap + to add something!' : 'No food logged on this day.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: NudgeTokens.textLow),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(
                        _buildMealGroups(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addFood(context),
        backgroundColor: NudgeTokens.foodB,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Log Food', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }

  void _addFood(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddFoodSheet(date: _currentDate),
    ).then((_) => _refresh());
  }

  void _addFoodToMeal(BuildContext context, String meal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddFoodSheet(initialMeal: meal, date: _currentDate),
    ).then((_) => _refresh());
  }

  void _reanalyzeMeal(BuildContext context, String meal, List<Map<String, dynamic>> items) {
    final description = items.map((e) => e['name'] ?? 'food').join(', ');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddFoodSheet(initialMeal: meal, initialDescription: description, date: _currentDate),
    ).then((_) => _refresh());
  }

  List<Widget> _buildMealGroups(BuildContext context) {
    const mealOrder = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final e in _entries) {
      final meal = (e['mealType'] as String?) ?? 'Other';
      grouped.putIfAbsent(meal, () => []).add(e);
    }
    final keys = grouped.keys.toList()
      ..sort((a, b) {
        final ai = mealOrder.indexOf(a);
        final bi = mealOrder.indexOf(b);
        if (ai == -1 && bi == -1) return a.compareTo(b);
        if (ai == -1) return 1;
        if (bi == -1) return -1;
        return ai.compareTo(bi);
      });

    final widgets = <Widget>[];
    for (final meal in keys) {
      final items = grouped[meal]!;
      final totalCal = items.fold<double>(0, (sum, e) {
        final servings = (e['servingsConsumed'] as num?)?.toDouble() ?? 1.0;
        return sum + ((e['calories'] ?? e['caloriesPerServing'] ?? 0) as num).toDouble() * servings;
      });

      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Row(
          children: [
            Text(
              meal.toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: NudgeTokens.textLow, letterSpacing: 1.2),
            ),
            const SizedBox(width: 8),
            Text(
              '${totalCal.toInt()} kcal',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: NudgeTokens.foodB),
            ),
            const Spacer(),
            InkWell(
              onTap: () => _reanalyzeMeal(context, meal, items),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 13, color: NudgeTokens.textLow),
                    SizedBox(width: 3),
                    Text('Re-analyze', style: TextStyle(fontSize: 11, color: NudgeTokens.textLow, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: () => _addFoodToMeal(context, meal),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 14, color: NudgeTokens.foodB),
                    SizedBox(width: 2),
                    Text('Add', style: TextStyle(fontSize: 11, color: NudgeTokens.foodB, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ));

      for (final e in items) {
        widgets.add(_FoodTile(
          entry: e,
          onDelete: () async {
            await FoodService.deleteEntry(e['id']);
            _refresh();
          },
          onTap: () async {
            final didEdit = await showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => EditFoodSheet(entry: e),
            );
            if (didEdit == true) _refresh();
          },
        ));
      }
    }
    return widgets;
  }
}

class _HeaderCard extends StatelessWidget {
  final double today;
  final double goal;
  final double progress;

  const _HeaderCard({required this.today, required this.goal, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [NudgeTokens.foodA, Color(0xFF3D2A14)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NudgeTokens.foodB.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: NudgeTokens.foodB.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Calories',
                    style: TextStyle(
                      color: NudgeTokens.foodB.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${today.toInt()}',
                        style: GoogleFonts.outfit(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '/ ${goal.toInt()} kcal',
                        style: const TextStyle(
                          color: NudgeTokens.textLow,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: NudgeTokens.foodB.withValues(alpha: 0.15),
                ),
                child: const Icon(Icons.restaurant_rounded, color: NudgeTokens.foodB, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              valueColor: const AlwaysStoppedAnimation(NudgeTokens.foodB),
            ),
          ),
          const SizedBox(height: 12),
          Builder(builder: (context) {
            final diff = (goal - today).toInt();
            final isOver = today > goal;
            return Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isOver ? NudgeTokens.red : NudgeTokens.green).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: (isOver ? NudgeTokens.red : NudgeTokens.green).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    isOver
                        ? '${diff.abs()} kcal over goal'
                        : '${diff.abs()} kcal under goal',
                    style: TextStyle(
                      color: isOver ? NudgeTokens.red : NudgeTokens.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 4),
          Text(
            today > goal ? 'Consider cutting back' : 'On track for your calorie goal',
            style: const TextStyle(
              color: NudgeTokens.textLow,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodTile extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  const _FoodTile({required this.entry, required this.onDelete, this.onTap});

  @override
  Widget build(BuildContext context) {
    final servings = (entry['servingsConsumed'] as num?)?.toDouble() ?? 1.0;
    final name = entry['name'] ?? 'Unknown';
    final cal = ((entry['calories'] ?? entry['caloriesPerServing'] ?? 0) as num).toDouble() * servings;
    final p = ((entry['protein'] ?? entry['proteinPerServing'] ?? 0) as num).toDouble() * servings;
    final c = ((entry['carbs'] ?? entry['carbsPerServing'] ?? 0) as num).toDouble() * servings;
    final f = ((entry['fat'] ?? entry['fatPerServing'] ?? 0) as num).toDouble() * servings;

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
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Row(
            children: [
              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
              if (entry['mealType'] != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: NudgeTokens.foodB.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: NudgeTokens.foodB.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    entry['mealType'].toString().toUpperCase(),
                    style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: NudgeTokens.foodB, letterSpacing: 0.5),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                _MacroChip(label: 'P', value: '${p.toInt()}g', color: Colors.blue),
                const SizedBox(width: 8),
                _MacroChip(label: 'C', value: '${c.toInt()}g', color: Colors.green),
                const SizedBox(width: 8),
                _MacroChip(label: 'F', value: '${f.toInt()}g', color: Colors.orange),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${cal.toInt()} kcal',
                style: const TextStyle(fontWeight: FontWeight.w800, color: NudgeTokens.foodB),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: NudgeTokens.red, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          value,
          style: const TextStyle(
            color: NudgeTokens.textLow,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MiniMacro extends StatelessWidget {
  final String label;
  final double current;
  final double goal;
  final Color color;

  const _MiniMacro(this.label, this.current, this.goal, this.color);

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    return Column(
      children: [
        SizedBox(
          width: 50,
          height: 50,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 4,
                color: color.withValues(alpha: 0.15),
              ),
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 4,
                color: color,
                strokeCap: StrokeCap.round,
              ),
              Center(
                child: Text(
                  '${current.toInt()}',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: NudgeTokens.textLow,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          '${goal.toInt()}g',
          style: TextStyle(
            fontSize: 10,
            color: NudgeTokens.textLow.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

