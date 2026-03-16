// lib/screens/health/goals_screen.dart

import 'package:flutter/material.dart';
import '../../app.dart' show NudgeTokens;
import '../../models/health_goal.dart';
import '../../services/health_center_service.dart';
import '../../utils/ai_analysis_service.dart';
import 'analysis_report_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:nudge/utils/nudge_theme_extension.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List<HealthGoal> _goals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _goals = HealthCenterService.getActiveGoals();
      _loading = false;
    });
  }

  void _addGoal() async {
    final result = await showModalBottomSheet<HealthGoal>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NudgeTokens.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => const _EditGoalSheet(),
    );

    if (result != null) {
      await HealthCenterService.saveGoal(result);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('HEALTH GOALS', style: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.8)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: NudgeTokens.healthB))
          : _goals.isEmpty
              ? _buildEmptyState()
              : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildAnalysisHero(),
                const SizedBox(height: 24),
                const Text('ACTIVE GOALS', style: TextStyle(color: NudgeTokens.textLow, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                const SizedBox(height: 12),
                ..._goals.map((g) => _GoalCard(
                  goal: g,
                  onDelete: () async {
                    await HealthCenterService.deleteGoal(g.id);
                    _load();
                  },
                )),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addGoal,
        backgroundColor: NudgeTokens.healthB,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildAnalysisHero() {
    final reports = AiAnalysisService.getSavedReports();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [NudgeTokens.purple.withValues(alpha: 0.2), NudgeTokens.purple.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NudgeTokens.purple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: NudgeTokens.purple, size: 20),
              const SizedBox(width: 10),
              Text('AI Health Coach', style: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh), fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Get a detailed analysis of your weekly performance compared to your goals.', style: TextStyle(color: NudgeTokens.textMid, fontSize: 12, height: 1.4)),
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton(
                onPressed: () async {
                  final notes = await showDialog<String>(
                    context: context,
                    builder: (ctx) {
                      final ctrl = TextEditingController();
                      return AlertDialog(
                        backgroundColor: NudgeTokens.card,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        title: Text('Add Weekly Notes', style: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh), fontSize: 18, fontWeight: FontWeight.w800)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Is there anything specific you need the AI to note for this report?', style: TextStyle(color: NudgeTokens.textMid, fontSize: 13, height: 1.4)),
                            const SizedBox(height: 16),
                            TextField(
                              controller: ctrl,
                              maxLines: 4,
                              style: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh), fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'e.g. Had a minor injury, felt very energetic, etc.',
                                hintStyle: const TextStyle(color: NudgeTokens.textLow, fontSize: 14),
                                filled: true,
                                fillColor: NudgeTokens.elevated,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, ""), child: const Text('Skip', style: TextStyle(color: NudgeTokens.textLow))),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, ctrl.text),
                            style: FilledButton.styleFrom(backgroundColor: NudgeTokens.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: const Text('Generate'),
                          ),
                        ],
                      );
                    }
                  );

                  if (notes == null) return;
                  if (!mounted) return;

                  showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: NudgeTokens.purple)));
                  try {
                    final report = await AiAnalysisService.generateWeeklyReport(userNotes: notes.isEmpty ? null : notes);
                    Navigator.pop(context); // Close loading
                    if (report != null) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AnalysisReportScreen(content: report, timestamp: DateTime.now().toIso8601String())));
                    }
                  } catch (e) {
                    if (mounted) Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: NudgeTokens.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Generate Report', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
              const SizedBox(width: 12),
              if (reports.isNotEmpty)
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => AnalysisReportScreen(content: reports.first['content'], timestamp: reports.first['timestamp'])));
                  },
                  child: const Text('View Last Report', style: TextStyle(color: NudgeTokens.purple, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flag_rounded, size: 64, color: NudgeTokens.textLow.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('No goals set yet', style: TextStyle(color: NudgeTokens.textMid, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Create your first health goal to track progress', style: TextStyle(color: NudgeTokens.textLow, fontSize: 12)),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final HealthGoal goal;
  final VoidCallback onDelete;

  const _GoalCard({required this.goal, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final progress = (goal.currentValue / goal.targetValue).clamp(0.0, 1.0);
    final daysLeft = goal.targetDate.difference(DateTime.now()).inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getCategoryColor(goal.category).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_getCategoryIcon(goal.category), color: _getCategoryColor(goal.category), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.title, style: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh), fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(goal.category.toUpperCase(), style: TextStyle(color: _getCategoryColor(goal.category), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                  ],
                ),
              ),
              IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded, color: NudgeTokens.textLow, size: 20)),
            ],
          ),
          const SizedBox(height: 16),
          Text(goal.description, style: const TextStyle(color: NudgeTokens.textMid, fontSize: 13, height: 1.4)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${goal.currentValue.toInt()} / ${goal.targetValue.toInt()} ${goal.unit}', style: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh), fontWeight: FontWeight.w900, fontSize: 14)),
              Text(daysLeft > 0 ? '$daysLeft days left' : 'Due today', style: const TextStyle(color: NudgeTokens.textLow, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: NudgeTokens.elevated,
              valueColor: AlwaysStoppedAnimation(_getCategoryColor(goal.category)),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String cat) {
    switch (cat) {
      case 'weight': return NudgeTokens.healthB;
      case 'fitness': return NudgeTokens.gymB;
      case 'nutrition': return NudgeTokens.foodB;
      default: return NudgeTokens.purple;
    }
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case 'weight': return Icons.monitor_weight_rounded;
      case 'fitness': return Icons.fitness_center_rounded;
      case 'nutrition': return Icons.restaurant_rounded;
      default: return Icons.star_rounded;
    }
  }
}

