import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/card_model.dart';
import '../providers/app_state.dart';

class MovieCard extends StatelessWidget {
  final TrackerCard card;

  const MovieCard({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border(
           bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2), width: 4),
        ),
         boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              card.iconCodePoint != null
                ? Icon(IconData(card.iconCodePoint!, fontFamily: 'MaterialIcons'), size: 32, color: Theme.of(context).primaryColor)
                : Text(card.emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text(
                      card.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4B4B4B)),
                    ),
                    Text(
                      "${(card.totalMinutes / 60).toStringAsFixed(1)} hours watched",
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    )
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showSearchDialog(context, appState),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1CB0F6), // Blue
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1CB0F6).withValues(alpha: 0.4),
                         blurRadius: 0,
                         offset: const Offset(0, 4),
                      )
                    ]
                  ),
                  child: const Text("Log Movie", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  void _showSearchDialog(BuildContext context, AppState appState) {
    final controller = TextEditingController();
    bool loading = false;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text("What did you watch?"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: "Movie Title",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F7),
                    suffixIcon: IconButton(
                       icon: const Icon(Icons.search),
                       onPressed: () async {
                         if (controller.text.isEmpty) return;
                         setState(() => loading = true);
                         final movie = await _fetchMovie(controller.text);
                         setState(() => loading = false);
                         
                         if (movie != null && context.mounted) {
                           // Auto add for now
                           Navigator.pop(ctx);
                           _confirmMovie(context, appState, movie);
                         } else {
                           if (context.mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Movie not found!")));
                           }
                         }
                       },
                    ),
                  ),
                  autofocus: true,
                  onSubmitted: (_) async {
                     // Same logic as button
                     if (controller.text.isEmpty) return;
                     setState(() => loading = true);
                     final movie = await _fetchMovie(controller.text);
                     setState(() => loading = false);
                     
                     if (movie != null && context.mounted) {
                       Navigator.pop(ctx);
                       _confirmMovie(context, appState, movie);
                     }
                  },
                ),
                if (loading) const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())
              ],
            ),
          );
        }
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchMovie(String term) async {
    try {
      final url = Uri.parse("https://itunes.apple.com/search?term=$term&entity=movie&limit=1");
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['resultCount'] > 0) {
          return data['results'][0];
        }
      }
    } catch (e) {
      debugPrint("Error fetching movie: $e");
    }
    return null;
  }

  void _confirmMovie(BuildContext context, AppState appState, Map<String, dynamic> movie) {
    final title = movie['trackName'];
    final millis = movie['trackTimeMillis'] ?? 0;
    final minutes = (millis / 60000).round();
    
    appState.addMediaEntry(card, minutes, title);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Added $title ($minutes mins)"), backgroundColor: Colors.green),
    );
  }
}
