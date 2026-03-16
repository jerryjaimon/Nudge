// lib/screens/protected/habit_routine_card.dart
import 'package:flutter/material.dart';
import '../../app.dart' show NudgeTokens;

class RoutineCard extends StatefulWidget {
  final Map<String, dynamic> habit;
  final Map<String, dynamic> allLogs; // entire habit_logs dict
  final String dayIso;
  final void Function(String itemId, bool done) onToggleItem;
  final VoidCallback onLongPress;
  final VoidCallback onTap;

  const RoutineCard({
    super.key,
    required this.habit,
    required this.allLogs,
    required this.dayIso,
    required this.onToggleItem,
    required this.onLongPress,
    required this.onTap,
  });

  @override
  State<RoutineCard> createState() => _RoutineCardState();
}

class _RoutineCardState extends State<RoutineCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _animCtrl;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  static const _categoryColors = {
    'morning': NudgeTokens.amber,
    'evening': NudgeTokens.blue,
    'fitness': NudgeTokens.gymB,
    'mindfulness': NudgeTokens.purple,
    'finance': NudgeTokens.finB,
    'learning': NudgeTokens.booksB,
    'anytime': NudgeTokens.textMid,
  };

  Color get _catColor {
    final colorVal = widget.habit['color'];
    if (colorVal is int) return Color(colorVal);
    final cat = (widget.habit['category'] as String?) ?? 'anytime';
    return _categoryColors[cat] ?? NudgeTokens.textMid;
  }

  bool _itemDone(String habitId, String itemId) {
    final key = '${habitId}__$itemId';
    final perLog = widget.allLogs[key];
    if (perLog is Map) {
      final v = perLog[widget.dayIso];
      if (v is int) return v >= 1;
      if (v is num) return v >= 1;
    }
    return false;
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _animCtrl.forward();
    } else {
      _animCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final habitId = (widget.habit['id'] as String?) ?? '';
    final name = (widget.habit['name'] as String?) ?? 'Routine';
    final iconCode = (widget.habit['iconCode'] is int)
        ? (widget.habit['iconCode'] as int)
        : Icons.checklist_rounded.codePoint;
    final items =
        ((widget.habit['routineItems'] as List?) ?? []).cast<Map>();
    final catColor = _catColor;

    final doneCount = items.where((item) {
      final itemId = (item['id'] as String?) ?? '';
      return _itemDone(habitId, itemId);
    }).length;

    final allDone = items.isNotEmpty && doneCount == items.length;
    final progressPct = items.isEmpty ? 0.0 : doneCount / items.length;

    final borderColor = allDone
        ? NudgeTokens.green.withValues(alpha: 0.30)
        : NudgeTokens.border;

    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: NudgeTokens.card,
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            // Header
            InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              onTap: _toggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    // Color dot
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: catColor,
                      ),
                    ),
                    // Icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: catColor.withValues(alpha: 0.10),
                        border:
                            Border.all(color: catColor.withValues(alpha: 0.20)),
                      ),
                      child: Icon(
                        IconData(iconCode, fontFamily: 'MaterialIcons'),
                        size: 17,
                        color: catColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: NudgeTokens.textHigh,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          // Progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: progressPct,
                              minHeight: 3,
                              backgroundColor:
                                  NudgeTokens.elevated,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                allDone ? NudgeTokens.green : catColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Count badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: allDone
                            ? NudgeTokens.green.withValues(alpha: 0.12)
                            : NudgeTokens.elevated,
                        border: Border.all(
                          color: allDone
                              ? NudgeTokens.green.withValues(alpha: 0.25)
                              : NudgeTokens.borderHi,
                        ),
                      ),
                      child: Text(
                        '$doneCount/${items.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: allDone ? NudgeTokens.green : NudgeTokens.textMid,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: NudgeTokens.textLow,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Expanded items
            SizeTransition(
              sizeFactor: _expandAnim,
              child: Column(
                children: [
                  Container(
                    height: 1,
                    color: NudgeTokens.border,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No items in this routine yet.\nLong-press to edit.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: NudgeTokens.textLow,
                        ),
                      ),
                    )
                  else
                    ...items.map((item) {
                      final itemId = (item['id'] as String?) ?? '';
                      final itemName = (item['name'] as String?) ?? 'Item';
                      final itemIconCode = (item['iconCode'] is int)
                          ? (item['iconCode'] as int)
                          : Icons.check_rounded.codePoint;
                      final done = _itemDone(habitId, itemId);

                      return InkWell(
                        onTap: () =>
                            widget.onToggleItem(itemId, !done),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              // Checkbox
                              AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 200),
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: done
                                      ? NudgeTokens.green
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: done
                                        ? NudgeTokens.green
                                        : NudgeTokens.textLow,
                                    width: 1.5,
                                  ),
                                ),
                                child: done
                                    ? const Icon(Icons.check_rounded,
                                        size: 14, color: Colors.black)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              // Item icon
                              Icon(
                                IconData(itemIconCode,
                                    fontFamily: 'MaterialIcons'),
                                size: 16,
                                color: done
                                    ? NudgeTokens.textLow
                                    : NudgeTokens.textMid,
                              ),
                              const SizedBox(width: 8),
                              // Item name
                              Expanded(
                                child: Text(
                                  itemName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: done
                                        ? NudgeTokens.textLow
                                        : NudgeTokens.textHigh,
                                    decoration: done
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: NudgeTokens.textLow,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
