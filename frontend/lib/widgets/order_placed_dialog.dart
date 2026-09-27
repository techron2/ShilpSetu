import 'package:flutter/material.dart';

import '../models/order_model.dart';
import '../screens/buyer/buyer_orders_screen.dart';
import '../theme/app_theme.dart';
import '../utils/inr.dart';

/// Confirmation for the actual order returned by the payment/order flow.
class OrderPlacedDialog extends StatelessWidget {
  final OrderModel order;

  const OrderPlacedDialog({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final isUpi = order.paymentMethod.toUpperCase() == 'UPI';
    final navigator = Navigator.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: AppTheme.successGreen,
            size: 28,
          ),
          SizedBox(width: 10),
          Text('Order Placed! 🎉'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.productTitle.isNotEmpty ? order.productTitle : 'Order',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Quantity: ${order.quantity} unit${order.quantity > 1 ? 's' : ''}',
          ),
          Text('Total: ${formatInr(order.totalPrice)}'),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                isUpi
                    ? Icons.account_balance_wallet_rounded
                    : Icons.payments_rounded,
                size: 14,
                color: isUpi ? AppTheme.successGreen : const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 5),
              Text(
                isUpi ? 'Payment: Paid via UPI' : 'Payment: Cash on Delivery',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isUpi
                      ? AppTheme.successGreen
                      : const Color(0xFFD97706),
                ),
              ),
            ],
          ),
          if (order.deliveryAddress.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Shipping to: ${order.deliveryAddress}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Order ID will appear in your Orders screen. The artisan will confirm shortly.',
              style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => navigator.pop(),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: () {
            navigator.pop();
            navigator.push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const BuyerOrdersScreen(),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryTerracotta,
            foregroundColor: Colors.white,
          ),
          child: const Text('View My Orders'),
        ),
      ],
    );
  }
}
