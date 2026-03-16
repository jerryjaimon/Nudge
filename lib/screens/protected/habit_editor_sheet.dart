// lib/screens/protected/habit_editor_sheet.dart
import 'package:flutter/material.dart';

class HabitEditorSheet extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const HabitEditorSheet({super.key, required this.initial});

  @override
  State<HabitEditorSheet> createState() => _HabitEditorSheetState();
}

class _HabitEditorSheetState extends State<HabitEditorSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _targetCtrl;
  late int _iconCode;
  String _type = 'build'; // 'build' or 'quit'
  TimeOfDay? _reminderTime;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: (widget.initial?['name'] as String?) ?? '');
    _targetCtrl = TextEditingController(text: (widget.initial?['target']?.toString()) ?? '1');
    _iconCode = (widget.initial?['iconCode'] is int)
        ? (widget.initial!['iconCode'] as int)
        : Icons.check_rounded.codePoint;
    _type = (widget.initial?['type'] as String?) ?? 'build';
    
    final rem = widget.initial?['reminderTime'] as String?;
    if (rem != null && rem.contains(':')) {
      final parts = rem.split(':');
      if (parts.length == 2) {
        _reminderTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 8,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  void _done() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    
    final target = int.tryParse(_targetCtrl.text.trim()) ?? 1;

    final now = DateTime.now().toIso8601String();
    
    String? remStr;
    if (_reminderTime != null) {
      remStr = '${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}';
    }

    Navigator.of(context).pop(<String, dynamic>{
      '__action': 'save',
      'id': widget.initial?['id'] ?? '${DateTime.now().millisecondsSinceEpoch}',
      'name': name,
      'iconCode': _iconCode,
      'type': _type,
      'target': target,
      'reminderTime': remStr,
      'createdAt': widget.initial?['createdAt'] ?? now,
      'updatedAt': now,
    });
  }

  void _delete() {
    final id = widget.initial?['id'];
    if (id == null) return;
    Navigator.of(context).pop(<String, dynamic>{'__action': 'delete', 'id': id});
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (t != null) {
      setState(() => _reminderTime = t);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final icons = <IconData>[
      Icons.check_rounded,
      Icons.local_fire_department_rounded,
      Icons.fitness_center_rounded,
      Icons.menu_book_rounded,
      Icons.timer_rounded,
      Icons.water_drop_rounded,
      Icons.directions_run_rounded,
      Icons.self_improvement_rounded,
      Icons.no_food_rounded,
      Icons.bolt_rounded,
      Icons.smoking_rooms_rounded,
      Icons.fastfood_rounded,
      Icons.videogame_asset_rounded,
      Icons.phone_android_rounded,
      Icons.money_off_rounded,
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 14 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (widget.initial != null)
                    TextButton.icon(
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      label: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                    )
                  else
                    const SizedBox.shrink(),
                  const Spacer(),
                  TextButton(onPressed: _done, child: const Text('Done')),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Habit name', hintText: 'e.g. Read 10 pages'),
              ),
              const SizedBox(height: 16),
              
              // Type segment
              Text(
                'Habit Type',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'build', label: Text('Build Good Habit'), icon: Icon(Icons.trending_up_rounded)),
                  ButtonSegment(value: 'quit', label: Text('Quit Bad Habit'), icon: Icon(Icons.trending_down_rounded)),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
                style: SegmentedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.05),
                  selectedBackgroundColor: _type == 'build' ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                ),
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                   Expanded(
                     child: TextField(
                        controller: _targetCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Daily Target', helperText: 'Target count per day'),
                      ),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: InkWell(
                       onTap: _pickTime,
                       borderRadius: BorderRadius.circular(12),
                       child: InputDecorator(
                         decoration: InputDecoration(
                           labelText: 'Daily Reminder',
                           border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                           contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                         ),
                         child: Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Text(_reminderTime?.format(context) ?? 'None'),
                             if (_reminderTime != null)
                               GestureDetector(
                                 onTap: () => setState(() => _reminderTime = null),
                                 child: const Icon(Icons.close_rounded, size: 16),
                               )
                             else
                               const Icon(Icons.notifications_outlined, size: 18),
                           ],
                         ),
                       ),
                     ),
                   ),
                ],
              ),
              const SizedBox(height: 16),

              Text(
                'Icon',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: icons.map((ic) {
                  final isSel = _iconCode == ic.codePoint;
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _iconCode = ic.codePoint),
                    child: Ink(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: isSel ? Colors.white.withOpacity(0.16) : Colors.white.withOpacity(0.06),
                        border: Border.all(color: isSel ? Colors.white.withOpacity(0.40) : Colors.white.withOpacity(0.10)),
                      ),
                      child: Icon(ic),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