class _EditGoalSheet extends StatefulWidget {
  const _EditGoalSheet();

  @override
  State<_EditGoalSheet> createState() => _EditGoalSheetState();
}

class _EditGoalSheetState extends State<_EditGoalSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _targetValCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  String _category = 'weight';
  DateTime _targetDate = DateTime.now().add(const Duration(days: 30));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CREATE HEALTH GOAL', style: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh), fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 20),
          _buildTextField('Goal Title', 'e.g. Lose 5kg', _titleCtrl),
          const SizedBox(height: 16),
          _buildTextField('AI-Readable Description', 'Providing context for AI analysis...', _descCtrl, maxLines: 3),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTextField('Target Value', '0', _targetValCtrl, keyboard: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField('Unit', 'kg', _unitCtrl)),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Category', style: TextStyle(color: NudgeTokens.textLow, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _buildCategoryPicker(),
          const SizedBox(height: 16),
          const Text('Target Date', style: TextStyle(color: NudgeTokens.textLow, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _targetDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
              );
              if (d != null) setState(() => _targetDate = d);
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: NudgeTokens.elevated, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, color: NudgeTokens.textMid, size: 18),
                  const SizedBox(width: 12),
                  Text('${_targetDate.day}/${_targetDate.month}/${_targetDate.year}', style: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                if (_titleCtrl.text.isEmpty) return;
                final goal = HealthGoal(
                  id: const Uuid().v4(),
                  title: _titleCtrl.text,
                  description: _descCtrl.text,
                  category: _category,
                  targetValue: double.tryParse(_targetValCtrl.text) ?? 0,
                  unit: _unitCtrl.text,
                  startDate: DateTime.now(),
                  targetDate: _targetDate,
                );
                Navigator.pop(context, goal);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: NudgeTokens.healthB,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Save Goal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String hint, TextEditingController ctrl, {int maxLines = 1, TextInputType? keyboard}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: NudgeTokens.textLow, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboard,
          style: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh), fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: NudgeTokens.textLow, fontSize: 14),
            filled: true,
            fillColor: NudgeTokens.elevated,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryPicker() {
    final cats = ['weight', 'fitness', 'nutrition', 'lifestyle'];
    return Row(
      children: cats.map((c) => Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _category = c),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: _category == c ? NudgeTokens.healthB : NudgeTokens.elevated,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(c[0].toUpperCase() + c.substring(1), style: TextStyle(color: _category == c ? Colors.white : NudgeTokens.textMid, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ),
      )).toList(),
    );
  }
}

