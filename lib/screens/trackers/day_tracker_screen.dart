// lib/screens/trackers/day_tracker_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../app.dart' show NudgeTokens;
import '../../services/widget_service.dart';
import '../../storage.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class DayTracker {
  final String id;
  final String title;
  /// If true, progress is calculated from [startDate]..[endDate].
  final bool isDateBased;
  final DateTime? startDate;
  final DateTime? endDate;
  /// Manual mode: current step and total steps.
  final int currentDay;
  final int totalDays;
  final Color color;

  const DayTracker({
    required this.id,
    required this.title,
    required this.isDateBased,
    this.startDate,
    this.endDate,
    this.currentDay = 0,
    this.totalDays = 100,
    required this.color,
  });

  // ── derived ──────────────────────────────────────────────────────────────

  int get resolvedCurrent {
    if (isDateBased && startDate != null) {
      final today = _onlyDay(DateTime.now());
      final start = _onlyDay(startDate!);
      return today.difference(start).inDays.clamp(0, resolvedTotal);
    }
    return currentDay.clamp(0, totalDays);
  }

  int get resolvedTotal {
    if (isDateBased && startDate != null && endDate != null) {
      return _onlyDay(endDate!).difference(_onlyDay(startDate!)).inDays;
    }
    return totalDays;
  }

  double get progress =>
      resolvedTotal > 0 ? resolvedCurrent / resolvedTotal : 0.0;

  int get remaining => (resolvedTotal - resolvedCurrent).clamp(0, resolvedTotal);

  static DateTime _onlyDay(DateTime d) => DateTime(d.year, d.month, d.day);

  // ── serialisation ────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isDateBased': isDateBased,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'currentDay': currentDay,
        'totalDays': totalDays,
        'color': color.toARGB32(),
      };

  static DayTracker fromJson(Map<String, dynamic> j) => DayTracker(
        id: j['id'] as String,
        title: j['title'] as String,
        isDateBased: j['isDateBased'] as bool? ?? false,
        startDate: j['startDate'] != null
            ? DateTime.tryParse(j['startDate'] as String)
            : null,
        endDate: j['endDate'] != null
            ? DateTime.tryParse(j['endDate'] as String)
            : null,
        currentDay: (j['currentDay'] as int?) ?? 0,
        totalDays: (j['totalDays'] as int?) ?? 100,
        color: Color(j['color'] as int? ?? NudgeTokens.purple.toARGB32()),
      );
}

// ── Screen ────────────────────────────────────────────────────────────────────

class DayTrackerScreen extends StatefulWidget {
  const DayTrackerScreen({super.key});

  @override
  State<DayTrackerScreen> createState() => _DayTrackerScreenState();
}

class _DayTrackerScreenState extends State<DayTrackerScreen> {
  static const _storageKey = 'day_trackers';
  List<DayTracker> _trackers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final box = await AppStorage.getSettingsBox();
    final raw = box.get(_storageKey, defaultValue: <dynamic>[]) as List;
    final trackers = raw
        .map((e) => DayTracker.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    // Seed with current year if empty
    if (trackers.isEmpty) {
      final now = DateTime.now();
      trackers.add(DayTracker(
        id: const Uuid().v4(),
        title: 'Year ${now.year}',
        isDateBased: true,
        startDate: DateTime(now.year, 1, 1),
        endDate: DateTime(now.year, 12, 31),
        color: NudgeTokens.purple,
      ));
      await _persist(trackers);
    }
    if (mounted) setState(() { _trackers = trackers; _loading = false; });
  }

  Future<void> _persist(List<DayTracker> list) async {
    final box = await AppStorage.getSettingsBox();
    await box.put(_storageKey, list.map((t) => t.toJson()).toList());
  }

  Future<void> _save() async {
    await _persist(_trackers);
    WidgetService.updateAll();
  }

