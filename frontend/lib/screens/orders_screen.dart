import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/buyer_service.dart';
import '../theme/app_theme.dart';
import '../utils/inr.dart';

/// Orders screen for artisans with immediate in-memory UI updates,
/// real-time Firestore streaming, and pull-to-refresh.
class OrdersScreen extends StatefulWidget {
  final List<OrderModel>? initialOrders;
  final Future<bool> Function(String orderId, String newStatus)? onCustomUpdateStatus;

  const OrdersScreen({
    super.key,
    this.initialOrders,
    this.onCustomUpdateStatus,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _filterStatus = 'all';
  List<OrderModel> _orders = [];
  bool _isLoading = true;
  String? _artisanId;
  StreamSubscription<QuerySnapshot>? _streamSub;

  @override
  void initState() {
    super.initState();
    if (widget.initialOrders != null) {
      _orders = List.from(widget.initialOrders!);
      _isLoading = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AppAuthProvider>(context);
    final aid = auth.currentArtisanId;

    if (aid != _artisanId) {
      _artisanId = aid;
      if (widget.initialOrders == null) {
        _loadOrders(isRefresh: false);
        _setupFirestoreStream(aid);
      }
    }
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }

  Future<void> _loadOrders({bool isRefresh = false}) async {
    final aid = _artisanId ?? '';
    if (aid.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (!isRefresh && _orders.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final fetched = await BuyerService.instance.getOrders(artisanId: aid);
      if (mounted) {
        setState(() {
          _orders = fetched;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupFirestoreStream(String artisanId) {
    _streamSub?.cancel();
    if (Firebase.apps.isEmpty || artisanId.isEmpty) return;

    try {
      // Query without composite index requirement, sorting in Dart
      _streamSub = FirebaseFirestore.instance
          .collection('orders')
          .where('artisan_id', isEqualTo: artisanId)
          .snapshots()
          .listen((snapshot) {
        final docs = snapshot.docs;
        final list = docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return OrderModel.fromJson(data);
        }).toList();

        // Sort descending by created_at
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (mounted) {
          setState(() {
            _orders = list;
            _isLoading = false;
          });
        }
      }, onError: (err) {
        debugPrint('Firestore stream error, falling back to REST: $err');
      });
    } catch (e) {
      debugPrint('Firestore stream setup error: $e');
    }
  }

  /// Immediate local in-memory update after status change.
  /// Re-applies active filter tab instantly with zero network delay.
  void _handleStatusUpdated(String orderId, String newStatus) {
    setState(() {
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        _orders[index] = _orders[index].copyWith(
          status: newStatus,
          updatedAt: DateTime.now().toIso8601String(),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    final statusFilters = [
      {'key': 'all',       'label': lang.getText('order_filter_all')},
      {'key': 'pending',   'label': lang.getText('order_filter_pending')},
      {'key': 'confirmed', 'label': lang.getText('order_filter_confirmed')},
      {'key': 'shipped',   'label': lang.getText('order_filter_shipped')},
      {'key': 'out_for_delivery', 'label': lang.getText('order_filter_out_for_delivery')},
      {'key': 'delivered', 'label': lang.getText('order_filter_delivered')},
      {'key': 'paid',      'label': lang.getText('order_filter_paid')},
    ];

    // Re-apply the active filter to the up-to-date orders list
    final filteredOrders = _filterStatus == 'all'
        ? _orders
        : _orders.where((o) => o.status == _filterStatus).toList();

    // Count pending orders across the full dataset
    final pendingCount = _orders.where((o) => o.status == 'pending').length;

    return Scaffold(
      backgroundColor: AppTheme.bgParchment,
      body: Column(
        children: [
          // Status filter chips with manual refresh button
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
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
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryTerracotta, size: 22),
                  tooltip: 'Reload orders',
                  onPressed: () => _loadOrders(isRefresh: true),
                ),
              ],
            ),
          ),

          // Main orders list or empty state wrapped in RefreshIndicator
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryTerracotta),
                  )
                : RefreshIndicator(
                    color: AppTheme.primaryTerracotta,
                    onRefresh: () => _loadOrders(isRefresh: true),
                    child: filteredOrders.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height * 0.65,
                              child: _emptyState(),
                            ),
                          )
                        : CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
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
                                          const Icon(
                                            Icons.mark_email_unread_rounded,
                                            color: Color(0xFFF57F17),
                                            size: 24,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              lang
                                                  .getText('order_pending_banner')
                                                  .replaceAll('{count}', pendingCount.toString()),
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
                                    (_, i) => _ArtisanOrderCard(
                                      key: ValueKey(filteredOrders[i].id),
                                      order: filteredOrders[i],
                                      onCustomUpdateStatus: widget.onCustomUpdateStatus,
                                      onStatusUpdated: (newStatus) =>
                                          _handleStatusUpdated(filteredOrders[i].id, newStatus),
                                    ),
                                    childCount: filteredOrders.length,
                                  ),
                                ),
                              ),
                            ],
                          ),
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

/// Order card with artisan actions (confirm / mark shipped / mark delivered).
class _ArtisanOrderCard extends StatefulWidget {
  final OrderModel order;
  final ValueChanged<String>? onStatusUpdated;
  final Future<bool> Function(String orderId, String newStatus)? onCustomUpdateStatus;

  const _ArtisanOrderCard({
    required this.order,
    this.onStatusUpdated,
    this.onCustomUpdateStatus,
    super.key,
  });

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
      case 'out_for_delivery': return AppTheme.inTransitBlue;
      case 'delivered': return const Color(0xFF7C3AED);
      case 'paid':      return AppTheme.successGreen;
      case 'cancelled': return AppTheme.warningRed;
      default:          return const Color(0xFF6B7280);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _updating = true);
    try {
      bool success = false;
      if (widget.onCustomUpdateStatus != null) {
        success = await widget.onCustomUpdateStatus!(widget.order.id, newStatus);
      } else {
        final updated = await BuyerService.instance.updateOrderStatus(widget.order.id, newStatus);
        success = updated != null;
      }

      if (!mounted) return;
      setState(() => _updating = false);

      if (success) {
        // Immediately notify parent to update in-memory list and re-apply active filter
        widget.onStatusUpdated?.call(newStatus);
        final visibleOrderId = widget.order.id.length > 8
            ? widget.order.id.substring(0, 8)
            : widget.order.id;
        final visibleStatus = widget.order.copyWith(status: newStatus).statusLabel;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #$visibleOrderId marked as $visibleStatus'),
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update status. Please check your connection.'),
            backgroundColor: AppTheme.warningRed,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _updating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: AppTheme.warningRed,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildPaymentBadge(order),
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
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.darkIndigo,
              ),
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
                Text(
                  '${context.watch<LanguageProvider>().getText('order_qty_label')}: ${order.quantity}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
                ),
              ],
            ),
            _buildDeliveryAddressSection(order),
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
                      formatInr(order.totalPrice),
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

            // Keep fulfillment actions aligned with the backend lifecycle.
            if (!_updating &&
                order.status != 'delivered' &&
                order.status != 'paid' &&
                order.status != 'cancelled') ...[
              const SizedBox(height: 12),
              _actionButtons(context, order.status),
            ] else if (_updating) ...[
              const SizedBox(height: 12),
              const Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryTerracotta,
                  ),
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
      'shipped':   'out_for_delivery',
      'out_for_delivery': 'delivered',
    }[currentStatus];

