// lib/screens/gym/profile_sheet.dart
import 'package:flutter/material.dart';

class ProfileSheet extends StatefulWidget {
  final double weightKg;
  final double heightCm;

  const ProfileSheet({
    super.key,
    required this.weightKg,
    required this.heightCm,
  });

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  late final TextEditingController _wCtrl;
  late final TextEditingController _hCtrl;

  @override
  void initState() {
    super.initState();
    _wCtrl = TextEditingController(text: widget.weightKg.toStringAsFixed(1));
    _hCtrl = TextEditingController(text: widget.heightCm.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _wCtrl.dispose();
    _hCtrl.dispose();
    super.dispose();
  }

  void _done() {
    final w = double.tryParse(_wCtrl.text.trim()) ?? widget.weightKg;
    final h = double.tryParse(_hCtrl.text.trim()) ?? widget.heightCm;

    Navigator.of(context).pop(<String, dynamic>{
      'weightKg': w.clamp(20, 250),
      'heightCm': h.clamp(100, 230),
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 14 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Spacer(),
                  TextButton(onPressed: _done, child: const Text('Done')),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _wCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Weight (kg)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _hCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Height (cm)'),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
