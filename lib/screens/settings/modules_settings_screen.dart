import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import '../../app.dart' show NudgeTokens;
import '../../storage.dart';
import '../../utils/health_service.dart';
import '../../utils/usage_service.dart';
import '../../utils/finance_service.dart';
import '../../utils/pomodoro_service.dart';
import '../digital_wellbeing/digital_wellbeing_screen.dart';
import '../food/nutrition_settings_screen.dart';
import 'settings_widgets.dart';

class ModulesSettingsScreen extends StatefulWidget {
  const ModulesSettingsScreen({super.key});

  @override
  State<ModulesSettingsScreen> createState() => _ModulesSettingsScreenState();
}

class _ModulesSettingsScreenState extends State<ModulesSettingsScreen> {
  bool _healthEnabled = false;
  bool _usagePermission = false;
  bool _revolutPermission = false;
  bool _overlayPermission = false;
  String _blockerTone = 'motivating';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final health = await HealthService.isEnabled();
    final usage = await UsageService.checkPermission();
    final revolut = await FinanceService.checkNotificationPermission();
    final overlay = await PomodoroService.checkOverlayPermission();
    
    setState(() {
      _healthEnabled = health;
      _usagePermission = usage;
      _revolutPermission = revolut;
      _overlayPermission = overlay;
      _blockerTone = AppStorage.settingsBox.get('blocker_tone', defaultValue: 'motivating') as String;
    });
  }

  static const _allModules = [
    ('gym',       'Gym & Fitness',    Icons.fitness_center_rounded),
    ('food',      'Food & Nutrition', Icons.restaurant_rounded),
    ('health',    'Health',           Icons.monitor_heart_rounded),
    ('my_habits', 'My Habits',        Icons.checklist_rounded),
    ('habits',    'Protected Habits', Icons.lock_rounded),
    ('pomodoro',  'Pomodoro',         Icons.timer_rounded),
    ('finance',   'Finance',          Icons.account_balance_wallet_rounded),
    ('movies',    'Movies',           Icons.local_movies_rounded),
    ('books',     'Books',            Icons.menu_book_rounded),
    ('detox',     'Digital Detox',    Icons.timer_off_rounded),
  ];

  List<Widget> _buildModuleToggles() {
    final enabled = AppStorage.enabledModules.toSet();
    return _allModules.map((m) {
      final (key, label, icon) = m;
      final isOn = enabled.contains(key);
      return SettingTile(
        icon: icon,
        title: label,
        subtitle: isOn ? 'Visible on Home' : 'Hidden',
        trailing: Switch(
          value: isOn,
          activeThumbColor: NudgeTokens.purple,
          activeTrackColor: NudgeTokens.purple.withValues(alpha: 0.35),
          onChanged: (v) {
            final mods = AppStorage.enabledModules.toList();
            if (v) { if (!mods.contains(key)) mods.add(key); }
            else   { mods.remove(key); }
            AppStorage.enabledModules = mods;
            setState(() {});
          },
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modules')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          const SectionHeader(title: 'Visibility'),
          ..._buildModuleToggles(),
          
          const SizedBox(height: 24),
          const SectionHeader(title: 'Integrations & Permissions'),
          SettingTile(
            icon: Icons.health_and_safety_rounded,
            title: 'Health Connect',
            subtitle: _healthEnabled ? 'Enabled' : 'Disabled',
            trailing: Switch(
              value: _healthEnabled,
              onChanged: (v) async {
                if (v) {
                  final granted = await HealthService.requestPermissions();
                  if (granted) await HealthService.setEnabled(true);
                } else {
                  await HealthService.setEnabled(false);
                }
                _load();
              },
            ),
          ),
          SettingTile(
            icon: Icons.track_changes_rounded,
            title: 'Usage Access',
            subtitle: _usagePermission ? 'Granted' : 'Click to grant',
            onTap: () async {
              await UsageService.requestPermission();
              _load();
            },
            trailing: Icon(
              _usagePermission ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
              color: _usagePermission ? NudgeTokens.green : NudgeTokens.amber,
              size: 20,
            ),
          ),
          SettingTile(
            icon: Icons.account_balance_rounded,
            title: 'Revolut Sync',
            subtitle: _revolutPermission ? 'Listening for payments' : 'Grant notification access',
            onTap: () async {
              await FinanceService.requestNotificationPermission();
              Future.delayed(const Duration(seconds: 2), _load);
            },
            trailing: Icon(
              _revolutPermission ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
              color: _revolutPermission ? NudgeTokens.green : NudgeTokens.amber,
              size: 20,
            ),
          ),
          SettingTile(
            icon: Icons.layers_rounded,
            title: 'Pomodoro App Blocker',
            subtitle: _overlayPermission ? 'Focus mode overlay active' : 'Grant overlay access',
            onTap: () async {
              await PomodoroService.requestOverlayPermission();
              Future.delayed(const Duration(seconds: 2), _load);
            },
            trailing: Icon(
              _overlayPermission ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
              color: _overlayPermission ? NudgeTokens.green : NudgeTokens.amber,
              size: 20,
            ),
          ),
          _BlockerToneTile(
            current: _blockerTone,
            onChanged: (tone) async {
              await AppStorage.settingsBox.put('blocker_tone', tone);
              setState(() => _blockerTone = tone);
            },
          ),

          const SizedBox(height: 24),
          const SectionHeader(title: 'Module Configuration'),
          SettingTile(
            icon: Icons.apps_rounded,
            title: 'Apps to Track',
            subtitle: 'Select apps for your dashboard',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppSelectionScreen())),
            trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow),
          ),
          SettingTile(
            icon: Icons.timer_off_rounded,
            title: 'Digital Detox',
            subtitle: 'Schedule app blocking',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DigitalWellbeingScreen(initialTab: 1))),
            trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow),
          ),
          SettingTile(
            icon: Icons.restaurant_menu_rounded,
            title: 'Nutrition Profile',
            subtitle: 'Set your macros and goals',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NutritionSettingsScreen())),
            trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow),
          ),
          SettingTile(
            icon: Icons.fitness_center_rounded,
            title: 'Exercise Manager',
            subtitle: 'Manage custom exercises',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExerciseManagerScreen())),
            trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow),
          ),
          SettingTile(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Finance Categories',
            subtitle: 'Manage budget tracking categories',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryManagerScreen())),
            trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow),
          ),
        ],
      ),
    );
  }
}

