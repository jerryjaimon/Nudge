import 'package:flutter/material.dart';
import '../../app.dart' show NudgeTokens;
import '../../storage.dart';
import '../../utils/gemini_service.dart';
import 'developer_options_screen.dart';
import 'ai_error_log_screen.dart';
import '../raw_health_screen.dart';
import '../finance/raw_notification_screen.dart';
import 'settings_widgets.dart';

class DeveloperSettingsScreen extends StatefulWidget {
  const DeveloperSettingsScreen({super.key});

  @override
  State<DeveloperSettingsScreen> createState() => _DeveloperSettingsScreenState();
}

class _DeveloperSettingsScreenState extends State<DeveloperSettingsScreen> {
  static const _availableModels = [
    'gemini-2.5-flash', 'gemini-2.5-pro', 'gemini-2.0-flash', 'gemini-2.0-flash-001', 'gemini-2.0-flash-exp-image-generation', 'gemini-2.0-flash-lite-001', 'gemini-2.0-flash-lite', 'gemini-2.5-flash-preview-tts', 'gemini-2.5-pro-preview-tts', 'gemma-3-1b-it', 'gemma-3-4b-it', 'gemma-3-12b-it', 'gemma-3-27b-it', 'gemma-3n-e4b-it', 'gemma-3n-e2b-it', 'gemini-flash-latest', 'gemini-flash-lite-latest', 'gemini-pro-latest', 'gemini-2.5-flash-lite', 'gemini-2.5-flash-image', 'gemini-2.5-flash-lite-preview-09-2025', 'gemini-3-pro-preview', 'gemini-3-flash-preview', 'gemini-3.1-pro-preview', 'gemini-3.1-pro-preview-customtools', 'gemini-3-pro-image-preview', 'nano-banana-pro-preview', 'gemini-3.1-flash-image-preview', 'gemini-robotics-er-1.5-preview', 'gemini-2.5-computer-use-preview-10-2025', 'deep-research-pro-preview-12-2025', 'gemini-embedding-001', 'aqa', 'imagen-4.0-generate-001', 'imagen-4.0-ultra-generate-001', 'imagen-4.0-fast-generate-001', 'veo-2.0-generate-001', 'veo-3.0-generate-001', 'veo-3.0-fast-generate-001', 'veo-3.1-generate-preview', 'veo-3.1-fast-generate-preview', 'gemini-2.5-flash-native-audio-latest', 'gemini-2.5-flash-native-audio-preview-09-2025', 'gemini-2.5-flash-native-audio-preview-12-2025',
  ];

  String _selectedModel = 'gemini-2.5-flash';
  bool _useSdk = false;
  final _key1Ctrl = TextEditingController();
  final _key2Ctrl = TextEditingController();
  int _activeKeyIndex = 1;
  bool _showKey1 = false;
  bool _showKey2 = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final key1 = AppStorage.settingsBox.get('gemini_api_key_1', defaultValue: '') as String;
    final key2 = AppStorage.settingsBox.get('gemini_api_key_2', defaultValue: '') as String;
    setState(() {
      _key1Ctrl.text = key1;
      _key2Ctrl.text = key2;
      _activeKeyIndex = AppStorage.settingsBox.get('active_gemini_key_index', defaultValue: 1) as int;
      final stored = AppStorage.settingsBox.get('gemini_model', defaultValue: 'gemini-2.5-flash') as String;
      _selectedModel = _availableModels.contains(stored) ? stored : 'gemini-2.5-flash';
      _useSdk = GeminiService.useSdk;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Developer Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          const SectionHeader(title: 'Gemini AI'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: NudgeTokens.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: NudgeTokens.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Gemini API Keys', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const Spacer(),
                    SegmentedButton<int>(
                      segments: const [ButtonSegment(value: 1, label: Text('1')), ButtonSegment(value: 2, label: Text('2'))],
                      selected: {_activeKeyIndex},
                      onSelectionChanged: (Set<int> newSelection) {
                        setState(() { _activeKeyIndex = newSelection.first; AppStorage.settingsBox.put('active_gemini_key_index', _activeKeyIndex); });
                      },
                      style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Model (Global)', style: TextStyle(fontSize: 12, color: NudgeTokens.textLow)),
                DropdownButtonFormField<String>(
                  value: _selectedModel,
                  items: _availableModels.map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) { if (v != null) { setState(() => _selectedModel = v); AppStorage.settingsBox.put('gemini_model', v); } },
                  decoration: const InputDecoration(isDense: true),
                ),
                const SizedBox(height: 20),
                const Text('Implementation', style: TextStyle(fontSize: 12, color: NudgeTokens.textLow)),
                SegmentedButton<bool>(
                   segments: const [
                     ButtonSegment(value: false, label: Text('HTTP REST', style: TextStyle(fontSize: 12)), icon: Icon(Icons.http_rounded, size: 14)),
                     ButtonSegment(value: true, label: Text('SDK', style: TextStyle(fontSize: 12)), icon: Icon(Icons.code_rounded, size: 14)),
                   ],
                   selected: {_useSdk},
                   onSelectionChanged: (s) { setState(() => _useSdk = s.first); AppStorage.settingsBox.put('gemini_use_sdk', s.first); },
                   style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _key1Ctrl,
                  obscureText: !_showKey1,
                  onChanged: (v) => AppStorage.settingsBox.put('gemini_api_key_1', v),
                  decoration: InputDecoration(
                    labelText: 'Key 1',
                    suffixIcon: IconButton(icon: Icon(_showKey1 ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18), onPressed: () => setState(() => _showKey1 = !_showKey1)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _key2Ctrl,
                  obscureText: !_showKey2,
                  onChanged: (v) => AppStorage.settingsBox.put('gemini_api_key_2', v),
                  decoration: InputDecoration(
                    labelText: 'Key 2',
                    suffixIcon: IconButton(icon: Icon(_showKey2 ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18), onPressed: () => setState(() => _showKey2 = !_showKey2)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                   mainAxisAlignment: MainAxisAlignment.end,
                   children: [
                     ValidateButton(apiKey: _activeKeyIndex == 1 ? _key1Ctrl.text : _key2Ctrl.text, model: _selectedModel),
                   ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          const SectionHeader(title: 'Debug Tools'),
          SettingTile(icon: Icons.science_rounded, title: 'Seed Data', subtitle: 'Developer options for modules', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeveloperOptionsScreen()))),
          SettingTile(icon: Icons.monitor_heart_rounded, title: 'Health Connect Raw', subtitle: 'Inspect health raw data', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RawHealthDataScreen()))),
          SettingTile(icon: Icons.bug_report_rounded, title: 'Notification Log', subtitle: 'View intercepted notifications', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RawNotificationScreen()))),
          SettingTile(icon: Icons.assignment_late_rounded, title: 'AI Error Log', subtitle: 'Gemini API failure logs', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiErrorLogScreen()))),
        ],
      ),
    );
  }
}
