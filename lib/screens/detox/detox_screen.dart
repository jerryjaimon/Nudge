import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:uuid/uuid.dart';
import '../../app.dart' show NudgeTokens;
import '../../storage.dart';
import '../../utils/detox_service.dart' show DetoxSchedule;

// Known doomscrolling / distraction app package names
const _doomApps = {
  'com.zhiliaoapp.musically',      // TikTok
  'com.ss.android.ugc.trill',      // TikTok (alt)
  'com.instagram.android',
  'com.twitter.android',           // X / Twitter
  'com.facebook.katana',
  'com.reddit.frontpage',
  'com.snapchat.android',
  'com.google.android.youtube',
  'com.facebook.orca',             // Messenger
  'com.pinterest',
  'com.linkedin.android',
  'com.tumblr',
  'com.whatsapp',
  'org.telegram.messenger',
  'com.discord',
  'com.netflix.mediaclient',
  'com.amazon.avod.thirdpartyclient', // Prime Video
  'com.google.android.apps.youtube.music',
  'com.spotify.music',
};

class DetoxScreen extends StatefulWidget {
  const DetoxScreen({super.key});

  @override
  State<DetoxScreen> createState() => _DetoxScreenState();
}

class _DetoxScreenState extends State<DetoxScreen> {
  List<DetoxSchedule> _schedules = [];
  bool _loading = true;

  static const _storageKey = 'detox_schedules';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final box = await AppStorage.getSettingsBox();
    final raw = box.get(_storageKey, defaultValue: <dynamic>[]) as List;
    setState(() {
      _schedules = raw
          .map((e) => DetoxSchedule.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      _loading = false;
    });
  }

  Future<void> _save() async {
    final box = await AppStorage.getSettingsBox();
    await box.put(_storageKey, _schedules.map((s) => s.toJson()).toList());
  }

