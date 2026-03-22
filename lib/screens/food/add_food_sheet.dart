import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../app.dart' show NudgeTokens;
import '../../utils/food_service.dart';
import 'dart:async';
import 'package:nudge/utils/nudge_theme_extension.dart';
import 'meal_selector.dart';

class AddFoodSheet extends StatefulWidget {
  final String? initialMeal;
  final String? initialDescription;
  const AddFoodSheet({super.key, this.initialMeal, this.initialDescription});

  @override
  State<AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<AddFoodSheet> {
  final _ctrl = TextEditingController();
  bool _isParsing = false;
  List<Map<String, dynamic>>? _parsedItems;
  File? _image;

  Timer? _searchDebounce;
  List<Map<String, dynamic>> _searchResults = [];
  String _selectedMeal = 'Lunch';
  List<Map<String, dynamic>> _mealTemplates = [];
  bool _showTemplates = false;
  bool _fromTemplate = false;

  String _getInitialMeal() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Breakfast';
    if (hour < 16) return 'Lunch';
    if (hour < 21) return 'Dinner';
    return 'Snack';
  }

  @override
  void initState() {
    super.initState();
    _selectedMeal = widget.initialMeal ?? _getInitialMeal();
    _ctrl.addListener(_onSearchChanged);
    _loadInitialHistory();
    _loadTemplates();
    if (widget.initialDescription != null && widget.initialDescription!.isNotEmpty) {
      _ctrl.text = widget.initialDescription!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _parseText());
    }
  }

  Future<void> _loadInitialHistory() async {
    final results = await FoodService.searchLibrary('');
    if (mounted) setState(() => _searchResults = results);
  }

  Future<void> _loadTemplates() async {
    final templates = await FoodService.getMealTemplates();
    if (mounted) setState(() => _mealTemplates = templates);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final query = _ctrl.text;
      final results = await FoodService.searchLibrary(query);
      if (mounted) setState(() => _searchResults = results);
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked != null) {
      setState(() {
        _image = File(picked.path);
        _isParsing = true;
        _parsedItems = null;
        _searchResults = [];
      });

      final bytes = await _image!.readAsBytes();
      final data = await FoodService.parseFoodImage(bytes);

      if (mounted) {
        setState(() {
          _isParsing = false;
          _parsedItems = data;
          if (data != null && data.isNotEmpty) {
            _ctrl.text = data.map((e) => e['name']).join(', ');
          }
        });
      }
    }
  }

  Future<void> _scanBarcode() async {
    final barcode = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _BarcodeScannerSheet(),
    );
    if (barcode == null || !mounted) return;
    debugPrint('[Barcode] Scanned value: $barcode');

    setState(() { _isParsing = true; _parsedItems = null; _searchResults = []; _fromTemplate = false; });

    String? snackMessage;
    try {
      final data = await FoodService.lookupBarcode(barcode);
      if (!mounted) return;
      if (data != null) {
        setState(() {
          _isParsing = false;
          _parsedItems = [data];
          _ctrl.text = data['name'] as String? ?? '';
        });
        return;
      }
      snackMessage = 'Product not found ($barcode). Try describing it manually.';
    } on TimeoutException {
      snackMessage = 'Network timeout — check your connection and try again.';
    } catch (e) {
      snackMessage = 'Lookup failed: $e';
    }

    if (mounted) {
      setState(() { _isParsing = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(snackMessage),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _parseText() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isParsing = true;
      _parsedItems = null;
      _searchResults = [];
    });

    final data = await FoodService.parseFoodDescription(text);

    if (mounted) setState(() { _isParsing = false; _parsedItems = data; });
  }

  void _addFromSearch(Map<String, dynamic> item) {
    setState(() {
      _parsedItems = [
        {...item, 'servingsConsumed': 1.0, 'mealType': _selectedMeal}
      ];
      _searchResults = [];
      _ctrl.text = item['name'];
    });
  }

  void _loadTemplate(Map<String, dynamic> template) {
    final items = (template['items'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final mealType = (template['mealType'] as String?) ?? _selectedMeal;
    setState(() {
      _parsedItems = items;
      _showTemplates = false;
      _fromTemplate = true;
      _selectedMeal = mealType;
      _ctrl.text = (template['name'] as String?) ?? '';
    });
  }

  Future<void> _saveAsTemplate() async {
    if (_parsedItems == null || _parsedItems!.isEmpty) return;
    final ctrl = TextEditingController(text: '$_selectedMeal Meal');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NudgeTokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Save Meal Template', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: NudgeTokens.textHigh)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Template name (e.g. My Breakfast)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: NudgeTokens.foodB),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await FoodService.saveMealTemplate(name, _selectedMeal, _parsedItems!);
    await _loadTemplates();
    messenger.showSnackBar(SnackBar(content: Text('"$name" saved as template.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<NudgeThemeExtension>();
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: theme?.cardBg ?? NudgeTokens.elevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            children: [
              Text(
                'Log Food',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: theme?.textColor ?? NudgeTokens.textHigh,
                ),
              ),
              const Spacer(),
              _IconButton(
                icon: Icons.qr_code_scanner_rounded,
                onTap: _scanBarcode,
              ),
              const SizedBox(width: 8),
              _IconButton(
                icon: Icons.camera_alt_rounded,
                onTap: () => _pickImage(ImageSource.camera),
              ),
              const SizedBox(width: 8),
              _IconButton(
                icon: Icons.photo_library_rounded,
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              const SizedBox(width: 8),
              _IconButton(
                icon: Icons.restaurant_menu_rounded,
                onTap: () => setState(() => _showTemplates = !_showTemplates),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_image != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(_image!, height: 120, width: double.infinity, fit: BoxFit.cover),
              ),
            ),
          TextField(
            controller: _ctrl,
            autofocus: true,
            style: TextStyle(color: theme?.textColor ?? NudgeTokens.textHigh),
            decoration: InputDecoration(
              hintText: 'Search or describe a meal...',
              hintStyle: const TextStyle(color: NudgeTokens.textLow),
              filled: true,
              fillColor: NudgeTokens.elevated,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: NudgeTokens.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: NudgeTokens.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: NudgeTokens.foodB.withValues(alpha: 0.6)),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.auto_awesome_rounded, color: NudgeTokens.foodB),
                tooltip: 'Analyse with Gemini',
                onPressed: _parseText,
              ),
            ),
            onSubmitted: (_) => _parseText(),
          ),
          const SizedBox(height: 12),
          Center(child: MealSelector(selected: _selectedMeal, onSelected: (v) => setState(() => _selectedMeal = v))),
          const SizedBox(height: 12),
          
          // Meal templates panel
          if (_showTemplates && _mealTemplates.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: theme?.cardBg ?? NudgeTokens.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NudgeTokens.foodB.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: Text('SAVED MEAL TEMPLATES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: NudgeTokens.textLow, letterSpacing: 1.2)),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _mealTemplates.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: NudgeTokens.border),
                      itemBuilder: (ctx, i) {
                        final t = _mealTemplates[i];
                        final count = (t['items'] as List?)?.length ?? 0;
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.restaurant_menu_rounded, color: NudgeTokens.foodB, size: 20),
                          title: Text(t['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, color: theme?.textColor)),
                          subtitle: Text('$count item${count == 1 ? '' : 's'} · ${t['mealType'] ?? ''}', style: const TextStyle(fontSize: 10, color: NudgeTokens.textLow)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_circle_outline_rounded, color: NudgeTokens.foodB, size: 18),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () async {
                                  await FoodService.deleteMealTemplate(t['name'] ?? '');
                                  _loadTemplates();
                                },
                                child: const Icon(Icons.delete_outline_rounded, color: NudgeTokens.textLow, size: 18),
                              ),
                            ],
                          ),
                          onTap: () => _loadTemplate(t),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          if (_parsedItems == null && !_isParsing)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: theme?.cardBg ?? NudgeTokens.card,
                borderRadius: BorderRadius.circular(12),
                border: theme?.cardDecoration(context).border ?? Border.all(color: NudgeTokens.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_ctrl.text.isEmpty && _searchResults.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text('RECENT SEARCHES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: NudgeTokens.textLow, letterSpacing: 1.2)),
                    ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: NudgeTokens.border),
                      itemBuilder: (context, index) {
                        final item = _searchResults[index];
                        final c = (item['caloriesPerServing'] ?? item['calories'] ?? 0).toInt();
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.menu_book_rounded, color: NudgeTokens.foodB, size: 20),
                          title: Text(item['name'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.w600, color: theme?.textColor)),
                          subtitle: const Text('From your library', style: TextStyle(fontSize: 10, color: NudgeTokens.textLow)),
                          trailing: Text('$c kcal', style: const TextStyle(color: NudgeTokens.textLow)),
                          onTap: () => _addFromSearch(item),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),
          if (_isParsing)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(NudgeTokens.foodB)),
                    SizedBox(height: 12),
                    Text('Gemini is analyzing...', style: TextStyle(color: NudgeTokens.textLow)),
                  ],
                ),
              ),
            )
          else if (_parsedItems != null && _parsedItems!.isNotEmpty) ...[
            if (_fromTemplate)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.edit_note_rounded, size: 14, color: NudgeTokens.textLow),
                    SizedBox(width: 4),
                    Text('Tap values to edit · swipe or tap × to remove',
                        style: TextStyle(fontSize: 11, color: NudgeTokens.textLow)),
                  ],
                ),
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _parsedItems!.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _ParsedItemCard(
                    data: _parsedItems![index],
                    onServingsChanged: (val) {
                      setState(() => _parsedItems![index]['servingsConsumed'] = val);
                    },
                    onDelete: () => setState(() => _parsedItems!.removeAt(index)),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_parsedItems!.length > 1) ...[
                  OutlinedButton.icon(
                    onPressed: _saveAsTemplate,
                    icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                    label: const Text('Save Meal'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: NudgeTokens.foodB,
                      side: const BorderSide(color: NudgeTokens.foodB),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      final nav = Navigator.of(context);
                      for (var item in _parsedItems!) {
                        await FoodService.saveEntry({...item, 'mealType': _selectedMeal});
                      }
                      nav.pop();
                    },
                    style: FilledButton.styleFrom(backgroundColor: NudgeTokens.foodB),
                    child: Text('Confirm & Save${_parsedItems!.length > 1 ? ' All (${_parsedItems!.length})' : ''}'),
                  ),
                ),
              ],
            ),
          ],
        ],
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<NudgeThemeExtension>();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme?.cardBg ?? NudgeTokens.card,
          borderRadius: BorderRadius.circular(12),
          border: theme?.cardDecoration(context).border ?? Border.all(color: NudgeTokens.border),
        ),
        child: Icon(icon, color: NudgeTokens.foodB, size: 20),
      ),
    );
  }
}

