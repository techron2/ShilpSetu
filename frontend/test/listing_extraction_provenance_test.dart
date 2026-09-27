import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/catalog_input_provenance.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/screens/artisan/listing_review_screen.dart';
import 'package:frontend/screens/artisan/voice_catalog_screen.dart';
import 'package:frontend/services/ai_catalog_service.dart';
import 'package:provider/provider.dart';

class _FakeListingService extends AiCatalogService {
  _FakeListingService(this.aiStructured, {this.isMock = false})
    : super(baseUrl: 'http://127.0.0.1:5000');

  final bool aiStructured;
  final bool isMock;

  @override
  Future<Map<String, dynamic>> voiceToListing({
    List<int>? audioBytes,
    String? audioFilename,
    String? directTranscript,
    String language = 'hi',
  }) async => {
    'success': true,
    'transcript': directTranscript ?? 'Prepared description.',
    'title_en': 'Craft item',
    'title_hi': 'शिल्प वस्तु',
    'description_en': 'A product description.',
    'description_hi': 'उत्पाद का विवरण।',
    'category': 'Other',
    'key_features': <String>[],
    'ai_structured': aiStructured,
    if (isMock) 'is_mock': true,
  };
}

const _reviewData = {
  'imageUrl': 'https://example.test/craft.jpg',
  'initialTitleEn': 'Craft item',
  'initialTitleHi': 'शिल्प वस्तु',
  'initialDescEn': 'A product description.',
  'initialDescHi': 'उत्पाद का विवरण।',
  'initialCategory': 'Other',
  'keyFeatures': <String>[],
  'transcript': 'A product description.',
};

ListingReviewScreen _review({bool? aiStructured}) {
  if (aiStructured == null) {
    return const ListingReviewScreen(
      imageUrl: 'https://example.test/craft.jpg',
      initialTitleEn: 'Craft item',
      initialTitleHi: 'शिल्प वस्तु',
      initialDescEn: 'A product description.',
      initialDescHi: 'उत्पाद का विवरण।',
      initialCategory: 'Other',
      keyFeatures: [],
      transcript: 'A product description.',
    );
  }
  return ListingReviewScreen(
    imageUrl: _reviewData['imageUrl'] as String,
    initialTitleEn: _reviewData['initialTitleEn'] as String,
    initialTitleHi: _reviewData['initialTitleHi'] as String,
    initialDescEn: _reviewData['initialDescEn'] as String,
    initialDescHi: _reviewData['initialDescHi'] as String,
    initialCategory: _reviewData['initialCategory'] as String,
    keyFeatures: _reviewData['keyFeatures'] as List<String>,
    transcript: _reviewData['transcript'] as String,
    aiStructured: aiStructured,
  );
}

void _setLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _mountReview(WidgetTester tester, {bool? aiStructured}) async {
  _setLargeViewport(tester);
  final products = ProductProvider();
  addTearDown(products.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ProductProvider>.value(value: products),
      ],
      child: MaterialApp(home: _review(aiStructured: aiStructured)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('Gemini-structured listing is labeled as an AI-assisted draft', (
    tester,
  ) async {
    await _mountReview(tester, aiStructured: true);

    expect(
      find.text('✨ AI-सहायता प्राप्त ड्राफ्ट (AI-assisted draft)'),
      findsOneWidget,
    );
    expect(find.textContaining('Standard extraction'), findsNothing);
    expect(find.textContaining('AI Generated'), findsNothing);
  });

  testWidgets('deterministic listing is labeled as standard extraction', (
    tester,
  ) async {
    await _mountReview(tester, aiStructured: false);

    expect(find.text('📝 मानक विवरण (Standard extraction)'), findsOneWidget);
    expect(find.textContaining('AI Parsed'), findsNothing);
    expect(find.textContaining('AI Generated'), findsNothing);
    expect(find.textContaining('AI-assisted draft'), findsNothing);
  });

  testWidgets('missing historical provenance defaults to standard extraction', (
    tester,
  ) async {
    await _mountReview(tester);

    expect(_review().aiStructured, isFalse);
    expect(find.text('📝 मानक विवरण (Standard extraction)'), findsOneWidget);
    expect(find.textContaining('AI Generated'), findsNothing);
  });

  for (final aiStructured in [true, false]) {
    testWidgets(
      'voice result ai_structured=$aiStructured reaches Listing Review',
      (tester) async {
        _setLargeViewport(tester);
        final products = ProductProvider();
        addTearDown(products.dispose);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<ProductProvider>.value(value: products),
            ],
            child: MaterialApp(
              home: VoiceCatalogScreen(
                imageUrl: 'https://example.test/craft.jpg',
                photoProvenance: CatalogPhotoProvenance.enhancedReal,
                aiCatalogService: _FakeListingService(aiStructured),
              ),
            ),
          ),
        );
        await tester.pump();
        final demoButton = find.text('Use demo transcript');
        await tester.ensureVisible(demoButton);
        await tester.tap(demoButton);
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        final reviewFinder = find.byType(ListingReviewScreen);
        expect(reviewFinder, findsOneWidget);
        final review = tester.widget<ListingReviewScreen>(reviewFinder);
        expect(review.aiStructured, aiStructured);
        expect(find.text('Demo transcript input'), findsOneWidget);
        expect(
          find.textContaining(
            aiStructured ? 'AI-assisted draft' : 'Standard extraction',
          ),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets(
    'mock listing output keeps its demo provenance instead of an AI badge',
    (tester) async {
      _setLargeViewport(tester);
      final products = ProductProvider();
      addTearDown(products.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ProductProvider>.value(value: products),
          ],
          child: MaterialApp(
            home: VoiceCatalogScreen(
              imageUrl: 'https://example.test/craft.jpg',
              aiCatalogService: _FakeListingService(false, isMock: true),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Use demo transcript'));
      await tester.tap(find.text('Use demo transcript'));
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('DEMO LISTING DATA'), findsOneWidget);
      expect(find.textContaining('AI-assisted draft'), findsNothing);
      expect(find.textContaining('AI Generated'), findsNothing);
    },
  );
}