  void _addSchedule() async {
    final result = await showModalBottomSheet<DetoxSchedule>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _EditScheduleSheet(),
    );
    if (result != null) {
      setState(() => _schedules.add(result));
      await _save();
    }
  }

  void _editSchedule(int idx) async {
    final result = await showModalBottomSheet<DetoxSchedule>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditScheduleSheet(schedule: _schedules[idx]),
    );
    if (result != null) {
      setState(() => _schedules[idx] = result);
      await _save();
    }
  }

  void _deleteSchedule(int idx) async {
    setState(() => _schedules.removeAt(idx));
    await _save();
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static const _dayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NudgeTokens.bg,
      appBar: AppBar(
        backgroundColor: NudgeTokens.bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Digital Detox',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700, color: Colors.white)),
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _schedules.isEmpty
              ? _buildEmpty()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: _schedules.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _buildScheduleTile(_schedules[i], i),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSchedule,
        backgroundColor: NudgeTokens.purple,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_off_rounded, size: 56, color: NudgeTokens.textLow),
          const SizedBox(height: 16),
          Text('No blocking schedules',
              style: GoogleFonts.outfit(
                  color: NudgeTokens.textMid,
                  fontWeight: FontWeight.w600,
                  fontSize: 16)),
          const SizedBox(height: 6),
          Text('Tap + to create a schedule',
              style: GoogleFonts.outfit(color: NudgeTokens.textLow, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildScheduleTile(DetoxSchedule s, int idx) {
    return GestureDetector(
      onTap: () => _editSchedule(idx),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NudgeTokens.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NudgeTokens.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.block_rounded, color: NudgeTokens.red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(s.name,
                      style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ),
                IconButton(
                  onPressed: () => _deleteSchedule(idx),
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: NudgeTokens.textLow, size: 18),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time_rounded,
                    color: NudgeTokens.textLow, size: 14),
                const SizedBox(width: 4),
                Text('${_fmtTime(s.startTime)} – ${_fmtTime(s.endTime)}',
                    style: GoogleFonts.outfit(
                        color: NudgeTokens.textMid, fontSize: 13)),
                const SizedBox(width: 16),
                ...List.generate(7, (d) {
                  final active = s.days.contains(d + 1);
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      _dayLabels[d],
                      style: GoogleFonts.outfit(
                        color: active ? NudgeTokens.purple : NudgeTokens.textLow,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                        fontSize: 12,
                      ),
                    ),
                  );
                }),
              ],
            ),
            if (s.blockedApps.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${s.blockedApps.length} app${s.blockedApps.length > 1 ? 's' : ''} blocked',
                style: GoogleFonts.outfit(color: NudgeTokens.textLow, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Edit schedule sheet ────────────────────────────────────────────────────────

class _EditScheduleSheet extends StatefulWidget {
  final DetoxSchedule? schedule;
  const _EditScheduleSheet({this.schedule});

  @override
  State<_EditScheduleSheet> createState() => _EditScheduleSheetState();
}

class _EditScheduleSheetState extends State<_EditScheduleSheet> {
  late TextEditingController _nameCtrl;
  TimeOfDay _start = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 7, minute: 0);
  List<int> _days = [1, 2, 3, 4, 5, 6, 7];
  List<String> _blockedApps = [];

  List<AppInfo> _installedApps = [];
  bool _appsLoading = false;

  static const _dayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  @override
  void initState() {
    super.initState();
    final s = widget.schedule;
    _nameCtrl = TextEditingController(text: s?.name ?? 'Night Mode');
    if (s != null) {
      _start = s.startTime;
      _end = s.endTime;
      _days = List.from(s.days);
      _blockedApps = List.from(s.blockedApps);
    }
    _loadApps();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    setState(() => _appsLoading = true);
    try {
      // excludeSystemApps: false so bundled apps like YouTube are included.
      // Filter manually to only keep apps with a valid name and package.
      final all = await InstalledApps.getInstalledApps(
          excludeSystemApps: false, withIcon: false);
      final apps = all
          .where((a) => a.name.isNotEmpty && a.packageName.isNotEmpty)
          .toList();
      // Sort: doom apps first, then alphabetical
      apps.sort((a, b) {
        final aD = _doomApps.contains(a.packageName) ? 0 : 1;
        final bD = _doomApps.contains(b.packageName) ? 0 : 1;
        if (aD != bD) return aD - bD;
        return a.name.compareTo(b.name);
      });
      if (mounted) setState(() { _installedApps = apps; _appsLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _appsLoading = false);
    }
  }

  void _showAppPicker() {
    String search = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NudgeTokens.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          builder: (_, ctrl) {
            final filtered = search.isEmpty
                ? _installedApps
                : _installedApps
                    .where((a) =>
                        a.name.toLowerCase().contains(search.toLowerCase()) ||
                        a.packageName.toLowerCase().contains(search.toLowerCase()))
                    .toList();
            return Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: NudgeTokens.textLow,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text('Block Apps',
                        style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18)),
                    const Spacer(),
                    Text('${_blockedApps.length} selected',
                        style: GoogleFonts.outfit(
                            color: NudgeTokens.textMid, fontSize: 13)),
                  ],
                ),
              ),
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (v) => setSt(() => search = v),
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search apps…',
                    hintStyle: GoogleFonts.outfit(color: NudgeTokens.textLow, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: NudgeTokens.textLow, size: 20),
                    suffixIcon: search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: NudgeTokens.textLow, size: 18),
                            onPressed: () => setSt(() => search = ''),
                          )
                        : null,
                    filled: true,
                    fillColor: NudgeTokens.elevated,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              // Doomscrolling quick-add banner
              if (search.isEmpty && _installedApps.any((a) => _doomApps.contains(a.packageName)))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: NudgeTokens.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NudgeTokens.red.withValues(alpha: 0.20)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: NudgeTokens.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Doomscrolling apps detected — recommended to block',
                            style: GoogleFonts.outfit(
                                color: NudgeTokens.textMid, fontSize: 12),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            final doom = _installedApps
                                .where((a) => _doomApps.contains(a.packageName))
                                .map((a) => a.packageName)
                                .toList();
                            setSt(() {
                              for (final pkg in doom) {
                                if (!_blockedApps.contains(pkg)) {
                                  _blockedApps.add(pkg);
                                }
                              }
                            });
                            setState(() {});
                          },
                          child: Text('Add all',
                              style: GoogleFonts.outfit(
                                  color: NudgeTokens.red,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: _appsLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: ctrl,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final app = filtered[i];
                          final pkg = app.packageName;
                          final selected = _blockedApps.contains(pkg);
                          final isDoom = _doomApps.contains(pkg);
                          return CheckboxListTile(
                            value: selected,
                            onChanged: (v) {
                              setSt(() {
                                if (v == true) {
                                  _blockedApps.add(pkg);
                                } else {
                                  _blockedApps.remove(pkg);
                                }
                              });
                              setState(() {});
                            },
                            title: Text(
                              app.name,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: isDoom
                                ? Text('Doomscrolling',
                                    style: GoogleFonts.outfit(
                                        color: NudgeTokens.red, fontSize: 11))
                                : null,
                            secondary: isDoom
                                ? const Icon(Icons.warning_amber_rounded,
                                    color: NudgeTokens.red, size: 18)
                                : null,
                            activeColor: NudgeTokens.purple,
                            checkColor: Colors.white,
                            tileColor: Colors.transparent,
                          );
                        },
                      ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NudgeTokens.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Done',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            ],
          );
          },
        ),
      ),
    );
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked != null) setState(() => isStart ? _start = picked : _end = picked);
  }

  void _save() {
    final schedule = DetoxSchedule(
      id: widget.schedule?.id ?? const Uuid().v4(),
      name: _nameCtrl.text.trim().isEmpty ? 'Schedule' : _nameCtrl.text.trim(),
      startTime: _start,
      endTime: _end,
      days: _days,
      blockedApps: _blockedApps,
    );
    Navigator.pop(context, schedule);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: NudgeTokens.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: NudgeTokens.textLow,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Blocking Schedule',
                style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              style: GoogleFonts.outfit(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Label',
                labelStyle: GoogleFonts.outfit(color: NudgeTokens.textLow),
                filled: true,
                fillColor: NudgeTokens.elevated,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _timeTile('Starts', _start, true)),
                const SizedBox(width: 12),
                Expanded(child: _timeTile('Ends', _end, false)),
              ],
            ),
            const SizedBox(height: 16),
            Text('Days',
                style: GoogleFonts.outfit(
                    color: NudgeTokens.textMid,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final day = i + 1;
                final active = _days.contains(day);
                return GestureDetector(
                  onTap: () => setState(() =>
                      active ? _days.remove(day) : _days.add(day)),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: active
                          ? NudgeTokens.purple
                          : NudgeTokens.elevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _dayLabels[i],
                      style: GoogleFonts.outfit(
                          color: active ? Colors.white : NudgeTokens.textLow,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Blocked Apps',
                        style: GoogleFonts.outfit(
                            color: NudgeTokens.textMid,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    if (_blockedApps.isNotEmpty)
                      Text('${_blockedApps.length} selected',
                          style: GoogleFonts.outfit(
                              color: NudgeTokens.textLow, fontSize: 11)),
                  ],
                ),
                TextButton.icon(
                  onPressed: _showAppPicker,
                  icon: const Icon(Icons.apps_rounded, size: 16),
                  label: Text(_appsLoading ? 'Loading…' : 'Choose'),
                  style: TextButton.styleFrom(
                      foregroundColor: NudgeTokens.purple),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: NudgeTokens.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text('Save Schedule',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeTile(String label, TimeOfDay time, bool isStart) {
    return GestureDetector(
      onTap: () => _pickTime(isStart),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: NudgeTokens.elevated,
            borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Text(label,
                style: GoogleFonts.outfit(
                    color: NudgeTokens.textLow, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
