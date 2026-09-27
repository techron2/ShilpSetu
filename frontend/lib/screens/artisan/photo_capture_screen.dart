import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/catalog_input_provenance.dart';
import '../../services/ai_catalog_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import 'voice_catalog_screen.dart';

class PhotoCaptureScreen extends StatefulWidget {
  final AiCatalogService? aiCatalogService;
  final Future<XFile?> Function(ImageSource source)? pickImage;

  const PhotoCaptureScreen({super.key, this.aiCatalogService, this.pickImage});

  @override
  State<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends State<PhotoCaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  late final AiCatalogService _aiService;

  Uint8List? _originalImageBytes;
  String? _originalImageFilename;
  String? _listingImageUrl;
  String? _comparisonImageUrl;
  String? _enhancementEngine;
  String? _photoError;
  CatalogPhotoProvenance? _photoProvenance;
  bool _isEnhancing = false;
  int _comparisonViewMode = 1; // 0: Original, 1: Enhanced (1:1 Studio), 2: Side-by-Side

  // Built-in sample handicraft URL for instant zero-permission testing
  static const String _kSampleCraftUrl = 'https://images.unsplash.com/photo-1615865417491-9941019fbc00?w=800';

  @override
  void initState() {
    super.initState();
    _aiService = widget.aiCatalogService ?? AiCatalogService();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = widget.pickImage != null
          ? await widget.pickImage!(source)
          : await _picker.pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 90);

      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _originalImageBytes = bytes;
          _originalImageFilename = file.name;
          _listingImageUrl = null;
          _comparisonImageUrl = null;
          _enhancementEngine = null;
          _photoError = null;
          _photoProvenance = null;
        });
        await _processEnhancement(bytes, file.name);
      }
    } catch (e) {
      _showError('कैमरा या गैलरी खोलने में समस्या आई: $e');
    }
  }

  void _useSampleCraft() {
    setState(() {
      _isEnhancing = false;
      _originalImageBytes = null;
      _originalImageFilename = null;
      _listingImageUrl = _kSampleCraftUrl;
      _comparisonImageUrl = null;
      _enhancementEngine = null;
      _photoError = null;
      _photoProvenance = CatalogPhotoProvenance.demoSample;
      _comparisonViewMode = 1;
    });
  }

  Future<void> _processEnhancement(Uint8List bytes, String filename) async {
    setState(() {
      _isEnhancing = true;
      _photoError = null;
      _listingImageUrl = null;
      _comparisonImageUrl = null;
      _enhancementEngine = null;
      _photoProvenance = null;
    });

    Map<String, dynamic> enhancement;
    try {
      enhancement = await _aiService.enhanceImage(imageBytes: bytes, filename: filename);
    } catch (_) {
      enhancement = {'success': false, 'friendly_error': 'Photo enhancement could not be reached.'};
    }

    final enhancedUrl = _stringValue(enhancement['image_url']);
    final isMockEnhancement = enhancement['is_mock'] == true;
    if (enhancement['success'] == true && !isMockEnhancement && enhancedUrl != null && enhancedUrl.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _isEnhancing = false;
        _listingImageUrl = enhancedUrl;
        _comparisonImageUrl = _stringValue(enhancement['comparison_url']);
        _enhancementEngine = _stringValue(enhancement['engine']);
        _photoProvenance = CatalogPhotoProvenance.enhancedReal;
        _comparisonViewMode = 1;
      });
      return;
    }

    final enhancementMessage = isMockEnhancement
        ? 'A demo enhancement response was ignored so it cannot replace your photo.'
        : (_stringValue(enhancement['friendly_error']) ??
              _stringValue(enhancement['error']) ??
              'Photo enhancement was unavailable.');

    Map<String, dynamic> upload;
    try {
      upload = await _aiService.uploadRawImage(imageBytes: bytes, filename: filename);
    } catch (_) {
      upload = {'success': false};
    }

    final originalUrl = _stringValue(upload['image_url']);
    final isMockUpload = upload['is_mock'] == true;
    if (upload['success'] == true && !isMockUpload && originalUrl != null && originalUrl.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _isEnhancing = false;
        _listingImageUrl = originalUrl;
        _photoProvenance = CatalogPhotoProvenance.originalFallback;
        _photoError = null;
        _comparisonImageUrl = null;
        _enhancementEngine = null;
        _comparisonViewMode = 0;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isEnhancing = false;
      _listingImageUrl = null;
      _photoProvenance = null;
      _photoError = isMockUpload
          ? 'A demo upload response was ignored. Your selected photo is still shown locally; retry or choose another photo.'
          : '$enhancementMessage Your original photo is still shown locally, but could not be uploaded. Retry or choose another photo.';
      _comparisonImageUrl = null;
      _enhancementEngine = null;
    });
  }

  Future<void> _retryEnhancement() async {
    final bytes = _originalImageBytes;
    final filename = _originalImageFilename;
    if (bytes == null || filename == null) return;
    await _processEnhancement(bytes, filename);
  }

  void _pickAnotherPhoto() {
    setState(() {
      _originalImageBytes = null;
      _originalImageFilename = null;
      _listingImageUrl = null;
      _comparisonImageUrl = null;
      _enhancementEngine = null;
      _photoError = null;
      _photoProvenance = null;
      _isEnhancing = false;
    });
  }

  String get _enhancementStatus {
    switch (_enhancementEngine) {
      case 'gemini_studio':
        return 'AI studio enhancement';
      case 'opencv_fallback':
        return 'Studio enhancement fallback';
      default:
        return 'Photo enhanced for listing';
    }
  }

  String? _stringValue(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  void _continueToVoiceListing() {
    final imageUrl = _listingImageUrl;
    final provenance = _photoProvenance;
    if (imageUrl == null || provenance == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoiceCatalogScreen(imageUrl: imageUrl, photoProvenance: provenance),
      ),
    );
  }

  Widget _buildSelectedPhotoPreview({required Widget photo}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(aspectRatio: 1, child: photo),
    );
  }

  Widget _buildOriginalFallbackView() => _buildProvenanceCard(
    image: _buildSelectedPhotoPreview(photo: Image.memory(_originalImageBytes!, fit: BoxFit.cover)),
    label: 'Using your original photo',
    message: 'Enhancement was unavailable, but your original photo was preserved.',
    icon: Icons.photo_outlined,
    actions: _retryAndPickActions(),
  );

  Widget _buildDemoSampleView() => _buildProvenanceCard(
    image: _buildSelectedPhotoPreview(
      photo: Image.network(
        _kSampleCraftUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const ColoredBox(
          color: AppTheme.bgParchment,
          child: Center(child: Icon(Icons.image_outlined, size: 48)),
        ),
      ),
    ),
    label: 'DEMO SAMPLE',
    message: 'No camera photo was used. This sample was not enhanced.',
    icon: Icons.science_outlined,
    actions: [
      TextButton.icon(
        onPressed: _pickAnotherPhoto,
        icon: const Icon(Icons.photo_library_outlined),
        label: const Text('Pick another photo'),
      ),
    ],
  );

  Widget _buildLocalFailureView() => _buildProvenanceCard(
    image: _buildSelectedPhotoPreview(photo: Image.memory(_originalImageBytes!, fit: BoxFit.cover)),
    label: 'Your selected photo is still here',
    message: _photoError ?? 'Photo upload failed. Retry or choose another photo.',
    icon: Icons.warning_amber_rounded,
    isError: true,
    actions: _retryAndPickActions(),
  );

  List<Widget> _retryAndPickActions() => [
    OutlinedButton.icon(
      key: const ValueKey('retry-photo-enhancement'),
      onPressed: _isEnhancing ? null : _retryEnhancement,
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('Retry'),
    ),
    TextButton.icon(
      key: const ValueKey('pick-another-photo'),
      onPressed: _isEnhancing ? null : _pickAnotherPhoto,
      icon: const Icon(Icons.photo_library_outlined),
      label: const Text('Pick another photo'),
    ),
  ];

  Widget _buildProvenanceCard({
    required Widget image,
    required String label,
    required String message,
    required IconData icon,
    bool isError = false,
    List<Widget> actions = const [],
  }) {
    final color = isError ? Colors.redAccent : AppTheme.darkIndigo;
    return Container(
      key: ValueKey('photo-provenance-${_photoProvenance?.name ?? 'local-only'}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isError ? Colors.redAccent : AppTheme.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          image,
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w800, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(fontSize: 13, height: 1.4)),
          if (actions.isNotEmpty) ...[const SizedBox(height: 8), Wrap(spacing: 8, runSpacing: 4, children: actions)],
        ],
      ),
    );
  }

  Widget _buildEnhancementLoadingView() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppTheme.primaryTerracotta.withValues(alpha: 0.1), blurRadius: 16)],
      ),
      child: const Column(
        children: [
          SizedBox(
            height: 50,
            width: 50,
            child: CircularProgressIndicator(color: AppTheme.primaryTerracotta, strokeWidth: 4),
          ),
          SizedBox(height: 24),
          Text(
            'Preparing your product photo…',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.darkIndigo),
          ),
          SizedBox(height: 8),
          Text(
            'Your original photo stays available if enhancement is unavailable.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgParchment,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('📷 स्मार्ट AI फोटो संवारें (Smart Photo)'),
        backgroundColor: AppTheme.primaryTerracotta,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.primaryTerracotta, AppTheme.secondaryOchre]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 32),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'चरण 1: फोटो खींचें या चुनें',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'We’ll prepare a clean product photo for your listing.',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              if (_isEnhancing) ...[
                _buildEnhancementLoadingView(),
              ] else if (_photoProvenance == CatalogPhotoProvenance.enhancedReal) ...[
                _buildComparisonView(),
                const SizedBox(height: 8),
                Text(
                  _enhancementStatus,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.successGreen, fontWeight: FontWeight.w700),
                ),
              ] else if (_photoProvenance == CatalogPhotoProvenance.originalFallback) ...[
                _buildOriginalFallbackView(),
              ] else if (_photoProvenance == CatalogPhotoProvenance.demoSample) ...[
                _buildDemoSampleView(),
              ] else if (_originalImageBytes != null && _photoError != null) ...[
                _buildLocalFailureView(),
              ] else ...[
                // Initial Photo Capture Buttons Card
                _buildInitialPickerCard(),
              ],

              const SizedBox(height: 30),

              if (_listingImageUrl != null && _photoProvenance != null && !_isEnhancing) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTerracotta,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 3,
                  ),
                  icon: const Icon(Icons.mic_rounded, size: 24),
                  label: Text(
                    _photoProvenance == CatalogPhotoProvenance.demoSample
                        ? 'Continue with demo photo'
                        : _photoProvenance == CatalogPhotoProvenance.originalFallback
                        ? 'Continue with original photo'
                        : 'आगे बढ़ें: बोलकर विवरण जोड़ें (Voice Listing) 🎙️',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  onPressed: _continueToVoiceListing,
                ),
                if (_photoProvenance == CatalogPhotoProvenance.enhancedReal) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.darkIndigo,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text('दूसरी फोटो चुनें (Pick Another Photo)'),
                    onPressed: _pickAnotherPhoto,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitialPickerCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderGrey),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(color: AppTheme.primaryTerracotta.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryTerracotta, size: 52),
          ),
          const SizedBox(height: 20),
          const Text(
            'शिल्प उत्पाद की फोटो लें',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.darkIndigo),
          ),
          const SizedBox(height: 8),
          const Text(
            'अपने मिट्टी के बर्तन, वस्त्र या हस्तशिल्प की साफ़ फोटो खींचें',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTerracotta,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.camera, size: 22),
            label: const Text(
              'कैमरे से फोटो खींचें (Take Photo)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            onPressed: () => _pickImage(ImageSource.camera),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.darkIndigo,
              minimumSize: const Size(double.infinity, 50),
              side: const BorderSide(color: AppTheme.borderGrey),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.photo_library_outlined, size: 22),
            label: const Text(
              'गैलरी से चुनें (Upload from Gallery)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            onPressed: () => _pickImage(ImageSource.gallery),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),
          // Instant one-tap sample craft button
          TextButton.icon(
            icon: const Icon(Icons.science_outlined, color: AppTheme.secondaryOchre),
            label: const Text(
              'Try Demo Sample Photo',
              style: TextStyle(color: AppTheme.secondaryOchre, fontWeight: FontWeight.w700, fontSize: 14),
            ),
            onPressed: _useSampleCraft,
          ),
          const Text(
            'Sample image for walkthrough only; no camera photo is used.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonView() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // View Mode Selector Pills
          Row(
            children: [
              Expanded(
                child: _modeButton(index: 1, label: '✨ Prepared photo', icon: Icons.auto_awesome),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _modeButton(index: 0, label: '📷 मूल (Original)', icon: Icons.image),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _modeButton(index: 2, label: '⚡ दोनों (Side by Side)', icon: Icons.compare),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Display Selected Mode
          if (_comparisonViewMode == 1) ...[
            // Enhanced real photo
            Column(
              children: [
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderGrey),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 1.0, // 1:1 standard e-commerce ratio
                          child: Image.network(
                            _listingImageUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: AppTheme.bgParchment,
                              child: const Center(child: Icon(Icons.broken_image, size: 48)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Prepared for listing',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Photo enhancement completed.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.successGreen),
                ),
              ],
            ),
          ] else if (_comparisonViewMode == 0) ...[
            // Original Photo
            Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: _originalImageBytes != null
                        ? Image.memory(
                            _originalImageBytes!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                          )
                        : const Icon(Icons.image_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Original unedited photo', style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ] else ...[
            // Side by Side
            if (_comparisonImageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  _comparisonImageUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => _buildSideBySideTiles(),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Comparison: original photo beside the prepared listing photo',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.darkIndigo),
              ),
            ] else ...[
              _buildSideBySideTiles(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSideBySideTiles() {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: _originalImageBytes != null
                      ? Image.memory(
                          _originalImageBytes!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                        )
                      : const Icon(Icons.image_outlined),
                ),
              ),
              const SizedBox(height: 6),
              const Text('Original', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(aspectRatio: 1.0, child: Image.network(_listingImageUrl!, fit: BoxFit.contain)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Prepared',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.successGreen),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _modeButton({required int index, required String label, required IconData icon}) {
    final isSelected = _comparisonViewMode == index;
    return InkWell(
      onTap: () => setState(() => _comparisonViewMode = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.darkIndigo : AppTheme.bgParchment,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.darkIndigo),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppTheme.darkIndigo,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
