import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/buyer_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/inr.dart';
import '../../widgets/app_back_button.dart';

/// Buyer orders use REST for initial/manual refresh and a buyer-scoped
/// Firestore stream for live status updates when Firebase is initialized.
class BuyerOrdersScreen extends StatefulWidget {
  final List<OrderModel>? initialOrders;
  const BuyerOrdersScreen({super.key, this.initialOrders});

  @override
  State<BuyerOrdersScreen> createState() => _BuyerOrdersScreenState();
}

class _BuyerOrdersScreenState extends State<BuyerOrdersScreen> {
  List<OrderModel> _orders = [];
  bool _isLoading = true;
  bool _identityUnavailable = false;
  bool _identityChecked = false;
  String _filterStatus = 'all';
  String _buyerId = '';
  StreamSubscription<QuerySnapshot>? _streamSub;

  static const List<Map<String, String>> _statusFilters = [
    {'key': 'all',       'label': 'All'},
    {'key': 'pending',   'label': '⏳ Pending'},
    {'key': 'confirmed', 'label': '✅ Confirmed'},
    {'key': 'shipped',   'label': '🚚 Shipped'},
    {'key': 'out_for_delivery', 'label': '📦 Out for Delivery'},
    {'key': 'delivered', 'label': '📦 Delivered'},
    {'key': 'paid',      'label': '💰 Paid'},
  ];

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
    if (widget.initialOrders != null) return;

    final buyerId = context.read<AppAuthProvider>().userModel?.uid.trim() ?? '';
    if (_identityChecked && buyerId == _buyerId) return;

