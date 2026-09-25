import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/order_model.dart';
import 'package:frontend/utils/artisan_dashboard_metrics.dart';

OrderModel _order({
  required String status,
  required double total,
  required String createdAt,
}) {
  return OrderModel(
    id: '$status-$createdAt',
    productId: 'product',
    buyerId: 'buyer',
    artisanId: 'artisan',
    quantity: 1,
    totalPrice: total,
    status: status,
    createdAt: createdAt,
  );
}

void main() {
  const currentMonth = '2026-09';
  final now = DateTime(2026, 9, 10);

  test('counts only pending orders after normalizing status', () {
    final metrics = ArtisanDashboardMetrics.fromOrders([
      _order(
        status: 'pending',
        total: 100,
        createdAt: '$currentMonth-01T12:00:00Z',
      ),
      _order(
        status: ' Pending ',
        total: 200,
        createdAt: '$currentMonth-02T12:00:00Z',
      ),
      _order(
        status: 'confirmed',
        total: 300,
        createdAt: '$currentMonth-03T12:00:00Z',
      ),
    ], now: now);

    expect(metrics.pendingOrders, 2);
  });

  test('earnings include only fulfilled current-month orders', () {
    final metrics = ArtisanDashboardMetrics.fromOrders([
      _order(
        status: 'delivered',
        total: 1200,
        createdAt: '$currentMonth-01T12:00:00Z',
      ),
      _order(
        status: 'paid',
        total: 350.50,
        createdAt: '$currentMonth-08T12:00:00Z',
      ),
      _order(
        status: 'pending',
        total: 9000,
        createdAt: '$currentMonth-09T12:00:00Z',
      ),
      _order(
        status: 'delivered',
        total: 800,
        createdAt: '2026-08-31T12:00:00Z',
      ),
      _order(status: 'paid', total: 500, createdAt: 'invalid'),
      _order(
        status: 'cancelled',
        total: 700,
        createdAt: '$currentMonth-05T12:00:00Z',
      ),
    ], now: now);

    expect(metrics.monthEarnings, 1550.50);
  });
}
