import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';

/// Packaged-food lookups from Open Food Facts (free, no API key).
/// https://world.openfoodfacts.org/data
class OpenFoodFacts {
  OpenFoodFacts({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _base = 'https://world.openfoodfacts.org';

  // Browsers do not allow setting User-Agent, so only send it on mobile.
  Map<String, String> get _headers =>
      kIsWeb ? const {} : const {'User-Agent': 'WeighWell/0.1 (food scale app)'};

  Future<Food?> byBarcode(String code) async {
    final clean = code.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return null;
    final uri = Uri.parse(
        '$_base/api/v2/product/$clean.json?fields=product_name,brands,nutriments,serving_quantity');
    final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['status'] != 1) return null;
    return parseProduct(body['product'] as Map<String, dynamic>?, barcode: clean);
  }

  Future<List<Food>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];
    final uri = Uri.parse('$_base/cgi/search.pl').replace(queryParameters: {
      'search_terms': q,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page_size': '15',
      'fields': 'product_name,brands,nutriments,serving_quantity,code',
    });
    final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final products = (body['products'] as List?) ?? const [];
    return products
        .whereType<Map<String, dynamic>>()
        .map((p) => parseProduct(p, barcode: p['code'] as String?, source: FoodSource.search))
        .whereType<Food>()
        .toList();
  }

  /// Turns an Open Food Facts product into a [Food], or null if it has no
  /// usable calorie data.
  static Food? parseProduct(Map<String, dynamic>? p,
      {String? barcode, FoodSource source = FoodSource.barcode}) {
    if (p == null) return null;
    final n = (p['nutriments'] as Map?)?.cast<String, dynamic>() ?? const {};
    double? num_(String k) {
      final v = n[k];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    var kcal = num_('energy-kcal_100g');
    final kj = num_('energy_100g') ?? num_('energy-kj_100g');
    if (kcal == null && kj != null) kcal = kj / 4.184;
    if (kcal == null) return null;

    final name = (p['product_name'] as String?)?.trim();
    final brand = (p['brands'] as String?)?.split(',').first.trim();
    final label = (name == null || name.isEmpty) ? 'Packaged food' : name;
    final serving = p['serving_quantity'];

    return Food(
      name: (brand != null && brand.isNotEmpty) ? '$label ($brand)' : label,
      kcalPer100: kcal,
      proteinPer100: num_('proteins_100g') ?? 0,
      carbsPer100: num_('carbohydrates_100g') ?? 0,
      fatPer100: num_('fat_100g') ?? 0,
      category: 'Packaged',
      source: source,
      barcode: barcode,
      typicalServingGrams: serving is num
          ? serving.toDouble()
          : (serving is String ? double.tryParse(serving) : null),
    );
  }
}

/// A guess from the photo recognizer.
class FoodGuess {
  const FoodGuess({required this.food, required this.confidence});
  final Food food;
  final double confidence;
}

/// Sends a food photo to your own backend (see /backend in this repo),
/// which asks a vision AI model what the food is. The API key stays on the
/// server — never put it in the app.
///
/// Set the URL at build time:
///   flutter run --dart-define=RECOGNIZE_URL=https://your-app.vercel.app/api/recognize
class PhotoRecognizer {
  PhotoRecognizer({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const endpoint = String.fromEnvironment('RECOGNIZE_URL');

  bool get isConfigured => endpoint.isNotEmpty;

  Future<List<FoodGuess>> recognize(Uint8List jpegBytes, {String mimeType = 'image/jpeg'}) async {
    if (!isConfigured) {
      throw StateError('Photo recognition is not set up yet.');
    }
    final res = await _client
        .post(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'image': base64Encode(jpegBytes), 'mimeType': mimeType}),
        )
        .timeout(const Duration(seconds: 40));
    if (res.statusCode != 200) {
      throw Exception('Could not read the photo (${res.statusCode}).');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final foods = (body['foods'] as List?) ?? const [];
    return foods.whereType<Map<String, dynamic>>().map((f) {
      return FoodGuess(
        confidence: (f['confidence'] as num? ?? 0.5).toDouble(),
        food: Food(
          name: f['name'] as String? ?? 'Food',
          kcalPer100: (f['kcalPer100'] as num? ?? 0).toDouble(),
          proteinPer100: (f['proteinPer100'] as num? ?? 0).toDouble(),
          carbsPer100: (f['carbsPer100'] as num? ?? 0).toDouble(),
          fatPer100: (f['fatPer100'] as num? ?? 0).toDouble(),
          category: 'Photo',
          source: FoodSource.photo,
          typicalServingGrams: (f['estimatedGrams'] as num?)?.toDouble(),
        ),
      );
    }).toList();
  }
}
