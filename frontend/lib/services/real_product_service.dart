import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/product_model.dart';
import 'i_product_service.dart';

/// Calls the real Flask backend at [ApiConfig.baseUrl].
///
/// Used when [ApiConfig.useMock] is `false`.
class RealProductService implements IProductService {
  final String _base = ApiConfig.baseUrl;

  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  void _checkStatus(http.Response res, String action) {
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception('$action failed (${res.statusCode}): ${body['error'] ?? res.body}');
    }
  }

  @override
  Future<List<Product>> fetchProducts({String? artisanId}) async {
    final uri = Uri.parse('$_base/api/products').replace(
      queryParameters: artisanId != null ? {'artisan_id': artisanId} : null,
    );
    final res = await http.get(uri, headers: _headers);
    _checkStatus(res, 'fetchProducts');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['products'] as List<dynamic>;
    return list.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<Product> createProduct(Product product) async {
    final res = await http.post(
      Uri.parse('$_base/api/products'),
      headers: _headers,
      body: jsonEncode(product.toJson()),
    );
    _checkStatus(res, 'createProduct');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return Product.fromJson(body['product'] as Map<String, dynamic>);
  }

  @override
  Future<Product> updateProduct(String productId, Map<String, dynamic> fields) async {
    final res = await http.put(
      Uri.parse('$_base/api/products/$productId'),
      headers: _headers,
      body: jsonEncode(fields),
    );
    _checkStatus(res, 'updateProduct');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return Product.fromJson(body['product'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteProduct(String productId) async {
    final res = await http.delete(
      Uri.parse('$_base/api/products/$productId'),
      headers: _headers,
    );
    _checkStatus(res, 'deleteProduct');
  }

  @override
  Future<Product?> getProduct(String productId) async {
    final res = await http.get(
      Uri.parse('$_base/api/products/$productId'),
      headers: _headers,
    );
    if (res.statusCode == 404) return null;
    _checkStatus(res, 'getProduct');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return Product.fromJson(body['product'] as Map<String, dynamic>);
  }
}
