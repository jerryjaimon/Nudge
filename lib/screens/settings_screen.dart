import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import '../app.dart';
import '../utils/gemini_service.dart';
import '../storage.dart';
import '../utils/health_service.dart';
import '../utils/usage_service.dart';
import '../utils/finance_service.dart';
import '../utils/pomodoro_service.dart';
import '../utils/notification_service.dart';
import 'export/export_screen.dart';
import 'finance/raw_notification_screen.dart';
import 'raw_health_screen.dart';
import 'food/nutrition_settings_screen.dart';
import 'detox/detox_screen.dart';
import 'settings/theme_settings_screen.dart';
import 'settings/ai_error_log_screen.dart';
import '../services/firebase_backup_service.dart';
import '../services/auth_service.dart';
import '../services/auto_backup_service.dart';
import 'auth/sign_in_screen.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _healthEnabled = false;
  bool _usagePermission = false;
  bool _revolutPermission = false;
  bool _overlayPermission = false;
  static const _availableModels = [
    'gemini-2.5-flash',
    'gemini-2.5-pro',
    'gemini-2.0-flash',
    'gemini-2.0-flash-001',
    'gemini-2.0-flash-exp-image-generation',
    'gemini-2.0-flash-lite-001',
    'gemini-2.0-flash-lite',
    'gemini-2.5-flash-preview-tts',
    'gemini-2.5-pro-preview-tts',
    'gemma-3-1b-it',
    'gemma-3-4b-it',
    'gemma-3-12b-it',
    'gemma-3-27b-it',
    'gemma-3n-e4b-it',
    'gemma-3n-e2b-it',
    'gemini-flash-latest',
    'gemini-flash-lite-latest',
    'gemini-pro-latest',
    'gemini-2.5-flash-lite',
    'gemini-2.5-flash-image',
    'gemini-2.5-flash-lite-preview-09-2025',
    'gemini-3-pro-preview',
    'gemini-3-flash-preview',
    'gemini-3.1-pro-preview',
    'gemini-3.1-pro-preview-customtools',
    'gemini-3-pro-image-preview',
    'nano-banana-pro-preview',
    'gemini-3.1-flash-image-preview',
    'gemini-robotics-er-1.5-preview',
    'gemini-2.5-computer-use-preview-10-2025',
    'deep-research-pro-preview-12-2025',
    'gemini-embedding-001',
    'aqa',
    'imagen-4.0-generate-001',
    'imagen-4.0-ultra-generate-001',
    'imagen-4.0-fast-generate-001',
    'veo-2.0-generate-001',
    'veo-3.0-generate-001',
    'veo-3.0-fast-generate-001',
    'veo-3.1-generate-preview',
    'veo-3.1-fast-generate-preview',
    'gemini-2.5-flash-native-audio-latest',
    'gemini-2.5-flash-native-audio-preview-09-2025',
    'gemini-2.5-flash-native-audio-preview-12-2025',
  ];

  String _selectedModel = 'gemini-2.5-flash';
  bool _useSdk = false;
  final _key1Ctrl = TextEditingController();
  final _key2Ctrl = TextEditingController();
  int _activeKeyIndex = 1;
  bool _showKey1 = false;
  bool _showKey2 = false;

  // ── Auto-backup state ─────────────────────────────────────────────────────
  bool _autoBackupEnabled = false;

  // ── Reminder state ────────────────────────────────────────────────────────
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  bool _reminderPersistent = false;

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
    final key1 = AppStorage.settingsBox.get('gemini_api_key_1', defaultValue: '') as String;
    final key2 = AppStorage.settingsBox.get('gemini_api_key_2', defaultValue: '') as String;
    // Migration: if old key exists and key1 is empty, move it
    final oldKey = AppStorage.settingsBox.get('gemini_api_key', defaultValue: '') as String;
    
    setState(() {
      _healthEnabled = health;
      _usagePermission = usage;
      _revolutPermission = revolut;
      _overlayPermission = overlay;
      _key1Ctrl.text = key1.isEmpty ? oldKey : key1;
      _key2Ctrl.text = key2;
      _activeKeyIndex = AppStorage.settingsBox.get('active_gemini_key_index', defaultValue: 1) as int;
      final stored = AppStorage.settingsBox.get('gemini_model', defaultValue: 'gemini-2.5-flash') as String;
      _selectedModel = _availableModels.contains(stored) ? stored : 'gemini-2.5-flash';
      _useSdk = GeminiService.useSdk;
      _reminderEnabled = AppStorage.reminderEnabled;
      _reminderTime = TimeOfDay(hour: AppStorage.reminderHour, minute: AppStorage.reminderMinute);
      _reminderPersistent = AppStorage.reminderPersistent;
      _autoBackupEnabled = AutoBackupService.isEnabled;
    });
    
    if (key1.isEmpty && oldKey.isNotEmpty) {
       await AppStorage.settingsBox.put('gemini_api_key_1', oldKey);
       await AppStorage.settingsBox.delete('gemini_api_key');
    }
  }

  Future<String?> _askPassphrase({required bool isRestore}) async {
    final ctrl = TextEditingController();
    bool obscure = true;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) => AlertDialog(
        backgroundColor: NudgeTokens.surface,
        title: Text(isRestore ? 'Restore Passphrase' : 'Backup Passphrase',
            style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRestore
                  ? 'Enter the passphrase you used when backing up.'
                  : 'Your data is encrypted with this passphrase. You\'ll need it to restore.',
              style: const TextStyle(color: NudgeTokens.textMid, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              obscureText: obscure,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Passphrase',
                labelStyle: const TextStyle(color: NudgeTokens.textLow),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: NudgeTokens.purple), borderRadius: BorderRadius.circular(10)),
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: NudgeTokens.textLow),
                  onPressed: () => setState(() => obscure = !obscure),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(isRestore ? 'Restore' : 'Backup',
                style: TextStyle(color: isRestore ? NudgeTokens.red : NudgeTokens.green, fontWeight: FontWeight.bold)),
          ),
        ],
      )),
    );
  }

  Future<void> _runBackup() async {
    final passphrase = await _askPassphrase(isRestore: false);
    if (passphrase == null || passphrase.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseBackupService.backup(passphrase);
      setState(() {});
      messenger.showSnackBar(const SnackBar(content: Text('Backup complete. Keep your passphrase safe — you need it to restore.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    }
  }

  Future<void> _runRestore() async {
    final passphrase = await _askPassphrase(isRestore: true);
    if (passphrase == null || passphrase.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseBackupService.restore(passphrase);
      messenger.showSnackBar(const SnackBar(content: Text('Restore complete. Restart the app.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Restore failed — wrong passphrase or no backup found.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          // ── Account ────────────────────────────────────────────────────────
          StreamBuilder(
            stream: AuthService.authStateChanges,
            builder: (context, snapshot) {
              final signedIn = AuthService.isSignedIn;
              if (signedIn) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: NudgeTokens.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: NudgeTokens.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: NudgeTokens.purple.withValues(alpha: 0.2),
                        backgroundImage: AuthService.photoUrl != null
                            ? NetworkImage(AuthService.photoUrl!)
                            : null,
                        child: AuthService.photoUrl == null
                            ? Text(
                                AuthService.displayName.isNotEmpty
                                    ? AuthService.displayName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: NudgeTokens.purple,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AuthService.displayName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Colors.white)),
                            Text(AuthService.email,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: NudgeTokens.textLow)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: NudgeTokens.surface,
                              title: const Text('Sign out?'),
                              content: const Text(
                                  'Your local data will not be deleted.',
                                  style: TextStyle(color: NudgeTokens.textMid)),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel')),
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Sign out',
                                        style: TextStyle(color: NudgeTokens.red))),
                              ],
                            ),
                          );
                          if (ok == true) await AuthService.signOut();
                        },
                        child: const Text('Sign out',
                            style: TextStyle(
                                color: NudgeTokens.textLow, fontSize: 12)),
                      ),
                    ],
                  ),
                );
              }
              // Not signed in
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: NudgeTokens.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: NudgeTokens.purple.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: NudgeTokens.purple.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_outline_rounded,
                          color: NudgeTokens.purple, size: 20),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('No account',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Colors.white)),
                          Text('Sign in to enable cloud backup',
                              style: TextStyle(
                                  fontSize: 12, color: NudgeTokens.textLow)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SignInScreen(onDone: () => Navigator.pop(context)),
                        ),
                      ),
                      child: const Text('Sign in',
                          style: TextStyle(
                              color: NudgeTokens.purple,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              );
            },
          ),
          const _SectionHeader(title: 'Appearance'),
          _SettingTile(
            icon: Icons.palette_rounded,
            title: 'App Theme',
            subtitle: 'Brutal, Neumorphic, Cute, Terminal...',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ThemeSettingsScreen()));
            },
            trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow),
          ),
          const SizedBox(height: 12),
          const _SectionHeader(title: 'Integrations'),
          _SettingTile(
            icon: Icons.health_and_safety_rounded,
            title: 'Health Connect',
            subtitle: _healthEnabled ? 'Enabled' : 'Disabled',
            trailing: Switch(
              value: _healthEnabled,
              onChanged: (v) async {
                if (v) {
                  final granted = await HealthService.requestPermissions();
                  if (granted) {
                    await HealthService.setEnabled(true);
                  }
                } else {
                  await HealthService.setEnabled(false);
                }
                _load();
              },
            ),
          ),
           _SettingTile(
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
          _SettingTile(
            icon: Icons.account_balance_rounded,
            title: 'Revolut Sync',
            subtitle: _revolutPermission ? 'Listening for payments' : 'Grant notification access',
            onTap: () async {
              await FinanceService.requestNotificationPermission();
              // wait a bit for user to return
              Future.delayed(const Duration(seconds: 2), _load);
            },
            trailing: Icon(
              _revolutPermission ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
              color: _revolutPermission ? NudgeTokens.green : NudgeTokens.amber,
              size: 20,
            ),
          ),
          _SettingTile(
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
          _SettingTile(
            icon: Icons.apps_rounded,
            title: 'Apps to Track',
            subtitle: 'Select apps for your dashboard',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _AppSelectionScreen()));
            },
            trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow),
          ),
          _SettingTile(
            icon: Icons.timer_off_rounded,
            title: 'Digital Detox',
            subtitle: 'Schedule app blocking',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DetoxScreen()));
            },
            trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow),
          ),
          _SettingTile(
            icon: Icons.restaurant_menu_rounded,
            title: 'Nutrition Profile',
            subtitle: 'Set your macros and goals',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NutritionSettingsScreen()));
            },
            trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Data & Export'),
          _SettingTile(
            icon: Icons.cloud_upload_rounded,
            title: 'Backup to Cloud',
            subtitle: FirebaseBackupService.lastBackupLabel(),
            onTap: _runBackup,
            trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow),
          ),
          _SettingTile(
            icon: Icons.cloud_download_rounded,
            title: 'Restore from Cloud',
            subtitle: 'Overwrites local data with cloud backup',
            onTap: _runRestore,
            trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow),
          ),
          _SettingTile(
            icon: Icons.nightlight_round,
            title: 'Nightly Auto-Backup',
            subtitle: _autoBackupEnabled ? 'Runs at 2 AM every night' : 'Disabled — tap to enable',
            color: _autoBackupEnabled ? NudgeTokens.green : null,
            onTap: () async {
              if (_autoBackupEnabled) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: NudgeTokens.surface,
                    title: const Text('Disable auto-backup?', style: TextStyle(color: Colors.white)),
                    content: const Text('The stored passphrase will be removed.', style: TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Disable', style: TextStyle(color: NudgeTokens.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await AutoBackupService.disable();
                  if (mounted) setState(() => _autoBackupEnabled = false);
                }
              } else {
                if (!AuthService.isSignedIn) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sign in with Google first to enable auto-backup.')),
                  );
                  return;
                }
                final passphrase = await _askPassphrase(isRestore: false);
                if (passphrase == null || passphrase.isEmpty) return;
                await AutoBackupService.enable(passphrase);
                if (mounted) setState(() => _autoBackupEnabled = true);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Auto-backup enabled. Will run at 2 AM daily.')),
                  );
                }
              }
            },
            trailing: Switch(
              value: _autoBackupEnabled,
              onChanged: null, // handled by onTap
              activeColor: NudgeTokens.green,
            ),
          ),
          _SettingTile(
            icon: Icons.upload_file_rounded,
            title: 'Export Data',
            subtitle: 'Download your local records',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExportScreen()));
            },
            trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow),
          ),
          _SettingTile(
            icon: Icons.fitness_center_rounded,
            title: 'Exercises',
            subtitle: 'Manage custom exercises',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _ExerciseManagerScreen()));
            },
            trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow),
          ),
          _SettingTile(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Finance Categories',
            subtitle: 'Manage budget tracking categories',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _CategoryManagerScreen()));
            },
            trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Gemini AI'),
          Container(
            padding: const EdgeInsets.all(16),
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
                    Text(
                      'Gemini API Keys',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    const Text('Active Key:', style: TextStyle(fontSize: 12, color: NudgeTokens.textLow)),
                    const SizedBox(width: 8),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 1, label: Text('1')),
                        ButtonSegment(value: 2, label: Text('2')),
                      ],
                      selected: {_activeKeyIndex},
                      onSelectionChanged: (Set<int> newSelection) {
                        setState(() {
                          _activeKeyIndex = newSelection.first;
                          AppStorage.settingsBox.put('active_gemini_key_index', _activeKeyIndex);
                        });
                      },
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Model (Global Selection)', style: TextStyle(fontSize: 12, color: NudgeTokens.textLow)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: _selectedModel,
                  isExpanded: true,
                  items: _availableModels
                      .map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedModel = v);
                      AppStorage.settingsBox.put('gemini_model', v);
                    }
                  },
                  decoration: const InputDecoration(isDense: true),
                ),
                const SizedBox(height: 20),

                // API Implementation toggle
                const Text('API Implementation', style: TextStyle(fontSize: 12, color: NudgeTokens.textLow)),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('HTTP REST', style: TextStyle(fontSize: 12)),
                      icon: Icon(Icons.http_rounded, size: 14),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('SDK (Fallback)', style: TextStyle(fontSize: 12)),
                      icon: Icon(Icons.code_rounded, size: 14),
                    ),
                  ],
                  selected: {_useSdk},
                  onSelectionChanged: (s) {
                    setState(() => _useSdk = s.first);
                    AppStorage.settingsBox.put('gemini_use_sdk', s.first);
                  },
                  style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
                const SizedBox(height: 6),
                Text(
                  _useSdk
                      ? 'Using google_generative_ai SDK. Switch to HTTP REST if it causes issues.'
                      : 'Using direct HTTP calls to the Gemini REST API (recommended).',
                  style: const TextStyle(fontSize: 11, color: NudgeTokens.textLow),
                ),
                const SizedBox(height: 20),

                // Key 1
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _key1Ctrl,
                        obscureText: !_showKey1,
                        onChanged: (v) => AppStorage.settingsBox.put('gemini_api_key_1', v),
                        decoration: InputDecoration(
                          hintText: 'Enter API Key 1',
                          isDense: true,
                          labelText: 'Key 1',
                          suffixIcon: IconButton(
                            icon: Icon(_showKey1 ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                            onPressed: () {
                              setState(() {
                                _showKey1 = !_showKey1;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ValidateButton(apiKey: _key1Ctrl.text, model: _selectedModel),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Key 2
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _key2Ctrl,
                        obscureText: !_showKey2,
                        onChanged: (v) => AppStorage.settingsBox.put('gemini_api_key_2', v),
                        decoration: InputDecoration(
                          hintText: 'Enter API Key 2',
                          isDense: true,
                          labelText: 'Key 2',
                          labelStyle: TextStyle(color: _activeKeyIndex == 2 ? NudgeTokens.purple : NudgeTokens.textLow),
                          suffixIcon: IconButton(
                            icon: Icon(_showKey2 ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                            onPressed: () {
                              setState(() {
                                _showKey2 = !_showKey2;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ValidateButton(apiKey: _key2Ctrl.text, model: _selectedModel),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Reminders & Streaks'),
          _SettingTile(
            icon: Icons.notifications_active_rounded,
            title: 'Daily Reminder',
            subtitle: _reminderEnabled
                ? 'Fires at ${_reminderTime.format(context)}'
                : 'Off — tap to enable',
            trailing: Switch(
              value: _reminderEnabled,
              onChanged: (v) async {
                await NotificationService().requestPermissions();
                setState(() => _reminderEnabled = v);
                AppStorage.reminderEnabled = v;
                if (v) {
                  await NotificationService().scheduleStreakReminder(
                    hour: _reminderTime.hour,
                    minute: _reminderTime.minute,
                    persistent: _reminderPersistent,
                  );
                } else {
                  await NotificationService().cancelStreakReminder();
                }
              },
            ),
          ),
          if (_reminderEnabled) ...[
            _SettingTile(
              icon: Icons.access_time_rounded,
              title: 'Reminder Time',
              subtitle:
                  'Currently ${_reminderTime.format(context)} — tap to change',
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _reminderTime,
                );
                if (picked == null) return;
                setState(() => _reminderTime = picked);
                AppStorage.reminderHour = picked.hour;
                AppStorage.reminderMinute = picked.minute;
                await NotificationService().scheduleStreakReminder(
                  hour: picked.hour,
                  minute: picked.minute,
                  persistent: _reminderPersistent,
                );
              },
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: NudgeTokens.textLow),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: NudgeTokens.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: NudgeTokens.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: NudgeTokens.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.push_pin_rounded,
                        color: NudgeTokens.purple, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Persistent Notification',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(
                          _reminderPersistent
                              ? "Can't be swiped away — only clears when you log data"
                              : 'Regular notification — you can swipe it away',
                          style: const TextStyle(
                              fontSize: 12, color: NudgeTokens.textLow),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _reminderPersistent,
                    onChanged: (v) async {
                      setState(() => _reminderPersistent = v);
                      AppStorage.reminderPersistent = v;
                      await NotificationService().scheduleStreakReminder(
                        hour: _reminderTime.hour,
                        minute: _reminderTime.minute,
                        persistent: v,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Debug'),
          _SettingTile(
            icon: Icons.monitor_heart_rounded,
            title: 'Health Connect Raw Data',
            subtitle: 'Inspect all steps, calories, workouts',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const RawHealthDataScreen()));
            },
            trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow, size: 20),
          ),
          _SettingTile(
            icon: Icons.bug_report_rounded,
            title: 'Notification Log',
            subtitle: 'View raw intercepted notifications',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const RawNotificationScreen()));
            },
            trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow, size: 20),
          ),
          _SettingTile(
            icon: Icons.assignment_late_rounded,
            title: 'AI Error Log',
            subtitle: 'View recent Gemini API failures',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AiErrorLogScreen()));
            },
            trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow, size: 20),
          ),
          const SizedBox(height: 32),
          const _SectionHeader(title: 'Danger Zone'),
          _SettingTile(
            icon: Icons.delete_forever_rounded,
            title: 'Delete Account & Data',
            subtitle: 'Wipe all local data and reset app',
            color: NudgeTokens.red,
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: NudgeTokens.surface,
                  title: const Text('Delete Everything?', style: TextStyle(color: NudgeTokens.red)),
                  content: const Text('This will irreversibly wipe all local files, logs, and settings. Are you sure?', style: TextStyle(color: Colors.white)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: NudgeTokens.red),
                      onPressed: () => Navigator.pop(ctx, true), 
                      child: const Text('Delete All Data', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                // Show loading
                showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: NudgeTokens.red)));
                
                try {
                  await AutoBackupService.disable();
                  await FirebaseBackupService.deleteBackup();
                  await AuthService.deleteAccount(); // re-auth + delete Firebase Auth user
                } catch (e) {
                  // If account deletion fails (e.g. not signed in), still wipe local data
                  try { await AuthService.signOut(); } catch (_) {}
                  debugPrint('Account deletion error: $e');
                }

                await AppStorage.clearAll();
                if (!mounted) return;
                Navigator.pop(context); // close dialog
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const OnboardingScreen()), 
                  (r) => false
                );
              }
            },
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Nudge v1.0.0',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: NudgeTokens.textLow,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? color;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? NudgeTokens.purple;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: NudgeTokens.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NudgeTokens.border),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: c, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: trailing,
      ),
    );
  }
}

