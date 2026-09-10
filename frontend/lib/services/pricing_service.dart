import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class PricingService {
  final String baseUrl;

  PricingService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  /// Canonical KalaVistar categories + legacy aliases, mirroring
  /// backend/services/categories.py so offline fallback prices resolve
  /// against the right craft profile instead of the generic formula.
  static String canonicalCategory(String category) {
    const canonical = {
      'textiles': 'Textiles',
      'pottery': 'Pottery',
      'jewellery': 'Jewellery',
      'embroidery': 'Embroidery',
      'wood craft': 'Wood Craft',
      'leather': 'Leather',
      'painting': 'Painting',
      'metal craft': 'Metal Craft',
      'other': 'Other',
    };
    const aliases = {
      'jewelry': 'Jewellery',
      'woodwork': 'Wood Craft',
      'metalwork': 'Metal Craft',
      'accessories': 'Other',
      'accessory': 'Other',
      'stonework': 'Other',
      'basketry': 'Other',
    };
    final key = category.trim().toLowerCase();
    if (key.isEmpty) return 'Other';
    return canonical[key] ?? aliases[key] ?? category.trim();
  }

  /// Calls POST /api/pricing/suggest to get ML-predicted fair-trade craft prices.
  Future<Map<String, dynamic>> suggestPrice({
    required String category,
    double? materialCost,
    String size = 'medium',
    String region = 'Uttar Pradesh',
  }) async {
    if (ApiConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 600));
      return _mockPriceSuggestion(category, size);
    }

    try {
      final uri = Uri.parse('$baseUrl/api/pricing/suggest');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'category': category,
          'material_cost': materialCost,
          'size': size,
          'region': region,
        }),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      } else {
        debugPrint('Pricing API returned status ${resp.statusCode}: ${resp.body}');
        return _mockPriceSuggestion(category, size, materialCost: materialCost, region: region);
      }
    } catch (e) {
      debugPrint('Error calling /api/pricing/suggest: $e');
      return _mockPriceSuggestion(category, size, materialCost: materialCost, region: region);
    }
  }

  Map<String, dynamic> _mockPriceSuggestion(
    String category,
    String size, {
    double? materialCost,
    String region = 'Uttar Pradesh',
  }) {
    final basePrices = {
      'Pottery': 320,
      'Textiles': 850,
      'Painting': 650,
      'Metal Craft': 1250,
      'Wood Craft': 750,
      'Jewellery': 450,
      'Embroidery': 550,
      'Leather': 950,
      'Other': 400,
    };
    category = canonicalCategory(category);
    final mult = size == 'small' ? 0.9 : (size == 'large' ? 1.8 : 1.3);
    final effectiveMaterialCost = materialCost ?? 60.0;
    final base = (basePrices[category] ?? (effectiveMaterialCost * 2.8)) * mult;
    final suggested = (base / 10).round() * 10;
    final min = (suggested * 0.85 / 10).round() * 10;
    final max = (suggested * 1.18 / 10).round() * 10;

    return {
      'success': true,
      'suggested_price': suggested,
      'price_range_min': min,
      'price_range_max': max,
      'currency': 'INR',
      'category': category,
      'size': size,
      'region': region,
      'material_cost': effectiveMaterialCost,
      'explanation': '$region में $category शिल्प के $size आकार और ₹${effectiveMaterialCost.toInt()} की सामग्री लागत के आधार पर ₹$suggested का निष्पक्ष मूल्य निर्धारित किया गया है।',
    };
  }
}
