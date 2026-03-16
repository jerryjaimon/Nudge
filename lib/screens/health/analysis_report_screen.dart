// lib/screens/health/analysis_report_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:nudge/utils/nudge_theme_extension.dart';
import '../../app.dart' show NudgeTokens;

class AnalysisReportScreen extends StatelessWidget {
  final String content;
  final String timestamp;

  const AnalysisReportScreen({
    super.key,
    required this.content,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(timestamp);
    final dateStr = '${date.day}/${date.month}/${date.year}';

    return Scaffold(
      appBar: AppBar(
        title: Text('AI COACH REPORT', style: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.8)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: NudgeTokens.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: NudgeTokens.purple, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weekly Insights', style: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh), fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('Generated on $dateStr', style: const TextStyle(color: NudgeTokens.textLow, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: NudgeTokens.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: NudgeTokens.border),
              ),
              child: MarkdownBody(
                data: content,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(color: NudgeTokens.textMid, fontSize: 15, height: 1.6),
                  h1: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh), fontSize: 20, fontWeight: FontWeight.w900, height: 2.0),
                  h2: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh), fontSize: 18, fontWeight: FontWeight.w800, height: 1.8),
                  h3: TextStyle(color: (Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh), fontSize: 16, fontWeight: FontWeight.w700, height: 1.6),
                  listBullet: const TextStyle(color: NudgeTokens.purple, fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

