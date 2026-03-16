// lib/screens/gym/gym_chat_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../storage.dart';
import '../../utils/gemini_service.dart';
import 'exercise_db.dart';

class GymChatScreen extends StatefulWidget {
  final String dayIso;
  final Function(Map<String, dynamic>)? onSaved;
  const GymChatScreen({super.key, required this.dayIso, this.onSaved});

  @override
  State<GymChatScreen> createState() => _GymChatScreenState();
}

class _GymChatScreenState extends State<GymChatScreen> {
  final _msgCtrl = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _thinking = false;
  bool _loading = true;
  final ScrollController _scrollCtrl = ScrollController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final box = await AppStorage.getGymBox();
    final history = (box.get('gemini_chat_history', defaultValue: <dynamic>[]) as List);
    
    if (mounted) {
      setState(() {
        if (history.isEmpty) {
          _messages.add({
            'isUser': false,
            'text': 'Hi! Tell me what you did today (e.g., "I did 3 sets of bench press 10 reps at 80kg"), or upload a screenshot. I\'ll log it for you!',
          });
        } else {
          _messages.addAll(history.map((e) {
            final map = Map<String, dynamic>.from(e as Map);
            if (map['data'] != null) {
              map['data'] = Map<String, dynamic>.from(map['data'] as Map);
            }
            return map;
          }));
        }
        _loading = false;
      });
    }
  }

  Future<void> _saveMessages() async {
    final box = await AppStorage.getGymBox();
    final toSave = _messages.length > 20 ? _messages.sublist(_messages.length - 20) : _messages;
    await box.put('gemini_chat_history', toSave);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send({List<XFile>? imageFiles}) async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty && (imageFiles == null || imageFiles.isEmpty)) return;
    _msgCtrl.clear();

    setState(() {
      _messages.add({
        'isUser': true,
        'text': text.isNotEmpty ? text : '(Attached Images)',
        'hasImage': imageFiles != null && imageFiles.isNotEmpty,
        if (imageFiles != null && imageFiles.isNotEmpty)
          'imagePaths': imageFiles.map((x) => x.path).toList(),
      });
      _thinking = true;
    });
    _saveMessages();
    _scrollToBottom();

    try {
      final prompt = '''
You are a highly capable fitness assistant for "Nudge".
The user will describe their workout session (exercises, cardio, or both).
Extract this information into a structured JSON format.

### Known Exercises for Reference:
${ExerciseDB.allExercises.join(', ')}

### Parsing Rules:
1. Normalize exercise names to match known ones if there's a clear match.
2. For weight, assume kilograms (kg) unless pounds (lbs) is specified.
3. If specific weights aren't mentioned but sets/reps are, use 0.0 for weight.
4. Extract cardio activity, duration in minutes, and distance if provided.
5. Provide a friendly summary in the "note" field.

### Output Format (ONLY JSON):
{
  "exercises": [
    {
      "name": "Exercise Name",
      "sets": [
        {"reps": 10, "weight": 80.0},
        {"reps": 8, "weight": 85.0}
      ]
    }
  ],
  "cardio": [
    {"activity": "Running", "minutes": 20, "distanceKm": 3.5}
  ],
  "note": "Great session! You hit 2 exercises and some cardio."
}

### Previous Chat Context:
${_messages.take(10).map((m) => "${m['isUser'] == true ? 'User' : 'Assistant'}: ${m['text']}").join('\n')}

User Workout Description: "$text"
''';

      List<({String mimeType, Uint8List bytes})>? images;
      if (imageFiles != null && imageFiles.isNotEmpty) {
        images = [];
        for (final f in imageFiles) {
          images.add((mimeType: 'image/jpeg', bytes: await f.readAsBytes()));
        }
      }

      final rawJson = await GeminiService.generate(
        prompt: prompt,
        images: images,
      ) ?? '{}';

      // Extract JSON block from response
      String cleanedJson = rawJson;
      final start = rawJson.indexOf('{');
      final end = rawJson.lastIndexOf('}');
      if (start != -1 && end != -1) {
        cleanedJson = rawJson.substring(start, end + 1);
      }

      final data = jsonDecode(cleanedJson);

      // Auto-create unknown exercises
      if (data['exercises'] != null) {
        final box = await AppStorage.getGymBox();
        final custom = (box.get('custom_exercises', defaultValue: <String>[]) as List).cast<String>();
        bool addedAny = false;
        for (var e in data['exercises']) {
          final name = e['name'] as String;
          final found = ExerciseDB.categories.values.any((l) => l.contains(name)) || custom.contains(name);
          if (!found) {
            custom.add(name);
            addedAny = true;
          }
        }
        if (addedAny) {
          await box.put('custom_exercises', custom);
        }
      }

      setState(() {
        _messages.add({
          'isUser': false,
          'text': data['note'] ?? 'Parsed your workout! Ready to save?',
          'data': data,
          'rawOutput': rawJson,
        });
        _thinking = false;
      });
      _saveMessages();
    } catch (e) {
      debugPrint('Gemini Error: $e');
      setState(() {
        _messages.add({
          'isUser': false,
          'text': 'I had some trouble understanding that. Error: $e',
          'rawOutput': 'Error: $e',
        });
        _thinking = false;
      });
    }
    _scrollToBottom();
  }

  void _save(Map<String, dynamic> data, int messageIndex) {
    if (widget.onSaved != null) {
      widget.onSaved!(data);
    }
    Navigator.of(context).pop(data);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFF030708),
        appBar: AppBar(title: const Text('GEMINI AI'), centerTitle: true),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF))),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF030708),
      appBar: AppBar(
        title: const Text('GEMINI AI'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                final isUser = m['isUser'] == true;
                final data = m['data'] as Map<String, dynamic>?;

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF7C4DFF) : const Color(0xFF111719),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isUser ? 20 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 20),
                      ),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m['text'] as String,
                          style: TextStyle(
                            color: isUser ? Colors.white : Colors.white.withValues(alpha: 0.9),
                            fontWeight: isUser ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        if (m['hasImage'] == true && m['imagePaths'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: (m['imagePaths'] as List).map((p) => ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(File(p as String), height: 100, width: 100, fit: BoxFit.cover),
                              )).toList(),
                            ),
                          ),
                        if (m['rawOutput'] != null) ...[
                          const SizedBox(height: 8),
                          ExpansionTile(
                            title: const Text('View Raw AI Output', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.all(8),
                            collapsedIconColor: Colors.blueGrey,
                            iconColor: Colors.white,
                            children: [
                              SelectableText(
                                m['rawOutput'] as String,
                                style: GoogleFonts.spaceMono(fontSize: 10, color: Colors.white70),
                              ),
                            ],
                          ),
                        ],
                        if (data != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((data['exercises'] as List?)?.isNotEmpty == true) ...[
                                  ...(data['exercises'] as List).map((e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text('• ${e['name']} (${(e['sets'] as List).length} sets)',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  )),
                                ],
                                if ((data['cardio'] as List?)?.isNotEmpty == true) ...[
                                  ...(data['cardio'] as List).map((c) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text('• ${c['activity']} (${c['minutes']} min)',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  )),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Builder(
                            builder: (context) {
                              final isSaved = m['saved'] == true;
                              return SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: isSaved ? null : () => _save(data, i),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: isSaved ? Colors.grey.withValues(alpha: 0.5) : const Color(0xFFB7FF5A),
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: Text(
                                    isSaved ? 'SAVED TO LOGBOOK' : 'SAVE TO LOGBOOK',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_thinking)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C4DFF)),
                  ),
                  const SizedBox(width: 8),
                  Text('Thinking...', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 32),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1520),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () async {
                    final picked = await _picker.pickMultiImage();
                    if (picked.isNotEmpty) {
                      _send(imageFiles: picked);
                    }
                  },
                  icon: const Icon(Icons.image_rounded, color: Colors.white54),
                ),
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 5,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintText: 'Type workout details...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _send(),
                  icon: const Icon(Icons.send_rounded, color: Color(0xFF7C4DFF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
