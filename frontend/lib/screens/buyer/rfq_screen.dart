import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/rfq_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/buyer_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import 'supplier_comparison_screen.dart';

/// RFQ creation screen.
///
/// The buyer can type a free-text requirement (e.g. "I need 200 cotton sarees
/// for a retail chain by next month, budget ₹50,000"). The text is sent to
/// the backend which uses Gemini to parse it into a structured RFQ. The buyer
/// reviews the AI-structured result and confirms.
class RfqScreen extends StatefulWidget {
  /// Optional pre-filled product info from product detail screen.
  final Map<String, dynamic>? prefilledProduct;

  const RfqScreen({super.key, this.prefilledProduct});

  @override
  State<RfqScreen> createState() => _RfqScreenState();
}

class _RfqScreenState extends State<RfqScreen> {
  final TextEditingController _controller = TextEditingController();
  RfqModel? _parsedRfq;
  bool _isLoading = false;
  bool _confirmed = false;
  String? _error;

  static const List<String> _suggestions = [
    '200 cotton sarees for my retail chain by next month, budget ₹50,000',
    '50 terracotta diyas for Diwali corporate gifts, under ₹15,000',
    '100 hand-embroidered cushion covers for home décor export',
    '20 silver Dhokra necklaces for a boutique jewelry store',
    '500 handwoven stoles for a fashion brand, natural dyes only',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.prefilledProduct != null) {
      final p = widget.prefilledProduct!;
      _controller.text =
          'I need some ${p['title'] ?? 'products'} from ${p['region'] ?? 'India'}. '
          'Category: ${p['category'] ?? ''}. Budget around '
          '₹${((p['price'] as num?)?.toDouble() ?? 0) * 10}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generateRfq() async {
    final text = _controller.text.trim();
    if (text.length < 10) {
      setState(() => _error = 'Please describe your requirement in more detail.');
      return;
    }
    final user = context.read<AppAuthProvider>().userModel;
    if (user == null) return;

    setState(() { _isLoading = true; _error = null; _parsedRfq = null; _confirmed = false; });

    final raw = await BuyerService.instance.createRfq(
      buyerId:         user.uid,
      requirementText: text,
    );
    if (!mounted) return;
    if (raw != null) {
      setState(() {
        _parsedRfq = RfqModel.fromJson(raw);
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = 'Could not parse requirement. Please try again or check backend.';
        _isLoading = false;
      });
    }
  }

  Future<void> _findSuppliers() async {
    if (_parsedRfq == null) return;
    setState(() => _isLoading = true);
    final matches = await BuyerService.instance.matchSuppliers(
      category: _parsedRfq!.category,
      quantity: _parsedRfq!.quantity,
      budget:   _parsedRfq!.estimatedBudget,
      region:   '',
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupplierComparisonScreen(
          matches: matches,
          requirement: _parsedRfq!.toJson(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgParchment,
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const AppBackButton() : null,
        title: const Text('📋 Request for Quotation'),
        backgroundColor: AppTheme.primaryTerracotta,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Explainer card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.darkIndigo, Color(0xFF2C3258)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        color: AppTheme.secondaryOchre, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI-Powered RFQ Generator',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Describe what you need in plain language. Our AI will structure it into a professional quotation request.',
                          style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Requirement text input
            const Text(
              'Describe Your Requirement',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.darkIndigo,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Include: what you need, quantity, budget, and deadline',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),

            Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(16),
              child: TextField(
                controller: _controller,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText:
                      'e.g. "I need 200 cotton sarees for my retail chain by next month, budget around ₹50,000"',
                  hintStyle: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 13,
                    height: 1.5,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Quick suggestion chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _suggestions.map((s) {
                final short = s.length > 40 ? '${s.substring(0, 40)}…' : s;
                return ActionChip(
                  label: Text(short,
                      style: const TextStyle(fontSize: 11)),
                  onPressed: () => _controller.text = s,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppTheme.borderGrey),
                );
              }).toList(),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.warningRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppTheme.warningRed, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                            color: AppTheme.warningRed, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            ElevatedButton.icon(
              icon: _isLoading && _parsedRfq == null
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_isLoading && _parsedRfq == null
                  ? 'Generating RFQ…'
                  : '✨ Generate RFQ with AI'),
              onPressed: _isLoading ? null : _generateRfq,
            ),

            // ── Parsed RFQ result ────────────────────────────────────────
            if (_parsedRfq != null) ...[
              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 16),

              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: AppTheme.secondaryOchre, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'AI-Structured RFQ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkIndigo,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'AI Parsed ✓',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.successGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _RfqCard(rfq: _parsedRfq!),

              const SizedBox(height: 20),

              if (!_confirmed) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('✅ Confirm & Find Matching Suppliers'),
                  onPressed: _isLoading ? null : () {
                    setState(() => _confirmed = true);
                    _findSuppliers();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit Requirement'),
                  onPressed: () => setState(() { _parsedRfq = null; _confirmed = false; }),
                ),
              ] else if (_isLoading) ...[
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: AppTheme.primaryTerracotta),
                      SizedBox(height: 12),
                      Text('Finding best matching artisans…',
                          style: TextStyle(color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
              ],
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _RfqCard extends StatelessWidget {
  final RfqModel rfq;
  const _RfqCard({required this.rfq});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _row(Icons.category_rounded, 'Category', rfq.category),
          _divider(),
          _row(Icons.numbers_rounded, 'Quantity',
              '${rfq.quantity} units'),
          _divider(),
          _row(Icons.currency_rupee_rounded, 'Target Price/Unit',
              '₹${rfq.targetPrice.toStringAsFixed(0)}'),
          _divider(),
          _row(Icons.account_balance_wallet_rounded, 'Est. Total Budget',
              '₹${rfq.estimatedBudget.toStringAsFixed(0)}'),
          _divider(),
          _row(Icons.calendar_today_rounded, 'Deadline', rfq.deadline),
          _divider(),
          _row(Icons.tune_rounded, 'Specifications',
              rfq.specifications.isNotEmpty ? rfq.specifications : '—'),
          _divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.description_rounded,
                    color: AppTheme.primaryTerracotta, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rfq.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.darkIndigo,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryTerracotta, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkIndigo,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      const Divider(height: 1, color: AppTheme.borderGrey, indent: 16, endIndent: 16);
}