  void _add() async {
    final result = await showModalBottomSheet<DayTracker>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TrackerEditorSheet(),
    );
    if (result != null) {
      setState(() => _trackers.add(result));
      await _save();
    }
  }

  void _edit(int idx) async {
    final result = await showModalBottomSheet<DayTracker>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TrackerEditorSheet(tracker: _trackers[idx]),
    );
    if (result != null) {
      setState(() => _trackers[idx] = result);
      await _save();
    }
  }

  void _delete(int idx) async {
    setState(() => _trackers.removeAt(idx));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NudgeTokens.bg,
      appBar: AppBar(
        backgroundColor: NudgeTokens.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Day Trackers',
          style: GoogleFonts.outfit(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20),
        ),
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: NudgeTokens.border),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              itemCount: _trackers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (_, i) => _TrackerCard(
                tracker: _trackers[i],
                onEdit: () => _edit(i),
                onDelete: () => _delete(i),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: NudgeTokens.purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('New Tracker',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── Tracker card ──────────────────────────────────────────────────────────────

class _TrackerCard extends StatelessWidget {
  final DayTracker tracker;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TrackerCard({
    required this.tracker,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final current = tracker.resolvedCurrent;
    final total = tracker.resolvedTotal;
    final pct = tracker.progress;
    final pctInt = (pct * 100).clamp(0, 100).toStringAsFixed(1);
    final remaining = tracker.remaining;
    final color = tracker.color;

    // Determine display date string
    String dateLabel = '';
    if (tracker.isDateBased && tracker.startDate != null && tracker.endDate != null) {
      final s = tracker.startDate!;
      final e = tracker.endDate!;
      dateLabel =
          '${_monthName(s.month)} ${s.day}, ${s.year}  –  ${_monthName(e.month)} ${e.day}, ${e.year}';
    }

    final now = DateTime.now();
    final dayLabel =
        '${_weekday(now.weekday)}, ${_monthName(now.month)} ${now.day}';

    return Container(
      decoration: BoxDecoration(
        color: NudgeTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tracker.title,
                        style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18),
                      ),
                      if (dateLabel.isNotEmpty)
                        Text(dateLabel,
                            style: GoogleFonts.outfit(
                                color: NudgeTokens.textLow, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded,
                      color: NudgeTokens.textLow, size: 18),
                  tooltip: 'Edit',
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: NudgeTokens.textLow, size: 18),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),

          // ── Date label ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
            child: Text(
              tracker.isDateBased ? dayLabel : 'Day $current of $total',
              style: GoogleFonts.outfit(
                  color: NudgeTokens.textMid,
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
            ),
          ),

          // ── Dot grid ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _DotGrid(
              total: total,
              current: current,
              color: color,
            ),
          ),

          // ── Stats ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$current / $total days ($pctInt%)',
                      style: GoogleFonts.outfit(
                          color: NudgeTokens.textMid,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$remaining days left',
                        style: GoogleFonts.outfit(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _monthName(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  static String _weekday(int w) => const [
        '', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
      ][w];
}

// ── Dot grid painter ─────────────────────────────────────────────────────────

class _DotGrid extends StatelessWidget {
  final int total;
  final int current;
  final Color color;

  const _DotGrid({
    required this.total,
    required this.current,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width - 72; // 20 padding each side + 32 container
    const dotSize = 7.0;
    const dotGap = 4.0;
    final cols = max(1, (width / (dotSize + dotGap)).floor());
    final rows = (total / cols).ceil();
    final gridHeight = rows * (dotSize + dotGap);

    return SizedBox(
      height: gridHeight,
      child: CustomPaint(
        size: Size(width, gridHeight),
        painter: _DotGridPainter(
          total: total,
          current: current,
          cols: cols,
          dotSize: dotSize,
          dotGap: dotGap,
          pastColor: Colors.white.withValues(alpha: 0.75),
          futureColor: Colors.white.withValues(alpha: 0.10),
          currentColor: color,
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  final int total;
  final int current;
  final int cols;
  final double dotSize;
  final double dotGap;
  final Color pastColor;
  final Color futureColor;
  final Color currentColor;

  _DotGridPainter({
    required this.total,
    required this.current,
    required this.cols,
    required this.dotSize,
    required this.dotGap,
    required this.pastColor,
    required this.futureColor,
    required this.currentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final past = Paint()..color = pastColor;
    final future = Paint()..color = futureColor;
    final today = Paint()..color = currentColor;
    final r = dotSize / 2;

    for (int i = 0; i < total; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      final cx = col * (dotSize + dotGap) + r;
      final cy = row * (dotSize + dotGap) + r;
      final center = Offset(cx, cy);

      if (i < current) {
        canvas.drawCircle(center, r, past);
      } else if (i == current) {
        // Glow ring for current day
        canvas.drawCircle(
          center,
          r + 2,
          Paint()..color = currentColor.withValues(alpha: 0.25),
        );
        canvas.drawCircle(center, r, today);
      } else {
        canvas.drawCircle(center, r, future);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) =>
      old.total != total ||
      old.current != current ||
      old.currentColor != currentColor;
}

// ── Editor sheet ──────────────────────────────────────────────────────────────

class _TrackerEditorSheet extends StatefulWidget {
  final DayTracker? tracker;
  const _TrackerEditorSheet({this.tracker});

  @override
  State<_TrackerEditorSheet> createState() => _TrackerEditorSheetState();
}

class _TrackerEditorSheetState extends State<_TrackerEditorSheet> {
  late TextEditingController _titleCtrl;
  bool _isDateBased = true;
  DateTime _startDate = DateTime(DateTime.now().year, 1, 1);
  DateTime _endDate = DateTime(DateTime.now().year, 12, 31);
  int _currentDay = 0;
  int _totalDays = 100;
  Color _color = NudgeTokens.purple;

  static const _palette = [
    NudgeTokens.purple,
    NudgeTokens.green,
    NudgeTokens.blue,
    NudgeTokens.amber,
    NudgeTokens.red,
    NudgeTokens.gymB,
    NudgeTokens.pomB,
    NudgeTokens.booksB,
    NudgeTokens.moviesB,
    NudgeTokens.finB,
  ];

  @override
  void initState() {
    super.initState();
    final t = widget.tracker;
    _titleCtrl = TextEditingController(text: t?.title ?? '');
    if (t != null) {
      _isDateBased = t.isDateBased;
      _startDate = t.startDate ?? _startDate;
      _endDate = t.endDate ?? _endDate;
      _currentDay = t.currentDay;
      _totalDays = t.totalDays;
      _color = t.color;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? _startDate : _endDate;
    final first = isStart ? DateTime(2000) : _startDate;
    final last = isStart ? _endDate : DateTime(2100);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                surface: NudgeTokens.elevated,
                primary: _color,
              ),
          dialogTheme:
              const DialogThemeData(backgroundColor: NudgeTokens.elevated),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => isStart ? _startDate = picked : _endDate = picked);
    }
  }

  void _save() {
    final title =
        _titleCtrl.text.trim().isEmpty ? 'Tracker' : _titleCtrl.text.trim();
    Navigator.pop(
      context,
      DayTracker(
        id: widget.tracker?.id ?? const Uuid().v4(),
        title: title,
        isDateBased: _isDateBased,
        startDate: _isDateBased ? _startDate : null,
        endDate: _isDateBased ? _endDate : null,
        currentDay: _isDateBased ? 0 : _currentDay,
        totalDays: _isDateBased ? 0 : _totalDays,
        color: _color,
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${_monthName(d.month)} ${d.day}, ${d.year}';

  static String _monthName(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: NudgeTokens.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 28),
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
            const SizedBox(height: 18),
            Text(
              widget.tracker == null ? 'New Tracker' : 'Edit Tracker',
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 20),
            ),
            const SizedBox(height: 20),

            // Title
            TextField(
              controller: _titleCtrl,
              style: GoogleFonts.outfit(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Topic / Title',
                hintText: 'e.g. Year 2026, 100-Day Challenge…',
                labelStyle: GoogleFonts.outfit(color: NudgeTokens.textLow),
                hintStyle: GoogleFonts.outfit(
                    color: NudgeTokens.textLow, fontSize: 13),
                filled: true,
                fillColor: NudgeTokens.elevated,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),

            // Mode toggle
            Text('Progress Mode',
                style: GoogleFonts.outfit(
                    color: NudgeTokens.textMid,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _modeBtn('Date Range', true)),
                const SizedBox(width: 10),
                Expanded(child: _modeBtn('Manual', false)),
              ],
            ),
            const SizedBox(height: 20),

            if (_isDateBased) ...[
              // Date range pickers
              Row(
                children: [
                  Expanded(child: _dateTile('Start', _startDate, true)),
                  const SizedBox(width: 12),
                  Expanded(child: _dateTile('End', _endDate, false)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${_endDate.difference(_startDate).inDays} day range',
                style: GoogleFonts.outfit(
                    color: NudgeTokens.textLow, fontSize: 12),
              ),
            ] else ...[
              // Manual sliders
              _label('Current Day'),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _currentDay.toDouble().clamp(0, _totalDays.toDouble()),
                      min: 0,
                      max: _totalDays.toDouble(),
                      divisions: _totalDays > 0 ? _totalDays : 1,
                      activeColor: _color,
                      onChanged: (v) => setState(() => _currentDay = v.round()),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '$_currentDay',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16),
                    ),
                  ),
                ],
              ),
              _label('Total Days'),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _totalDays.toDouble().clamp(1, 3650),
                      min: 1,
                      max: 3650,
                      activeColor: _color,
                      onChanged: (v) => setState(() {
                        _totalDays = v.round();
                        if (_currentDay > _totalDays) _currentDay = _totalDays;
                      }),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '$_totalDays',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // Colour picker
            _label('Colour'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _palette.map((c) {
                final selected = c == _color;
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: selected
                          ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 8)]
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 16)
                        : null,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  widget.tracker == null ? 'Create Tracker' : 'Save Changes',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeBtn(String label, bool isDate) {
    final selected = _isDateBased == isDate;
    return GestureDetector(
      onTap: () => setState(() => _isDateBased = isDate),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _color.withValues(alpha: 0.15) : NudgeTokens.elevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? _color.withValues(alpha: 0.5) : NudgeTokens.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: selected ? _color : NudgeTokens.textLow,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _dateTile(String label, DateTime date, bool isStart) {
    return GestureDetector(
      onTap: () => _pickDate(isStart),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: NudgeTokens.elevated,
            borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.outfit(
                    color: NudgeTokens.textLow, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              _fmtDate(date),
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: GoogleFonts.outfit(
                color: NudgeTokens.textMid,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      );
}
