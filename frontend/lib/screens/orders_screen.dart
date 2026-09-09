import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/buyer_service.dart';
import '../theme/app_theme.dart';

/// Orders screen for artisans — real-time Firestore stream filtered by artisan_id.
/// Also provides status update actions (confirm, mark shipped, etc.)
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _filterStatus = 'all';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final lang = context.watch<LanguageProvider>();
    final artisanId = auth.currentArtisanId;

    final statusFilters = [
      {'key': 'all',       'label': lang.getText('order_filter_all')},
      {'key': 'pending',   'label': lang.getText('order_filter_pending')},
      {'key': 'confirmed', 'label': lang.getText('order_filter_confirmed')},
      {'key': 'shipped',   'label': lang.getText('order_filter_shipped')},
      {'key': 'delivered', 'label': lang.getText('order_filter_delivered')},
      {'key': 'paid',      'label': lang.getText('order_filter_paid')},
    ];

    return Scaffold(
      backgroundColor: AppTheme.bgParchment,
      body: Column(
        children: [
          // Status filter chips
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: statusFilters.map((f) {
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
                      fontSize: 13,
                    ),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: selected ? AppTheme.primaryTerracotta : AppTheme.borderGrey,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Real-time orders stream from Firestore (or REST fallback if Firebase not initialized)
          Expanded(
            child: Firebase.apps.isEmpty
                ? _RestFallbackOrders(artisanId: artisanId, filter: _filterStatus)
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('orders')
                        .where('artisan_id', isEqualTo: artisanId)
                        .orderBy('created_at', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: AppTheme.primaryTerracotta));
                      }

                      if (snapshot.hasError) {
                        // Fallback: try REST API if Firestore stream fails (e.g. missing index)
                        return _RestFallbackOrders(artisanId: artisanId, filter: _filterStatus);
                      }

                var orders = (snapshot.data?.docs ?? [])
                    .map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      data['id'] = doc.id;
                      return OrderModel.fromJson(data);
                    })
                    .toList();

                if (_filterStatus != 'all') {
                  orders = orders.where((o) => o.status == _filterStatus).toList();
                }

                if (orders.isEmpty) {
                  return _emptyState();
                }

                // Pending orders banner
                final pendingCount = orders.where((o) => o.status == 'pending').length;

                return CustomScrollView(
                  slivers: [
                    if (pendingCount > 0)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFFFE082)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.mark_email_unread_rounded,
                                    color: Color(0xFFF57F17), size: 24),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    lang.getText('order_pending_banner').replaceAll('{count}', pendingCount.toString()),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFE65100),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _ArtisanOrderCard(order: orders[i]),
                          childCount: orders.length,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final lang = context.watch<LanguageProvider>();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.secondaryOchre.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inbox_rounded,
              size: 60,
              color: AppTheme.secondaryOchre,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            lang.getText('order_no_orders'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkIndigo,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            lang.getText('orders_empty_desc'),
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

/// REST fallback widget when Firestore stream errors (e.g. composite index not ready).
class _RestFallbackOrders extends StatefulWidget {
  final String artisanId;
  final String filter;
  const _RestFallbackOrders({required this.artisanId, required this.filter});

  @override
  State<_RestFallbackOrders> createState() => _RestFallbackOrdersState();
}

class _RestFallbackOrdersState extends State<_RestFallbackOrders> {
  List<OrderModel> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final orders = await BuyerService.instance.getOrders(artisanId: widget.artisanId);
    if (mounted) setState(() { _orders = orders; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryTerracotta));
    }
    var filtered = widget.filter == 'all'
        ? _orders
        : _orders.where((o) => o.status == widget.filter).toList();
    if (filtered.isEmpty) {
      return const Center(child: Text('No orders found', style: TextStyle(color: Color(0xFF6B7280))));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: filtered.length,
      itemBuilder: (_, i) => _ArtisanOrderCard(order: filtered[i]),
    );
  }
}

/// Order card with artisan actions (confirm / mark shipped / mark delivered).
class _ArtisanOrderCard extends StatefulWidget {
  final OrderModel order;
  const _ArtisanOrderCard({required this.order});

  @override
  State<_ArtisanOrderCard> createState() => _ArtisanOrderCardState();
}

class _ArtisanOrderCardState extends State<_ArtisanOrderCard> {
  bool _updating = false;

  Color get _statusColor {
    switch (widget.order.status) {
      case 'pending':   return const Color(0xFFF59E0B);
      case 'confirmed': return AppTheme.successGreen;
      case 'shipped':   return AppTheme.inTransitBlue;
      case 'delivered': return const Color(0xFF7C3AED);
      case 'paid':      return AppTheme.successGreen;
      case 'cancelled': return AppTheme.warningRed;
      default:          return const Color(0xFF6B7280);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _updating = true);
    await BuyerService.instance.updateOrderStatus(widget.order.id, newStatus);
    if (mounted) setState(() => _updating = false);
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
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
                      fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor),
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
            Text(
              order.productTitle.isNotEmpty ? order.productTitle : 'Order',
              style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.darkIndigo),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 5),
                Text(
                  '${context.watch<LanguageProvider>().getText('order_buyer_label')}: ${order.buyerName.isNotEmpty ? order.buyerName : "—"}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.inventory_2_rounded, size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 5),
                Text('${context.watch<LanguageProvider>().getText('order_qty_label')}: ${order.quantity}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
                const SizedBox(width: 16),
                if (order.deliveryAddress.isNotEmpty) ...[
                  const Icon(Icons.location_on_rounded,
                      size: 14, color: AppTheme.primaryTerracotta),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      order.deliveryAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppTheme.borderGrey),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.watch<LanguageProvider>().getText('order_total_amount'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${order.totalPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryTerracotta,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFF6B7280)),
                      const SizedBox(width: 4),
                      Text(
                        '${order.quantity} unit${order.quantity > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Artisan action buttons
            if (!_updating && order.status != 'delivered' && order.status != 'paid' &&
                order.status != 'cancelled') ...[
              const SizedBox(height: 12),
              _actionButtons(context, order.status),
            ] else if (_updating) ...[
              const SizedBox(height: 12),
              const Center(
                child: SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.primaryTerracotta),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionButtons(BuildContext context, String currentStatus) {
    final lang = context.watch<LanguageProvider>();
    final nextStatus = {
      'pending':   'confirmed',
      'confirmed': 'shipped',
      'shipped':   'delivered',
    }[currentStatus];

    final nextLabel = {
      'pending':   '✅ ${lang.getText('order_confirm_btn')}',
      'confirmed': '🚚 ${lang.getText('order_ship_btn')}',
      'shipped':   '📦 ${lang.getText('order_deliver_btn')}',
    }[currentStatus];

    if (nextStatus == null) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
        label: Text(nextLabel!, style: const TextStyle(fontSize: 13)),
        onPressed: () => _updateStatus(nextStatus),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.successGreen,
          foregroundColor: Colors.white,
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
