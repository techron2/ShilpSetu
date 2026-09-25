import '../models/order_model.dart';

/// Honest, order-backed summary values shown on the artisan Home screen.
class ArtisanDashboardMetrics {
  const ArtisanDashboardMetrics({
    required this.pendingOrders,
    required this.monthEarnings,
  });

  final int pendingOrders;
  final double monthEarnings;

  factory ArtisanDashboardMetrics.fromOrders(
    Iterable<OrderModel> orders, {
    DateTime? now,
  }) {
    final localNow = now ?? DateTime.now();
    var pending = 0;
    var earnings = 0.0;

    for (final order in orders) {
      final status = order.status.trim().toLowerCase();
      if (status == 'pending') pending += 1;

      // Earnings are counted only once an order has been fulfilled or paid.
      if (status != 'delivered' && status != 'paid') continue;
      final createdAt = DateTime.tryParse(order.createdAt)?.toLocal();
      if (createdAt == null ||
          createdAt.year != localNow.year ||
          createdAt.month != localNow.month) {
        continue;
      }
      earnings += order.totalPrice;
    }

    return ArtisanDashboardMetrics(
      pendingOrders: pending,
      monthEarnings: earnings,
    );
  }
}
