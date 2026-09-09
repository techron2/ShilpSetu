import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/buyer_service.dart';
import '../../theme/app_theme.dart';
import 'buyer_product_detail_screen.dart';

/// Buyer home screen with product search, category chips, and product grid.
class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _categories = [
    'All', 'Textiles', 'Pottery', 'Jewelry', 'Embroidery',
    'Woodwork', 'Leather', 'Painting', 'Metalwork',
  ];
  String _selectedCategory = 'All';
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() { _isLoading = true; });
    final results = await BuyerService.instance.searchProducts(limit: 50);
    if (mounted) {
      setState(() {
        _products = results;
        _isLoading = false;
        _hasSearched = true;
      });
    }
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    final cat   = _selectedCategory == 'All' ? '' : _selectedCategory;
    setState(() { _isLoading = true; _hasSearched = true; });
    final results = await BuyerService.instance.searchProducts(
      query: query,
      category: cat,
    );
    if (mounted) {
      setState(() { _products = results; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppAuthProvider>().userModel;
    final name = user?.name ?? 'Buyer';

    return Scaffold(
      backgroundColor: AppTheme.bgParchment,
      body: CustomScrollView(
        slivers: [
          // ── Decorative SliverAppBar ───────────────────────────────────
          SliverAppBar(
            expandedHeight: 170,
            pinned: true,
            backgroundColor: AppTheme.primaryTerracotta,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryTerracotta, Color(0xFFC25A47)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.white24,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.shopping_bag_outlined,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'नमस्ते, $name 🛍️',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Discover authentic Indian handicrafts',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(30),
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: 'Search sarees, pottery, jewelry…',
                      hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryTerracotta),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _loadAll();
                              },
                            ),
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryTerracotta,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Search',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      // Override global theme for this specific search field (no label needed)
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Category chips ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final cat = _categories[i];
                  final selected = cat == _selectedCategory;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategory = cat);
                      _search();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.primaryTerracotta : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? AppTheme.primaryTerracotta
                              : AppTheme.borderGrey,
                        ),
                        boxShadow: selected
                            ? [BoxShadow(
                                color: AppTheme.primaryTerracotta.withValues(alpha: 0.25),
                                blurRadius: 6, offset: const Offset(0, 2))]
                            : [],
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: selected ? Colors.white : const Color(0xFF4B5563),
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── Results header ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Text(
                    _hasSearched
                        ? '${_products.length} products found'
                        : 'All Products',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                  const Spacer(),
                  if (_isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryTerracotta,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Product grid ─────────────────────────────────────────────
          _isLoading && _products.isEmpty
              ? const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryTerracotta),
                  ),
                )
              : _products.isEmpty && _hasSearched
                  ? SliverFillRemaining(
                      child: _emptyState(),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.72,   // slightly wider for content breathing room
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _ProductCard(product: _products[index]),
                          childCount: _products.length,
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.secondaryOchre.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 56,
              color: AppTheme.secondaryOchre,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No products found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkIndigo,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try a different keyword or category',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Show all products'),
            onPressed: _loadAll,
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final title    = product['title']?.toString() ?? 'Product';
    final price    = (product['price'] as num?)?.toDouble() ?? 0;
    final category = product['category']?.toString() ?? '';
    final rating   = (product['rating'] as num?)?.toDouble() ?? 4.0;
    final imageUrl = product['image_url']?.toString() ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BuyerProductDetailScreen(product: product),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderGrey),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.primaryTerracotta.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholderIcon(),
                        ),
                      )
                    : _placeholderIcon(),
              ),
            ),

            // Product Info
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category badge — minimum 12px
                    if (category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryOchre.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            fontSize: 12,            // was 9 — fixed
                            fontWeight: FontWeight.w700,
                            color: AppTheme.secondaryOchre,
                          ),
                        ),
                      ),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkIndigo,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Rating row — minimum 12px
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFD4AF37), size: 14),
                        const SizedBox(width: 2),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,            // was 11
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '🛡️ Verified',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.successGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryTerracotta,
                          ),
                        ),
                        // Cluster badge — raised to 11px
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F1DC),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFD4AF37), width: 0.8),
                          ),
                          child: const Text(
                            '🌿 Cluster',
                            style: TextStyle(
                              fontSize: 11,           // was 8 — fixed
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8C6E14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderIcon() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.palette_rounded,
              size: 36, color: AppTheme.primaryTerracotta.withValues(alpha: 0.4)),
          const SizedBox(height: 4),
          const Text('🏺', style: TextStyle(fontSize: 24)),
        ],
      ),
    );
  }
}
