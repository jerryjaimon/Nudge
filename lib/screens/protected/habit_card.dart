// lib/screens/protected/habit_card.dart
import 'package:flutter/material.dart';
import '../../app.dart' show NudgeTokens;

class HabitCard extends StatelessWidget {
  final String title;
  final int iconCode;
  final int count;
  final List<int> last7;
  final String type;
  final int target;
  final VoidCallback onTapEdit;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const HabitCard({
    super.key,
    required this.title,
    required this.iconCode,
    required this.count,
    required this.last7,
    required this.type,
    required this.target,
    required this.onTapEdit,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    final maxV = last7.isEmpty ? 1 : (last7.reduce((a, b) => a > b ? a : b).clamp(1, 999999));
    final todayCount = last7.isNotEmpty ? last7.last : 0;
    
    final isQuit = type == 'quit';
    
    // Logic for "Build" habit:
    //  - green if todayCount >= target
    //  - text low if < target
    // Logic for "Quit" habit:
    //  - green if todayCount <= target
    //  - red if todayCount > target
    
    Color accentColor;
    String statusText;
    
    if (isQuit) {
      if (todayCount > target) {
        accentColor = Colors.redAccent;
        statusText = 'Over limit ($todayCount / $target)';
      } else {
        accentColor = NudgeTokens.green;
        statusText = 'Under limit ($todayCount / $target)';
      }
    } else {
      if (todayCount >= target) {
        accentColor = NudgeTokens.green;
        statusText = 'Target reached ($todayCount / $target)';
      } else {
        accentColor = (todayCount > 0) ? NudgeTokens.blue : NudgeTokens.textLow;
        statusText = 'In progress ($todayCount / $target)';
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTapEdit,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
             color: NudgeTokens.card,
            border: Border.all(
              color: accentColor.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                   // Icon
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: accentColor.withValues(alpha: 0.10),
                      border: Border.all(color: accentColor.withValues(alpha: 0.20)),
                    ),
                    child: Icon(
                      IconData(iconCode, fontFamily: 'MaterialIcons'),
                      size: 18,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                           maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          statusText,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: accentColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  // Count badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: accentColor.withValues(alpha: 0.12),
                      border: Border.all(color: accentColor.withValues(alpha: 0.22)),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Mini bar chart + controls row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Minus
                  _SmallIconBtn(
                    icon: Icons.remove_rounded,
                    onPressed: onMinus,
                    color: isQuit ? Colors.redAccent : NudgeTokens.textLow,
                  ),
                  const SizedBox(width: 6),
                  // 7-day bars
                  Expanded(
                    child: _MiniBars(
                      values: last7,
                      maxV: maxV,
                      isQuit: isQuit,
                      target: target,
                      accentColor: accentColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Plus
                  _SmallIconBtn(
                    icon: Icons.add_rounded,
                    onPressed: onPlus,
                    color: isQuit ? Colors.redAccent : NudgeTokens.green,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  const _SmallIconBtn({required this.icon, required this.onPressed, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: color.withValues(alpha: 0.10),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

class _MiniBars extends StatelessWidget {
  final List<int> values;
  final int maxV;
  final bool isQuit;
  final int target;
  final Color accentColor;

  const _MiniBars({
    required this.values,
    required this.maxV,
    required this.isQuit,
    required this.target,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final bars = values.isEmpty ? List<int>.filled(7, 0) : values;
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    // Today index: last7 index 6 is today
    const todayIdx = 6;

    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final v = i < bars.length ? bars[i] : 0;
          final h = maxV > 0 ? (v / maxV).clamp(0.0, 1.0) : 0.0;
          final isToday = i == todayIdx;
          final hasVal = v > 0;

          Color barColor;
          Color strokeColor = Colors.transparent;
          
          if (!hasVal) {
            barColor = NudgeTokens.elevated;
          } else {
            Color c;
            if (isQuit) {
              c = (v > target) ? Colors.redAccent : NudgeTokens.green;
            } else {
              c = (v >= target) ? NudgeTokens.green : NudgeTokens.blue;
            }
            barColor = isToday ? c : c.withValues(alpha: 0.45);
            strokeColor = c;
          }

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Bar
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        width: double.infinity,
                        height: hasVal ? (h * 28).clamp(4.0, 28.0) : 3,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: barColor,
                          border: isToday && hasVal
                              ? Border.all(color: strokeColor.withValues(alpha: 0.5), width: 0.5)
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Day label
                  Text(
                    days[i],
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                      color: isToday ? accentColor : NudgeTokens.textLow,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
