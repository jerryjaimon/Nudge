import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app.dart' show NudgeTokens;
import '../../storage.dart';
import '../../utils/food_service.dart';
import '../../services/health_center_service.dart';

class NutritionSettingsScreen extends StatefulWidget {
  const NutritionSettingsScreen({super.key});

  @override
  State<NutritionSettingsScreen> createState() => _NutritionSettingsScreenState();
}

class _NutritionSettingsScreenState extends State<NutritionSettingsScreen> {
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  
  String _activityLevel = 'Moderate';
  String _goal = 'Maintenance';

  final List<String> _activityOptions = ['Sedentary', 'Light', 'Moderate', 'Active', 'Very Active'];
  final List<String> _goalOptions = ['Weight Loss', 'Maintenance', 'Muscle Gain'];

  Map<String, double> _macros = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final profile = HealthCenterService.profile;
    final box = AppStorage.settingsBox;

    // Prefer HealthCenterService profile data (source of truth)
    final h = (profile['heightCm'] as num?)?.toDouble() ??
        (box.get('user_height', defaultValue: 170.0) as double);
    final w = (profile['weightKg'] as num?)?.toDouble() ??
        (box.get('user_weight', defaultValue: 70.0) as double);
    _heightCtrl.text = h.toStringAsFixed(0);
    _weightCtrl.text = w.toStringAsFixed(1);

    final hcActivity = profile['activityLevel'] as String? ?? '';
    final hcGoal = profile['goal'] as String? ?? '';
    _activityLevel = hcActivity.isNotEmpty
        ? _activityToDisplay(hcActivity)
        : (box.get('user_activity', defaultValue: 'Moderate') as String);
    _goal = hcGoal.isNotEmpty
        ? _goalToDisplay(hcGoal)
        : (box.get('user_goal', defaultValue: 'Maintenance') as String);

    _refreshMacros();
  }

  // ── Format converters ──────────────────────────────────────────────────────

  String _activityToDisplay(String hc) {
    const map = {
      'sedentary': 'Sedentary',
      'light': 'Light',
      'moderate': 'Moderate',
      'active': 'Active',
      'very_active': 'Very Active',
    };
    return map[hc] ?? 'Moderate';
  }

  String _activityToHC(String display) {
    const map = {
      'Sedentary': 'sedentary',
      'Light': 'light',
      'Moderate': 'moderate',
      'Active': 'active',
      'Very Active': 'very_active',
    };
    return map[display] ?? 'moderate';
  }

  String _goalToDisplay(String hc) {
    const map = {'lose': 'Weight Loss', 'maintain': 'Maintenance', 'gain': 'Muscle Gain'};
    return map[hc] ?? 'Maintenance';
  }

  String _goalToHC(String display) {
    const map = {'Weight Loss': 'lose', 'Maintenance': 'maintain', 'Muscle Gain': 'gain'};
    return map[display] ?? 'maintain';
  }

  void _refreshMacros() {
    setState(() {
      _macros = FoodService.getMacroGoals();
    });
  }

  Future<void> _saveSettings() async {
    final h = double.tryParse(_heightCtrl.text) ?? 170.0;
    final w = double.tryParse(_weightCtrl.text) ?? 70.0;

    // Keep settings_box in sync (legacy fallback)
    final box = AppStorage.settingsBox;
    box.put('user_height', h);
    box.put('user_weight', w);
    box.put('user_activity', _activityLevel);
    box.put('user_goal', _goal);

    // Sync to HealthCenterService — this recalculates macros properly
    // (uses real gender/age if already set in profile)
    final existing = Map<String, dynamic>.from(HealthCenterService.profile);
    await HealthCenterService.saveProfile({
      ...existing,
      'heightCm': h,
      'weightKg': w,
      'activityLevel': _activityToHC(_activityLevel),
      'goal': _goalToHC(_goal),
    });

    _refreshMacros();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nutrition profile saved!'),
          backgroundColor: NudgeTokens.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: NudgeTokens.foodB),
            onPressed: _saveSettings,
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Body Metrics',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          _buildTextField('Height (cm)', _heightCtrl, Icons.height_rounded),
          const SizedBox(height: 16),
          _buildTextField('Weight (kg)', _weightCtrl, Icons.monitor_weight_rounded),
          
          const SizedBox(height: 32),
          Text(
            'Lifestyle & Goals',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          _buildDropdown('Activity Level', _activityLevel, _activityOptions, (val) {
            setState(() => _activityLevel = val!);
          }),
          const SizedBox(height: 16),
          _buildDropdown('Primary Goal', _goal, _goalOptions, (val) {
            setState(() => _goal = val!);
          }),
          
          const SizedBox(height: 48),
          if (_macros.isNotEmpty) _buildMacroDisplay(),
          
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: NudgeTokens.foodB,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _saveSettings,
            child: const Text('Calculate & Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, IconData icon) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: NudgeTokens.textLow),
        filled: true,
        fillColor: NudgeTokens.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: NudgeTokens.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      dropdownColor: NudgeTokens.surface,
      items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildMacroDisplay() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: NudgeTokens.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: Column(
        children: [
          Text(
            'Daily Targets',
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: NudgeTokens.foodB),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MacroRing('Calories', _macros['calories'] ?? 0, 'kcal', Colors.white),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MacroStat('Protein', _macros['protein'] ?? 0, NudgeTokens.blue),
              _MacroStat('Carbs', _macros['carbs'] ?? 0, NudgeTokens.amber),
              _MacroStat('Fat', _macros['fat'] ?? 0, NudgeTokens.red),
              _MacroStat('Fibre', _macros['fibre'] ?? 0, NudgeTokens.green),
            ],
          )
        ],
      ),
    );
  }
}

class _MacroRing extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color color;

  const _MacroRing(this.label, this.value, this.unit, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${value.toInt()}',
          style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          '$label ($unit)',
          style: const TextStyle(fontSize: 12, color: NudgeTokens.textLow, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _MacroStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MacroStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${value.toInt()}g',
          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