// ── Private Manager Screens ──────────────────────────────────────────────────
// Note: These were extracted from settings_screen.dart and renamed to follow public naming convention where appropriate.

class AppSelectionScreen extends StatefulWidget {
  const AppSelectionScreen({super.key});
  @override
  State<AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<AppSelectionScreen> {
  List<AppInfo> _apps = [];
  Set<String> _tracked = {};
  bool _loading = true;
  String _sortBy = 'name';
  Map<String, int> _lastUsedTime = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final apps = await InstalledApps.getInstalledApps(excludeSystemApps: true, withIcon: true);
    final trackedList = AppStorage.settingsBox.get('tracked_apps', defaultValue: <String>[]) as List;
    final stats = await UsageService.fetchUsageStats(monthly: false);
    final lastTimeMap = <String, int>{};
    for (var info in stats) {
      final last = int.tryParse(info.lastTimeUsed ?? '0') ?? 0;
      lastTimeMap[info.packageName!] = last;
    }
    setState(() {
      _apps = apps;
      _lastUsedTime = lastTimeMap;
      _tracked = Set<String>.from(trackedList);
      _sortApps();
      _loading = false;
    });
  }

  void _sortApps() {
    if (_sortBy == 'name') {
      _apps.sort((a, b) => (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase()));
    } else {
      _apps.sort((a, b) {
        final timeA = _lastUsedTime[a.packageName] ?? 0;
        final timeB = _lastUsedTime[b.packageName] ?? 0;
        return timeB.compareTo(timeA);
      });
    }
  }

  void _toggleSort() {
    setState(() {
      _sortBy = _sortBy == 'name' ? 'lastUsed' : 'name';
      _sortApps();
    });
  }

  void _toggle(String package) {
    setState(() {
      if (_tracked.contains(package)) _tracked.remove(package);
      else _tracked.add(package);
    });
    AppStorage.settingsBox.put('tracked_apps', _tracked.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Apps'),
        actions: [
          TextButton.icon(
            onPressed: _toggleSort,
            icon: Icon(_sortBy == 'name' ? Icons.sort_by_alpha_rounded : Icons.access_time_rounded, size: 16),
            label: Text(_sortBy == 'name' ? 'Name' : 'Last Use', style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _apps.length,
              itemBuilder: (context, index) {
                final app = _apps[index];
                final isTracked = _tracked.contains(app.packageName);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: NudgeTokens.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: NudgeTokens.border),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 48, height: 48, padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: app.icon != null ? Image.memory(app.icon!, fit: BoxFit.contain) : const Icon(Icons.android_rounded, color: NudgeTokens.textLow),
                    ),
                    title: Text(app.name ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    subtitle: Text(app.packageName ?? '', style: const TextStyle(fontSize: 10, color: NudgeTokens.textLow), maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Checkbox(
                      value: isTracked,
                      activeColor: NudgeTokens.purple,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      onChanged: (_) => _toggle(app.packageName!),
                    ),
                    onTap: () => _toggle(app.packageName!),
                  ),
                );
              },
            ),
    );
  }
}

