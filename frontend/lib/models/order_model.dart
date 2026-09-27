/// Represents a timestamped status update in the order lifecycle.
class StatusHistoryEntry {
  final String status;
  final String timestamp;

  const StatusHistoryEntry({
    required this.status,
    required this.timestamp,
  });

  factory StatusHistoryEntry.fromJson(Map<String, dynamic> json) {
    return StatusHistoryEntry(
      status: json['status']?.toString() ?? '',
      timestamp: json['timestamp']?.toString() ?? json['time']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'timestamp': timestamp,
  };
}

/// Represents a ShilpSetu order stored in Firestore "orders" collection.
class OrderModel {
  final String id;
  final String productId;
  final String buyerId;
  final String artisanId;
  final int quantity;
  final double totalPrice;
  /// Backend lifecycle: pending -> confirmed -> shipped -> out_for_delivery
  /// -> delivered -> paid. Cancelled is terminal and outside that progression.
  final String status;
  final String deliveryAddress;
  final Map<String, dynamic>? deliveryAddressMap;
  final String buyerName;
  final String artisanName;
  final String productTitle;
  final String notes;
  final String trackingNumber;
  final String trackingUrl;
  final String createdAt;
  final String updatedAt;
  final String rfqId;
  final List<StatusHistoryEntry> statusHistory;
  final String paymentMethod; // 'UPI' | 'COD'
  final String paymentStatus; // 'paid' | 'pending' | 'payment_failed'
  final String stripePaymentIntentId;
  final String razorpayOrderId;
  final String razorpayPaymentId;

