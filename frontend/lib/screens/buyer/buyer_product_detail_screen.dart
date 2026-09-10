import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../services/buyer_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/inr.dart';
import '../../widgets/app_back_button.dart';
import 'rfq_screen.dart';
import 'supplier_comparison_screen.dart';

/// Buyer-facing product detail screen.
/// Features:
/// - Product specs & bilingual details
/// - Live Digital Craft Passport with QR Code
/// - Virtual Cluster membership & combined capacity
/// - AI-Generated Promotional Caption with WhatsApp sharing
/// - Artisan Trust Score & reliability metrics
class BuyerProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const BuyerProductDetailScreen({super.key, required this.product});

  @override
  State<BuyerProductDetailScreen> createState() => _BuyerProductDetailScreenState();
}

class _BuyerProductDetailScreenState extends State<BuyerProductDetailScreen> {
  int _quantity = 1;
  bool _orderingNow = false;
  bool _isGeneratingPromo = false;

  Map<String, dynamic>? _trustScore;
  Map<String, dynamic>? _cluster;

  Map<String, dynamic> get p => widget.product;

  String get title    => p['title']?.toString() ?? 'Product';
  String get desc     => p['description']?.toString() ?? '';
  double get price    => (p['price'] as num?)?.toDouble() ?? 0;
  int    get stock    => (p['stock_quantity'] as num?)?.toInt() ?? 0;
  String get category => p['category']?.toString() ?? '';
  // Rating is nullable on purpose: older Firestore products may not carry
  // rating data, in which case the UI shows a neutral state instead of a
  // fabricated default score.
  double? get ratingOrNull => (p['rating'] as num?)?.toDouble();
  bool   get hasRating => ratingOrNull != null;
  double get rating    => ratingOrNull ?? 0;
  int    get reviews  => (p['review_count'] as num?)?.toInt() ?? 0;
  String get region   => p['region']?.toString() ?? '';
  String get artisanName => p['artisan_name']?.toString() ?? '';
  String get productCluster => p['artisan_cluster']?.toString() ?? '';
  String get imageUrl => p['image_url']?.toString() ?? '';
  String get artisanId => p['artisan_id']?.toString() ?? '';
  String get productId => p['id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _fetchExtraBadges();
  }

  Future<void> _fetchExtraBadges() async {
    final aid = artisanId.isNotEmpty ? artisanId : 'test_artisan_phase4';
    final results = await Future.wait([
      BuyerService.instance.getTrustScore(aid),
      BuyerService.instance.getClusterByArtisan(aid),
    ]);

    if (!mounted) return;
    setState(() {
      _trustScore = results[0];
      _cluster = results[1];
    });
  }

