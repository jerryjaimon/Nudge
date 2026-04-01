// lib/utils/pdf_export_service.dart

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/health_center_service.dart';
import 'ai_analysis_service.dart';
import '../storage.dart';
import 'package:intl/intl.dart';

class PdfExportService {
  static Future<void> exportProgress() async {
    final pdf = pw.Document();
    
    // Fetch data
    final history = await HealthCenterService.getHistoryStats(14); // Last 2 weeks
    final profile = HealthCenterService.profile;
    final reports = AiAnalysisService.getSavedReports();
    final latestReport = reports.isNotEmpty ? reports.first['content'] as String : 'No AI Coach report available yet.';
    
    final dateFormat = DateFormat('yyyy-MM-dd');

    // --- Cover Page ---
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('NUDGE: Progress Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text('User: ${profile['name'] ?? 'User'}'),
              pw.Text('Goal: ${profile['goal'] ?? 'Maintain'}'),
              pw.Text('Report Date: ${dateFormat.format(DateTime.now())}'),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 40),
              pw.Text('AI COACH SUMMARY', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text(latestReport, style: const pw.TextStyle(fontSize: 12)),
            ],
          );
        },
      ),
    );

    // --- Logbook Table Page ---
    pdf.addPage(
      pw.MultiPage(
        header: (pw.Context context) => pw.Text('Logbook Report (Last 14 Days)', style: pw.TextStyle(fontSize: 14, color: PdfColors.grey)),
        build: (pw.Context context) {
          final gymData = history.where((e) => (e['workoutTimeMin'] as num? ?? 0) > 0 || (e['workoutCal'] as num? ?? 0) > 0 || e['hasLocalWorkout'] == true).toList();
          
          return [
            pw.Text('GYM SESSIONS', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Duration', 'Gym Calories'],
              data: gymData.map((e) {
                return [
                  e['date'] ?? '',
                  '${e['workoutTimeMin']}m',
                  '${(e['workoutCal'] as num).toInt()} kcal',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 30),
            pw.Text('DAILY ACTIVITY & NUTRITION', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Steps', 'Run (Cal)', 'Food (In)', 'Water (ml)'],
              data: history.map((e) {
                return [
                  e['date'] ?? '',
                  '${(e['steps'] as num).toInt()}',
                  '${(e['runningCal'] as num).toInt()}',
                  '${(e['foodCalories'] as num).toInt()}',
                  '${(e['waterMl'] as num).toInt()}',
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    // Share/Print the PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) => pdf.save(),
      name: 'Nudge_Progress_${dateFormat.format(DateTime.now())}.pdf',
    );
  }

  static pw.Widget _pdfStatBlock(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(value, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  /// Export gym workouts for a given date range as a PDF.
  static Future<void> exportGymWorkoutsRange(DateTime from, DateTime to) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('yyyy-MM-dd');
    final displayFormat = DateFormat('MMM d, yyyy');

    // Fetch workouts filtered to range
    final gymBox = await AppStorage.getGymBox();
    final workoutsRaw = (gymBox.get('workouts', defaultValue: <dynamic>[]) as List);
    final workouts = workoutsRaw
        .map((e) => (e as Map).cast<String, dynamic>())
        .where((w) {
          final iso = w['dayIso'] as String?;
          if (iso == null) return false;
          try {
            final d = DateTime.parse(iso);
            final fromDay = DateTime(from.year, from.month, from.day);
            final toDay = DateTime(to.year, to.month, to.day);
            return !d.isBefore(fromDay) && !d.isAfter(toDay);
          } catch (_) {
            return false;
          }
        })
        .toList()
      ..sort((a, b) => (a['dayIso'] as String).compareTo(b['dayIso'] as String));

    // Summary stats
    final totalSessions = workouts.length;
    final totalExercises = workouts.fold<int>(
        0, (sum, w) => sum + ((w['exercises'] as List?)?.length ?? 0));
    final totalCalories = workouts.fold<int>(
        0, (sum, w) => sum + ((w['calories'] as num?)?.toInt() ?? 0));
    final totalCardioMin = workouts.fold<int>(0, (sum, w) {
      final cardio = (w['cardio'] as List?) ?? [];
      return sum + cardio.fold<int>(0, (s, c) => s + ((c as Map)['minutes'] as num? ?? 0).toInt());
    });

    // ── Cover page ───────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('NUDGE: Gym Activity Report',
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text('${displayFormat.format(from)}  —  ${displayFormat.format(to)}',
                style: const pw.TextStyle(fontSize: 13)),
            pw.Text('Generated: ${displayFormat.format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 20),
            pw.Row(children: [
              _pdfStatBlock('Sessions', '$totalSessions'),
              pw.SizedBox(width: 36),
              _pdfStatBlock('Exercises Logged', '$totalExercises'),
              pw.SizedBox(width: 36),
              _pdfStatBlock('Gym Calories', '$totalCalories kcal'),
              pw.SizedBox(width: 36),
              _pdfStatBlock('Cardio Time', '${totalCardioMin}min'),
            ]),
            if (workouts.isEmpty) ...[
              pw.SizedBox(height: 40),
              pw.Text('No gym workouts logged in this period.',
                  style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey600)),
            ],
          ],
        ),
      ),
    );

    if (workouts.isNotEmpty) {
      // ── Detailed workout pages ─────────────────────────────────────────────
      pdf.addPage(
        pw.MultiPage(
          header: (pw.Context ctx) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Workout Log',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text('${displayFormat.format(from)} — ${displayFormat.format(to)}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              ],
            ),
          ),
          build: (pw.Context ctx) {
            final content = <pw.Widget>[];
            for (final w in workouts) {
              final iso = w['dayIso'] as String;
              final exercises = ((w['exercises'] as List?) ?? [])
                  .map((e) => (e as Map).cast<String, dynamic>())
                  .toList();
              final cardio = ((w['cardio'] as List?) ?? [])
                  .map((e) => (e as Map).cast<String, dynamic>())
                  .toList();
              final hcSessions = ((w['hcSessions'] as List?) ?? [])
                  .map((e) => (e as Map).cast<String, dynamic>())
                  .toList();
              final calories = (w['calories'] as num?)?.toInt() ?? 0;
              final note = (w['note'] as String?) ?? '';

              content.add(pw.SizedBox(height: 14));
              content.add(pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(iso,
                      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  if (calories > 0)
                    pw.Text('$calories kcal',
                        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ));
              content.add(pw.Divider(thickness: 0.5));

              if (exercises.isEmpty && cardio.isEmpty && hcSessions.isEmpty) {
                content.add(pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 8, bottom: 6),
                  child: pw.Text('(No detailed exercises logged)',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500,
                          fontStyle: pw.FontStyle.italic)),
                ));
              }

              for (final ex in exercises) {
                final name = (ex['name'] as String?) ?? 'Exercise';
                final sets = ((ex['sets'] as List?) ?? [])
                    .map((s) => (s as Map).cast<String, dynamic>())
                    .toList();
                final setsText = sets.map((s) {
                  final reps = (s['reps'] as num?)?.toInt() ?? 0;
                  final wt = (s['weight'] as num?)?.toDouble() ?? 0.0;
                  if (wt > 0) {
                    final wtStr = wt % 1 == 0 ? wt.toStringAsFixed(0) : wt.toStringAsFixed(1);
                    return '${reps}r × ${wtStr}kg';
                  }
                  return '$reps reps';
                }).join('   ');

                content.add(pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 8, top: 3, bottom: 3),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(
                        width: 140,
                        child: pw.Text('• $name',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                      pw.Expanded(
                        child: pw.Text(setsText,
                            style: const pw.TextStyle(fontSize: 10)),
                      ),
                    ],
                  ),
                ));
              }

              for (final c in cardio) {
                final activity = (c['activity'] as String?) ?? 'Cardio';
                final minutes = (c['minutes'] as num?)?.toInt() ?? 0;
                final distKm = (c['distanceKm'] as num?)?.toDouble() ?? 0.0;
                var detail = '${minutes}min';
                if (distKm > 0) detail += ' · ${distKm.toStringAsFixed(1)}km';
                content.add(pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 8, top: 3, bottom: 3),
                  child: pw.Text('• $activity (cardio): $detail',
                      style: const pw.TextStyle(fontSize: 10)),
                ));
              }

              for (final hc in hcSessions) {
                final type = (hc['type'] as String?) ?? 'Session';
                final dur = (hc['durationMin'] as num?)?.toInt() ?? 0;
                final source = (hc['source'] as String?) ?? 'Health Connect';
                content.add(pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 8, top: 3, bottom: 3),
                  child: pw.Text('• $type (${dur}min via $source)',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ));
              }

              if (note.isNotEmpty) {
                content.add(pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 8, top: 3, bottom: 6),
                  child: pw.Text('Note: $note',
                      style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey600,
                          fontStyle: pw.FontStyle.italic)),
                ));
              }
            }
            return content;
          },
        ),
      );

      // ── Summary table ──────────────────────────────────────────────────────
      pdf.addPage(
        pw.MultiPage(
          build: (pw.Context ctx) => [
            pw.Text('Session Summary',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Exercises', 'Sets', 'Cardio', 'Calories'],
              data: workouts.map((w) {
                final exList = (w['exercises'] as List?) ?? [];
                final cardioList = (w['cardio'] as List?) ?? [];
                final totalSets = exList.fold<int>(
                    0, (s, e) => s + (((e as Map)['sets'] as List?)?.length ?? 0));
                final cardioSummary = cardioList.isEmpty
                    ? '—'
                    : cardioList
                        .map((c) =>
                            '${(c as Map)['activity'] ?? ''} ${(c['minutes'] ?? 0)}m')
                        .join(', ');
                final cal = (w['calories'] as num?)?.toInt() ?? 0;
                return [
                  w['dayIso'] ?? '',
                  '${exList.length}',
                  '$totalSets',
                  cardioSummary,
                  cal > 0 ? '$cal kcal' : '—',
                ];
              }).toList(),
            ),
          ],
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) => pdf.save(),
      name: 'Nudge_Gym_${dateFormat.format(from)}_to_${dateFormat.format(to)}.pdf',
    );
  }
}
