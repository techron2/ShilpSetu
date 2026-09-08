import '../config/api_config.dart';
import 'i_product_service.dart';
import 'mock_product_service.dart';
import 'real_product_service.dart';

/// Returns the correct [IProductService] implementation based on [ApiConfig.useMock].
///
/// Usage:
/// ```dart
/// final service = ProductServiceFactory.create();
/// final products = await service.fetchProducts();
/// ```
class ProductServiceFactory {
  ProductServiceFactory._();

  static IProductService create() {
    if (ApiConfig.useMock) {
      return MockProductService();
    }
    return RealProductService();
  }
}
