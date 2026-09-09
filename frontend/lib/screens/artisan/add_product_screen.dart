import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/ai_catalog_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import 'photo_capture_screen.dart';

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

/// Form screen to add or edit a product listing with native image picker
/// and studio AI enhancement pipeline.
class AddProductScreen extends StatefulWidget {
  final Product? productToEdit;

  const AddProductScreen({super.key, this.productToEdit});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  final AiCatalogService _aiService = AiCatalogService();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _stockCtrl;
  late String _selectedCategory;

  // Image handling state
  Uint8List? _pickedImageBytes;
  String? _pickedImageFilename;
  String? _existingImageUrl;
  String? _uploadedRawImageUrl;
  String? _enhancedImageUrl;
  String? _comparisonImageUrl;
  bool _isEnhancing = false;
  bool _isUploading = false;
  bool _useEnhanced = true; // true: enhanced studio, false: raw original
  int _previewMode = 1; // 0: Original, 1: Enhanced, 2: Before/After Comparison

  bool get _isEditing => widget.productToEdit != null;

  @override
  void initState() {
    super.initState();
    final p = widget.productToEdit;
    _titleCtrl = TextEditingController(text: p?.title ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _priceCtrl = TextEditingController(text: p != null ? p.price.toStringAsFixed(0) : '');
    _stockCtrl = TextEditingController(text: p != null ? p.stockQuantity.toString() : '10');
    _selectedCategory = p != null && _kCategories.contains(p.category)
        ? p.category
        : _kCategories.first;

    if (p != null && p.imageUrl.isNotEmpty) {
      _existingImageUrl = p.imageUrl;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  // ── Image Picker ─────────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 92,
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _pickedImageBytes = bytes;
          _pickedImageFilename = file.name;
          _uploadedRawImageUrl = null;
          _enhancedImageUrl = null;
          _comparisonImageUrl = null;
          _useEnhanced = true;
          _previewMode = 0; // initially show picked photo
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('फोटो चुनने में समस्या आई: $e'),
            backgroundColor: AppTheme.warningRed,
          ),
        );
      }
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'उत्पाद की फोटो चुनें (Choose Product Photo)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkIndigo,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTerracotta.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryTerracotta),
                ),
                title: const Text(
                  'कैमरा से फोटो खींचें (Take Photo)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('फोन के कैमरे से सीधी तस्वीर लें'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryOchre.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppTheme.secondaryOchre),
                ),
                title: const Text(
                  'गैलरी या फ़ाइल्स से चुनें (Gallery / Files)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('डिवाइस से मौजूदा फोटो चुनें'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Image Enhancement ────────────────────────────────────────────────────────

  Future<void> _enhancePhoto() async {
    if (_pickedImageBytes == null) return;

    setState(() => _isEnhancing = true);

    try {
      final res = await _aiService.enhanceImage(
        imageBytes: _pickedImageBytes!,
        filename: _pickedImageFilename ?? 'craft.jpg',
      );

      if (mounted) {
        setState(() => _isEnhancing = false);
        if (res['success'] == true) {
          setState(() {
            _enhancedImageUrl = res['image_url'];
            _uploadedRawImageUrl = res['original_image_url'];
            _comparisonImageUrl = res['comparison_url'];
            _useEnhanced = true;
            _previewMode = 1; // show enhanced studio preview
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✨ स्टूडियो क्वालिटी फोटो तैयार! (Studio Quality Ready)'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['friendly_error'] ?? res['error'] ?? 'Enhancement failed'),
              backgroundColor: AppTheme.warningRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isEnhancing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enhancement error: $e'),
            backgroundColor: AppTheme.warningRed,
          ),
        );
      }
    }
  }

  // ── Form Submission ──────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Resolve final image URL
    String finalImageUrl = '';

    final messenger = ScaffoldMessenger.of(context);
    final productProvider = context.read<ProductProvider>();
    final auth = context.read<AppAuthProvider>();
    final navigator = Navigator.of(context);

    if (_pickedImageBytes != null) {
      if (_enhancedImageUrl != null && _useEnhanced) {
        // User chose the enhanced image
        finalImageUrl = _enhancedImageUrl!;
      } else if (_uploadedRawImageUrl != null && !_useEnhanced) {
        // User chose original image and it's already uploaded
        finalImageUrl = _uploadedRawImageUrl!;
      } else {
        // User chose original image and it's not yet uploaded -> upload now
        setState(() => _isUploading = true);
        final upRes = await _aiService.uploadRawImage(
          imageBytes: _pickedImageBytes!,
          filename: _pickedImageFilename ?? 'craft.jpg',
        );
        if (mounted) {
          setState(() => _isUploading = false);
        }

        if (upRes['success'] == true && upRes['image_url'] != null) {
          finalImageUrl = upRes['image_url'];
        } else {
          messenger.showSnackBar(
            SnackBar(
              content: Text(upRes['friendly_error'] ?? 'फोटो अपलोड नहीं हो सकी'),
              backgroundColor: AppTheme.warningRed,
            ),
          );
          return;
        }
      }
    } else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
      finalImageUrl = _existingImageUrl!;
    }

    if (finalImageUrl.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('कृपया उत्पाद की फोटो जोड़ें (Please select a product photo)'),
          backgroundColor: AppTheme.warningRed,
        ),
      );
      return;
    }

    final artisanId = auth.currentArtisanId;

    bool ok;
    if (_isEditing) {
      final updates = {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'image_url': finalImageUrl,
        'price': double.parse(_priceCtrl.text.trim()),
        'stock_quantity': int.parse(_stockCtrl.text.trim()),
        'category': _selectedCategory,
      };
      ok = await productProvider.updateProduct(widget.productToEdit!.id, updates);
    } else {
      final product = Product(
        id: '',
        artisanId: artisanId,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        imageUrl: finalImageUrl,
        price: double.parse(_priceCtrl.text.trim()),
        stockQuantity: int.parse(_stockCtrl.text.trim()),
        category: _selectedCategory,
      );
      ok = await productProvider.addProduct(product);
    }

    if (mounted) {
      if (ok) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? '✅ उत्पाद सफलतापूर्वक अपडेट हो गया! (Product updated!)'
                : '✅ उत्पाद सफलतापूर्वक बाज़ार में जुड़ गया! (Product published!)'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        navigator.pop(true);
      } else {
        final err = productProvider.errorMessage;
        messenger.showSnackBar(
          SnackBar(
            content: Text(err ?? (_isEditing ? 'Failed to update product' : 'Failed to add product')),
            backgroundColor: AppTheme.warningRed,
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            children: [
              // ── AI Wizard Shortcut ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTerracotta.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryTerracotta.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryTerracotta.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: AppTheme.primaryTerracotta, size: 26),
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
                      style: TextStyle(fontSize: 13, color: Color(0xFF4A5568), height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTerracotta,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
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

              // ── Section: Product Image ─────────────────────────────────
              _sectionLabel('🖼️ Product Image (उत्पाद फोटो)'),
              const SizedBox(height: 12),

              _buildImageUploadSection(),

              const SizedBox(height: 28),

              // ── Section: Basic Info ────────────────────────────────────
              _sectionLabel('📦 Product Details (उत्पाद विवरण)'),
              const SizedBox(height: 14),

              TextFormField(
                controller: _titleCtrl,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Product Title *',
                  hintText: 'e.g. Handcrafted Terracotta Kulhad',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText: 'Describe materials, craft tradition, region…',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Please add a description' : null,
              ),
              const SizedBox(height: 14),

              // Category dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _kCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedCategory = v);
                },
                borderRadius: BorderRadius.circular(12),
              ),

              const SizedBox(height: 28),

              // ── Section: Pricing & Stock ───────────────────────────────
              _sectionLabel('💰 Pricing & Stock (मूल्य व स्टॉक)'),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceCtrl,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Price (₹) *',
                        hintText: '350',
                        prefixIcon: Icon(Icons.currency_rupee_rounded),
                      ),
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
                    child: TextFormField(
                      controller: _stockCtrl,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Stock *',
                        hintText: '10',
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                      ),
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

              const SizedBox(height: 36),

              // ── Submit Button ──────────────────────────────────────────
              ElevatedButton(
                onPressed: (provider.isLoading || _isUploading || _isEnhancing) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  backgroundColor: AppTheme.primaryTerracotta,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: (provider.isLoading || _isUploading)
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        _isEditing ? 'Update Product' : 'Publish to Marketplace',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Image Upload & Enhancement UI Component ──────────────────────────────────

  Widget _buildImageUploadSection() {
    final hasImage = _pickedImageBytes != null || (_existingImageUrl != null && _existingImageUrl!.isNotEmpty);

    if (!hasImage) {
      // Empty state: Upload prompt
      return InkWell(
        onTap: _showImageSourcePicker,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.secondaryOchre.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryOchre.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_a_photo_outlined,
                  size: 36,
                  color: AppTheme.secondaryOchre,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'फोटो अपलोड करें (Upload Photo)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkIndigo,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'कैमरा या गैलरी से उत्पाद की तस्वीर चुनें',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _showImageSourcePicker,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTerracotta,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('फोटो चुनें (Choose Photo)', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
    }

    // Image selected preview & enhancement options
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFE7DC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with change & remove actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'उत्पाद फोटो (Product Photo)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkIndigo,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _showImageSourcePicker,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('बदलें', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.primaryTerracotta),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.warningRed, size: 20),
                    tooltip: 'हटाएं (Remove)',
                    onPressed: () {
                      setState(() {
                        _pickedImageBytes = null;
                        _pickedImageFilename = null;
                        _existingImageUrl = null;
                        _enhancedImageUrl = null;
                        _uploadedRawImageUrl = null;
                        _comparisonImageUrl = null;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Preview display with mode tabs if enhanced
          if (_enhancedImageUrl != null) ...[
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildPreviewTab(0, '📷 Original (मूल)'),
                  _buildPreviewTab(1, '✨ Enhanced (स्टूडियो)'),
                  if (_comparisonImageUrl != null) _buildPreviewTab(2, '⚖️ Before/After'),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Active Image Box
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 220,
              width: double.infinity,
              color: const Color(0xFFF9FAFB),
              child: _buildActiveImagePreview(),
            ),
          ),

          const SizedBox(height: 14),

          // ── Enhancement action / Version choice ──
          if (_enhancedImageUrl == null) ...[
            // Enhance CTA Button
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.secondaryOchre.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.secondaryOchre.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: AppTheme.secondaryOchre, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'AI स्टूडियो फोटो संवारें (Studio Quality)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkIndigo,
                          ),
                        ),
                      ),
                      if (_isEnhancing)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryTerracotta),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'बैकग्राउंड हटाएं, प्रकाश और छाया संतुलित करें और ई-कॉमर्स 1:1 स्टूडियो लुक पाएं।',
                    style: TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _isEnhancing ? null : _enhancePhoto,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryOchre,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: Text(
                      _isEnhancing ? 'फोटो संवारी जा रही है... (Processing...)' : '✨ Enhance Photo (फोटो संवारें)',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Choice selector: Use Enhanced vs Use Original
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'लिस्टिंग के लिए कौन सी फोटो चुनना चाहते हैं?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkIndigo,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildChoiceCard(
                        isEnhancedChoice: true,
                        title: '✨ Enhanced',
                        subtitle: 'स्टूडियो AI (Recommended)',
                        isSelected: _useEnhanced,
                        onTap: () => setState(() {
                          _useEnhanced = true;
                          _previewMode = 1;
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildChoiceCard(
                        isEnhancedChoice: false,
                        title: '📷 Original',
                        subtitle: 'मूल फोटो (Raw Photo)',
                        isSelected: !_useEnhanced,
                        onTap: () => setState(() {
                          _useEnhanced = false;
                          _previewMode = 0;
                        }),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewTab(int mode, String label) {
    final isActive = _previewMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _previewMode = mode),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              color: isActive ? AppTheme.darkIndigo : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveImagePreview() {
    if (_previewMode == 2 && _comparisonImageUrl != null) {
      return Image.network(
        _comparisonImageUrl!,
        fit: BoxFit.contain,
        errorBuilder: (ctx, err, stack) => const Center(child: Text('Comparison load error')),
      );
    }

    if (_previewMode == 1 && _enhancedImageUrl != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            _enhancedImageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) => const Center(child: Text('Enhanced image load error')),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: Colors.amber, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'AI Studio Enhanced',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Default: Original preview
    if (_pickedImageBytes != null) {
      return Image.memory(
        _pickedImageBytes!,
        fit: BoxFit.cover,
      );
    }

    if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
      return Image.network(
        _existingImageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => const Center(child: Text('Image load error')),
      );
    }

    return const Center(child: Icon(Icons.image, size: 48, color: Colors.grey));
  }

  Widget _buildChoiceCard({
    required bool isEnhancedChoice,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final activeColor = isEnhancedChoice ? AppTheme.primaryTerracotta : AppTheme.secondaryOchre;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.08) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? activeColor : Colors.grey,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? AppTheme.darkIndigo : const Color(0xFF4B5563),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? activeColor : const Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.primaryTerracotta,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.darkIndigo,
          ),
        ),
      ],
    );
  }
}
