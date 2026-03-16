import 'package:flutter/material.dart';
import '../../storage.dart';
import '../../utils/data_seeder.dart';
import '../../utils/health_service.dart';


class GymSettingsSheet extends StatefulWidget {
  final int targetDaysPerWeek;
  const GymSettingsSheet({super.key, required this.targetDaysPerWeek});

  @override
  State<GymSettingsSheet> createState() => _GymSettingsSheetState();
}

class _GymSettingsSheetState extends State<GymSettingsSheet> {
  late int _target;
  bool _healthEnabled = false;

  @override
  void initState() {
    super.initState();
    _target = widget.targetDaysPerWeek.clamp(1, 7);
    _healthEnabled = AppStorage.settingsBox.get('health_connect_enabled', defaultValue: false) as bool;
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _done() {
    Navigator.of(context).pop(<String, dynamic>{
      'targetDaysPerWeek': _target,
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: 14 + MediaQuery.of(context).viewInsets.bottom,
        ),
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
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                TextButton(onPressed: _done, child: const Text('Done')),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xFF101722),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flag_rounded),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Perfect week target',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _target = (_target - 1).clamp(1, 7)),
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  Text(
                    '$_target',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _target = (_target + 1).clamp(1, 7)),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Example: set to 3 if 3 gym days counts as a perfect week.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.70)),
            ),
            const SizedBox(height: 12),
            Text(
              'Daily Activity',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xFF101722),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                children: [
                   Row(
                    children: [
                      const Icon(Icons.health_and_safety_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Health Connect',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Switch(
                        value: _healthEnabled,
                        onChanged: (v) async {
                          if (v) {
                            final granted = await HealthService.requestPermissions();
                            if (granted) {
                              setState(() => _healthEnabled = true);
                              await HealthService.setEnabled(true);
                            } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Permissions denied or Health Connect not available.')),
                                  );
                                }
                            }
                          } else {
                            setState(() => _healthEnabled = false);
                            await HealthService.setEnabled(false);
                          }
                        },
                      ),
                    ],
                  ),
                  if (_healthEnabled) ...[
                    const Divider(height: 24),
                    TextButton.icon(
                      onPressed: () async {
                        final granted = await HealthService.requestPermissions();
                         if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(granted ? 'Permissions verified!' : 'Permissions missing.')),
                            );
                          }
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Refresh Permissions', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final b = await AppStorage.getGymBox();
                  await DataSeeder.seedGymWorkouts(b);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('300+ workout sets seeded successfully!')),
                    );
                  }
                },
                icon: const Icon(Icons.data_thresholding_rounded),
                label: const Text('Seed 1 Year of Data (300+ sets)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orangeAccent,
                  side: const BorderSide(color: Colors.orangeAccent),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  const cutoff = '2026-02-28';
                  final b = await AppStorage.getGymBox();

                  bool beforeCutoff(Map w) {
                    final iso = w['dayIso'] as String?;
                    return iso != null && iso.compareTo(cutoff) < 0;
                  }

                  final workouts = (b.get('workouts', defaultValue: <dynamic>[]) as List).cast<Map>();
                  workouts.removeWhere(beforeCutoff);
                  await b.put('workouts', workouts);

                  final history = (b.get('health_history', defaultValue: <dynamic>[]) as List).cast<Map>();
                  history.removeWhere(beforeCutoff);
                  await b.put('health_history', history);

                  final water = (b.get('water_logs', defaultValue: <dynamic>[]) as List).cast<Map>();
                  water.removeWhere(beforeCutoff);
                  await b.put('water_logs', water);

                  final local = (b.get('local_health_logs', defaultValue: <dynamic>[]) as List).cast<Map>();
                  local.removeWhere(beforeCutoff);
                  await b.put('local_health_logs', local);

                  final weigh = (b.get('weigh_ins', defaultValue: <dynamic>[]) as List).cast<Map>();
                  weigh.removeWhere(beforeCutoff);
                  await b.put('weigh_ins', weigh);

                  final rawWeights = Map<String, dynamic>.from(
                      (b.get('daily_weights', defaultValue: <dynamic, dynamic>{}) as Map).cast<String, dynamic>());
                  rawWeights.removeWhere((k, _) => k.compareTo(cutoff) < 0);
                  await b.put('daily_weights', rawWeights);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All data before Feb 28th cleared!')),
                    );
                  }
                },
                icon: const Icon(Icons.delete_sweep_rounded),
                label: const Text('Purge All Data Before Feb 28th'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}
