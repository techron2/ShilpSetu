import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../services/i_product_service.dart';
import '../services/product_service_factory.dart';

/// Holds the product list and coordinates all product operations.
///
/// Exposes:
/// - [products] — current list of loaded products
/// - [isLoading] — true while a network/mock call is in progress
/// - [errorMessage] — non-null when the last operation failed
class ProductProvider extends ChangeNotifier {
  final IProductService _service = ProductServiceFactory.create();

  List<Product> _products   = [];
  bool          _isLoading  = false;
  String?       _errorMessage;

  // ── Getters ──────────────────────────────────────────────────────────────
  List<Product> get products     => List.unmodifiable(_products);
  bool          get isLoading    => _isLoading;
  String?       get errorMessage => _errorMessage;

  void _setLoading(bool v) { _isLoading = v; notifyListeners(); }
  void _setError(String? v) { _errorMessage = v; notifyListeners(); }
  void clearError() { _errorMessage = null; notifyListeners(); }

  // ── Fetch ────────────────────────────────────────────────────────────────

  /// Load (or reload) the product list.
  ///
  /// Pass [artisanId] to filter to only that artisan's products.
  Future<void> fetchProducts({String? artisanId}) async {
    _setLoading(true);
    _setError(null);
    try {
      _products = await _service.fetchProducts(artisanId: artisanId);
    } catch (e) {
      _setError('Could not load products: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ── Create ───────────────────────────────────────────────────────────────

  /// Add a new product. Optimistically inserts it; removes on failure.
  Future<bool> addProduct(Product product) async {
    _setLoading(true);
    _setError(null);
    try {
      final saved = await _service.createProduct(product);
      _products = [saved, ..._products];
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Could not add product: $e');
      _setLoading(false);
      return false;
    }
  }

  // ── Update ───────────────────────────────────────────────────────────────

  /// Update a product's fields in place.
  Future<bool> updateProduct(String productId, Map<String, dynamic> fields) async {
    _setLoading(true);
    _setError(null);
    try {
      final updated = await _service.updateProduct(productId, fields);
      _products = _products.map((p) => p.id == productId ? updated : p).toList();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Could not update product: $e');
      _setLoading(false);
      return false;
    }
  }

  // ── Delete ───────────────────────────────────────────────────────────────

  /// Remove a product from the list and backend.
  Future<bool> deleteProduct(String productId) async {
    _setLoading(true);
    _setError(null);
    try {
      await _service.deleteProduct(productId);
      _products = _products.where((p) => p.id != productId).toList();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Could not delete product: $e');
      _setLoading(false);
      return false;
    }
  }
}