class ExerciseManagerScreen extends StatefulWidget {
  const ExerciseManagerScreen({super.key});
  @override
  State<ExerciseManagerScreen> createState() => _ExerciseManagerScreenState();
}

class _ExerciseManagerScreenState extends State<ExerciseManagerScreen> {
  List<String> _custom = [];
  @override
  void initState() { super.initState(); _load(); }
  void _load() {
    setState(() {
      _custom = (AppStorage.gymBox.get('custom_exercises', defaultValue: <String>[]) as List).cast<String>();
    });
  }
  void _add() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NudgeTokens.surface,
        title: const Text('New Exercise'),
        content: TextField(controller: ctrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Bench Press')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isNotEmpty && !_custom.contains(text)) {
                _custom.add(text);
                AppStorage.gymBox.put('custom_exercises', _custom);
                _load();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          )
        ],
      )
    );
  }
  void _delete(int ix) {
    _custom.removeAt(ix);
    AppStorage.gymBox.put('custom_exercises', _custom);
    _load();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Exercises'), actions: [IconButton(icon: const Icon(Icons.add_rounded), onPressed: _add)]),
      body: _custom.isEmpty
          ? const Center(child: Text('No custom exercises', style: TextStyle(color: NudgeTokens.textLow)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _custom.length,
              itemBuilder: (ctx, i) => ListTile(
                title: Text(_custom[i], style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded, color: NudgeTokens.red), onPressed: () => _delete(i)),
              ),
            ),
    );
  }
}

class CategoryManagerScreen extends StatefulWidget {
  const CategoryManagerScreen({super.key});
  @override
  State<CategoryManagerScreen> createState() => _CategoryManagerScreenState();
}

class _CategoryManagerScreenState extends State<CategoryManagerScreen> {
  List<String> _cats = [];
  @override
  void initState() { super.initState(); _load(); }
  void _load() {
    setState(() {
      _cats = (AppStorage.financeBox.get('custom_categories', defaultValue: <String>[]) as List).cast<String>();
    });
  }
  void _add() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NudgeTokens.surface,
        title: const Text('New Category'),
        content: TextField(controller: ctrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Subscriptions')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isNotEmpty && !_cats.contains(text)) {
                _cats.add(text);
                AppStorage.financeBox.put('custom_categories', _cats);
                _load();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          )
        ],
      )
    );
  }
  void _delete(int ix) {
    _cats.removeAt(ix);
    AppStorage.financeBox.put('custom_categories', _cats);
    _load();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finance Categories'), actions: [IconButton(icon: const Icon(Icons.add_rounded), onPressed: _add)]),
      body: _cats.isEmpty
          ? const Center(child: Text('No custom categories', style: TextStyle(color: NudgeTokens.textLow)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _cats.length,
              itemBuilder: (ctx, i) => ListTile(
                title: Text(_cats[i], style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded, color: NudgeTokens.red), onPressed: () => _delete(i)),
              ),
            ),
    );
  }
}

class _BlockerToneTile extends StatelessWidget {
  final String current;
  final void Function(String) onChanged;
  const _BlockerToneTile({required this.current, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: NudgeTokens.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: NudgeTokens.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: NudgeTokens.purple.withValues(alpha: 0.15)), child: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: NudgeTokens.purple)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Blocker Message Tone', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: NudgeTokens.textHigh)),
              Text('What should the overlay say?', style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.textLow)),
            ]),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _ToneChip(label: '🚀 Motivating', selected: current == 'motivating', color: NudgeTokens.blue, onTap: () => onChanged('motivating')),
            const SizedBox(width: 10),
            _ToneChip(label: '😤 Scolding', selected: current == 'scolding', color: NudgeTokens.red, onTap: () => onChanged('scolding')),
          ]),
        ],
      ),
    );
  }
}

class _ToneChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _ToneChip({required this.label, required this.selected, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected ? color.withValues(alpha: 0.15) : NudgeTokens.elevated,
            border: Border.all(color: selected ? color.withValues(alpha: 0.5) : NudgeTokens.border, width: selected ? 1.5 : 1),
          ),
          child: Text(label, textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? color : NudgeTokens.textLow)),
        ),
      ),
    );
  }
}
