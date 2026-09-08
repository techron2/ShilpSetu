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
}
