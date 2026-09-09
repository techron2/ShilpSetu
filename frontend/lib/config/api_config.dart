/// Central configuration for the ShilpSetu Flutter app.
///
/// Flip [useMock] to `false` to switch from in-memory mock data
/// to the real Flask backend at [baseUrl].
class ApiConfig {
  ApiConfig._(); // prevent instantiation

  /// When `true`, all product/user reads come from [MockProductService].
  /// When `false` (active), calls are made to the real Flask REST API.
  static const bool useMock = false;

  /// Base URL for the Flask backend.
  /// On Android emulator use 10.0.2.2 instead of localhost.
  static const String baseUrl = 'http://127.0.0.1:5000';

  /// Android emulator version (uncomment when running on emulator):
  // static const String baseUrl = 'http://10.0.2.2:5000';

  // ── Endpoint paths ─────────────────────────────────────────────────────────
  static String get products      => '$baseUrl/api/products';
  static String get productSearch => '$baseUrl/api/products/search';
  static String get matching      => '$baseUrl/api/matching/buyer-supplier';
  static String get rfq           => '$baseUrl/api/rfq';
  static String get orders        => '$baseUrl/api/orders';
  static String get catalog       => '$baseUrl/api/catalog';
  static String get assistant     => '$baseUrl/api/assistant/ask';
  static String get pricing       => '$baseUrl/api/pricing/suggest';
  static String get promoGenerate => '$baseUrl/api/promo/generate';
  static String get clusters      => '$baseUrl/api/clusters';

  static String productById(String id)      => '$products/$id';
  static String orderById(String id)        => '$orders/$id';
  static String passport(String id)         => '$baseUrl/api/passport/$id';
  static String passportPublicView(String id)=> '$baseUrl/passport/$id';
  static String analyticsSummary(String id) => '$baseUrl/api/analytics/summary?artisan_id=$id';
  static String trustScore(String id)       => '$baseUrl/api/users/$id/trust-score';
  static String clusterById(String id)      => '$clusters/$id';
  static String clusterJoin(String id)      => '$clusters/$id/join';
  static String clusterByArtisan(String id) => '$clusters/by-artisan/$id';
}
