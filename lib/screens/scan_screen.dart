import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../data/food_database.dart';
import '../models/models.dart';
import '../services/food_lookup.dart';
import '../services/nutrition.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'weigh_screen.dart';

enum ScanMode { photo, barcode, type }

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, this.meal});
  final Meal? meal;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  ScanMode _mode = ScanMode.photo;

  void _weigh(Food food) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WeighScreen(food: food, meal: widget.meal),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Add food', style: TextStyle(fontWeight: w800, fontSize: 22)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
                  child: PillToggle<ScanMode>(
                    options: const {
                      ScanMode.photo: 'Photo',
                      ScanMode.barcode: 'Barcode',
                      ScanMode.type: 'Type name',
                    },
                    value: _mode,
                    onChanged: (m) => setState(() => _mode = m),
                  ),
                ),
                Expanded(
                  child: switch (_mode) {
                    ScanMode.photo => _PhotoTab(onPick: _weigh, onSearchInstead: () => setState(() => _mode = ScanMode.type)),
                    ScanMode.barcode => _BarcodeTab(onPick: _weigh),
                    ScanMode.type => _SearchTab(onPick: _weigh),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Photo

class _PhotoTab extends StatefulWidget {
  const _PhotoTab({required this.onPick, required this.onSearchInstead});
  final ValueChanged<Food> onPick;
  final VoidCallback onSearchInstead;

  @override
  State<_PhotoTab> createState() => _PhotoTabState();
}

class _PhotoTabState extends State<_PhotoTab> {
  Uint8List? _image;
  bool _busy = false;
  String? _error;
  List<FoodGuess> _guesses = [];

  Future<void> _take(ImageSource source) async {
    final recognizer = context.read<PhotoRecognizer>();
    XFile? file;
    try {
      file = await ImagePicker().pickImage(source: source, maxWidth: 1024, imageQuality: 75);
    } catch (e) {
      setState(() => _error = 'Could not open the camera. Check camera permission.');
      return;
    }
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final name = file.name.toLowerCase();
    final mime = file.mimeType ??
        (name.endsWith('.png') ? 'image/png' : name.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
    setState(() {
      _image = bytes;
      _guesses = [];
      _error = null;
      _busy = true;
    });
    if (!recognizer.isConfigured) {
      setState(() {
        _busy = false;
        _error = 'Photo recognition is not switched on in this build. Type the food name instead.';
      });
      return;
    }
    try {
      final guesses = await recognizer.recognize(bytes, mimeType: mime);
      if (!mounted) return;
      setState(() {
        _guesses = guesses;
        _busy = false;
        if (guesses.isEmpty) _error = 'We could not see any food. Try again closer, or type the name.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'We could not read the photo. Check your internet, or type the name.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Container(
            height: 300,
            color: const Color(0xFF2B3A31),
            alignment: Alignment.center,
            child: _image == null
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.restaurant, size: 72, color: Color(0xFF9FC2AE)),
                      SizedBox(height: 12),
                      Text('Take a photo of your plate',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: w700)),
                    ],
                  )
                : Image.memory(_image!, fit: BoxFit.cover, width: double.infinity, height: 300),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _busy ? null : () => _take(ImageSource.camera),
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(_image == null ? 'Take a photo' : 'Take another photo'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _take(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(kIsWeb ? 'Upload a photo' : 'Choose from my photos'),
        ),
        const SizedBox(height: 18),
        if (_busy)
          const Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text('Looking at your food…', style: TextStyle(fontSize: 17, fontWeight: w700)),
            ],
          ),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(fontSize: 16, color: Color(0xFF8A3A0B), fontWeight: w700)),
          const SizedBox(height: 8),
          TextButton(onPressed: widget.onSearchInstead, child: const Text('Type the food name', style: TextStyle(fontSize: 17, fontWeight: w800))),
        ],
        if (_guesses.isNotEmpty) ...[
          const Text('We found', style: TextStyle(fontSize: 15, color: AppColors.muted, fontWeight: w700)),
          const SizedBox(height: 8),
          for (final g in _guesses) ...[
            _FoodResultTile(food: g.food, onTap: () => widget.onPick(g.food), cta: 'Yes, weigh it'),
            const SizedBox(height: 8),
          ],
          TextButton(onPressed: widget.onSearchInstead, child: const Text('Not right? Type the name', style: TextStyle(fontSize: 17, fontWeight: w800))),
        ],
      ],
    );
  }
}

// -------------------------------------------------------------- Barcode

