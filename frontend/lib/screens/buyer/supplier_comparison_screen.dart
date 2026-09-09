import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import 'buyer_product_detail_screen.dart';
import 'chat_screen.dart';

/// Side-by-side supplier/product comparison screen.
/// Shows up to 3 matched artisans from the /api/matching/buyer-supplier endpoint.
class SupplierComparisonScreen extends StatelessWidget {
  final List<Map<String, dynamic>> matches;
  final Map<String, dynamic> requirement;

  const SupplierComparisonScreen({
    super.key,
    required this.matches,
    required this.requirement,
  });

  @override
  Widget build(BuildContext context) {
    final displayMatches = matches.take(3).toList();

    return Scaffold(
      backgroundColor: AppTheme.bgParchment,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('🔍 Matched Suppliers'),
        backgroundColor: AppTheme.primaryTerracotta,
        foregroundColor: Colors.white,
      ),
      body: displayMatches.isEmpty
          ? _emptyState()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Requirement summary
                  _RequirementBanner(requirement: requirement),
                  const SizedBox(height: 20),

                  const Text(
                    'Best Matching Artisans',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkIndigo,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${displayMatches.length} supplier${displayMatches.length > 1 ? 's' : ''} found via AI matching',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 16),

                  // Side-by-side cards (or stacked if 3)
                  if (displayMatches.length <= 2)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: displayMatches
                          .map((m) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: _SupplierCard(match: m),
                                ),
                              ))
                          .toList(),
                    )
                  else ...[
                    // Top match — full width
                    _SupplierCard(match: displayMatches[0], highlighted: true),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _SupplierCard(match: displayMatches[1])),
                        const SizedBox(width: 10),
                        Expanded(child: _SupplierCard(match: displayMatches[2])),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Comparison table
                  if (displayMatches.length > 1) ...[
                    const Text(
                      'Comparison Table',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.darkIndigo,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ComparisonTable(matches: displayMatches),
                    const SizedBox(height: 40),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            const Text(
              'No matching suppliers found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try a different category or add more products to the catalog.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequirementBanner extends StatelessWidget {
  final Map<String, dynamic> requirement;
  const _RequirementBanner({required this.requirement});

  @override
  Widget build(BuildContext context) {
    final category = requirement['category']?.toString() ?? '';
    final quantity = requirement['quantity']?.toString() ?? '';
    final budget   = (requirement['budget'] as num?)?.toDouble() ?? 0;
    final region   = requirement['region']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.darkIndigo,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Requirement',
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (category.isNotEmpty) _chip('🏷️ $category'),
              if (quantity.isNotEmpty) _chip('📦 $quantity units'),
              if (budget > 0) _chip('💰 ₹${budget.toStringAsFixed(0)} budget'),
              if (region.isNotEmpty) _chip('📍 $region'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SupplierCard extends StatelessWidget {
  final Map<String, dynamic> match;
  final bool highlighted;

  const _SupplierCard({required this.match, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final product = match['product'] as Map<String, dynamic>? ?? {};
    final artisan = match['artisan'] as Map<String, dynamic>? ?? {};
    final rank    = match['rank'] as int? ?? 1;
    final score   = (match['similarity_score'] as num?)?.toDouble() ?? 0;

    final title     = product['title']?.toString() ?? 'Product';
    final price     = (product['price'] as num?)?.toDouble() ?? 0;
    final stock     = (product['stock_quantity'] as num?)?.toInt() ?? 0;
    final name      = artisan['name']?.toString() ?? 'Artisan';
    final region    = artisan['region']?.toString() ?? '';
    final rating    = (artisan['rating'] as num?)?.toDouble() ?? 4.0;
    final artisanId = artisan['id']?.toString() ?? '';

    return Container(
      margin: highlighted ? const EdgeInsets.only(bottom: 4) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted ? AppTheme.primaryTerracotta : AppTheme.borderGrey,
          width: highlighted ? 2 : 1,
        ),
        boxShadow: highlighted
            ? [BoxShadow(
                color: AppTheme.primaryTerracotta.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4))]
            : [BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rank badge + header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: highlighted
                  ? AppTheme.primaryTerracotta.withValues(alpha: 0.08)
                  : const Color(0xFFF9FAFB),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: highlighted
                      ? AppTheme.primaryTerracotta
                      : const Color(0xFF6B7280),
                  child: Text(
                    '#$rank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: highlighted ? AppTheme.primaryTerracotta : AppTheme.darkIndigo,
                    ),
                  ),
                ),
                if (highlighted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTerracotta,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'BEST MATCH',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product title
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
                const SizedBox(height: 8),

                // Price
                _infoRow(Icons.currency_rupee_rounded, '₹${price.toStringAsFixed(0)}/unit',
                    AppTheme.primaryTerracotta),

                // Region
                if (region.isNotEmpty)
                  _infoRow(Icons.location_on_rounded, region, AppTheme.inTransitBlue),

                // Stock
                _infoRow(Icons.inventory_2_rounded, '$stock in stock',
                    stock > 50 ? AppTheme.successGreen : AppTheme.warningRed),

                // Rating
                Row(
                  children: [
                    ...List.generate(5, (i) => Icon(
                      i < rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: AppTheme.secondaryOchre, size: 14,
                    )),
                    const SizedBox(width: 4),
                    Text(rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                  ],
                ),

                const SizedBox(height: 4),

                // Similarity score
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'AI Match: ${(score * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.successGreen,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 34,
                        child: ElevatedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BuyerProductDetailScreen(product: product),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryTerracotta,
                            foregroundColor: Colors.white,
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                          child: const Text('View'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SizedBox(
                        height: 34,
                        child: OutlinedButton(
                          onPressed: () {
                            final user = context.read<AppAuthProvider>().userModel;
                            if (user == null || artisanId.isEmpty) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  currentUserId: user.uid,
                                  currentUserName: user.name,
                                  otherUserId: artisanId,
                                  otherUserName: name,
                                  isCurrentUserArtisan: false,
                                ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            side: const BorderSide(color: AppTheme.inTransitBlue),
                            foregroundColor: AppTheme.inTransitBlue,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                          child: const Text('Chat'),
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
    );
  }

  Widget _infoRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  final List<Map<String, dynamic>> matches;
  const _ComparisonTable({required this.matches});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['', ...matches.map((m) {
        final a = m['artisan'] as Map? ?? {};
        return a['name']?.toString() ?? 'Artisan';
      })],
      ['Price/unit', ...matches.map((m) {
        final p = m['product'] as Map? ?? {};
        final price = (p['price'] as num?)?.toDouble() ?? 0;
        return '₹${price.toStringAsFixed(0)}';
      })],
      ['In Stock', ...matches.map((m) {
        final p = m['product'] as Map? ?? {};
        return '${(p['stock_quantity'] as num?)?.toInt() ?? 0}';
      })],
      ['Region', ...matches.map((m) {
        final a = m['artisan'] as Map? ?? {};
        return a['region']?.toString() ?? '—';
      })],
      ['Rating', ...matches.map((m) {
        final a = m['artisan'] as Map? ?? {};
        final r = (a['rating'] as num?)?.toDouble() ?? 4.0;
        return '⭐ ${r.toStringAsFixed(1)}';
      })],
      ['AI Match', ...matches.map((m) {
        final s = (m['similarity_score'] as num?)?.toDouble() ?? 0;
        return '${(s * 100).toStringAsFixed(0)}%';
      })],
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: Table(
        border: TableBorder.symmetric(
          inside: const BorderSide(color: AppTheme.borderGrey, width: 0.5),
        ),
        columnWidths: const {0: FlexColumnWidth(1.4)},
        children: rows.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          return TableRow(
            decoration: BoxDecoration(
              color: i == 0
                  ? AppTheme.darkIndigo
                  : (i % 2 == 0 ? const Color(0xFFFAFAFA) : Colors.white),
              borderRadius: i == 0
                  ? const BorderRadius.vertical(top: Radius.circular(13))
                  : null,
            ),
            children: row.asMap().entries.map((e) {
              final isHeader = i == 0;
              final isLabel = e.key == 0 && i > 0;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Text(
                  e.value,
                  textAlign: e.key == 0 ? TextAlign.left : TextAlign.center,
                  style: TextStyle(
                    color: isHeader ? Colors.white : AppTheme.darkIndigo,
                    fontWeight: (isHeader || isLabel)
                        ? FontWeight.w700
                        : FontWeight.w500,
                    fontSize: isHeader ? 11 : 12,
                  ),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}
