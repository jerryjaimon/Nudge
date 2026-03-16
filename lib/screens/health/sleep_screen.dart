import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/sleep_service.dart';
import 'package:intl/intl.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  SleepSession? _lastNight;
  DateTime? _tempBed;
  DateTime? _tempWake;
  bool _isEdited = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    setState(() => _loading = true);
    // Sync to storage first (preserves userValidated), then read back from storage
    await SleepService.syncSleep();
    SleepSession? session = await SleepService.getStoredSleep();
    // Fallback to live if nothing in storage yet
    session ??= await SleepService.getHealthConnectSleep();
    session ??= await SleepService.inferLastNightSleep();

    setState(() {
      _lastNight = session;
      _tempBed = session?.bedTime;
      _tempWake = session?.wakeTime;
      _isEdited = false;
      _loading = false;
    });
  }

  void _validate(bool confirmed) async {
    if (_lastNight == null) return;
    // Ensure the session exists in storage before validating
    await SleepService.syncSleep();
    final dayIso = "${_lastNight!.wakeTime.year}-${_lastNight!.wakeTime.month.toString().padLeft(2, '0')}-${_lastNight!.wakeTime.day.toString().padLeft(2, '0')}";
    await SleepService.validateSleep(dayIso, confirmed);
    _load();
  }

  void _saveEdits() async {
    if (_lastNight == null || _tempBed == null || _tempWake == null) return;
    await SleepService.syncSleep();
    final dayIso = "${_lastNight!.wakeTime.year}-${_lastNight!.wakeTime.month.toString().padLeft(2, '0')}-${_lastNight!.wakeTime.day.toString().padLeft(2, '0')}";
    await SleepService.updateSleepWindow(dayIso, _tempBed!, _tempWake!);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040B12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('Sleep Cycle', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
        actions: [
          if (_isEdited)
            TextButton(
              onPressed: _saveEdits,
              child: Text('SAVE', style: GoogleFonts.outfit(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            ),
          IconButton(
            icon: const Icon(Icons.sync_rounded, color: Colors.blueAccent),
            onPressed: _load,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
        : RefreshIndicator(
            onRefresh: () async => _load(),
            color: Colors.blueAccent,
            backgroundColor: const Color(0xFF1A1F26),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (_lastNight != null) ...[
                  _buildSummaryCard(_isEdited ? null : _lastNight!, _tempBed, _tempWake),
                  const SizedBox(height: 30),
                  _buildMetricGrid(_lastNight!),
                  const SizedBox(height: 30),
                  _buildTimeline(_lastNight!, _tempBed!, _tempWake!),
                  if (!_isEdited) _buildValidationCard(_lastNight!),
                  const SizedBox(height: 40),
                  _buildSourceInfo(_lastNight!),
                ] else 
                  _buildEmptyState(),
              ],
            ),
          ),
    );
  }

  Widget _buildSummaryCard(SleepSession? session, DateTime? bed, DateTime? wake) {
    final displayBed = bed ?? session!.bedTime;
    final displayWake = wake ?? session!.wakeTime;
    final duration = displayWake.difference(displayBed);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.indigo.withOpacity(0.35), 
            Colors.blue.withOpacity(0.15),
            Colors.deepPurple.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: -5,
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                session?.source == 'health_connect' ? Icons.watch_rounded : Icons.smartphone_rounded,
                size: 14,
                color: Colors.white54,
              ),
              const SizedBox(width: 8),
              Text(
                _isEdited ? 'MANUAL EDIT' : (session?.source == 'health_connect' ? 'WATCH DATA' : 'PHONE INFERENCE'), 
                style: GoogleFonts.outfit(color: _isEdited ? Colors.orangeAccent : Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${duration.inHours}h ${duration.inMinutes % 60}m',
            style: GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _timeBox('Bedtime', displayBed),
                Container(width: 1, height: 20, color: Colors.white10, margin: const EdgeInsets.symmetric(horizontal: 24)),
                _timeBox('Woke Up', displayWake),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeBox(String label, DateTime time) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(DateFormat.jm().format(time), style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildMetricGrid(SleepSession session) {
    String relLabel = 'Medium';
    Color relColor = Colors.orangeAccent;
    if (session.reliabilityScore > 0.8) {
      relLabel = 'High';
      relColor = Colors.blueAccent;
    } else if (session.reliabilityScore < 0.5) {
      relLabel = 'Low';
      relColor = Colors.redAccent;
    }

    if (session.userValidated == true) {
      relLabel = 'Verified';
      relColor = Colors.greenAccent;
    }

    return Row(
      children: [
        Expanded(child: _metricTile('Score', '${session.quality}', Icons.star_rounded, Colors.amberAccent)),
        const SizedBox(width: 16),
        Expanded(child: _metricTile('Reliability', relLabel, Icons.verified_user_rounded, relColor)),
      ],
    );
  }

  Widget _metricTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(label, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _fmtHour(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final suffix = dt.hour < 12 ? 'AM' : 'PM';
    return '$h $suffix';
  }

  Widget _buildTimeline(SleepSession session, DateTime bed, DateTime wake) {
    // Make window dynamic so it always covers the actual bed/wake range.
    // Start 1 h before bed (floored to the hour), end 1 h after wake.
    final earliest = bed.isBefore(wake) ? bed : wake;
    final latest   = wake.isAfter(bed)  ? wake : bed;
    final windowStart = DateTime(earliest.year, earliest.month, earliest.day, earliest.hour, 0)
        .subtract(const Duration(hours: 1));
    final windowEnd   = DateTime(latest.year, latest.month, latest.day, latest.hour + 1, 0);
    final totalSec = windowEnd.difference(windowStart).inSeconds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Adjust Sleep Window', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 0.5)),
            if (session.interruptions.isNotEmpty)
              Text('${session.interruptions.length} Phone Events', style: GoogleFonts.outfit(fontSize: 10, color: Colors.redAccent.withOpacity(0.8), fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 10),
        SliderTheme(
          data: SliderThemeData(
            rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 8),
            activeTrackColor: Colors.blueAccent,
            inactiveTrackColor: Colors.white.withOpacity(0.05),
            overlayColor: Colors.blueAccent.withOpacity(0.1),
            trackHeight: 16,
          ),
          child: Stack(
            children: [
              RangeSlider(
                values: RangeValues(
                  bed.difference(windowStart).inSeconds.toDouble().clamp(0.0, totalSec.toDouble()),
                  wake.difference(windowStart).inSeconds.toDouble().clamp(0.0, totalSec.toDouble()),
                ),
                min: 0,
                max: totalSec.toDouble(),
                onChanged: (values) {
                  setState(() {
                    _tempBed = windowStart.add(Duration(seconds: values.start.toInt()));
                    _tempWake = windowStart.add(Duration(seconds: values.end.toInt()));
                    _isEdited = true;
                  });
                },
              ),
              // Interruptions dots
              IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: SizedBox(
                    height: 8,
                    width: double.infinity,
                    child: Stack(
                      children: session.interruptions.map((intTime) {
                         final offsetSec = intTime.difference(windowStart).inSeconds;
                         final pos = (offsetSec / totalSec).clamp(0.0, 1.0);
                         return Positioned(
                           left: (MediaQuery.of(context).size.width - 48 - 32) * pos,
                           top: 0,
                           bottom: 0,
                           child: Container(width: 3, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                         );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_fmtHour(windowStart), style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w600)),
            const Text('DRAG TO EDIT', style: TextStyle(color: Colors.white10, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
            Text(_fmtHour(windowEnd), style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  Widget _buildValidationCard(SleepSession session) {
    if (session.userValidated != null) {
      return Container(
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: session.userValidated! ? Colors.greenAccent.withOpacity(0.05) : Colors.redAccent.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: (session.userValidated! ? Colors.greenAccent : Colors.redAccent).withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(session.userValidated! ? Icons.verified_rounded : Icons.report_problem_rounded, 
                 color: session.userValidated! ? Colors.greenAccent : Colors.redAccent, size: 16),
            const SizedBox(width: 12),
            Text(
              session.userValidated! ? 'You confirmed this sleep session.' : 'You marked this as incorrect.',
              style: TextStyle(color: session.userValidated! ? Colors.greenAccent : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text('Is this sleep data correct?', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _validate(false),
                  icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 18),
                  label: const Text('Not Right', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _validate(true),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourceInfo(SleepSession session) {
    String msg = session.source == 'health_connect' 
                ? 'Pulling primary data from Health Connect (Watch/Sensor).'
                : 'Health Connect data unavailable. Inferring from phone usage patterns.';
    
    if (session.interruptions.isNotEmpty) {
      msg += ' Heads up: phone activity was detected during this window.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white24, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.nights_stay_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
          ),
          const SizedBox(height: 32),
          Text('No sleep data found.', style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'We couldn\'t find any sleep records in Health Connect or usage patterns for last night.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 14, height: 1.5),
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Check Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              // Usually handled via package_info or similar, but for now we suggest settings
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please ensure Health Connect and Usage Access are enabled in system settings.'))
              );
            },
            child: const Text('How to fix this?', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }
}