class _BarcodeTab extends StatefulWidget {
  const _BarcodeTab({required this.onPick});
  final ValueChanged<Food> onPick;

  @override
  State<_BarcodeTab> createState() => _BarcodeTabState();
}

class _BarcodeTabState extends State<_BarcodeTab> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE],
  );
  final _typed = TextEditingController();
  String? _lastCode;
  bool _busy = false;
  Food? _found;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _typed.dispose();
    super.dispose();
  }

  Future<void> _lookup(String code) async {
    if (_busy || code == _lastCode && _found != null) return;
    final off = context.read<OpenFoodFacts>();
    final mine = context.read<AppState>().myFoods;
    setState(() {
      _busy = true;
      _error = null;
      _found = null;
      _lastCode = code;
    });
    // Check foods we saved before (works offline).
    final saved = mine.where((f) => f.barcode == code).firstOrNull;
    if (saved != null) {
      setState(() {
        _busy = false;
        _found = saved;
      });
      return;
    }
    try {
      final food = await off.byBarcode(code);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _found = food;
        if (food == null) _error = 'We do not know this product yet. Try "Type name".';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No internet connection. Try again or type the name.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            height: 280,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    final code = capture.barcodes.firstOrNull?.rawValue;
                    if (code != null) _lookup(code);
                  },
                ),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 250,
                      height: 130,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF7FE0A8), width: 3),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 14,
                  child: Text('Point at the barcode',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: w700, shadows: [Shadow(blurRadius: 6)])),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _typed,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(labelText: 'Or type the barcode number'),
                onSubmitted: _lookup,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 56,
              child: OutlinedButton(onPressed: () => _lookup(_typed.text), child: const Text('Find')),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_busy) const Center(child: CircularProgressIndicator()),
        if (_error != null)
          Text(_error!, style: const TextStyle(fontSize: 16, color: Color(0xFF8A3A0B), fontWeight: w700)),
        if (_found != null) ...[
          const Text('We found', style: TextStyle(fontSize: 15, color: AppColors.muted, fontWeight: w700)),
          const SizedBox(height: 8),
          _FoodResultTile(food: _found!, onTap: () => widget.onPick(_found!), cta: 'Yes, weigh it'),
        ],
      ],
    );
  }
}

// --------------------------------------------------------------- Search

class _SearchTab extends StatefulWidget {
  const _SearchTab({required this.onPick});
  final ValueChanged<Food> onPick;

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  final _q = TextEditingController();
  List<Food> _online = [];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _searchOnline() async {
    final off = context.read<OpenFoodFacts>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await off.search(_q.text);
      if (!mounted) return;
      setState(() {
        _online = r;
        _busy = false;
        if (r.isEmpty) _error = 'Nothing found online.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No internet connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = context.watch<AppState>().myFoods;
    final local = searchBuiltIn(_q.text, extra: mine).take(30).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: TextField(
            controller: _q,
            autofocus: true,
            style: const TextStyle(fontSize: 18),
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'e.g. banana, rice, paneer',
            ),
            onChanged: (_) => setState(() => _online = []),
            onSubmitted: (_) => local.isEmpty ? _searchOnline() : null,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            children: [
              for (final f in local) ...[
                _FoodResultTile(food: f, onTap: () => widget.onPick(f)),
                const SizedBox(height: 8),
              ],
              if (_q.text.trim().length >= 2) ...[
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _searchOnline,
                  icon: const Icon(Icons.public),
                  label: const Text('Search packaged foods online'),
                ),
                const SizedBox(height: 10),
              ],
              if (_busy) const Center(child: CircularProgressIndicator()),
              if (_error != null) Text(_error!, style: const TextStyle(fontSize: 16, fontWeight: w700)),
              for (final f in _online) ...[
                _FoodResultTile(food: f, onTap: () => widget.onPick(f)),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FoodResultTile extends StatelessWidget {
  const _FoodResultTile({required this.food, required this.onTap, this.cta});
  final Food food;
  final VoidCallback onTap;
  final String? cta;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(food.name, style: const TextStyle(fontSize: 19, fontWeight: w800)),
                        Text(
                          '${food.category} · ${fmtInt(food.kcalPer100)} kcal · ${fmt1(food.proteinPer100)} g protein per 100 g',
                          style: const TextStyle(fontSize: 15, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  if (cta == null) const Icon(Icons.chevron_right, color: AppColors.muted, size: 28),
                ],
              ),
              if (cta != null) ...[
                const SizedBox(height: 12),
                FilledButton(onPressed: onTap, child: Text(cta!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
