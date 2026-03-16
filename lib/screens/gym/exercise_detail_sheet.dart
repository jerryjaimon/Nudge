import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../app.dart' show NudgeTokens;
import '../../storage.dart';
import 'exercise_thumbnail.dart';
import 'exercise_info.dart';
import 'gym_progress_charts.dart';

class ExerciseDetailSheet extends StatefulWidget {
  final String exerciseName;
  final VoidCallback? onSelect;

  const ExerciseDetailSheet({
    super.key, 
    required this.exerciseName,
    this.onSelect,
  });

  @override
  State<ExerciseDetailSheet> createState() => _ExerciseDetailSheetState();
}

class _ExerciseDetailSheetState extends State<ExerciseDetailSheet> with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  bool _loading = true;
  List<Map<String, dynamic>> _history = [];
  double _pr = 0;
  Map<String, dynamic>? _details;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutQuart));
    
    _loadData();
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final box = await AppStorage.getGymBox();
    final workouts = (box.get('workouts', defaultValue: []) as List).cast<Map>();
    
    final List<Map<String, dynamic>> exerciseHistory = [];
    double bestW = 0;

    for (final w in workouts) {
      final exList = (w['exercises'] as List?) ?? [];
      for (final ex in exList) {
        if (ex['name'] == widget.exerciseName) {
          final sets = (ex['sets'] as List?) ?? [];
          if (sets.isNotEmpty) {
            exerciseHistory.add({
              'dayIso': w['dayIso'],
              'sets': sets,
            });
            for (final s in sets) {
              final weight = (s['weight'] as num?)?.toDouble() ?? 0.0;
              if (weight > bestW) bestW = weight;
            }
          }
        }
      }
    }

    // Sort by date desc
    exerciseHistory.sort((a, b) => (b['dayIso'] as String).compareTo(a['dayIso'] as String));
    
    _details = ExerciseDetailData.getDetails(widget.exerciseName);

    setState(() {
      _history = exerciseHistory;
      _pr = bestW;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0F16),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      ),
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, widget.onSelect != null ? 100 : 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ExerciseThumbnail(exerciseName: widget.exerciseName, size: 80, iconSize: 40),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.exerciseName,
                                      style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    if (_details != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_details!['category'].toString().toUpperCase()} · ${_details!['equipment']}',
                                        style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Stats Row
                          Row(
                            children: [
                              _buildStatCard('Personal Record', '${_pr % 1 == 0 ? _pr.toInt() : _pr.toStringAsFixed(1)} kg', Icons.emoji_events_rounded, Colors.amber),
                              const SizedBox(width: 12),
                              _buildStatCard('Total Sessions', '${_history.length}', Icons.history_rounded, Colors.blue),
                            ],
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Progress Chart
                          if (_history.isNotEmpty) ...[
                            Text('PROGRESS CHART', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white38, letterSpacing: 1.2)),
                            const SizedBox(height: 12),
                            GymProgressCharts(workouts: _history, exerciseName: widget.exerciseName),
                          ],
                          
                          const SizedBox(height: 32),
                          
                          // Instructions
                          if (_details != null && _details!['instructions'].toString().isNotEmpty) ...[
                            Text('HOW TO', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white38, letterSpacing: 1.2)),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: Text(
                                _details!['instructions'],
                                style: TextStyle(color: Colors.white.withOpacity(0.8), height: 1.6, fontSize: 14),
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 32),
                          
                          // Recent History
                          if (_history.isNotEmpty) ...[
                             Text('RECENT SESSIONS', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white38, letterSpacing: 1.2)),
                             const SizedBox(height: 12),
                             ..._history.take(3).map((h) => _buildHistoryItem(h)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.onSelect != null)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24,
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C4DFF).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: widget.onSelect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                      child: const Text(
                        'SELECT EXERCISE',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.1),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),

    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 12),
            Text(value, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> h) {
    final date = DateTime.parse(h['dayIso']);
    final formattedDate = DateFormat('MMM d, yyyy').format(date);
    final sets = h['sets'] as List;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                Text('${sets.length} sets', style: const TextStyle(fontSize: 11, color: Colors.white38)),
              ],
            ),
            const Spacer(),
            Text(
              sets.map((s) => '${s['weight']}kg').join(' · '),
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
