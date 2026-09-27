import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:frontend/models/catalog_input_provenance.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/screens/artisan/listing_review_screen.dart';
import 'package:frontend/screens/artisan/photo_capture_screen.dart';
import 'package:frontend/screens/artisan/voice_catalog_screen.dart';
import 'package:frontend/services/ai_catalog_service.dart';

final Uint8List _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jH9sAAAAASUVORK5CYII=',
);

class _FakeAiCatalogService extends AiCatalogService {
  _FakeAiCatalogService({required this.enhancement, required this.upload}) : super(baseUrl: 'http://127.0.0.1:5000');

  final Map<String, dynamic> enhancement;
  final Map<String, dynamic> upload;
  final Map<String, dynamic> listing = const {
    'success': true,
    'transcript': 'prepared demo text',
    'title_en': 'Craft item',
    'title_hi': 'शिल्प वस्तु',
    'description_en': 'A sample item.',
    'description_hi': 'एक नमूना वस्तु।',
    'category': 'Pottery',
    'key_features': <String>[],
  };
  int enhancementCalls = 0;
  int uploadCalls = 0;
  List<int>? submittedImageBytes;
  List<int>? submittedAudioBytes;
  String? submittedTranscript;

  @override
  Future<Map<String, dynamic>> enhanceImage({required List<int> imageBytes, String filename = 'craft.jpg'}) async {
    enhancementCalls++;
    submittedImageBytes = List<int>.from(imageBytes);
    return enhancement;
  }

  @override
  Future<Map<String, dynamic>> uploadRawImage({required List<int> imageBytes, String filename = 'craft.jpg'}) async {
    uploadCalls++;
    submittedImageBytes = List<int>.from(imageBytes);
    return upload;
  }

  @override
  Future<Map<String, dynamic>> voiceToListing({
    List<int>? audioBytes,
    String? audioFilename,
    String? directTranscript,
    String language = 'hi',
  }) async {
    submittedAudioBytes = audioBytes;
    submittedTranscript = directTranscript;
    return listing;
  }
}

