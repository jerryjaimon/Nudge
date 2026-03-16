// lib/screens/export/export_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../export/csv_export.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  int _tab = 0;
  bool _loading = true;
  String _csv = '';

  final _tabs = const [
    'Pomodoro Logs',
    'Pomodoro Projects',
    'Gym Workouts',
    'Gym Cardio',
    'Protected Habits',
    'Protected Logs',
    'Movies',
    'Books',
    'Health History (Totals)',
    'Health Logs (Manual)',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _csv = '';
    });

    String csv;
    switch (_tab) {
      case 0:
        csv = await CsvExport.exportPomodoroLogs();
        break;
      case 1:
        csv = await CsvExport.exportPomodoroProjects();
        break;
      case 2:
        csv = await CsvExport.exportGymWorkouts();
        break;
      case 3:
        csv = await CsvExport.exportGymCardio();
        break;
      case 4:
        csv = await CsvExport.exportProtectedHabits();
        break;
      case 5:
        csv = await CsvExport.exportProtectedHabitLogs();
        break;
      case 6:
        csv = await CsvExport.exportMoviesRaw();
        break;
      case 7:
        csv = await CsvExport.exportBooksRaw();
        break;
      case 8:
        csv = await CsvExport.exportHealthHistory();
        break;
      case 9:
        csv = await CsvExport.exportLocalHealthLogs();
        break;
      default:
        csv = '';
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _csv = csv;
    });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied CSV to clipboard'), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export (CSV)'),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xFF101722),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _tab,
                  isExpanded: true,
                  items: List.generate(
                    _tabs.length,
                    (i) => DropdownMenuItem<int>(value: i, child: Text(_tabs[i])),
                  ),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _tab = v);
                    _load();
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0xFF101722),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: SelectableText(
                          _csv.isEmpty ? '(empty)' : _csv,
                          style: const TextStyle(fontFamily: 'monospace', height: 1.25),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: _loading ? null : _copy,
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy CSV'),
          ),
        ),
      ),
    );
  }
}
