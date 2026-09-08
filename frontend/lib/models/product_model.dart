/// Represents a single artisan product in the ShilpSetu marketplace.
class Product {
  final String id;
  final String artisanId;
  final String title;
  final String description;
  final String imageUrl;
  final double price;
  final int stockQuantity;
  final String category;
  final String? createdAt;

  const Product({
    required this.id,
    required this.artisanId,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.price,
    required this.stockQuantity,
    required this.category,
    this.createdAt,
  });

  /// Creates a [Product] from a JSON map returned by the Flask API.
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id:            json['id']?.toString() ?? '',
      artisanId:     json['artisan_id']?.toString() ?? '',
      title:         json['title']?.toString() ?? '',
      description:   json['description']?.toString() ?? '',
      imageUrl:      json['image_url']?.toString() ?? '',
      price:         (json['price'] as num?)?.toDouble() ?? 0.0,
      stockQuantity: (json['stock_quantity'] as num?)?.toInt() ?? 0,
      category:      json['category']?.toString() ?? 'Uncategorized',
      createdAt:     json['created_at']?.toString(),
    );
  }

  /// Converts this [Product] to a JSON map for API requests.
  Map<String, dynamic> toJson() => {
    'id':             id,
    'artisan_id':     artisanId,
    'title':          title,
    'description':    description,
    'image_url':      imageUrl,
    'price':          price,
    'stock_quantity': stockQuantity,
    'category':       category,
    if (createdAt != null) 'created_at': createdAt,
  };

  /// Returns a copy of this product with overridden fields.
  Product copyWith({
    String? id,
    String? artisanId,
    String? title,
    String? description,
    String? imageUrl,
    double? price,
    int? stockQuantity,
    String? category,
    String? createdAt,
  }) {
    return Product(
      id:            id            ?? this.id,
      artisanId:     artisanId    ?? this.artisanId,
      title:         title        ?? this.title,
      description:   description  ?? this.description,
      imageUrl:      imageUrl     ?? this.imageUrl,
      price:         price        ?? this.price,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      category:      category     ?? this.category,
      createdAt:     createdAt    ?? this.createdAt,
    );
  }

  @override
  String toString() => 'Product(id: $id, title: $title, price: ₹$price)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Product && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
