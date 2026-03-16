import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../app.dart';
import '../../storage.dart';
import '../../utils/nudge_theme_extension.dart';

class AiErrorLogScreen extends StatefulWidget {
  const AiErrorLogScreen({super.key});

  @override
  State<AiErrorLogScreen> createState() => _AiErrorLogScreenState();
}

class _AiErrorLogScreenState extends State<AiErrorLogScreen> {
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final box = await AppStorage.getAiLogsBox();
    setState(() {
      _logs = (box.get('errors', defaultValue: <dynamic>[]) as List)
          .cast<Map<String, dynamic>>()
          .toList();
    });
  }

  Future<void> _clear() async {
    final box = await AppStorage.getAiLogsBox();
    await box.put('errors', <dynamic>[]);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<NudgeThemeExtension>()!;
    final tColor = theme.textColor ?? Colors.white;
    final tDimColor = theme.textDim ?? NudgeTokens.textLow;

    return Scaffold(
      backgroundColor: theme.scaffoldBg ?? NudgeTokens.bg,
      appBar: AppBar(
        title: const Text('AI Error Log'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_logs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _clear,
              tooltip: 'Clear Logs',
            ),
        ],
      ),
      body: _logs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 48, color: tDimColor),
                  const SizedBox(height: 16),
                  Text(
                    'No errors logged',
                    style: TextStyle(color: tDimColor, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                final date = DateTime.parse(log['timestamp'] as String);
                final timeStr = DateFormat('MMM d, HH:mm:ss').format(date);
                final msg = log['message'] as String;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: theme.cardDecoration(context),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Row(
                      children: [
                        Text(
                          timeStr,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: NudgeTokens.purple,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: msg));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Copied to clipboard')),
                            );
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        msg,
                        style: TextStyle(
                          color: tColor,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
