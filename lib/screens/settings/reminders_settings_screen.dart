import 'package:flutter/material.dart';
import '../../app.dart' show NudgeTokens;
import '../../storage.dart';
import '../../utils/notification_service.dart';
import 'settings_widgets.dart';

class RemindersSettingsScreen extends StatefulWidget {
  const RemindersSettingsScreen({super.key});

  @override
  State<RemindersSettingsScreen> createState() => _RemindersSettingsScreenState();
}

class _RemindersSettingsScreenState extends State<RemindersSettingsScreen> {
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  bool _reminderPersistent = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _reminderEnabled = AppStorage.reminderEnabled;
      _reminderTime = TimeOfDay(hour: AppStorage.reminderHour, minute: AppStorage.reminderMinute);
      _reminderPersistent = AppStorage.reminderPersistent;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders & Streaks')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          const SectionHeader(title: 'Daily Reminders'),
          SettingTile(
            icon: Icons.notifications_active_rounded,
            title: 'Daily Reminder',
            subtitle: _reminderEnabled ? 'Fires at ${_reminderTime.format(context)}' : 'Off — tap to enable',
            trailing: Switch(
              value: _reminderEnabled,
              onChanged: (v) async {
                await NotificationService().requestPermissions();
                setState(() => _reminderEnabled = v);
                AppStorage.reminderEnabled = v;
                if (v) {
                  await NotificationService().scheduleStreakReminder(
                    hour: _reminderTime.hour, minute: _reminderTime.minute, persistent: _reminderPersistent,
                  );
                } else {
                  await NotificationService().cancelStreakReminder();
                }
              },
            ),
          ),
          if (_reminderEnabled) ...[
            SettingTile(
              icon: Icons.access_time_rounded,
              title: 'Reminder Time',
              subtitle: 'Currently ${_reminderTime.format(context)} — tap to change',
              onTap: () async {
                final picked = await showTimePicker(context: context, initialTime: _reminderTime);
                if (picked == null) return;
                setState(() => _reminderTime = picked);
                AppStorage.reminderHour = picked.hour;
                AppStorage.reminderMinute = picked.minute;
                await NotificationService().scheduleStreakReminder(
                  hour: picked.hour, minute: picked.minute, persistent: _reminderPersistent,
                );
              },
              trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: NudgeTokens.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: NudgeTokens.border)),
              child: Row(
                children: [
                   Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: NudgeTokens.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.push_pin_rounded, color: NudgeTokens.purple, size: 20)),
                   const SizedBox(width: 14),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const Text('Persistent Notification', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                         Text(_reminderPersistent ? "Can't be swiped away — only clears when you log data" : 'Regular notification — you can swipe it away', style: const TextStyle(fontSize: 12, color: NudgeTokens.textLow)),
                       ],
                     ),
                   ),
                   Switch(
                     value: _reminderPersistent,
                     onChanged: (v) async {
                       setState(() => _reminderPersistent = v);
                       AppStorage.reminderPersistent = v;
                       await NotificationService().scheduleStreakReminder(hour: _reminderTime.hour, minute: _reminderTime.minute, persistent: v);
                     },
                   ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
