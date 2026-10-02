// lib/screens/protected/bookmarks_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import '../../storage.dart';
import '../../app.dart' show NudgeTokens;
import 'habit_card.dart';
import 'habit_detail_screen.dart';
import 'habit_editor_sheet.dart';
import 'package:nudge/utils/nudge_theme_extension.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  Box? _box;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _box = await AppStorage.getProtectedBox();
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _bookmarkedHabits() {
    final b = _box;
    if (b == null) return [];
    final raw = (b.get('habits', defaultValue: <dynamic>[]) as List);
    return raw
        .map((e) => (e as Map).cast<String, dynamic>())
        .where((h) => h['isBookmarked'] == true)
        .toList();
  }

  Map<String, dynamic> _logsAll() {
    final b = _box;
    if (b == null) return {};
    final raw = b.get('habit_logs', defaultValue: <String, dynamic>{});
    return (raw as Map).cast<String, dynamic>();
  }

  int _countForToday(String habitId) {
    final now = DateTime.now();
    final dayIso = '${now.year}-${now.month.toString().padLeft(2, "0")}-${now.day.toString().padLeft(2, "0")}';
    final logs = _logsAll();
    final per = logs[habitId];
    if (per is Map) {
      final v = per[dayIso];
      if (v is int) return v;
      if (v is num) return v.toInt();
    }
    return 0;
  }

  Future<void> _toggleBookmark(Map<String, dynamic> habit) async {
    final b = _box;
    if (b == null) return;
    final list = (b.get('habits', defaultValue: <dynamic>[]) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final idx = list.indexWhere((h) => h['id'] == habit['id']);
    if (idx >= 0) {
      list[idx]['isBookmarked'] = !(list[idx]['isBookmarked'] ?? false);
      await b.put('habits', list);
      setState(() {});
    }
  }

  void _openDetail(Map<String, dynamic> habit) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => HabitDetailScreen(habit: habit, logs: _logsAll()[habit['id']?.toString()] as Map?),
    )).then((_) => setState((){}));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: NudgeTokens.blue)));
    }

    final bookmarked = _bookmarkedHabits();

    return Scaffold(
      backgroundColor: NudgeTokens.bg,
      appBar: AppBar(
        backgroundColor: NudgeTokens.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Bookmarks',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: NudgeTokens.border),
        ),
      ),
      body: bookmarked.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bookmarked.length,
              itemBuilder: (context, index) {
                final h = bookmarked[index];
                final id = h['id']?.toString() ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: HabitCard(
                    title: h['name'] ?? 'Habit',
                    iconCode: h['iconCode'] ?? Icons.bookmark_rounded.codePoint,
                    count: _countForToday(id),
                    last7: const [], // simplified for bookmarks view
                    type: h['type'] ?? 'build',
                    target: h['target'] ?? 1,
                    isBookmarked: true,
                    onToggleBookmark: () => _toggleBookmark(h),
                    onTapEdit: () {},
                    onPlus: () {},
                    onMinus: () {},
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_border_rounded, size: 64, color: NudgeTokens.textLow.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'No bookmarked habits',
            style: GoogleFonts.outfit(color: NudgeTokens.textMid, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Bookmark your most important habits\nfor quick access.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: NudgeTokens.textLow, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