    final nextLabel = {
      'pending':   '✅ ${lang.getText('order_confirm_btn')}',
      'confirmed': '🚚 ${lang.getText('order_ship_btn')}',
      'shipped':   '📍 ${lang.getText('order_out_for_delivery_btn')}',
      'out_for_delivery': '📦 ${lang.getText('order_deliver_btn')}',
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

  Widget _buildDeliveryAddressSection(OrderModel order) {
    final map = order.deliveryAddressMap;
    final hasMap = map != null && map.isNotEmpty;
    final rawStr = order.deliveryAddress.trim();

    if (!hasMap && rawStr.isEmpty) return const SizedBox.shrink();

    final name = hasMap ? (map['name']?.toString().trim() ?? '') : '';
    final phone = hasMap ? (map['phone']?.toString().trim() ?? '') : '';
    final line1 = hasMap ? (map['line1']?.toString().trim() ?? '') : '';
    final line2 = hasMap ? (map['line2']?.toString().trim() ?? '') : '';
    final city = hasMap ? (map['city']?.toString().trim() ?? '') : '';
    final state = hasMap ? (map['state']?.toString().trim() ?? '') : '';
    final pincode = hasMap ? (map['pincode']?.toString().trim() ?? '') : '';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 15, color: AppTheme.primaryTerracotta),
              const SizedBox(width: 5),
              const Text(
                'Delivery Address',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkIndigo,
                ),
              ),
              if (phone.isNotEmpty) ...[
                const Spacer(),
                const Icon(Icons.phone_outlined, size: 13, color: Color(0xFF6B7280)),
                const SizedBox(width: 3),
                Text(
                  phone,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 5),
          if (hasMap) ...[
            if (name.isNotEmpty)
              Text(
                name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
            if (line1.isNotEmpty || line2.isNotEmpty)
              Text(
                [line1, if (line2.isNotEmpty) line2].join(', '),
                style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
              ),
            if (city.isNotEmpty || state.isNotEmpty || pincode.isNotEmpty)
              Text(
                '${[city, state].where((s) => s.isNotEmpty).join(', ')}${pincode.isNotEmpty ? ' - $pincode' : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
          ] else ...[
            Text(
              rawStr,
              style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentBadge(OrderModel order) {
    final isUpi = order.paymentMethod.toUpperCase() == 'UPI';
    final isPaid = order.paymentStatus.toLowerCase() == 'paid';
    final isFailed = order.paymentStatus.toLowerCase() == 'payment_failed';

    final Color badgeColor;
    final String label;
    final IconData icon;

    if (isFailed) {
      badgeColor = AppTheme.warningRed;
      label = 'Payment Failed';
      icon = Icons.error_outline_rounded;
    } else if (isUpi && isPaid) {
      badgeColor = AppTheme.successGreen;
      label = 'Paid via UPI';
      icon = Icons.check_circle_rounded;
    } else if (isUpi) {
      badgeColor = const Color(0xFF2563EB);
      label = 'UPI (${order.paymentStatus})';
      icon = Icons.account_balance_wallet_outlined;
    } else {
      badgeColor = const Color(0xFFD97706);
      label = isPaid ? 'COD (Collected)' : 'Cash on Delivery';
      icon = Icons.payments_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}