class _AppSelectionScreen extends StatefulWidget {
  const _AppSelectionScreen();

  @override
  State<_AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<_AppSelectionScreen> {
  List<AppInfo> _apps = [];
  Set<String> _tracked = {};
  bool _loading = true;
  String _sortBy = 'name'; // 'name' or 'lastUsed'
  Map<String, int> _lastUsedTime = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final apps = await InstalledApps.getInstalledApps(excludeSystemApps: true, withIcon: true);
    final trackedList = AppStorage.settingsBox.get('tracked_apps', defaultValue: <String>[]) as List;
    
    // Fetch last use time for sorting
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
        return timeB.compareTo(timeA); // Recent first
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
      if (_tracked.contains(package)) {
        _tracked.remove(package);
      } else {
        _tracked.add(package);
      }
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
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: app.icon != null
                          ? Image.memory(app.icon!, fit: BoxFit.contain)
                          : const Icon(Icons.android_rounded, color: NudgeTokens.textLow),
                    ),
                    title: Text(
                      app.name ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    subtitle: Text(
                      app.packageName ?? '',
                      style: const TextStyle(fontSize: 10, color: NudgeTokens.textLow),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Checkbox(
                      value: isTracked,
                      activeColor: NudgeTokens.purple,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      onChanged: (_) => _toggle(app.packageName),
                    ),
                    onTap: () => _toggle(app.packageName),
                  ),
                );
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ExerciseManagerScreen extends StatefulWidget {
  const _ExerciseManagerScreen();

  @override
  State<_ExerciseManagerScreen> createState() => _ExerciseManagerScreenState();
}

class _ExerciseManagerScreenState extends State<_ExerciseManagerScreen> {
  List<String> _custom = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

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
        title: const Text('New Exercise'),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Bench Press'),
        ),
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
      appBar: AppBar(
        title: const Text('Manage Exercises'),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: _add),
        ],
      ),
      body: _custom.isEmpty
          ? const Center(child: Text('No custom exercises', style: TextStyle(color: NudgeTokens.textLow)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _custom.length,
              itemBuilder: (ctx, i) => ListTile(
                title: Text(_custom[i], style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: NudgeTokens.red),
                  onPressed: () => _delete(i),
                ),
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _CategoryManagerScreen extends StatefulWidget {
  const _CategoryManagerScreen();

  @override
  State<_CategoryManagerScreen> createState() => _CategoryManagerScreenState();
}

class _CategoryManagerScreenState extends State<_CategoryManagerScreen> {
  List<String> _cats = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _cats = (AppStorage.financeBox.get('categories', defaultValue: <String>['Food', 'Shopping', 'Bills', 'Transport', 'General']) as List).cast<String>();
    });
  }

  void _add() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Category'),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Subscriptions'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isNotEmpty && !_cats.contains(text)) {
                _cats.add(text);
                AppStorage.financeBox.put('categories', _cats);
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
    if (_cats.length <= 1) return; // keep at least one
    _cats.removeAt(ix);
    AppStorage.financeBox.put('categories', _cats);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance Categories'),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: _add),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _cats.length,
        itemBuilder: (ctx, i) => ListTile(
          title: Text(_cats[i], style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: _cats.length > 1
            ? IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: NudgeTokens.red),
                onPressed: () => _delete(i),
              )
            : null,
        ),
      ),
    );
  }
}
class _ValidateButton extends StatefulWidget {
  final String apiKey;
  final String model;

  const _ValidateButton({required this.apiKey, required this.model});

  @override
  State<_ValidateButton> createState() => _ValidateButtonState();
}

class _ValidateButtonState extends State<_ValidateButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: _loading
          ? null
          : () async {
              final key = widget.apiKey.trim();
              if (key.isEmpty) return;
              setState(() => _loading = true);
              final ok = await GeminiService.validateKey(key, widget.model);
              if (!mounted) return;
              setState(() => _loading = false);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                  ok ? 'API Key is valid!' : 'Validation failed — check key or model.',
                  style: TextStyle(color: ok ? NudgeTokens.green : NudgeTokens.red),
                ),
              ));
            },
      style: FilledButton.styleFrom(
        backgroundColor: NudgeTokens.purple,
        visualDensity: VisualDensity.compact,
      ),
      child: _loading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Text('Validate'),
    );
  }
}

