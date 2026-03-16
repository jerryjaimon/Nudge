// lib/utils/pdf_export_service.dart

import 'dart:io';
import 'package:flutter/services.dart';
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
}
