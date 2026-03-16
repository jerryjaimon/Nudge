import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/card_model.dart';
import '../providers/app_state.dart';


class WeightCard extends StatelessWidget {
  final TrackerCard card;

  const WeightCard({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    
    // Get last weight
    double currentWeight = card.weightHistory.isNotEmpty ? card.weightHistory.last : 0.0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border(
           bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2), width: 4), // 3D effect
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4B4B4B)),
                  ),
                  Text(
                    "Current: ${currentWeight > 0 ? '$currentWeight kg' : '--'}",
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _buildAddButton(context, appState),
            ],
          ),
          if (card.weightHistory.length > 1) ...[
             const SizedBox(height: 24),
             SizedBox(
               height: 60,
               child: CustomPaint(
                 painter: _SparklinePainter(
                   data: card.weightHistory, 
                   color: Theme.of(context).primaryColor
                 ),
                 size: Size.infinite,
               ),
             )
          ]
        ],
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, AppState appState) {
    return GestureDetector(
      onTap: () {
        _showWeightDialog(context, appState);
      },
      child: Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          borderRadius: BorderRadius.circular(16),
           boxShadow: [
            BoxShadow(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
              blurRadius: 0,
              offset: const Offset(0, 4), // internal 3d effect
            )
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  void _showWeightDialog(BuildContext context, AppState appState) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Log Weight"),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: "kg",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            filled: true,
            fillColor: const Color(0xFFF5F5F7),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null) {
                appState.addWeightEntry(card, val);
                Navigator.pop(ctx);
              }
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    
    double minVal = data.reduce((a, b) => a < b ? a : b);
    double maxVal = data.reduce((a, b) => a > b ? a : b);
    
    if (maxVal == minVal) {
      maxVal += 1;
      minVal -= 1;
    }
    
    final widthStep = size.width / (data.length - 1);
    
    for (int i = 0; i < data.length; i++) {
      final x = i * widthStep;
      // Normalize y to height
      final normalized = (data[i] - minVal) / (maxVal - minVal);
      final y = size.height - (normalized * size.height);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
    
    // Draw dots
    final dotPaint = Paint()..color = color;
    for (int i = 0; i < data.length; i++) {
      final x = i * widthStep;
      final normalized = (data[i] - minVal) / (maxVal - minVal);
      final y = size.height - (normalized * size.height);
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