    _identityChecked = true;
    _buyerId = buyerId;
    _streamSub?.cancel();
    if (mounted) {
      setState(() {
        _orders = [];
        _isLoading = true;
        _identityUnavailable = false;
      });
    }
    _loadOrders();
    _setupFirestoreStream(buyerId);
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    if (widget.initialOrders != null) return;
    final buyerId = _buyerId;
    if (buyerId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _identityUnavailable = true;
        });
      }
      return;
    }
    if (_orders.isEmpty && mounted) setState(() => _isLoading = true);

    try {
      final orders = await BuyerService.instance.getOrders(buyerId: buyerId);
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted || buyerId != _buyerId) return;
      setState(() {
        _orders = orders;
        _isLoading = false;
        _identityUnavailable = false;
      });
    } catch (_) {
      if (!mounted || buyerId != _buyerId) return;
      setState(() => _isLoading = false);
    }
  }

  void _setupFirestoreStream(String buyerId) {
    if (Firebase.apps.isEmpty || buyerId.isEmpty) return;

    try {
      _streamSub = FirebaseFirestore.instance
          .collection('orders')
          .where('buyer_id', isEqualTo: buyerId)
          .snapshots()
          .listen((snapshot) {
        final orders = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return OrderModel.fromJson(data);
        }).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (!mounted || buyerId != _buyerId) return;
        setState(() {
          _orders = orders;
          _isLoading = false;
          _identityUnavailable = false;
        });
      }, onError: (Object error) {
        // The REST result remains available; the refresh action can retry it.
        debugPrint('Buyer orders Firestore stream error; keeping REST data: $error');
      });
    } catch (error) {
      debugPrint('Buyer orders Firestore stream setup failed; keeping REST data: $error');
    }
  }

  List<OrderModel> get _filteredOrders {
    if (_filterStatus == 'all') return _orders;
    return _orders.where((o) => o.status == _filterStatus).toList();
  }

  String get _selectedFilterLabel => _statusFilters
      .firstWhere((filter) => filter['key'] == _filterStatus)['label']!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgParchment,
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const AppBackButton() : null,
        title: const Text('My Orders'),
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
    final identityUnavailable = _identityUnavailable;
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
            identityUnavailable
                ? 'Sign in to view your orders'
                : _filterStatus == 'all'
                    ? 'अभी कोई ऑर्डर नहीं\n(No orders yet)'
                    : 'No $_selectedFilterLabel orders',
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
            identityUnavailable
                ? 'Your buyer profile is not available yet.'
                : 'Browse products and place your first order!',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
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
      case 'out_for_delivery': return AppTheme.inTransitBlue;
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

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(
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

            // ── 5-Stage Order Tracking Timeline ─────────────────────────────
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppTheme.borderGrey),
            const SizedBox(height: 12),
            _buildOrderTimeline(order),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTimeline(OrderModel order) {
    if (order.status == 'cancelled') {
      String cancelTime = '';
      for (final h in order.statusHistory) {
        if (h.status == 'cancelled') {
          cancelTime = _formatTimelineDate(h.timestamp);
          break;
        }
      }
      if (cancelTime.isEmpty && order.updatedAt.isNotEmpty) {
        cancelTime = _formatTimelineDate(order.updatedAt);
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.warningRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.warningRed.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: AppTheme.warningRed, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Cancelled',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.warningRed,
                      fontSize: 13,
                    ),
                  ),
                  if (cancelTime.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Cancelled on ${cancelTime.replaceAll('\n', ' ')}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 5 canonical stages in order:
    // 1: placed, 2: packed, 3: shipped, 4: out_for_delivery, 5: delivered
    int currentStage = 1;
    switch (order.status) {
      case 'pending':
        currentStage = 1;
        break;
      case 'confirmed':
        currentStage = 2;
        break;
      case 'shipped':
        currentStage = 3;
        break;
      case 'out_for_delivery':
        currentStage = 4;
        break;
      case 'delivered':
      case 'paid':
        currentStage = 5;
        break;
      default:
        currentStage = 1;
    }

    final stages = [
      _StageInfo(
        key: 'placed',
        label: 'Order Placed',
        icon: Icons.check_rounded,
        timestamp: _findStageTimestamp(order, 'placed', 1, currentStage),
      ),
      _StageInfo(
        key: 'packed',
        label: 'Packed',
        icon: Icons.inventory_2_rounded,
        timestamp: _findStageTimestamp(order, 'packed', 2, currentStage),
      ),
      _StageInfo(
        key: 'shipped',
        label: 'Shipped',
        icon: Icons.local_shipping_rounded,
        timestamp: _findStageTimestamp(order, 'shipped', 3, currentStage),
      ),
      _StageInfo(
        key: 'out_for_delivery',
        label: 'Out for Delivery',
        icon: Icons.location_on_rounded,
        timestamp: _findStageTimestamp(order, 'out_for_delivery', 4, currentStage),
      ),
      _StageInfo(
        key: 'delivered',
        label: 'Delivered',
        icon: Icons.home_rounded,
        timestamp: _findStageTimestamp(order, 'delivered', 5, currentStage),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Horizontal node row with interconnecting lines
        Row(
          children: [
            for (int i = 0; i < stages.length; i++)
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == 0
                            ? Colors.transparent
                            : (i + 1 <= currentStage
                                ? AppTheme.successGreen
                                : const Color(0xFFE5E7EB)),
                      ),
                    ),
                    _buildStageCircle(stages[i], isCompleted: i + 1 <= currentStage),
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == stages.length - 1
                            ? Colors.transparent
                            : (i + 2 <= currentStage
                                ? AppTheme.successGreen
                                : const Color(0xFFE5E7EB)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Labels & Timestamps row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < stages.length; i++)
              Expanded(
                child: Column(
                  children: [
                    Text(
                      stages[i].label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: i + 1 <= currentStage
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: i + 1 <= currentStage
                            ? AppTheme.darkIndigo
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                    if (i + 1 <= currentStage && stages[i].timestamp != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _formatTimelineDate(stages[i].timestamp!),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 9,
                          height: 1.25,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  String? _findStageTimestamp(
      OrderModel order, String stageKey, int stageIndex, int currentStage) {
    if (stageIndex > currentStage) return null;

    // Search statusHistory
    for (final h in order.statusHistory) {
      if (h.status.toLowerCase() == stageKey.toLowerCase() && h.timestamp.isNotEmpty) {
        return h.timestamp;
      }
    }

    // Alternative status aliases in history
    if (stageKey == 'placed') {
      for (final h in order.statusHistory) {
        if (h.status.toLowerCase() == 'pending' && h.timestamp.isNotEmpty) {
          return h.timestamp;
        }
      }
      if (order.createdAt.isNotEmpty) return order.createdAt;
    }
    if (stageKey == 'packed') {
      for (final h in order.statusHistory) {
        if (h.status.toLowerCase() == 'confirmed' && h.timestamp.isNotEmpty) {
          return h.timestamp;
        }
      }
    }
    if (stageKey == 'delivered') {
      for (final h in order.statusHistory) {
        if (h.status.toLowerCase() == 'paid' && h.timestamp.isNotEmpty) {
          return h.timestamp;
        }
      }
    }

    // Fallbacks for older orders
    if (stageIndex == currentStage && order.updatedAt.isNotEmpty) {
      return order.updatedAt;
    }
    if (stageIndex == 1 && order.createdAt.isNotEmpty) {
      return order.createdAt;
    }
    return null;
  }

  String _formatTimelineDate(String isoStr) {
    if (isoStr.trim().isEmpty) return '';
    try {
      final dt = DateTime.parse(isoStr.replaceFirst('Z', '+00:00')).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final m = months[dt.month - 1];
      final d = dt.day;
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final min = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$d $m\n$hour:$min $ampm';
    } catch (_) {
      return isoStr.length > 10 ? isoStr.substring(0, 10) : isoStr;
    }
  }

  Widget _buildStageCircle(_StageInfo stage, {required bool isCompleted}) {
    if (isCompleted) {
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: AppTheme.successGreen,
          shape: BoxShape.circle,
        ),
        child: Icon(stage.icon, color: Colors.white, size: 15),
      );
    }
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD1D5DB), width: 2),
      ),
      child: Icon(stage.icon, color: const Color(0xFF9CA3AF), size: 14),
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

class _StageInfo {
  final String key;
  final String label;
  final IconData icon;
  final String? timestamp;

  const _StageInfo({
    required this.key,
    required this.label,
    required this.icon,
    this.timestamp,
  });
}
