import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../providers/product_provider.dart';
import '../../services/product_service_factory.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import 'add_product_screen.dart';

/// Full Product Detail screen for artisans.
/// Displays high-res product photo, bilingual title/description switcher,
/// price, stock, key craft features, human-formatted date, and Edit/Delete actions.
class ProductDetailScreen extends StatefulWidget {
  final String productId;
  final Product? initialProduct;

  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.initialProduct,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? _product;
  bool _isLoading = false;
  String? _errorMessage;
  int _selectedLangTab = 0; // 0: Hindi, 1: English

  @override
  void initState() {
    super.initState();
    _product = widget.initialProduct;
    if (_product == null) {
      _fetchProductDetails();
    }
  }

  Future<void> _fetchProductDetails() async {
    // If no initial product or to refresh latest data from GET /api/products/<id>
    if (_product == null) {
      setState(() => _isLoading = true);
    }
    try {
      final service = ProductServiceFactory.create();
      final fetched = await service.getProduct(widget.productId);
      if (mounted) {
        setState(() {
          if (fetched != null) {
            _product = fetched;
          }
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_product == null) {
            _errorMessage = 'उत्पाद विवरण लोड करने में समस्या आई: $e';
          }
        });
      }
    }
  }

  String _formatReadableDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return 'हाल ही में जोड़ा गया (Recently added)';
    try {
      final dt = DateTime.parse(rawDate).toLocal();
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final month = months[dt.month - 1];
      final day = dt.day.toString().padLeft(2, '0');
      final year = dt.year;
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$day $month $year, $hour:$minute $ampm';
    } catch (_) {
      return rawDate;
    }
  }

  Map<String, String> _parseBilingualText(String text) {
    if (text.contains('[English]:')) {
      final parts = text.split('[English]:');
      return {
        'hi': parts[0].replaceAll('[Hindi]:', '').trim(),
        'en': parts.length > 1 ? parts[1].trim() : '',
      };
    } else if (text.contains('\n\nEnglish:')) {
      final parts = text.split('\n\nEnglish:');
      return {
        'hi': parts[0].trim(),
        'en': parts.length > 1 ? parts[1].trim() : '',
      };
    }
    return {'hi': text.trim(), 'en': text.trim()};
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Text('उत्पाद हटाएं? (Delete?)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: Text(
          'क्या आप वाकई "${_product?.title ?? 'यह उत्पाद'}" को अपनी दुकान से हटाना चाहते हैं?\n\n(Are you sure you want to permanently delete this product listing?)',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('रद्द करें (Cancel)', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('हाँ, हटाएं (Delete)', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final ok = await context.read<ProductProvider>().deleteProduct(widget.productId);
      if (mounted) {
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ उत्पाद सफलतापूर्वक हटा दिया गया (Product Deleted)'),
              backgroundColor: AppTheme.darkIndigo,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true); // Return to MyProductsScreen and refresh
        } else {
          final err = context.read<ProductProvider>().errorMessage;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err ?? 'हटाने में समस्या आई'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleEdit() async {
    if (_product == null) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(productToEdit: _product),
      ),
    );
    if (updated == true && mounted) {
      await _fetchProductDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _product == null) {
      return Scaffold(
        backgroundColor: AppTheme.bgParchment,
        appBar: AppBar(
          leading: const AppBackButton(),
          title: const Text('उत्पाद विवरण (Product Detail)'),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryTerracotta),
        ),
      );
    }

    if (_product == null) {
      return Scaffold(
        backgroundColor: AppTheme.bgParchment,
        appBar: AppBar(
          leading: const AppBackButton(),
          title: const Text('उत्पाद विवरण (Product Detail)'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 60, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(_errorMessage ?? 'उत्पाद नहीं मिला (Product not found)', textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _fetchProductDetails,
                  icon: const Icon(Icons.refresh),
                  label: const Text('पुनः प्रयास करें (Retry)'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final p = _product!;
    final bilingualDesc = _parseBilingualText(p.description);
    final bilingualTitle = _parseBilingualText(p.title);

    return Scaffold(
      backgroundColor: AppTheme.bgParchment,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('उत्पाद विवरण (Product Detail)'),
        backgroundColor: AppTheme.primaryTerracotta,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'ताज़ा करें (Refresh)',
            onPressed: _fetchProductDetails,
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Colors.white),
            tooltip: 'संपादित करें (Edit)',
            onPressed: _handleEdit,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          children: [
            // ── Large Product Hero Image Card ──────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 1.15,
                      child: p.imageUrl.isNotEmpty
                          ? Image.network(
                              p.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => _imageFallback(),
                              loadingBuilder: (ctx, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  color: AppTheme.bgParchment,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: AppTheme.primaryTerracotta,
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                );
                              },
                            )
                          : _imageFallback(),
                    ),
                    // Studio Enhanced Badge Overlay
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.darkIndigo.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.auto_awesome, color: AppTheme.secondaryOchre, size: 15),
                            SizedBox(width: 6),
                            Text(
                              '✨ AI Studio Enhanced',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // ── Main Details Card (Title, Category, Price & Stock) ──────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderGrey),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Pill & Artisan ID
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryTerracotta.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.category_outlined, size: 14, color: AppTheme.primaryTerracotta),
                            const SizedBox(width: 5),
                            Text(
                              p.category,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryTerracotta,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'ID: ${p.id.length > 8 ? p.id.substring(0, 8) : p.id}',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500, fontFamily: 'monospace'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Title (Hindi & English)
                  Text(
                    _selectedLangTab == 0 ? bilingualTitle['hi']! : bilingualTitle['en']!,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.darkIndigo,
                      height: 1.3,
                    ),
                  ),

                  const Divider(height: 24, thickness: 1, color: AppTheme.borderGrey),

                  // Price & Stock Banner
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'विक्रय मूल्य (Price)',
                            style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${p.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primaryTerracotta,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: p.stockQuantity > 0 ? const Color(0xFFE8F5E9) : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: p.stockQuantity > 0 ? const Color(0xFFC8E6C9) : Colors.red.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.inventory_2_rounded,
                              size: 18,
                              color: p.stockQuantity > 0 ? const Color(0xFF2E7D32) : Colors.redAccent,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${p.stockQuantity} उपलब्ध',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: p.stockQuantity > 0 ? const Color(0xFF1B5E20) : Colors.redAccent,
                                  ),
                                ),
                                Text(
                                  p.stockQuantity > 0 ? 'In Stock' : 'Out of Stock',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: p.stockQuantity > 0 ? const Color(0xFF388E3C) : Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── Bilingual Description Card with Tab Switcher ──────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderGrey),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '📜 शिल्प का विवरण (Description)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkIndigo,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Language Switcher Pills
                  Row(
                    children: [
                      Expanded(
                        child: _langTabPill(
                          index: 0,
                          label: '🇮🇳 हिंदी (Hindi)',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _langTabPill(
                          index: 1,
                          label: '🌐 English',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Description Body
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.bgParchment,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderGrey),
                    ),
                    child: Text(
                      _selectedLangTab == 0
                          ? (bilingualDesc['hi']!.isNotEmpty ? bilingualDesc['hi']! : p.description)
                          : (bilingualDesc['en']!.isNotEmpty ? bilingualDesc['en']! : p.description),
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.55,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── Key Features / Heritage Highlights ──────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFFDFBF7),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.secondaryOchre.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.verified_rounded, color: AppTheme.secondaryOchre, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '✨ शिल्प की विशेषताएं (Craft Highlights)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkIndigo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureBullet('100% पारंपरिक हस्तशिल्प और प्राकृतिक सामग्री (100% Handcrafted)'),
                  _buildFeatureBullet('शिल्पकार द्वारा सीधा प्रमाणित उत्पाद (Direct Artisan Sourced)'),
                  _buildFeatureBullet('पर्यावरण अनुकूल एवं टिकाऊ कला (Eco-friendly & Sustainable)'),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── Creation Metadata ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderGrey),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: Colors.grey),
                  const SizedBox(width: 10),
                  Text(
                    'जोड़ा गया: ${_formatReadableDate(p.createdAt)}',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // ── Persistent Action Bar (Edit & Delete) ─────────────────────────────
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Delete Button
              Expanded(
                flex: 4,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent, width: 1.5),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  label: const Text(
                    'हटाएं (Delete)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  onPressed: _handleDelete,
                ),
              ),
              const SizedBox(width: 12),
              // Edit Button
              Expanded(
                flex: 6,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTerracotta,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  label: const Text(
                    'संपादित करें (Edit)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  onPressed: _handleEdit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _langTabPill({required int index, required String label}) {
    final isSelected = _selectedLangTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedLangTab = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.darkIndigo : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.darkIndigo : AppTheme.borderGrey,
            width: 1.2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppTheme.darkIndigo,
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppTheme.successGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppTheme.darkIndigo, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: AppTheme.bgParchment,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.image_outlined, size: 60, color: AppTheme.secondaryOchre),
          SizedBox(height: 8),
          Text('शिल्प फोटो (Handicraft Photo)', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}
