import '../models/product_model.dart';

/// Abstract interface for product data operations.
///
/// Both [MockProductService] and [RealProductService] implement this,
/// allowing the app to swap between them via [ApiConfig.useMock].
abstract class IProductService {
  /// Fetch all products. Pass [artisanId] to filter by artisan.
  Future<List<Product>> fetchProducts({String? artisanId});

  /// Create a new product. Returns the saved [Product] with its assigned id.
  Future<Product> createProduct(Product product);

  /// Update an existing product. Returns the updated [Product].
  Future<Product> updateProduct(String productId, Map<String, dynamic> fields);

  /// Delete a product by id.
  Future<void> deleteProduct(String productId);

  /// Fetch a single product by id.
  Future<Product?> getProduct(String productId);
}
