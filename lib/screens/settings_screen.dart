import 'package:flutter/material.dart';
import '../../app.dart' show NudgeTokens;
import 'settings/settings_widgets.dart';
import 'settings/modules_settings_screen.dart';
import 'settings/theme_settings_screen.dart';
import 'settings/backup_settings_screen.dart';
import 'settings/reminders_settings_screen.dart';
import 'settings/developer_settings_screen.dart';
import 'settings/about_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
          const SectionHeader(title: 'Personalization'),
          SettingTile(
            icon: Icons.grid_view_rounded,
            title: 'Modules',
            subtitle: 'Manage home screen widgets & apps',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ModulesSettingsScreen())),
            trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow),
          ),
          SettingTile(
            icon: Icons.palette_rounded,
            title: 'Appearance',
            subtitle: 'Themes, colors, and layout style',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThemeSettingsScreen())),
            trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow),
          ),
          SettingTile(
            icon: Icons.notifications_active_rounded,
            title: 'Reminders & Streaks',
            subtitle: 'Daily alerts and persistence',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RemindersSettingsScreen())),
            trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow),
          ),
          
          const SizedBox(height: 24),
          const SectionHeader(title: 'Data & Security'),
          SettingTile(
            icon: Icons.cloud_sync_rounded,
            title: 'Backup & Sync',
            subtitle: 'Google Cloud, Auto-backup, Export',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupSettingsScreen())),
            trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow),
          ),
          
          const SizedBox(height: 24),
          const SectionHeader(title: 'System'),
          SettingTile(
            icon: Icons.code_rounded,
            title: 'Developer',
            subtitle: 'Gemini AI, seed data, and logs',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeveloperSettingsScreen())),
            trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow),
          ),
          SettingTile(
            icon: Icons.info_outline_rounded,
            title: 'About',
            subtitle: 'Version, credits, and updates',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
            trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow),
          ),
          
          const SizedBox(height: 40),
          Center(
            child: Opacity(
              opacity: 0.5,
              child: Column(
                children: [
                  const Icon(Icons.rocket_launch_rounded, size: 24, color: NudgeTokens.purple),
                  const SizedBox(height: 8),
                  Text('Nudge', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