void _setLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpRouteTransition(WidgetTester tester) async {
  for (var frame = 0; frame < 6; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _openPhotoPicker(WidgetTester tester, _FakeAiCatalogService service) async {
  _setLargeViewport(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: PhotoCaptureScreen(
        aiCatalogService: service,
        pickImage: (_) async => XFile.fromData(_tinyPng, name: 'artisan-product.png'),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.textContaining('Upload from Gallery'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('real enhancement URL and engine are retained for the listing', (tester) async {
    final service = _FakeAiCatalogService(
      enhancement: const {
        'success': true,
        'image_url': 'https://cdn.example.test/real-enhanced.jpg',
        'comparison_url': 'https://cdn.example.test/real-comparison.jpg',
        'engine': 'gemini_studio',
      },
      upload: const {'success': false},
    );

    await _openPhotoPicker(tester, service);

    expect(service.enhancementCalls, 1);
    expect(service.uploadCalls, 0);
    expect(service.submittedImageBytes, orderedEquals(_tinyPng));
    expect(find.text('AI studio enhancement'), findsOneWidget);
    expect(find.text('1080×1080 Studio 1:1'), findsNothing);
    await tester.tap(find.textContaining('Voice Listing'));
    await _pumpRouteTransition(tester);

    final voice = tester.widget<VoiceCatalogScreen>(find.byType(VoiceCatalogScreen));
    expect(voice.imageUrl, 'https://cdn.example.test/real-enhanced.jpg');
    expect(voice.photoProvenance, CatalogPhotoProvenance.enhancedReal);
  });

  testWidgets('OpenCV enhancement is not labeled as Gemini-generated', (tester) async {
    final service = _FakeAiCatalogService(
      enhancement: const {
        'success': true,
        'image_url': 'https://cdn.example.test/opencv-enhanced.jpg',
        'engine': 'opencv_fallback',
      },
      upload: const {'success': false},
    );

    await _openPhotoPicker(tester, service);

    expect(find.text('Studio enhancement fallback'), findsOneWidget);
    expect(find.text('AI studio enhancement'), findsNothing);
  });

  testWidgets('enhancement failure uploads and continues with the original photo', (tester) async {
    final service = _FakeAiCatalogService(
      enhancement: const {'success': false, 'friendly_error': 'Enhancement unavailable.'},
      upload: const {'success': true, 'image_url': 'https://cdn.example.test/real-original.jpg'},
    );

    await _openPhotoPicker(tester, service);

    expect(service.enhancementCalls, 1);
    expect(service.uploadCalls, 1);
    expect(service.submittedImageBytes, orderedEquals(_tinyPng));
    expect(find.text('Using your original photo'), findsOneWidget);
    expect(find.text('Enhancement was unavailable, but your original photo was preserved.'), findsOneWidget);
    expect(find.text('Photo enhanced for listing'), findsNothing);
    expect(find.text('Photo enhancement completed.'), findsNothing);
    expect(find.text('1080×1080 Studio 1:1'), findsNothing);

    await tester.tap(find.text('Continue with original photo'));
    await _pumpRouteTransition(tester);
    final voice = tester.widget<VoiceCatalogScreen>(find.byType(VoiceCatalogScreen));
    expect(voice.imageUrl, 'https://cdn.example.test/real-original.jpg');
    expect(voice.photoProvenance, CatalogPhotoProvenance.originalFallback);
  });

  testWidgets('when enhancement and upload fail, local photo stays visible and flow is blocked', (tester) async {
    final service = _FakeAiCatalogService(
      enhancement: const {'success': false, 'friendly_error': 'Enhancement unavailable.'},
      upload: const {'success': false, 'friendly_error': 'Upload unavailable.'},
    );

    await _openPhotoPicker(tester, service);

    expect(find.byWidgetPredicate((widget) => widget is Image && widget.image is MemoryImage), findsOneWidget);
    expect(find.text('Your selected photo is still here'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Pick another photo'), findsOneWidget);
    expect(find.textContaining('Continue'), findsNothing);
    expect(service.uploadCalls, 1);
  });

  testWidgets('mock URLs cannot replace a real selection or enable continuation', (tester) async {
    final service = _FakeAiCatalogService(
      enhancement: const {'success': true, 'image_url': 'https://images.unsplash.com/demo-stock.jpg', 'is_mock': true},
      upload: const {'success': true, 'image_url': 'https://images.unsplash.com/demo-stock.jpg', 'is_mock': true},
    );

    await _openPhotoPicker(tester, service);

    expect(find.text('Your selected photo is still here'), findsOneWidget);
    expect(find.textContaining('Continue'), findsNothing);
    expect(find.text('AI studio enhancement'), findsNothing);
  });

  testWidgets('demo sample photo is explicit and never calls enhancement', (tester) async {
    final service = _FakeAiCatalogService(enhancement: const {'success': false}, upload: const {'success': false});
    _setLargeViewport(tester);
    await tester.pumpWidget(MaterialApp(home: PhotoCaptureScreen(aiCatalogService: service)));
    await tester.pump();

    await tester.tap(find.text('Try Demo Sample Photo'));
    await tester.pump();

    expect(service.enhancementCalls, 0);
    expect(service.uploadCalls, 0);
    expect(find.text('DEMO SAMPLE'), findsOneWidget);
    expect(find.text('No camera photo was used. This sample was not enhanced.'), findsOneWidget);
    expect(find.text('1080×1080 Studio 1:1'), findsNothing);
    expect(find.textContaining('background removed'), findsNothing);

    await tester.tap(find.text('Continue with demo photo'));
    await _pumpRouteTransition(tester);
    final voice = tester.widget<VoiceCatalogScreen>(find.byType(VoiceCatalogScreen));
    expect(voice.imageUrl, contains('photo-1615865417491'));
    expect(voice.photoProvenance, CatalogPhotoProvenance.demoSample);
    expect(find.text('Demo sample image'), findsOneWidget);
  });

  testWidgets('demo transcript is direct text and provenance appears on review', (tester) async {
    final service = _FakeAiCatalogService(enhancement: const {'success': false}, upload: const {'success': false});
    final products = ProductProvider();
    addTearDown(products.dispose);
    _setLargeViewport(tester);

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider<ProductProvider>.value(value: products)],
        child: MaterialApp(
          home: VoiceCatalogScreen(
            imageUrl: 'https://cdn.example.test/demo.jpg',
            photoProvenance: CatalogPhotoProvenance.demoSample,
            aiCatalogService: service,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Demo sample image'), findsOneWidget);
    expect(find.text('Use demo transcript'), findsOneWidget);
    expect(find.textContaining('microphone and speech transcription are not used'), findsOneWidget);
    await tester.tap(find.text('Use demo transcript'));
    await _pumpRouteTransition(tester);

    expect(service.submittedTranscript, isNotEmpty);
    expect(service.submittedAudioBytes, isNull);
    expect(find.byType(ListingReviewScreen), findsOneWidget);
    expect(find.text('Demo sample photo'), findsOneWidget);
    expect(find.text('Demo transcript input'), findsOneWidget);
    expect(find.textContaining('Demo text:'), findsOneWidget);
    expect(
      find.text('This listing was generated from the prepared demo description, not recorded speech.'),
      findsOneWidget,
    );
    final review = tester.widget<ListingReviewScreen>(find.byType(ListingReviewScreen));
    expect(review.photoProvenance, CatalogPhotoProvenance.demoSample);
    expect(review.descriptionProvenance, CatalogDescriptionProvenance.demoTranscript);
  });

  testWidgets('review from recorded voice has no demo input labels', (tester) async {
    final products = ProductProvider();
    addTearDown(products.dispose);
    _setLargeViewport(tester);

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider<ProductProvider>.value(value: products)],
        child: const MaterialApp(
          home: ListingReviewScreen(
            imageUrl: 'https://cdn.example.test/real.jpg',
            initialTitleEn: 'Real craft',
            initialTitleHi: 'वास्तविक शिल्प',
            initialDescEn: 'A real craft.',
            initialDescHi: 'एक वास्तविक शिल्प।',
            initialCategory: 'Pottery',
            keyFeatures: [],
            transcript: 'Recorded speech transcript.',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Demo transcript input'), findsNothing);
    expect(find.text('Demo sample photo'), findsNothing);
  });
}