class _ParsedItemCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final ValueChanged<double> onServingsChanged;
  final VoidCallback? onDelete;

  const _ParsedItemCard({required this.data, required this.onServingsChanged, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final servings = (data['servingsConsumed'] as num?)?.toDouble() ?? 1.0;
    
    final baseCal = ((data['caloriesPerServing'] ?? data['calories'] ?? 0) as num).toDouble();
    final baseP = ((data['proteinPerServing'] ?? data['protein'] ?? 0) as num).toDouble();
    final baseC = ((data['carbsPerServing'] ?? data['carbs'] ?? 0) as num).toDouble();
    final baseF = ((data['fatPerServing'] ?? data['fat'] ?? 0) as num).toDouble();

    final cal = baseCal * servings;
    final p = baseP * servings;
    final c = baseC * servings;
    final f = baseF * servings;

    final theme = Theme.of(context).extension<NudgeThemeExtension>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme?.cardBg ?? NudgeTokens.card,
        borderRadius: BorderRadius.circular(16),
        border: theme?.cardDecoration(context).border ?? Border.all(color: NudgeTokens.foodB.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _editField(context, 'name', data['name'] ?? '', (val) => onServingsChanged(servings)),
                  child: Text(
                    data['name'] ?? 'Unknown',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme?.textColor ?? NudgeTokens.textHigh,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Row(
                children: [
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: NudgeTokens.textLow, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Remove',
                      onPressed: onDelete,
                    ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: NudgeTokens.textLow),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: servings > 0.5 ? () => onServingsChanged(servings - 0.5) : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${servings == servings.toInt() ? servings.toInt() : servings}x',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: theme?.textColor),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: NudgeTokens.textLow),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => onServingsChanged(servings + 0.5),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _editField(context, 'caloriesPerServing', baseCal.toString(), (val) {
              data['caloriesPerServing'] = double.tryParse(val) ?? 0.0;
              onServingsChanged(servings);
            }),
            child: Text(
              '${cal.toInt()} kcal',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: NudgeTokens.foodB,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MacroCol(
                label: 'PROTEIN', 
                value: '${p.toInt()}g', 
                color: Colors.blue,
                onTap: () => _editField(context, 'proteinPerServing', baseP.toString(), (val) {
                  data['proteinPerServing'] = double.tryParse(val) ?? 0.0;
                  onServingsChanged(servings);
                }),
              ),
              _MacroCol(
                label: 'CARBS', 
                value: '${c.toInt()}g', 
                color: Colors.green,
                onTap: () => _editField(context, 'carbsPerServing', baseC.toString(), (val) {
                  data['carbsPerServing'] = double.tryParse(val) ?? 0.0;
                  onServingsChanged(servings);
                }),
              ),
              _MacroCol(
                label: 'FAT', 
                value: '${f.toInt()}g', 
                color: Colors.orange,
                onTap: () => _editField(context, 'fatPerServing', baseF.toString(), (val) {
                  data['fatPerServing'] = double.tryParse(val) ?? 0.0;
                  onServingsChanged(servings);
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _editField(BuildContext context, String field, String currentVal, Function(String) onSave) {
    final ctrl = TextEditingController(text: currentVal);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${field.replaceAll('PerServing', '')}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: field == 'name' ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: 'Enter new value'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (field == 'name') data['name'] = ctrl.text;
              onSave(ctrl.text);
              Navigator.pop(ctx);
            }, 
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _MacroCol extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _MacroCol({required this.label, required this.value, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<NudgeThemeExtension>();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: theme?.textColor ?? NudgeTokens.textHigh,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Barcode Scanner Sheet ─────────────────────────────────────────────────────

class _BarcodeScannerSheet extends StatefulWidget {
  const _BarcodeScannerSheet();

  @override
  State<_BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<_BarcodeScannerSheet> {
  bool _scanned = false;
  String? _cameraError;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.55,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: _cameraError != null
                ? Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.no_photography_rounded,
                              color: Colors.white54, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            _cameraError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Go to Settings → Apps → Nudge → Permissions → Camera',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  )
                : MobileScanner(
                    onDetect: (capture) {
                      if (_scanned) return;
                      final barcode = capture.barcodes.firstOrNull;
                      final value = barcode?.rawValue;
                      debugPrint('[Barcode] Detected ${capture.barcodes.length} barcode(s). First format=${barcode?.format} rawValue=$value');
                      if (value != null && value.isNotEmpty) {
                        _scanned = true;
                        Navigator.pop(context, value);
                      }
                    },
                    errorBuilder: (context, error, child) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() => _cameraError =
                              'Camera error: ${error.errorCode.name}. '
                              'Check camera permission.');
                        }
                      });
                      return const SizedBox.expand(
                          child: ColoredBox(color: Colors.black));
                    },
                  ),
          ),
          // Overlay UI
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Point camera at barcode',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
          ),
          // Scan frame
          Center(
            child: Container(
              width: 240,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: NudgeTokens.foodB, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
