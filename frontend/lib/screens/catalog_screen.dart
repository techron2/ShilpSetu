import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/product_provider.dart';
import '../theme/app_theme.dart';
import 'artisan/photo_capture_screen.dart';
import 'artisan/product_detail_screen.dart';

/// Catalog screen ("शिल्प सूची") for artisans.
///
/// Queries and displays real products from Firestore via [ProductProvider].
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchIfEmpty();
    });
  }

  void _fetchIfEmpty() {
    final provider = context.read<ProductProvider>();
    if (provider.products.isEmpty && !provider.isLoading) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final auth = context.read<AppAuthProvider>();
    final artisanId = auth.currentArtisanId;
    await context.read<ProductProvider>().fetchProducts(artisanId: artisanId);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bgParchment,
      body: Consumer<ProductProvider>(
        builder: (context, provider, _) {
          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppTheme.primaryTerracotta,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── AI Camera Scan CTA ────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.secondaryOchre.withValues(alpha: 0.7),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.secondaryOchre.withValues(alpha: 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryOchre.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_enhance_rounded,
                                color: AppTheme.secondaryOchre,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lang.getText('catalog_smart_scan_title'),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.darkIndigo,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    lang.getText('catalog_smart_scan_desc'),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF6B7280),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryTerracotta,
                            minimumSize: const Size(double.infinity, 52),
                          ),
                          icon: const Icon(Icons.add_a_photo, size: 22),
                          label: Text(
                            lang.getText('catalog_smart_scan_btn'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          onPressed: () async {
                            final added = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(builder: (_) => const PhotoCaptureScreen()),
                            );
                            if (added == true || context.mounted) {
                              _refresh();
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Catalog Header ────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        lang.getText('catalog_header'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkIndigo,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryTerracotta.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${provider.products.length} ${lang.getText('catalog_count_suffix')}",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryTerracotta,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Products Content ──────────────────────────────────────
                  if (provider.isLoading && provider.products.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(color: AppTheme.primaryTerracotta),
                      ),
                    )
                  else if (provider.errorMessage != null && provider.products.isEmpty)
                    _buildErrorState(context, provider.errorMessage!)
                  else if (provider.products.isEmpty)
                    _buildEmptyState(context)
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: provider.products.length,
                      itemBuilder: (context, index) {
                        final product = provider.products[index];
                        return _buildProductCard(context, product);
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(
                productId: product.id,
                initialProduct: product,
              ),
            ),
          );
          if (changed == true || context.mounted) {
            _refresh();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product thumbnail image / craft fallback
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: product.imageUrl.isNotEmpty
                      ? Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => _buildPlaceholderImage(product.category),
                        )
                      : _buildPlaceholderImage(product.category),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkIndigo,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        product.category,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4B5563),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '₹${product.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryTerracotta,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFC8E6C9)),
                          ),
                          child: Text(
                            '${product.stockQuantity} ${context.watch<LanguageProvider>().getText('stock_available')}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.successGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(String category) {
    IconData icon = Icons.palette_rounded;
    final cat = category.toLowerCase();
    if (cat.contains('pottery') || cat.contains('clay')) {
      icon = Icons.coffee_rounded;
    } else if (cat.contains('textile') || cat.contains('fabric') || cat.contains('saree')) {
      icon = Icons.dry_cleaning_rounded;
    } else if (cat.contains('painting') || cat.contains('art')) {
      icon = Icons.brush_rounded;
    } else if (cat.contains('metal') || cat.contains('brass')) {
      icon = Icons.pets_rounded;
    } else if (cat.contains('jewel') || cat.contains('accessories')) {
      icon = Icons.diamond_rounded;
    }

    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: AppTheme.secondaryOchre.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: Icon(
        icon,
        color: AppTheme.secondaryOchre,
        size: 32,
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              'त्रुटि: उत्पाद लोड नहीं हो सके\n($error)',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('पुनः प्रयास करें (Retry)'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTerracotta),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.secondaryOchre.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 56,
                color: AppTheme.secondaryOchre,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              lang.getText('no_products'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkIndigo,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              lang.getText('catalog_smart_scan_desc'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}
