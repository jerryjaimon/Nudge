// lib/screens/protected/icon_picker_sheet.dart
import 'package:flutter/material.dart';

class IconPickerSheet extends StatelessWidget {
  final int? selectedCode;
  const IconPickerSheet({super.key, this.selectedCode});

  static const List<IconData> icons = [
    Icons.bolt_rounded,
    Icons.check_circle_rounded,
    Icons.fitness_center_rounded,
    Icons.local_fire_department_rounded,
    Icons.water_drop_rounded,
    Icons.restaurant_rounded,
    Icons.self_improvement_rounded,
    Icons.menu_book_rounded,
    Icons.code_rounded,
    Icons.music_note_rounded,
    Icons.brush_rounded,
    Icons.sports_soccer_rounded,
    Icons.directions_run_rounded,
    Icons.work_rounded,
    Icons.coffee_rounded,
    Icons.wb_sunny_rounded,
    Icons.nights_stay_rounded,
    Icons.timer_rounded,
    Icons.cleaning_services_rounded,
    Icons.mood_rounded,
    Icons.spa_rounded,
    Icons.psychology_rounded,
    Icons.monitor_heart_rounded,
    Icons.keyboard_rounded,
    Icons.draw_rounded,
    Icons.attach_money_rounded,
    Icons.no_cell_rounded,
    Icons.bedtime_rounded,
    Icons.person_rounded,
    Icons.group_rounded,
    Icons.star_rounded,
    Icons.favorite_rounded,
    Icons.lightbulb_rounded,
    Icons.shopping_bag_rounded,
    Icons.pets_rounded,
    Icons.wifi_off_rounded,
    Icons.phone_android_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final sel = selectedCode;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pick icon',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop<int?>(null),
                  child: const Text('Cancel'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: icons.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemBuilder: (_, i) {
                  final icon = icons[i];
                  final code = icon.codePoint;
                  final isSel = sel == code;

                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).pop<int>(code),
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: isSel ? Colors.white.withOpacity(0.18) : Colors.white.withOpacity(0.06),
                        border: Border.all(color: Colors.white.withOpacity(isSel ? 0.22 : 0.10)),
                      ),
                      child: Icon(icon, size: 20),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
