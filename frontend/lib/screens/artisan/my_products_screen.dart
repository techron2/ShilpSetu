import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import 'add_product_screen.dart';
import 'product_detail_screen.dart';

/// Displays all products belonging to the currently signed-in artisan.
class MyProductsScreen extends StatefulWidget {
  const MyProductsScreen({super.key});

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen> {
  @override
  void initState() {
    super.initState();
    // Load products when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth    = context.read<AppAuthProvider>();
      final artisanId = auth.firebaseUser?.uid ?? 'artisan_001'; // mock fallback
      context.read<ProductProvider>().fetchProducts(artisanId: artisanId);
    });
  }

  Future<void> _refresh() async {
    final auth     = context.read<AppAuthProvider>();
    final artisanId = auth.firebaseUser?.uid ?? 'artisan_001';
    await context.read<ProductProvider>().fetchProducts(artisanId: artisanId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgParchment,
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const AppBackButton() : null,
        title: const Text('My Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AddProductScreen()),
          );
          if (added == true) _refresh();
        },
        backgroundColor: AppTheme.primaryTerracotta,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Product',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Consumer<ProductProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryTerracotta),
            );
          }
          if (provider.errorMessage != null) {
            return _ErrorView(
              message: provider.errorMessage!,
              onRetry: _refresh,
            );
          }
          if (provider.products.isEmpty) {
            return _EmptyView(
              onAdd: () async {
                final added = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const AddProductScreen()),
                );
                if (added == true) _refresh();
              },
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppTheme.primaryTerracotta,
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 100),
              itemCount: provider.products.length,
              itemBuilder: (context, i) =>
                  _ProductCard(
                    product: provider.products[i],
                    onRefresh: _refresh,
                  ),
            ),
          );
        },
      ),
    );
  }
}

// ── Product card ─────────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onRefresh});
  final Product product;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
            onRefresh();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image / placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: product.imageUrl.isNotEmpty
                  ? Image.network(
                      product.imageUrl,
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
            ),
            const SizedBox(width: 14),

            // Text info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontSize: 15),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  _chip(product.category),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '₹${product.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryTerracotta,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.inventory_2_outlined,
                          size: 15,
                          color: AppTheme.darkIndigo.withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Text(
                        '${product.stockQuantity} in stock',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Delete button
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent.withValues(alpha: 0.8)),
              onPressed: () => _confirmDelete(context),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _imagePlaceholder() {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: AppTheme.bgParchment,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.image_outlined,
          size: 36, color: AppTheme.secondaryOchre),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.secondaryOchre.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: AppTheme.secondaryOchre,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Product?'),
        content: Text('Are you sure you want to delete "${product.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final ok =
          await context.read<ProductProvider>().deleteProduct(product.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Product deleted' : 'Could not delete product'),
            backgroundColor:
                ok ? AppTheme.successGreen : Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 80,
                color: AppTheme.secondaryOchre.withValues(alpha: 0.6)),
            const SizedBox(height: 20),
            Text('No products yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Add your first handicraft product and start selling on ShilpSetu!',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.darkIndigo.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add First Product'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