  Future<void> _shareToWhatsApp() async {
    setState(() => _isGeneratingPromo = true);
    final promo = await BuyerService.instance.generatePromoCaption(
      productId: productId.isNotEmpty ? productId : 'test_passport_prod_01',
      language: 'hi',
    );
    if (!mounted) return;
    setState(() => _isGeneratingPromo = false);

    final caption = promo?['caption'] ??
        '🌿 Check out this authentic handcrafted $title on ShilpSetu!\n\n'
        'Price: ${formatInr(price)}\n'
        'View Digital Craft Passport: ${ApiConfig.passportPublicView(productId.isNotEmpty ? productId : 'sample')}\n\n'
        '#ShilpSetu #VocalForLocal #HandmadeInIndia';

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.share_rounded, color: Color(0xFF25D366), size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Share via WhatsApp / Social',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Text(
                caption,
                style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF14532D)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send_rounded),
                label: const Text('Share to WhatsApp / Apps', style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: () {
                  Navigator.pop(ctx);
                  SharePlus.instance.share(caption);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPassportPreviewDialog() {
    final passportUrl = ApiConfig.passportPublicView(productId.isNotEmpty ? productId : 'test_passport_prod_01');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: AppTheme.successGreen, size: 26),
            SizedBox(width: 8),
            Text('Digital Craft Passport'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEADBCE), width: 1.5),
              ),
              child: QrImageView(
                data: passportUrl,
                version: QrVersions.auto,
                size: 160,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'Origin: ${region.isNotEmpty ? region : 'India'} • 100% Handcrafted',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B5E57)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                passportUrl,
                style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563), fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _placeOrder() async {
    final user = context.read<AppAuthProvider>().userModel;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to place an order')),
      );
      return;
    }

    setState(() => _orderingNow = true);
    final messenger = ScaffoldMessenger.of(context);
    final order = await BuyerService.instance.createOrder(
      productId:    productId,
      buyerId:      user.uid,
      artisanId:    artisanId,
      quantity:     _quantity,
      totalPrice:   price * _quantity,
      buyerName:    user.name,
      productTitle: title,
    );
    if (!mounted) return;
    setState(() => _orderingNow = false);

    if (order != null) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 28),
              SizedBox(width: 10),
              Text('Order Placed! 🎉'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Quantity: $_quantity unit${_quantity > 1 ? 's' : ''}'),
              Text('Total: ${formatInr(price * _quantity)}'),
              const SizedBox(height: 8),
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to place order. Check backend connection.'),
          backgroundColor: AppTheme.warningRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final passportUrl = ApiConfig.passportPublicView(productId.isNotEmpty ? productId : 'sample');

    return Scaffold(
      backgroundColor: AppTheme.bgParchment,
      body: CustomScrollView(
        slivers: [
          // ── Product Image AppBar ────────────────────────────────────────
          SliverAppBar(
            leading: const AppBackButton(),
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppTheme.primaryTerracotta,
            flexibleSpace: FlexibleSpaceBar(
              background: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
            ),
          ),

          // ── Product Details ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category tag
                  if (category.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTerracotta.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.primaryTerracotta,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Title
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.darkIndigo,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Rating + Region row (rating shown only when present in data)
                  Row(
                    children: [
                      if (hasRating) ...[
                        ...List.generate(5, (i) => Icon(
                          i < rating.round()
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: AppTheme.secondaryOchre,
                          size: 18,
                        )),
                        const SizedBox(width: 6),
                        Text(
                          reviews > 0
                              ? '${rating.toStringAsFixed(1)} ($reviews review${reviews == 1 ? '' : 's'})'
                              : rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                        ),
                      ] else ...[
                        const Icon(Icons.rate_review_outlined,
                            size: 16, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 6),
                        const Text(
                          'No ratings yet',
                          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                        ),
                      ],
                      const Spacer(),
                      if (region.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 14, color: AppTheme.primaryTerracotta),
                            const SizedBox(width: 3),
                            Text(
                              region,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryTerracotta,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  // Artisan identity (from product data when available)
                  if (artisanName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded,
                            size: 15, color: AppTheme.primaryTerracotta),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            productCluster.isNotEmpty
                                ? 'By $artisanName • $productCluster'
                                : 'By $artisanName',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkIndigo,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Artisan Trust Score Badge
                  if (_trustScore != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F6F0),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5DDD5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded, color: AppTheme.successGreen, size: 16),
                          const SizedBox(width: 5),
                          Text(
                            '${_trustScore!['badge'] ?? 'Master Artisan'} • ${_trustScore!['trust_score'] ?? 4.8}★ (${_trustScore!['completion_rate_pct'] ?? 100}% Fulfillment)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF5A4D45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Virtual Cluster Badge
                  if (_cluster != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F1DC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD4AF37), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.hub_rounded, color: Color(0xFF8C6E14), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '🌿 Virtual Cluster Member: ${_cluster!['name']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: Color(0xFF2C221E),
                                  ),
                                ),
                                Text(
                                  'Combined Capacity: ${_cluster!['combined_capacity']} units/month for bulk procurement',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B5E57)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Price
                  Row(
                    children: [
                      Text(
                        formatInr(price),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryTerracotta,
                        ),
                      ),
                      const Text(
                        ' per unit',
                        style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: stock > 0
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          stock > 0 ? '✓ In Stock ($stock)' : '✗ Out of Stock',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: stock > 0
                                ? AppTheme.successGreen
                                : AppTheme.warningRed,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: AppTheme.borderGrey),
                  const SizedBox(height: 16),

                  // Description
                  const Text(
                    'About this Product',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkIndigo,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    desc.isNotEmpty ? desc : 'Handcrafted with care by skilled artisans.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4B5563),
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Quantity selector
                  Row(
                    children: [
                      const Text(
                        'Quantity:',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkIndigo,
                        ),
                      ),
                      const Spacer(),
                      _QuantityButton(
                        icon: Icons.remove_rounded,
                        onPressed: _quantity > 1
                            ? () => setState(() => _quantity--)
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '$_quantity',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.darkIndigo,
                          ),
                        ),
                      ),
                      _QuantityButton(
                        icon: Icons.add_rounded,
                        onPressed: () => setState(() => _quantity++),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.bgParchment,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Subtotal:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        Text(
                          formatInr(price * _quantity),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryTerracotta,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Action Buttons ──────────────────────────────────────────────
                  ElevatedButton.icon(
                    icon: _orderingNow
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.shopping_cart_checkout_rounded),
                    label: Text(_orderingNow ? 'Placing Order…' : '🛒 Order Now'),
                    onPressed: _orderingNow || stock == 0 ? null : _placeOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // WhatsApp AI Promo Share Button
                  ElevatedButton.icon(
                    icon: _isGeneratingPromo
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.chat_bubble_outline_rounded),
                    label: Text(_isGeneratingPromo ? 'Generating AI Caption…' : '📲 Share to WhatsApp (AI Promo)'),
                    onPressed: _isGeneratingPromo ? null : _shareToWhatsApp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    icon: const Icon(Icons.request_quote_rounded),
                    label: const Text('📋 Request Quote (RFQ)'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RfqScreen(prefilledProduct: p),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    icon: const Icon(Icons.compare_arrows_rounded),
                    label: const Text('🔍 Find & Compare Suppliers'),
                    onPressed: () async {
                      final nav = Navigator.of(context);
                      final matches = await BuyerService.instance.matchSuppliers(
                        category: category,
                        quantity: _quantity,
                        budget: price * _quantity * 2,
                        region: region,
                      );
                      if (!mounted) return;
                      nav.push(
                        MaterialPageRoute(
                          builder: (_) => SupplierComparisonScreen(
                            matches: matches,
                            requirement: {
                              'category': category,
                              'quantity': _quantity,
                              'budget': price * _quantity * 2,
                            },
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.inTransitBlue,
                      side: const BorderSide(color: AppTheme.inTransitBlue, width: 2),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Digital Craft Passport with QR Code ────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFEADBCE), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFE8F5E9),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.verified_rounded, color: Color(0xFF2E7D32), size: 18),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Digital Craft Passport',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: Color(0xFF2C221E),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Scan this QR code to verify GI certification, artisan heritage story, and authentic sustainable materials.',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF6B5E57), height: 1.4),
                                  ),
                                  const SizedBox(height: 10),
                                  TextButton.icon(
                                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                    label: const Text('View Web Certificate', style: TextStyle(fontWeight: FontWeight.w700)),
                                    onPressed: _showPassportPreviewDialog,
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.primaryTerracotta,
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // QR Code
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE5DDD5)),
                              ),
                              child: QrImageView(
                                data: passportUrl,
                                version: QrVersions.auto,
                                size: 92,
                                backgroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: AppTheme.primaryTerracotta.withValues(alpha: 0.1),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.palette_rounded, size: 72,
                color: AppTheme.primaryTerracotta),
            SizedBox(height: 8),
            Text('🏺', style: TextStyle(fontSize: 40)),
          ],
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  const _QuantityButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.borderGrey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: AppTheme.darkIndigo),
      ),
    );
  }
}