  const OrderModel({
    required this.id,
    required this.productId,
    required this.buyerId,
    required this.artisanId,
    required this.quantity,
    required this.totalPrice,
    required this.status,
    this.deliveryAddress = '',
    this.deliveryAddressMap,
    this.buyerName = '',
    this.artisanName = '',
    this.productTitle = '',
    this.notes = '',
    this.trackingNumber = '',
    this.trackingUrl = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.rfqId = '',
    this.statusHistory = const [],
    this.paymentMethod = 'COD',
    this.paymentStatus = 'pending',
    this.stripePaymentIntentId = '',
    this.razorpayOrderId = '',
    this.razorpayPaymentId = '',
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawAddr = json['delivery_address'];
    String formattedAddr = '';
    Map<String, dynamic>? addrMap;
    if (rawAddr is Map) {
      addrMap = Map<String, dynamic>.from(rawAddr);
      final parts = <String>[];
      if ((addrMap['name'] ?? '').toString().trim().isNotEmpty) {
        parts.add(addrMap['name'].toString().trim());
      }
      if ((addrMap['phone'] ?? '').toString().trim().isNotEmpty) {
        parts.add(addrMap['phone'].toString().trim());
      }
      if ((addrMap['line1'] ?? '').toString().trim().isNotEmpty) {
        parts.add(addrMap['line1'].toString().trim());
      }
      if ((addrMap['line2'] ?? '').toString().trim().isNotEmpty) {
        parts.add(addrMap['line2'].toString().trim());
      }
      if ((addrMap['city'] ?? '').toString().trim().isNotEmpty) {
        parts.add(addrMap['city'].toString().trim());
      }
      final st = (addrMap['state'] ?? '').toString().trim();
      final pin = (addrMap['pincode'] ?? '').toString().trim();
      if (st.isNotEmpty && pin.isNotEmpty) {
        parts.add('$st - $pin');
      } else if (st.isNotEmpty) {
        parts.add(st);
      } else if (pin.isNotEmpty) {
        parts.add(pin);
      }
      formattedAddr = parts.join(', ');
    } else {
      formattedAddr = rawAddr?.toString() ?? '';
    }

    return OrderModel(
      id:                 json['id']?.toString() ?? '',
      productId:          json['product_id']?.toString() ?? '',
      buyerId:            json['buyer_id']?.toString() ?? '',
      artisanId:          json['artisan_id']?.toString() ?? '',
      quantity:           (json['quantity'] as num?)?.toInt() ?? 1,
      totalPrice:         (json['total_price'] as num?)?.toDouble() ?? 0.0,
      status:             json['status']?.toString() ?? 'pending',
      deliveryAddress:    formattedAddr,
      deliveryAddressMap: addrMap,
      buyerName:          json['buyer_name']?.toString() ?? '',
      artisanName:        json['artisan_name']?.toString() ?? '',
      productTitle:       json['product_title']?.toString() ?? '',
      notes:              json['notes']?.toString() ?? '',
      trackingNumber:     json['tracking_number']?.toString() ?? '',
      trackingUrl:        json['tracking_url']?.toString() ?? '',
      createdAt:          json['created_at']?.toString() ?? '',
      updatedAt:          json['updated_at']?.toString() ?? '',
      rfqId:              json['rfq_id']?.toString() ?? '',
      statusHistory:      (json['status_history'] as List?)
                             ?.map((e) => StatusHistoryEntry.fromJson(e is Map ? Map<String, dynamic>.from(e) : {}))
                             .toList() ?? const [],
      paymentMethod:          json['payment_method']?.toString() ?? 'COD',
      paymentStatus:          json['payment_status']?.toString() ?? 'pending',
      stripePaymentIntentId:  json['stripe_payment_intent_id']?.toString() ?? json['razorpay_payment_id']?.toString() ?? '',
      razorpayOrderId:        json['razorpay_order_id']?.toString() ?? '',
      razorpayPaymentId:      json['razorpay_payment_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id':                       id,
    'product_id':               productId,
    'buyer_id':                 buyerId,
    'artisan_id':               artisanId,
    'quantity':                 quantity,
    'total_price':              totalPrice,
    'status':                   status,
    'delivery_address':         deliveryAddressMap ?? deliveryAddress,
    'buyer_name':               buyerName,
    'artisan_name':             artisanName,
    'product_title':            productTitle,
    'notes':                    notes,
    'tracking_number':          trackingNumber,
    'tracking_url':             trackingUrl,
    'created_at':               createdAt,
    'updated_at':               updatedAt,
    'rfq_id':                   rfqId,
    'status_history':           statusHistory.map((e) => e.toJson()).toList(),
    'payment_method':           paymentMethod,
    'payment_status':           paymentStatus,
    'stripe_payment_intent_id': stripePaymentIntentId,
    'razorpay_order_id':        razorpayOrderId,
    'razorpay_payment_id':      razorpayPaymentId,
  };

  static const List<String> statusFlow = [
    'pending', 'confirmed', 'shipped', 'out_for_delivery', 'delivered', 'paid'
  ];

  bool get isPaid => paymentStatus.toLowerCase() == 'paid';
  bool get isCod => paymentMethod.toUpperCase() == 'COD';
  bool get isUpi => paymentMethod.toUpperCase() == 'UPI';

  /// Creates a copy of this OrderModel with given fields replaced.
  OrderModel copyWith({
    String? id,
    String? productId,
    String? buyerId,
    String? artisanId,
    int? quantity,
    double? totalPrice,
    String? status,
    String? deliveryAddress,
    Map<String, dynamic>? deliveryAddressMap,
    String? buyerName,
    String? artisanName,
    String? productTitle,
    String? notes,
    String? trackingNumber,
    String? trackingUrl,
    String? createdAt,
    String? updatedAt,
    String? rfqId,
    List<StatusHistoryEntry>? statusHistory,
    String? paymentMethod,
    String? paymentStatus,
    String? stripePaymentIntentId,
    String? razorpayOrderId,
    String? razorpayPaymentId,
  }) {
    return OrderModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      buyerId: buyerId ?? this.buyerId,
      artisanId: artisanId ?? this.artisanId,
      quantity: quantity ?? this.quantity,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryAddressMap: deliveryAddressMap ?? this.deliveryAddressMap,
      buyerName: buyerName ?? this.buyerName,
      artisanName: artisanName ?? this.artisanName,
      productTitle: productTitle ?? this.productTitle,
      notes: notes ?? this.notes,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      trackingUrl: trackingUrl ?? this.trackingUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rfqId: rfqId ?? this.rfqId,
      statusHistory: statusHistory ?? this.statusHistory,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      stripePaymentIntentId: stripePaymentIntentId ?? this.stripePaymentIntentId,
      razorpayOrderId: razorpayOrderId ?? this.razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId ?? this.razorpayPaymentId,
    );
  }

  /// Returns a display-friendly label for the status.
  String get statusLabel {
    switch (status) {
      case 'pending':   return '⏳ Pending';
      case 'confirmed': return '✅ Confirmed';
      case 'shipped':   return '🚚 Shipped';
      case 'out_for_delivery': return '🚚 Out for Delivery';
      case 'delivered': return '📦 Delivered';
      case 'paid':      return '💰 Paid';
      case 'cancelled': return '❌ Cancelled';
      default:          return status;
    }
  }
}
