import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import 'photo_capture_screen.dart';

const List<String> _kCategories = [
  'Pottery',
  'Textiles',
  'Painting',
  'Metal Craft',
  'Embroidery',
  'Leather',
  'Jewellery',
  'Wood Craft',
  'Other',
];

/// Form screen to add or edit a product listing.
class AddProductScreen extends StatefulWidget {
  final Product? productToEdit;

  const AddProductScreen({super.key, this.productToEdit});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey        = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _imageUrlCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _stockCtrl;
  late String _selectedCategory;

  bool get _isEditing => widget.productToEdit != null;

  @override
  void initState() {
    super.initState();
    final p = widget.productToEdit;
    _titleCtrl    = TextEditingController(text: p?.title ?? '');
    _descCtrl     = TextEditingController(text: p?.description ?? '');
    _imageUrlCtrl = TextEditingController(text: p?.imageUrl ?? '');
    _priceCtrl    = TextEditingController(text: p != null ? p.price.toStringAsFixed(0) : '');
    _stockCtrl    = TextEditingController(text: p != null ? p.stockQuantity.toString() : '10');
    _selectedCategory = p != null && _kCategories.contains(p.category)
        ? p.category
        : _kCategories.first;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _imageUrlCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth      = context.read<AppAuthProvider>();
    final artisanId = auth.firebaseUser?.uid ?? widget.productToEdit?.artisanId ?? 'artisan_001';

    bool ok;
    if (_isEditing) {
      final updates = {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'image_url': _imageUrlCtrl.text.trim(),
        'price': double.parse(_priceCtrl.text.trim()),
        'stock_quantity': int.parse(_stockCtrl.text.trim()),
        'category': _selectedCategory,
      };
      ok = await context.read<ProductProvider>().updateProduct(widget.productToEdit!.id, updates);
    } else {
      final product = Product(
        id:            '',  // will be assigned by service
        artisanId:     artisanId,
        title:         _titleCtrl.text.trim(),
        description:   _descCtrl.text.trim(),
        imageUrl:      _imageUrlCtrl.text.trim(),
        price:         double.parse(_priceCtrl.text.trim()),
        stockQuantity: int.parse(_stockCtrl.text.trim()),
        category:      _selectedCategory,
      );
      ok = await context.read<ProductProvider>().addProduct(product);
    }

    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? '✅ उत्पाद सफलतापूर्वक अपडेट हो गया! (Product updated!)' : '✅ Product added successfully!'),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); // signal parent to refresh
      } else {
        final err = context.read<ProductProvider>().errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err ?? (_isEditing ? 'Failed to update product' : 'Failed to add product')),
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
        title: Text(_isEditing ? '✏️ उत्पाद संपादित करें (Edit Product)' : 'Add New Product'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            children: [
              // ── Preview banner ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryTerracotta, AppTheme.secondaryOchre],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storefront_rounded,
                        color: Colors.white, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your product will be visible to buyers on KalaVistar Marketplace.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── AI Wizard Shortcut ───────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryTerracotta, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryTerracotta.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.auto_awesome, color: AppTheme.primaryTerracotta, size: 28),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '✨ स्मार्ट AI कैटलॉग विज़ार्ड (AI Wizard)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.darkIndigo,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'फोटो खींचें (ऑटो बैकग्राउंड रिमूवल 1080×1080) और बोलकर बताएं, AI खुद द्विभाषी लिस्टिंग तैयार करेगा।',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTerracotta,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.bolt_rounded, size: 20),
                      label: const Text('AI विज़ार्ड शुरू करें (Start AI Flow)'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PhotoCaptureScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Section: Basic Info ───────────────────────────────────
              _sectionLabel(context, '📦 Product Details (या मैन्युअल भरें)'),
              const SizedBox(height: 12),

              _field(
                controller: _titleCtrl,
                label: 'Product Title *',
                hint:  'e.g. Handcrafted Terracotta Kulhad',
                icon:  Icons.title_rounded,
                action: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 14),

              _field(
                controller: _descCtrl,
                label: 'Description *',
                hint:  'Describe materials, craft tradition, region…',
                icon:  Icons.description_outlined,
                maxLines: 4,
                action: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Please add a description' : null,
              ),
              const SizedBox(height: 14),

              // Category dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: _inputDec(
                  label: 'Category *',
                  icon:  Icons.category_outlined,
                ),
                items: _kCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedCategory = v);
                },
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(height: 24),

              // ── Section: Pricing ──────────────────────────────────────
              _sectionLabel(context, '💰 Pricing & Stock'),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _priceCtrl,
                      label: 'Price (₹) *',
                      hint:  '350',
                      icon:  Icons.currency_rupee_rounded,
                      keyboardType: TextInputType.number,
                      action: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final n = double.tryParse(v.trim());
                        if (n == null || n <= 0) return 'Enter valid price';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _field(
                      controller: _stockCtrl,
                      label: 'Stock *',
                      hint:  '10',
                      icon:  Icons.inventory_2_outlined,
                      keyboardType: TextInputType.number,
                      action: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final n = int.tryParse(v.trim());
                        if (n == null || n < 0) return 'Enter valid number';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Section: Image ────────────────────────────────────────
              _sectionLabel(context, '🖼️ Product Image'),
              const SizedBox(height: 12),

              _field(
                controller: _imageUrlCtrl,
                label: 'Image URL (optional)',
                hint:  'https://example.com/my-product.jpg',
                icon:  Icons.image_outlined,
                keyboardType: TextInputType.url,
                action: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),

              // Image preview
              if (_imageUrlCtrl.text.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _imageUrlCtrl.text.trim(),
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.bgParchment,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderGrey),
                      ),
                      child: const Center(
                        child: Text('Invalid image URL',
                            style: TextStyle(color: Colors.redAccent)),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 36),

              // ── Submit ────────────────────────────────────────────────
              ElevatedButton(
                onPressed: provider.isLoading ? null : _submit,
                child: provider.isLoading
                    ? const SizedBox(
                        height: 22,
                        width:  22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text('Add Product to Marketplace'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(color: AppTheme.darkIndigo),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction action = TextInputAction.next,
    String? Function(String?)? validator,
    void Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller:         controller,
      maxLines:           maxLines,
      keyboardType:       keyboardType,
      textInputAction:    action,
      onFieldSubmitted:   onFieldSubmitted,
      onChanged: (_) => setState(() {}), // re-render image preview
      decoration:         _inputDec(label: label, hint: hint, icon: icon),
      validator:          validator,
    );
  }

  InputDecoration _inputDec({
    required String label,
    required IconData icon,
    String hint = '',
  }) {
    return InputDecoration(
      labelText:  label,
      hintText:   hint,
      prefixIcon: Icon(icon, color: AppTheme.primaryTerracotta),
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
      filled:    true,
      fillColor: AppTheme.cardBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
