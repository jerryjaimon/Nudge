import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/card_model.dart';
import '../providers/app_state.dart';
import 'dart:async';

class TimeCard extends StatefulWidget {
  final TrackerCard card;

  const TimeCard({super.key, required this.card});

  @override
  State<TimeCard> createState() => _TimeCardState();
}

class _TimeCardState extends State<TimeCard> {
  Timer? _timer;
  bool _isRunning = false;
  int _sessionSeconds = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    setState(() {
      if (_isRunning) {
        _stopTimer();
      } else {
        _startTimer();
      }
    });
  }

  void _startTimer() {
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _sessionSeconds++;
      });
    });
  }

  void _stopTimer() {
    _isRunning = false;
    _timer?.cancel();
    
    // Save to AppState
    final appState = Provider.of<AppState>(context, listen: false);
    appState.addTimeEntry(widget.card, _sessionSeconds);
    
    setState(() {
      _sessionSeconds = 0;
    });
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final totalSeconds = widget.card.durationSeconds + (_isRunning ? _sessionSeconds : 0);

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
              widget.card.iconCodePoint != null
                ? Icon(IconData(widget.card.iconCodePoint!, fontFamily: 'MaterialIcons'), size: 32, color: Theme.of(context).primaryColor)
                : Text(widget.card.emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.card.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4B4B4B)),
                  ),
                  Text(
                    _formatDuration(totalSeconds),
                    style: const TextStyle(
                      fontSize: 24, 
                      fontFamily: 'Monospace', 
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF9600), // Orange
                    ),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: _toggleTimer,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    color: _isRunning ? const Color(0xFFFF4B4B) : const Color(0xFF58CC02),
                    shape: BoxShape.circle,
                     boxShadow: [
                      BoxShadow(
                        color: (_isRunning ? const Color(0xFFFF4B4B) : const Color(0xFF58CC02)).withValues(alpha: 0.4),
                        blurRadius: 0,
                        offset: const Offset(0, 4),
                      )
                    ]
                  ),
                  child: Icon(
                    _isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    color: Colors.white, 
                    size: 32
                  ),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}
