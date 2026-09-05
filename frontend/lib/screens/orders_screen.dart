import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  final List<Map<String, dynamic>> _orders = const [
    {
      "order_id": "ORD-7821",
      "item_title": "टेराकोटा कुल्हड़ सेट (6 पीस)",
      "buyer": "प्रिया शर्मा (नई दिल्ली)",
      "amount": "₹ 350",
      "status_text": "पैक करें - कल पिकअप है",
      "status_badge": "पैक करने के लिए तैयार",
      "status_color": Color(0xFFD97706),
      "icon": Icons.inventory_2_rounded,
      "date": "05 सितम्बर 2026",
    },
    {
      "order_id": "ORD-7819",
      "item_title": "दाबू प्रिंट कॉटन स्टोल",
      "buyer": "अनन्या रॉय (बेंगलुरु)",
      "amount": "₹ 890",
      "status_text": "भारतीय डाक द्वारा रास्ते में",
      "status_badge": "रास्ते में (In Transit)",
      "status_color": AppTheme.inTransitBlue,
      "icon": Icons.local_shipping_rounded,
      "date": "03 सितम्बर 2026",
    },
    {
      "order_id": "ORD-7790",
      "item_title": "हाथ से बनी टेराकोटा हांडी",
      "buyer": "रोहित वर्मा (मुंबई)",
      "amount": "₹ 750",
      "status_text": "ग्राहक को सफलतापूर्वक मिल गया",
      "status_badge": "सफल डिलीवरी (Delivered)",
      "status_color": AppTheme.successGreen,
      "icon": Icons.check_circle_rounded,
      "date": "28 अगस्त 2026",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Status Overview Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.mark_email_unread_rounded, color: Color(0xFFF57F17), size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "आपको 1 नया ऑर्डर मिला है जिसे पैक करना है।",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE65100),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "हाल के ऑर्डर्स (Recent Orders)",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.darkIndigo,
              ),
            ),
            const SizedBox(height: 12),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                final order = _orders[index];
                final Color statusColor = order['status_color'] as Color;

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(order['icon'] as IconData, color: statusColor, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    order['status_badge'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              order['order_id'],
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          order['item_title'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkIndigo,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 16, color: Color(0xFF6B7280)),
                            const SizedBox(width: 4),
                            Text(
                              "खरीदार: ${order['buyer']}",
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF4B5563),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: AppTheme.borderGrey),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              order['amount'],
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryTerracotta,
                              ),
                            ),
                            Text(
                              order['date'],
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
