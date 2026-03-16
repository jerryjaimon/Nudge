// lib/widgets/water_tracker_card.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../storage.dart';
import '../utils/health_service.dart';
import '../utils/nudge_theme_extension.dart';
import '../app.dart' show NudgeTokens;
import '../screens/health/water_history_screen.dart';

class WaterTrackerCard extends StatefulWidget {
  final VoidCallback? onRefresh;
  const WaterTrackerCard({super.key, this.onRefresh});

  @override
  State<WaterTrackerCard> createState() => _WaterTrackerCardState();
}

class _WaterTrackerCardState extends State<WaterTrackerCard> with TickerProviderStateMixin {
  double _total = 0.0;
  double _goal = 2000.0;
  bool _loading = true;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _loadData();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final water = await HealthService.getTodayWater();
    final goal = AppStorage.settingsBox.get('water_goal', defaultValue: 2000.0) as double;
    if (mounted) {
      setState(() {
        _total = water['total'] ?? 0.0;
        _goal = goal;
        _loading = false;
      });
    }
  }

  Future<void> _addWater(double ml) async {
    await HealthService.addLocalWater(ml);
    await _loadData();
    if (widget.onRefresh != null) widget.onRefresh!();
  }

  void _showHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WaterHistoryScreen()),
    );
  }

  Future<void> _showGoalDialog() async {
    final ctrl = TextEditingController(text: _goal.toInt().toString());
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NudgeTokens.surface,
        title: const Text('Daily Water Goal', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Goal (ml)',
            labelStyle: TextStyle(color: Colors.white70),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final val = double.tryParse(ctrl.text) ?? 2000.0;
              await AppStorage.settingsBox.put('water_goal', val);
              Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    final theme = Theme.of(context).extension<NudgeThemeExtension>()!;
    final progress = (_total / _goal).clamp(0.0, 1.0);
    final color = theme.accentColor ?? NudgeTokens.blue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: theme.cardDecoration(context),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(theme.cardRadius != null ? (theme.cardRadius! / 2).clamp(0, 12) : 12),
                ),
                child: Icon(Icons.water_drop_rounded, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hydration', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: (theme.cardBg == Colors.white) ? Colors.black : Colors.white,
                    )),
                    Text('${_total.toInt()} / ${_goal.toInt()} ml', style: TextStyle(fontSize: 12, color: (theme.cardBg == Colors.white) ? Colors.grey : NudgeTokens.textLow, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showHistory(context),
                icon: Icon(Icons.history_rounded, size: 20, color: (theme.cardBg == Colors.white) ? Colors.grey : NudgeTokens.textLow),
              ),
              IconButton(
                onPressed: _showGoalDialog,
                icon: Icon(Icons.settings_suggest_rounded, size: 20, color: (theme.cardBg == Colors.white) ? Colors.grey : NudgeTokens.textLow),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Bottle Animation
              SizedBox(
                width: 70,
                height: 110,
                child: AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: BottleLiquidPainter(
                        progress: progress,
                        waveValue: _waveController.value,
                        color: color,
                        emptyColor: (theme.cardBg == Colors.white) ? const Color(0xFFF0F0F0) : NudgeTokens.elevated,
                        borderColor: theme.cardBorder ?? (theme.cardBg == Colors.white ? Colors.black.withOpacity(0.1) : NudgeTokens.border),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 24),
              // Controls
              Expanded(
                child: Column(
                  children: [
                    _WaterActionButton(
                      label: '+250ml',
                      icon: Icons.add_rounded,
                      onTap: () => _addWater(250),
                      color: color,
                      theme: theme,
                    ),
                    const SizedBox(height: 12),
                    _WaterActionButton(
                      label: '-250ml',
                      icon: Icons.remove_rounded,
                      onTap: () => _addWater(-250),
                      color: (theme.cardBg == Colors.white) ? Colors.grey : NudgeTokens.textLow,
                      isSmall: true,
                      theme: theme,
                    ),
                    const SizedBox(height: 12),
                    _WaterActionButton(
                      label: '+500ml',
                      icon: Icons.local_drink_rounded,
                      onTap: () => _addWater(500),
                      color: color,
                      theme: theme,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaterActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final bool isSmall;
  final NudgeThemeExtension theme;

  const _WaterActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.color,
    required this.theme,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(theme.cardRadius != null ? (theme.cardRadius! / 2).clamp(0, 16) : 16),
      child: Container(
        height: isSmall ? 36 : 42,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(theme.cardRadius != null ? (theme.cardRadius! / 2).clamp(0, 16) : 16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BottleLiquidPainter extends CustomPainter {
  final double progress;
  final double waveValue;
  final Color color;
  final Color emptyColor;
  final Color borderColor;

  BottleLiquidPainter({
    required this.progress,
    required this.waveValue,
    required this.color,
    required this.emptyColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = emptyColor
      ..style = PaintingStyle.fill;

    // Draw Bottle Shape Background
    final path = Path();
    // Neck
    path.moveTo(size.width * 0.3, 0);
    path.lineTo(size.width * 0.7, 0);
    path.lineTo(size.width * 0.7, size.height * 0.15);
    // Shoulder
    path.quadraticBezierTo(size.width, size.height * 0.2, size.width, size.height * 0.3);
    // Body
    path.lineTo(size.width, size.height - 12);
    path.quadraticBezierTo(size.width, size.height, size.width - 12, size.height);
    path.lineTo(12, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - 12);
    path.lineTo(0, size.height * 0.3);
    path.quadraticBezierTo(0, size.height * 0.2, size.width * 0.3, size.height * 0.15);
    path.close();

    canvas.drawPath(path, paint);

    // Liquid Clip
    canvas.save();
    canvas.clipPath(path);

    if (progress > 0) {
      final liquidPaint = Paint()..color = color;
      final wavePath = Path();
      
      final currentHeight = size.height * (1.0 - progress);
      
      wavePath.moveTo(0, currentHeight);
      for (double i = 0.0; i <= size.width; i++) {
        wavePath.lineTo(
          i,
          currentHeight + math.sin((i / size.width * 2 * math.pi) + (waveValue * 2 * math.pi)) * 4,
        );
      }
      wavePath.lineTo(size.width, size.height);
      wavePath.lineTo(0, size.height);
      wavePath.close();

      canvas.drawPath(wavePath, liquidPaint);
      
      // Top layer of liquid (shiny)
      canvas.drawPath(
        wavePath, 
        Paint()..color = Colors.white.withOpacity(0.3)..style = PaintingStyle.stroke..strokeWidth = 2
      );
    }

    canvas.restore();

    // Outline
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant BottleLiquidPainter oldDelegate) => true;
}

