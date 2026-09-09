import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/pricing_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';

const List<String> _kCategories = [
  'Pottery',
  'Textiles',
  'Painting',
  'Metal Craft',
  'Accessories',
  'Jewellery',
  'Wood Craft',
  'Other',
];

/// Step 3 of the AI Catalog Flow:
/// Review and edit the AI-generated bilingual (EN & HI) product listing.
class ListingReviewScreen extends StatefulWidget {
  final String imageUrl;
  final String initialTitleEn;
  final String initialTitleHi;
  final String initialDescEn;
  final String initialDescHi;
  final String initialCategory;
  final List<String> keyFeatures;
  final String transcript;

  const ListingReviewScreen({
    super.key,
    required this.imageUrl,
    required this.initialTitleEn,
    required this.initialTitleHi,
    required this.initialDescEn,
    required this.initialDescHi,
    required this.initialCategory,
    required this.keyFeatures,
    required this.transcript,
  });

  @override
  State<ListingReviewScreen> createState() => _ListingReviewScreenState();
}

class _ListingReviewScreenState extends State<ListingReviewScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleEnCtrl;
  late TextEditingController _titleHiCtrl;
  late TextEditingController _descEnCtrl;
  late TextEditingController _descHiCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _stockCtrl;
  late TextEditingController _materialCostCtrl;
  late String _selectedCategory;
  late List<String> _features;

  int _selectedLangTab = 0; // 0: Hindi (Primary for Artisan), 1: English

  final PricingService _pricingService = PricingService();
  bool _isLoadingPrice = true;
  int? _suggestedPrice;
  int? _priceRangeMin;
  int? _priceRangeMax;
  String? _priceExplanation;
  String _craftSize = 'medium';
  String _craftRegion = 'Uttar Pradesh';

  static const List<String> _kRegions = [
    'Uttar Pradesh',
    'Rajasthan',
    'Bihar',
    'Gujarat',
    'West Bengal',
    'Odisha',
    'Madhya Pradesh',
    'Karnataka',
    'Maharashtra',
    'Tamil Nadu',
    'Delhi',
  ];

  @override
  void initState() {
    super.initState();
    _titleEnCtrl = TextEditingController(text: widget.initialTitleEn);
    _titleHiCtrl = TextEditingController(text: widget.initialTitleHi);
    _descEnCtrl  = TextEditingController(text: widget.initialDescEn);
    _descHiCtrl  = TextEditingController(text: widget.initialDescHi);
    _priceCtrl   = TextEditingController(text: '');
    _stockCtrl   = TextEditingController(text: '10');

    _selectedCategory = _kCategories.contains(widget.initialCategory)
        ? widget.initialCategory
        : 'Pottery';
    _features = List<String>.from(widget.keyFeatures);

    final defaultMaterialCosts = {
      'Pottery': '60',
      'Textiles': '280',
      'Painting': '140',
      'Metal Craft': '450',
      'Wood Craft': '250',
      'Jewellery': '160',
      'Accessories': '120',
      'Other': '150',
    };
    _materialCostCtrl = TextEditingController(
      text: defaultMaterialCosts[_selectedCategory] ?? '80',
    );

    _fetchPriceSuggestion();
  }

  Future<void> _fetchPriceSuggestion() async {
    setState(() => _isLoadingPrice = true);
    final matCost = double.tryParse(_materialCostCtrl.text.trim());
    final res = await _pricingService.suggestPrice(
      category: _selectedCategory,
      materialCost: matCost,
      size: _craftSize,
      region: _craftRegion,
    );
    if (mounted) {
      setState(() {
        _isLoadingPrice = false;
        _suggestedPrice = (res['suggested_price'] as num?)?.round();
        _priceRangeMin = (res['price_range_min'] as num?)?.round();
        _priceRangeMax = (res['price_range_max'] as num?)?.round();
        _priceExplanation = res['explanation'] as String?;
        if (_suggestedPrice != null && (_priceCtrl.text.isEmpty || _priceCtrl.text == '350')) {
          _priceCtrl.text = _suggestedPrice.toString();
        }
      });
    }
  }

  @override
  void dispose() {
    _titleEnCtrl.dispose();
    _titleHiCtrl.dispose();
    _descEnCtrl.dispose();
    _descHiCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _materialCostCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AppAuthProvider>();
    final artisanId = auth.firebaseUser?.uid ?? 'artisan_001';

    // Build the final saved title & description
    // When Hindi tab is active, prioritize Hindi with English subtitle
    final title = _titleHiCtrl.text.trim().isNotEmpty
        ? _titleHiCtrl.text.trim()
        : _titleEnCtrl.text.trim();

    final desc = _descHiCtrl.text.trim().isNotEmpty
        ? '${_descHiCtrl.text.trim()}\n\n[English]: ${_descEnCtrl.text.trim()}'
        : _descEnCtrl.text.trim();

    final product = Product(
      id: '',
      artisanId: artisanId,
      title: title,
      description: desc,
      imageUrl: widget.imageUrl,
      price: double.tryParse(_priceCtrl.text.trim()) ?? 350.0,
      stockQuantity: int.tryParse(_stockCtrl.text.trim()) ?? 10,
      category: _selectedCategory,
    );

    final ok = await context.read<ProductProvider>().addProduct(product);

    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 उत्पाद सफलतापूर्वक बाज़ार में जुड़ गया! (Listing Saved!)'),
            backgroundColor: AppTheme.successGreen,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Pop all wizard screens back to the catalog root
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        final err = context.read<ProductProvider>().errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err ?? 'Failed to save product'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bgParchment,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('✨ समीक्षा एवं पुष्टि (Review Listing)'),
        backgroundColor: AppTheme.primaryTerracotta,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // Product Preview Header Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        widget.imageUrl,
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 90,
                          height: 90,
                          color: AppTheme.borderGrey,
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryTerracotta.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '✨ AI द्वारा तैयार (AI Generated)',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryTerracotta,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _selectedLangTab == 0
                                ? (_titleHiCtrl.text.isNotEmpty ? _titleHiCtrl.text : 'शीर्षक')
                                : (_titleEnCtrl.text.isNotEmpty ? _titleEnCtrl.text : 'Title'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.darkIndigo,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'श्रेणी: $_selectedCategory',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Transcript indicator (if voice was recorded)
              if (widget.transcript.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryOchre.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.secondaryOchre.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mic, color: AppTheme.secondaryOchre, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'बोलकर कहा: "${widget.transcript}"',
                          style: const TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: AppTheme.darkIndigo,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Bilingual Language Switcher Tabs
              Row(
                children: [
                  Expanded(
                    child: _langTabButton(
                      index: 0,
                      label: '🇮🇳 हिंदी (Hindi)',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _langTabButton(
                      index: 1,
                      label: '🌐 English',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Editable Title & Description depending on active language
              if (_selectedLangTab == 0) ...[
                // Hindi Fields
                _label('उत्पाद का नाम (शीर्षक - हिंदी) *'),
                const SizedBox(height: 6),
                _inputField(
                  controller: _titleHiCtrl,
                  hint: 'जैसे: हाथ से बना टेराकोटा कुल्हड़',
                  icon: Icons.title,
                  validator: (v) => v == null || v.trim().isEmpty ? 'कृपया शीर्षक दर्ज करें' : null,
                ),
                const SizedBox(height: 16),

                _label('शिल्प का विवरण (Description - हिंदी) *'),
                const SizedBox(height: 6),
                _inputField(
                  controller: _descHiCtrl,
                  hint: 'शिल्प, सामग्री और पारंपरिक कला के बारे में लिखें...',
                  icon: Icons.description_outlined,
                  maxLines: 4,
                  validator: (v) => v == null || v.trim().isEmpty ? 'कृपया विवरण दर्ज करें' : null,
                ),
              ] else ...[
                // English Fields
                _label('Product Title (English) *'),
                const SizedBox(height: 6),
                _inputField(
                  controller: _titleEnCtrl,
                  hint: 'e.g. Handcrafted Terracotta Chai Kulhad Set',
                  icon: Icons.title,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Please enter English title' : null,
                ),
                const SizedBox(height: 16),

                _label('Product Description (English) *'),
                const SizedBox(height: 6),
                _inputField(
                  controller: _descEnCtrl,
                  hint: 'Describe materials, heritage craft, and uses...',
                  icon: Icons.description_outlined,
                  maxLines: 4,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Please enter English description' : null,
                ),
              ],

              const SizedBox(height: 20),

              // Category Selector
              _label('शिल्प श्रेणी (Category) *'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: _fieldDec(icon: Icons.category_outlined),
                items: _kCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _selectedCategory = v;
                      final defaultCosts = {
                        'Pottery': '60',
                        'Textiles': '280',
                        'Painting': '140',
                        'Metal Craft': '450',
                        'Wood Craft': '250',
                        'Jewellery': '160',
                        'Accessories': '120',
                        'Other': '150',
                      };
                      if (_materialCostCtrl.text.isEmpty ||
                          defaultCosts.values.contains(_materialCostCtrl.text)) {
                        _materialCostCtrl.text = defaultCosts[v] ?? '80';
                      }
                    });
                    _fetchPriceSuggestion();
                  }
                },
                borderRadius: BorderRadius.circular(12),
              ),

              const SizedBox(height: 20),

              // Key Features Tags
              if (_features.isNotEmpty) ...[
                _label('✨ मुख्य विशेषताएं (Key Features)'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _features.map((f) {
                    return Chip(
                      label: Text(f, style: const TextStyle(fontSize: 12)),
                      backgroundColor: AppTheme.bgParchment,
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() => _features.remove(f));
                      },
                      side: const BorderSide(color: AppTheme.secondaryOchre),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],

              // AI Suggested Price Card
              _buildSuggestedPriceCard(),

              // Price & Stock
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('कीमत (₹) *'),
                        const SizedBox(height: 6),
                        _inputField(
                          controller: _priceCtrl,
                          hint: '350',
                          icon: Icons.currency_rupee,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'कीमत लिखें';
                            final n = double.tryParse(v.trim());
                            if (n == null || n <= 0) return 'अमान्य कीमत';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('उपलब्ध संख्या *'),
                        const SizedBox(height: 6),
                        _inputField(
                          controller: _stockCtrl,
                          hint: '10',
                          icon: Icons.inventory_2_outlined,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'संख्या लिखें';
                            final n = int.tryParse(v.trim());
                            if (n == null || n < 0) return 'अमान्य संख्या';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 36),

              // Save Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTerracotta,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 3,
                ),
                icon: provider.isLoading
                    ? const SizedBox.shrink()
                    : const Icon(Icons.check_circle_rounded, size: 24),
                label: provider.isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        'दुकान में जोड़ें (Save Product to Store)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                onPressed: provider.isLoading ? null : _saveProduct,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _langTabButton({required int index, required String label}) {
    final isSelected = _selectedLangTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedLangTab = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.darkIndigo : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.darkIndigo : AppTheme.borderGrey,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppTheme.darkIndigo,
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppTheme.darkIndigo,
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: (_) => setState(() {}),
      decoration: _fieldDec(icon: icon, hint: hint),
    );
  }

  InputDecoration _fieldDec({required IconData icon, String hint = ''}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppTheme.primaryTerracotta, size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.borderGrey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.borderGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryTerracotta, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _buildSuggestedPriceCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8F3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.secondaryOchre.withValues(alpha: 0.5), width: 1.5),
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
          // Header row with badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTerracotta.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: AppTheme.primaryTerracotta, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '✨ AI अनुशंसित निष्पक्ष मूल्य (Fair-Trade Pricing)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.darkIndigo,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'सामग्री लागत, आकार व क्षेत्र पर आधारित निष्पक्ष बाज़ार मूल्य',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (_isLoadingPrice)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primaryTerracotta),
                ),
            ],
          ),

          const Divider(height: 24, thickness: 1, color: AppTheme.borderGrey),

          // Artisan Inputs for AI Pricing: Material Cost & Region
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Material Cost Input
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('सामग्री लागत (₹) *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _materialCostCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _fieldDec(
                        icon: Icons.shopping_bag_outlined,
                        hint: 'जैसे: 80',
                      ),
                      onChanged: (_) {
                        // User can press recalculate button to update suggestion
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Region Selector
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('शिल्प क्षेत्र (Region) *'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _craftRegion,
                      decoration: _fieldDec(icon: Icons.location_on_outlined),
                      items: _kRegions
                          .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(r, style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _craftRegion = v);
                          _fetchPriceSuggestion();
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Craft Size Selector Pills (Small, Medium, Large)
          Row(
            children: [
              const Text(
                'आकार (Size): ',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.darkIndigo),
              ),
              const SizedBox(width: 6),
              ...['small', 'medium', 'large'].map((sizeKey) {
                final isSelected = _craftSize == sizeKey;
                final labels = {
                  'small': 'छोटा (S)',
                  'medium': 'मध्यम (M)',
                  'large': 'बड़ा (L)',
                };
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(labels[sizeKey] ?? sizeKey),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _craftSize = sizeKey);
                        _fetchPriceSuggestion();
                      }
                    },
                    selectedColor: AppTheme.primaryTerracotta,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : AppTheme.darkIndigo,
                    ),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? AppTheme.primaryTerracotta : Colors.grey.shade300,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }),
            ],
          ),

          const SizedBox(height: 12),

          // Recalculate Button
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _isLoadingPrice ? null : _fetchPriceSuggestion,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryTerracotta,
                side: const BorderSide(color: AppTheme.primaryTerracotta),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                '✨ नया मूल्य सुझाएं (Recalculate Fair Price)',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Price & Range Row
          if (_suggestedPrice != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.secondaryOchre.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '₹$_suggestedPrice',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryTerracotta,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 14),
                      if (_priceRangeMin != null && _priceRangeMax != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryOchre.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.secondaryOchre.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            'दायरा: ₹$_priceRangeMin – ₹$_priceRangeMax',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkIndigo,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Explanation
                  if (_priceExplanation != null && _priceExplanation!.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: AppTheme.primaryTerracotta),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _priceExplanation!,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 14),

                  // Button to populate or use this price
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _priceCtrl.text = _suggestedPrice.toString();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('🎉 ₹$_suggestedPrice मूल्य उत्पाद के लिए लागू कर दिया गया है!'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: AppTheme.successGreen,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('यह कीमत लागू करें (Use This Price)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.darkIndigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'मूल्य अनुमान प्राप्त किया जा रहा है...',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),
          Text(
            '* आप नीचे अपनी सुविधानुसार इस कीमत को कभी भी बदल सकते हैं। (You can edit the price below before saving).',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
