import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/card_model.dart';
import '../models/card_type.dart';
import '../providers/app_state.dart';

class AddCardSheet extends StatefulWidget {
  const AddCardSheet({super.key});

  @override
  State<AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<AddCardSheet> {
  final _titleController = TextEditingController();
  
  // Icon Selection
  IconData _selectedIcon = Icons.edit;
  
  CardType _selectedType = CardType.habit;
  Frequency _selectedFrequency = Frequency.daily;
  int _target = 1;

  final List<IconData> _availableIcons = [
    Icons.edit, Icons.directions_run, Icons.fitness_center, Icons.local_drink,
    Icons.book, Icons.code, Icons.language, Icons.music_note,
    Icons.movie, Icons.videogame_asset, Icons.brush, Icons.camera_alt,
    Icons.bed, Icons.sunny, Icons.nightlight_round, Icons.local_fire_department,
    Icons.star, Icons.favorite, Icons.check_circle, Icons.timer,
    Icons.attach_money, Icons.work, Icons.school, Icons.home,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 24, 
        left: 24, 
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("New Nudge", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: _showIconPicker,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).primaryColor, width: 2),
                  ),
                  child: Icon(_selectedIcon, color: Theme.of(context).primaryColor, size: 30),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                     labelText: "Title",
                     border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTypeSegment("Habit", CardType.habit),
                const SizedBox(width: 8),
                _buildTypeSegment("Counter", CardType.counter),
                const SizedBox(width: 8),
                _buildTypeSegment("Weight", CardType.weight),
                const SizedBox(width: 8),
                _buildTypeSegment("Movie", CardType.movie),
                const SizedBox(width: 8),
                _buildTypeSegment("Time", CardType.time),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_selectedType == CardType.habit) ...[
             const Text("Frequency"),
             const SizedBox(height: 8),
             Row(
               children: [
                 ChoiceChip(
                   label: const Text("Daily"), 
                   selected: _selectedFrequency == Frequency.daily,
                   onSelected: (v) => setState(() => _selectedFrequency = Frequency.daily),
                 ),
                 const SizedBox(width: 12),
                 ChoiceChip(
                   label: const Text("Weekly"), 
                   selected: _selectedFrequency == Frequency.weekly,
                   onSelected: (v) => setState(() => _selectedFrequency = Frequency.weekly),
                 ),
               ],
             ),
             const SizedBox(height: 16),
             if (_selectedFrequency == Frequency.weekly) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Times per week:"),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => setState(() => _target = _target > 1 ? _target - 1 : 1), 
                          icon: const Icon(Icons.remove),
                        ),
                        Text("$_target", style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          onPressed: () => setState(() => _target++), 
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    )
                  ],
                )
             ]
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text("Create"),
            ),
          )
        ],
      ),
    );
  }

  void _showIconPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _availableIcons.length,
          itemBuilder: (context, index) {
            final icon = _availableIcons[index];
            return GestureDetector(
              onTap: () {
                setState(() => _selectedIcon = icon);
                Navigator.pop(ctx);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedIcon == icon ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: _selectedIcon == icon ? Border.all(color: Theme.of(context).primaryColor, width: 2) : null,
                ),
                child: Icon(icon, color: Colors.black87),
              ),
            );
          },
        );
      }
    );
  }

  Widget _buildTypeSegment(String title, CardType type) {
    bool isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey.withValues(alpha: 0.3),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          title, 
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
          ),
        ),
      ),
    );
  }

  void _save() {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a title"), backgroundColor: Colors.red),
      );
      return;
    }
    
    final appState = Provider.of<AppState>(context, listen: false);
    
    final card = TrackerCard.create(
      title: _titleController.text,
      emoji: "", // Legacy field, empty now
      iconCodePoint: _selectedIcon.codePoint,
      type: _selectedType,
      frequency: _selectedFrequency,
      target: _selectedFrequency == Frequency.daily ? 1 : _target,
    );
    
    appState.addCard(card);
    Navigator.pop(context);
  }
}
