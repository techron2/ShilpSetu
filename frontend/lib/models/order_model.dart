/// Represents a ShilpSetu order stored in Firestore "orders" collection.
class OrderModel {
  final String id;
  final String productId;
  final String buyerId;
  final String artisanId;
  final int quantity;
  final double totalPrice;
  final String status; // pending | confirmed | shipped | delivered | paid | cancelled
  final String deliveryAddress;
  final String buyerName;
  final String artisanName;
  final String productTitle;
  final String notes;
  final String trackingNumber;
  final String trackingUrl;
  final String createdAt;
  final String updatedAt;
  final String rfqId;

  const OrderModel({
    required this.id,
    required this.productId,
    required this.buyerId,
    required this.artisanId,
    required this.quantity,
    required this.totalPrice,
    required this.status,
    this.deliveryAddress = '',
    this.buyerName = '',
    this.artisanName = '',
    this.productTitle = '',
    this.notes = '',
    this.trackingNumber = '',
    this.trackingUrl = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.rfqId = '',
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id:              json['id']?.toString() ?? '',
      productId:       json['product_id']?.toString() ?? '',
      buyerId:         json['buyer_id']?.toString() ?? '',
      artisanId:       json['artisan_id']?.toString() ?? '',
      quantity:        (json['quantity'] as num?)?.toInt() ?? 1,
      totalPrice:      (json['total_price'] as num?)?.toDouble() ?? 0.0,
      status:          json['status']?.toString() ?? 'pending',
      deliveryAddress: json['delivery_address']?.toString() ?? '',
      buyerName:       json['buyer_name']?.toString() ?? '',
      artisanName:     json['artisan_name']?.toString() ?? '',
      productTitle:    json['product_title']?.toString() ?? '',
      notes:           json['notes']?.toString() ?? '',
      trackingNumber:  json['tracking_number']?.toString() ?? '',
      trackingUrl:     json['tracking_url']?.toString() ?? '',
      createdAt:       json['created_at']?.toString() ?? '',
      updatedAt:       json['updated_at']?.toString() ?? '',
      rfqId:           json['rfq_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id':               id,
    'product_id':       productId,
    'buyer_id':         buyerId,
    'artisan_id':       artisanId,
    'quantity':         quantity,
    'total_price':      totalPrice,
    'status':           status,
    'delivery_address': deliveryAddress,
    'buyer_name':       buyerName,
    'artisan_name':     artisanName,
    'product_title':    productTitle,
    'notes':            notes,
    'tracking_number':  trackingNumber,
    'tracking_url':     trackingUrl,
    'created_at':       createdAt,
    'updated_at':       updatedAt,
    'rfq_id':           rfqId,
  };

  static const List<String> statusFlow = [
    'pending', 'confirmed', 'shipped', 'delivered', 'paid'
  ];

  /// Returns a display-friendly label for the status.
  String get statusLabel {
    switch (status) {
      case 'pending':   return '⏳ Pending';
      case 'confirmed': return '✅ Confirmed';
      case 'shipped':   return '🚚 Shipped';
      case 'delivered': return '📦 Delivered';
      case 'paid':      return '💰 Paid';
      case 'cancelled': return '❌ Cancelled';
      default:          return status;
    }
  }
}
