import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/buyer_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import 'chat_screen.dart';

/// Orders screen for buyers — fetches from backend REST API.
class BuyerOrdersScreen extends StatefulWidget {
  const BuyerOrdersScreen({super.key});

  @override
  State<BuyerOrdersScreen> createState() => _BuyerOrdersScreenState();
}

class _BuyerOrdersScreenState extends State<BuyerOrdersScreen> {
  List<OrderModel> _orders = [];
  bool _isLoading = true;
  String _filterStatus = 'all';

  static const List<Map<String, String>> _statusFilters = [
    {'key': 'all',       'label': 'All'},
    {'key': 'pending',   'label': '⏳ Pending'},
    {'key': 'confirmed', 'label': '✅ Confirmed'},
    {'key': 'shipped',   'label': '🚚 Shipped'},
    {'key': 'delivered', 'label': '📦 Delivered'},
    {'key': 'paid',      'label': '💰 Paid'},
  ];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final user = context.read<AppAuthProvider>().userModel;
    if (user == null) return;
    setState(() => _isLoading = true);

    final orders = await BuyerService.instance.getOrders(buyerId: user.uid);
    if (mounted) {
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    }
  }

  List<OrderModel> get _filteredOrders {
    if (_filterStatus == 'all') return _orders;
    return _orders.where((o) => o.status == _filterStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgParchment,
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const AppBackButton() : null,
        title: const Text('📦 My Orders'),
        backgroundColor: AppTheme.primaryTerracotta,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadOrders,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status filter chips
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: _statusFilters.map((f) {
                final selected = f['key'] == _filterStatus;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f['label']!),
                    selected: selected,
                    onSelected: (_) => setState(() => _filterStatus = f['key']!),
                    selectedColor: AppTheme.primaryTerracotta,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF4B5563),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: selected ? AppTheme.primaryTerracotta : AppTheme.borderGrey,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Orders list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryTerracotta))
                : _filteredOrders.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: _filteredOrders.length,
                        itemBuilder: (_, i) => _OrderCard(
                          order: _filteredOrders[i],
                          onRefresh: _loadOrders,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _filterStatus == 'all' ? 'No orders yet' : 'No $_filterStatus orders',
            style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Browse products and place your first order!',
            style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onRefresh;

  const _OrderCard({required this.order, required this.onRefresh});

  Color get _statusColor {
    switch (order.status) {
      case 'pending':   return const Color(0xFFF59E0B);
      case 'confirmed': return AppTheme.successGreen;
      case 'shipped':   return AppTheme.inTransitBlue;
      case 'delivered': return const Color(0xFF7C3AED);
      case 'paid':      return AppTheme.successGreen;
      case 'cancelled': return AppTheme.warningRed;
      default:          return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge + order ID
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    order.statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _statusColor,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  order.id.length > 8 ? '#${order.id.substring(0, 8)}' : '#${order.id}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Product title
            Text(
              order.productTitle.isNotEmpty ? order.productTitle : 'Order',
              style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.darkIndigo),
            ),
            const SizedBox(height: 6),

            // Artisan
            Row(
              children: [
                const Icon(Icons.palette_rounded, size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 5),
                Text(
                  'Artisan: ${order.artisanName.isNotEmpty ? order.artisanName : "—"}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Qty + Address
            Row(
              children: [
                const Icon(Icons.inventory_2_rounded, size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 5),
                Text('Qty: ${order.quantity}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
              ],
            ),
            if (order.trackingNumber.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.local_shipping_rounded,
                      size: 14, color: AppTheme.inTransitBlue),
                  const SizedBox(width: 5),
                  Text(
                    'Tracking: ${order.trackingNumber}',
                    style: const TextStyle(
                      fontSize: 13, color: AppTheme.inTransitBlue,
                      fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1, color: AppTheme.borderGrey),
            const SizedBox(height: 10),

            // Price + date + chat button
            Row(
              children: [
                Text(
                  '₹${order.totalPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryTerracotta,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${order.quantity} unit${order.quantity > 1 ? 's' : ''})',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const Spacer(),
                // Chat button
                SizedBox(
                  height: 32,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.chat_rounded, size: 14),
                    label: const Text('Chat', style: TextStyle(fontSize: 12)),
                    onPressed: order.artisanId.isNotEmpty
                        ? () {
                            final user = context.read<AppAuthProvider>().userModel;
                            if (user == null) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  currentUserId: user.uid,
                                  currentUserName: user.name,
                                  otherUserId: order.artisanId,
                                  otherUserName: order.artisanName.isNotEmpty
                                      ? order.artisanName
                                      : 'Artisan',
                                  isCurrentUserArtisan: false,
                                ),
                              ),
                            );
                          }
                        : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      side: const BorderSide(color: AppTheme.inTransitBlue),
                      foregroundColor: AppTheme.inTransitBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
