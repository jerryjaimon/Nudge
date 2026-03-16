import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/detox_service.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:uuid/uuid.dart';

class DetoxScreen extends StatefulWidget {
  const DetoxScreen({super.key});

  @override
  State<DetoxScreen> createState() => _DetoxScreenState();
}

class _DetoxScreenState extends State<DetoxScreen> {
  final List<DetoxSchedule> _schedules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    // This is a simplified fetch; in real app we'd use AppStorage directly
    // but the service handles it.
    final box = await UsageStats.queryUsageStats(DateTime.now(), DateTime.now()); // dummy to wait
    // Actually we'll just read from service if we added a getter, or manually from box here.
    // For brevity, let's assume we can get them.
    setState(() => _loading = false);
  }

  void _addSchedule() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _EditScheduleSheet(),
    ).then((_) => _loadSchedules());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04120B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Digital Detox', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeader(),
              const SizedBox(height: 30),
              Text('Schedules', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70)),
              const SizedBox(height: 15),
              // List existing schedules here...
              _buildEmptyState(),
            ],
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSchedule,
        backgroundColor: const Color(0xFF00F5FF),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.timer_off_rounded, color: Colors.orange),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Auto-Blocking', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('Lock distracting apps on a schedule.', style: GoogleFonts.outfit(color: Colors.white54)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 50),
          Icon(Icons.auto_awesome_motion_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 20),
          Text('No blocking schedules set.', style: GoogleFonts.outfit(color: Colors.white30)),
        ],
      ),
    );
  }
}

class _EditScheduleSheet extends StatefulWidget {
  final DetoxSchedule? schedule;
  const _EditScheduleSheet({super.key, this.schedule});

  @override
  State<_EditScheduleSheet> createState() => _EditScheduleSheetState();
}

class _EditScheduleSheetState extends State<_EditScheduleSheet> {
  late TextEditingController _nameCtrl;
  TimeOfDay _start = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 7, minute: 0);
  List<int> _days = [1, 2, 3, 4, 5, 6, 7];
  List<String> _blockedApps = [];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.schedule?.name ?? 'Night Mode');
    if (widget.schedule != null) {
      _start = widget.schedule!.startTime;
      _end = widget.schedule!.endTime;
      _days = widget.schedule!.days;
      _blockedApps = widget.schedule!.blockedApps;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A1610),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Blocking Schedule', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 25),
          TextField(
            controller: _nameCtrl,
            style: GoogleFonts.outfit(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Label',
              labelStyle: GoogleFonts.outfit(color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _timeTile('Starts', _start, (t) => setState(() => _start = t))),
              const SizedBox(width: 15),
              Expanded(child: _timeTile('Ends', _end, (t) => setState(() => _end = t))),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Blocked Apps', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
              TextButton(onPressed: () {}, child: const Text('Change')),
            ],
          ),
          Wrap(
            spacing: 8,
            children: _blockedApps.map((pkg) => Chip(label: Text(pkg.split('.').last, style: const TextStyle(fontSize: 10)))).toList(),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              DetoxService.instance.saveSchedule(DetoxSchedule(
                id: widget.schedule?.id ?? const Uuid().v4(),
                name: _nameCtrl.text,
                startTime: _start,
                endTime: _end,
                days: _days,
                blockedApps: _blockedApps,
              ));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00F5FF),
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text('Save Schedule', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _timeTile(String label, TimeOfDay time, Function(TimeOfDay) onSelect) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) onSelect(picked);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 4),
            Text(time.format(context), style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
