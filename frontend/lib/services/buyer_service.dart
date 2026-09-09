import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/order_model.dart';
import '../models/rfq_model.dart';

/// Service layer for all buyer-facing API calls.
/// Talks to the Phase 4 Flask endpoints.
class BuyerService {
  BuyerService._();
  static final BuyerService instance = BuyerService._();

  // ── Product Search ─────────────────────────────────────────────────────────

  /// Search products by keyword, category, and/or price range.
  /// Returns the raw product list as List<Map>.
  Future<List<Map<String, dynamic>>> searchProducts({
    String query = '',
    String category = '',
    double? minPrice,
    double? maxPrice,
    int limit = 50,
  }) async {
    final params = <String, String>{};
    if (query.isNotEmpty)    params['query']     = query;
    if (category.isNotEmpty) params['category']  = category;
    if (minPrice != null)    params['min_price'] = minPrice.toString();
    if (maxPrice != null)    params['max_price'] = maxPrice.toString();
    params['limit'] = limit.toString();

    final uri = Uri.parse(ApiConfig.productSearch).replace(queryParameters: params);
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body['success'] == true) {
        return List<Map<String, dynamic>>.from(body['products'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── Buyer-Supplier Matching ────────────────────────────────────────────────

  /// Returns a ranked list of matched artisans/products via cosine similarity.
  Future<List<Map<String, dynamic>>> matchSuppliers({
    required String category,
    required int quantity,
    required double budget,
    String region = '',
  }) async {
    try {
      final resp = await http.post(
        Uri.parse(ApiConfig.matching),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'category': category,
          'quantity': quantity,
          'budget':   budget,
          'region':   region,
        }),
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body['success'] == true) {
        return List<Map<String, dynamic>>.from(body['matches'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── RFQ ───────────────────────────────────────────────────────────────────

  /// Parse free-text buyer requirement into a structured RFQ via Gemini API.
  Future<Map<String, dynamic>?> createRfq({
    required String buyerId,
    required String requirementText,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse(ApiConfig.rfq),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'buyer_id':         buyerId,
          'requirement_text': requirementText,
        }),
      ).timeout(const Duration(seconds: 25));
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body['success'] == true) {
        return body['rfq'] as Map<String, dynamic>?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetch all RFQs for a buyer.
  Future<List<RfqModel>> getBuyerRfqs(String buyerId) async {
    try {
      final uri = Uri.parse(ApiConfig.rfq).replace(queryParameters: {'buyer_id': buyerId});
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body['success'] == true) {
        return (body['rfqs'] as List)
            .map((r) => RfqModel.fromJson(r as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── Orders ────────────────────────────────────────────────────────────────

  /// Create a new order.
  Future<OrderModel?> createOrder({
    required String productId,
    required String buyerId,
    required String artisanId,
    required int quantity,
    required double totalPrice,
    String deliveryAddress = '',
    String buyerName = '',
    String artisanName = '',
    String productTitle = '',
    String notes = '',
    String rfqId = '',
  }) async {
    try {
      final resp = await http.post(
        Uri.parse(ApiConfig.orders),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'product_id':       productId,
          'buyer_id':         buyerId,
          'artisan_id':       artisanId,
          'quantity':         quantity,
          'total_price':      totalPrice,
          'delivery_address': deliveryAddress,
          'buyer_name':       buyerName,
          'artisan_name':     artisanName,
          'product_title':    productTitle,
          'notes':            notes,
          'rfq_id':           rfqId,
        }),
      ).timeout(const Duration(seconds: 10));
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body['success'] == true && body['order'] != null) {
        return OrderModel.fromJson(body['order'] as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetch orders filtered by buyer or artisan ID.
  Future<List<OrderModel>> getOrders({
    String buyerId = '',
    String artisanId = '',
    String status = '',
  }) async {
    final params = <String, String>{};
    if (buyerId.isNotEmpty)   params['buyer_id']   = buyerId;
    if (artisanId.isNotEmpty) params['artisan_id'] = artisanId;
    if (status.isNotEmpty)    params['status']     = status;

    try {
      final uri = Uri.parse(ApiConfig.orders).replace(queryParameters: params);
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body['success'] == true) {
        return (body['orders'] as List)
            .map((o) => OrderModel.fromJson(o as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Update an order's status.
  Future<OrderModel?> updateOrderStatus(String orderId, String status) async {
    try {
      final resp = await http.put(
        Uri.parse(ApiConfig.orderById(orderId)),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': status}),
      ).timeout(const Duration(seconds: 10));
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body['success'] == true && body['order'] != null) {
        return OrderModel.fromJson(body['order'] as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Digital Craft Passport ──────────────────────────────────────────────────

  /// Fetches structured public passport JSON for a product.
  Future<Map<String, dynamic>?> getPassport(String productId) async {
    try {
      final resp = await http
          .get(Uri.parse(ApiConfig.passport(productId)), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body['success'] == true && body['passport'] != null) {
        return Map<String, dynamic>.from(body['passport'] as Map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Analytics Summary ───────────────────────────────────────────────────────

  /// Fetches aggregated sales analytics for an artisan (for fl_chart & summary cards).
  Future<Map<String, dynamic>?> getAnalyticsSummary(String artisanId) async {
    try {
      final resp = await http
          .get(Uri.parse(ApiConfig.analyticsSummary(artisanId)))
          .timeout(const Duration(seconds: 10));
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body['success'] == true && body['data'] != null) {
        return Map<String, dynamic>.from(body['data'] as Map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Trust Score ────────────────────────────────────────────────────────────

  /// Fetches trust score and completion metrics for an artisan or buyer.
  Future<Map<String, dynamic>?> getTrustScore(String userId) async {
    try {
      final resp = await http
          .get(Uri.parse(ApiConfig.trustScore(userId)))
          .timeout(const Duration(seconds: 10));
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body['success'] == true && body['data'] != null) {
        return Map<String, dynamic>.from(body['data'] as Map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── AI Promo Caption ───────────────────────────────────────────────────────

  /// Generates a WhatsApp/social marketing caption with emojis, hashtags, and pricing.
  Future<Map<String, dynamic>?> generatePromoCaption({
    required String productId,
    String? language,
  }) async {
    try {
      final payload = <String, dynamic>{'product_id': productId};
      if (language != null && language.isNotEmpty) {
        payload['language'] = language;
      }
      final resp = await http
          .post(
            Uri.parse(ApiConfig.promoGenerate),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body['success'] == true) {
        return body;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Virtual Clusters ───────────────────────────────────────────────────────

  /// Fetch cluster details by artisan ID.
  Future<Map<String, dynamic>?> getClusterByArtisan(String artisanId) async {
    try {
      final resp = await http
          .get(Uri.parse(ApiConfig.clusterByArtisan(artisanId)))
          .timeout(const Duration(seconds: 10));
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body['success'] == true && body['cluster'] != null) {
        return Map<String, dynamic>.from(body['cluster'] as Map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Create a new virtual cluster.
  Future<Map<String, dynamic>?> createCluster({
    required String name,
    required String craftType,
    required String region,
    required String artisanId,
    String artisanName = '',
    int capacity = 300,
    String description = '',
  }) async {
    try {
      final resp = await http
          .post(
            Uri.parse(ApiConfig.clusters),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'craft_type': craftType,
              'region': region,
              'artisan_id': artisanId,
              'artisan_name': artisanName,
              'capacity': capacity,
              'description': description,
            }),
          )
          .timeout(const Duration(seconds: 10));
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body['success'] == true && body['cluster'] != null) {
        return Map<String, dynamic>.from(body['cluster'] as Map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Join an existing virtual cluster.
  Future<Map<String, dynamic>?> joinCluster({
    required String clusterId,
    required String artisanId,
    String artisanName = '',
    int capacity = 200,
  }) async {
    try {
      final resp = await http
          .post(
            Uri.parse(ApiConfig.clusterJoin(clusterId)),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'artisan_id': artisanId,
              'artisan_name': artisanName,
              'capacity': capacity,
            }),
          )
          .timeout(const Duration(seconds: 10));
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body['success'] == true && body['cluster'] != null) {
        return Map<String, dynamic>.from(body['cluster'] as Map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
