import '../models/product_model.dart';
import 'i_product_service.dart';

/// In-memory product service with 5 real Indian handicraft samples.
///
/// Used when [ApiConfig.useMock] is `true`. Simulates async latency
/// so the UI behaves identically to the real service.
class MockProductService implements IProductService {
  // Internal mutable list — starts with 5 seed products
  final List<Product> _products = [
    const Product(
      id:            'mock_001',
      artisanId:     'artisan_001',
      title:         'Handcrafted Terracotta Chai Kulhad Set',
      description:   'Hand-thrown terracotta kulhads by Radha Devi, fired in traditional wood kiln. '
                     'Earthy aroma enhances every sip. Set of 6 pieces.',
      imageUrl:      'https://images.unsplash.com/photo-1615865417491-9941019fbc00?w=600',
      price:         350,
      stockQuantity: 18,
      category:      'Pottery',
      createdAt:     '2026-09-01',
    ),
    const Product(
      id:            'mock_002',
      artisanId:     'artisan_001',
      title:         'Natural Indigo Dabu Block Print Stole',
      description:   'Hand block-printed stole using natural indigo dye and dabu mud resist technique '
                     'from Bagru, Rajasthan. Each piece is unique.',
      imageUrl:      'https://images.unsplash.com/photo-1607613009820-a29f7bb81c04?w=600',
      price:         890,
      stockQuantity: 12,
      category:      'Textiles',
      createdAt:     '2026-09-02',
    ),
    const Product(
      id:            'mock_003',
      artisanId:     'artisan_001',
      title:         'Madhubani Folk Art Painting on Paper',
      description:   'Traditional Madhubani painting by Meera Kumari depicting peacocks and lotus flowers. '
                     'Handmade paper, natural pigments. Darbhanga, Bihar.',
      imageUrl:      'https://images.unsplash.com/photo-1591085686350-798c0f9faa7f?w=600',
      price:         1200,
      stockQuantity: 5,
      category:      'Painting',
      createdAt:     '2026-09-03',
    ),
    const Product(
      id:            'mock_004',
      artisanId:     'artisan_001',
      title:         'Warli Tribal Tote Bag',
      description:   'Cotton tote bag with Warli tribal art hand-painted by artisans from Dahanu, Maharashtra. '
                     'Natural dyes, eco-friendly.',
      imageUrl:      'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?w=600',
      price:         450,
      stockQuantity: 30,
      category:      'Other',
      createdAt:     '2026-09-04',
    ),
    const Product(
      id:            'mock_005',
      artisanId:     'artisan_001',
      title:         'Dhokra Brass Dokra Elephant',
      description:   'Lost-wax cast brass elephant figurine by tribal artisans from Bastar, Chhattisgarh. '
                     'Each piece is hand-crafted and unique.',
      imageUrl:      'https://images.unsplash.com/photo-1599458252573-56ae36120de1?w=600',
      price:         750,
      stockQuantity: 8,
      category:      'Metal Craft',
      createdAt:     '2026-09-05',
    ),
  ];

  int _idCounter = 100;

  /// Simulated network delay.
  Future<void> _delay() => Future.delayed(const Duration(milliseconds: 400));

  @override
  Future<List<Product>> fetchProducts({String? artisanId}) async {
    await _delay();
    if (artisanId != null && artisanId.isNotEmpty) {
      return _products.where((p) => p.artisanId == artisanId).toList();
    }
    return List.unmodifiable(_products);
  }

  @override
  Future<Product> createProduct(Product product) async {
    await _delay();
    final newId = 'mock_${++_idCounter}';
    final saved = product.copyWith(id: newId, createdAt: DateTime.now().toIso8601String());
    _products.add(saved);
    return saved;
  }

  @override
  Future<Product> updateProduct(String productId, Map<String, dynamic> fields) async {
    await _delay();
    final index = _products.indexWhere((p) => p.id == productId);
    if (index == -1) throw Exception('Product not found: $productId');
    final existing = _products[index];
    final updated = existing.copyWith(
      title:         fields['title']         as String?,
      description:   fields['description']   as String?,
      imageUrl:      fields['image_url']     as String?,
      price:         (fields['price'] as num?)?.toDouble(),
      stockQuantity: (fields['stock_quantity'] as num?)?.toInt(),
      category:      fields['category']      as String?,
    );
    _products[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteProduct(String productId) async {
    await _delay();
    _products.removeWhere((p) => p.id == productId);
  }

  @override
  Future<Product?> getProduct(String productId) async {
    await _delay();
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
  }
}
