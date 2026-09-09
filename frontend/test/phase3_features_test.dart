import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/providers/navigation_provider.dart';
import 'package:frontend/screens/artisan/listing_review_screen.dart';
import 'package:frontend/screens/artisan/business_assistant_screen.dart';
import 'package:frontend/screens/main_screen.dart';

import 'package:frontend/providers/language_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildTestableWidget(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ChangeNotifierProvider(create: (_) => AppAuthProvider()),
      ChangeNotifierProvider(create: (_) => ProductProvider()),
      ChangeNotifierProvider(create: (_) => LanguageProvider()),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets('Test 1: ListingReviewScreen renders AI Suggested Price section with all inputs', (tester) async {
    await tester.pumpWidget(_buildTestableWidget(
      const ListingReviewScreen(
        imageUrl: 'https://example.com/craft.jpg',
        initialTitleEn: 'Terracotta Chai Kulhad',
        initialTitleHi: 'टेराकोटा कुल्हड़',
        initialDescEn: 'Handmade clay tea cups',
        initialDescHi: 'हाथ से बने मिट्टी के कुल्हड़',
        initialCategory: 'Pottery',
        keyFeatures: ['100% Clay', 'Handcrafted'],
        transcript: 'यह शुद्ध मिट्टी से बना कुल्हड़ है',
      ),
    ));

    // Wait for initial price suggestion fetch to resolve
    await tester.pumpAndSettle();

    // 1. Verify AI pricing header
    expect(find.textContaining('AI अनुशंसित निष्पक्ष मूल्य'), findsOneWidget);

    // 2. Verify Material Cost input field is present
    expect(find.text('सामग्री लागत (₹) *'), findsOneWidget);
    expect(find.byIcon(Icons.shopping_bag_outlined), findsOneWidget);

    // 3. Verify Region dropdown is present
    expect(find.text('शिल्प क्षेत्र (Region) *'), findsOneWidget);

    // 4. Verify Size pills are present
    expect(find.text('छोटा (S)'), findsOneWidget);
    expect(find.text('मध्यम (M)'), findsOneWidget);
    expect(find.text('बड़ा (L)'), findsOneWidget);

    // 5. Verify Recalculate button is present
    expect(find.textContaining('नया मूल्य सुझाएं'), findsOneWidget);

    // 6. Verify Suggested price and Apply button exist
    expect(find.textContaining('यह कीमत लागू करें'), findsOneWidget);

    // 7. Verify editable final price field exists
    expect(find.text('कीमत (₹) *'), findsOneWidget);
  });

  testWidgets('Test 2: BusinessAssistantScreen displays chat bubbles, text input, and responds to messages', (tester) async {
    await tester.pumpWidget(_buildTestableWidget(
      const BusinessAssistantScreen(),
    ));

    await tester.pumpAndSettle();

    // 1. Verify screen title
    expect(find.textContaining('व्यापार सहायक'), findsWidgets);

    // 2. Verify initial welcome message from AI is present
    expect(find.textContaining('नमस्ते शिल्पकार जी!'), findsOneWidget);

    // 3. Verify input field and send button are present
    final inputFinder = find.byType(TextField);
    expect(inputFinder, findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);

    // 4. Type a question
    await tester.enterText(inputFinder, 'दीवाली के मौसम में बिक्री कैसे बढ़ाएं?');
    await tester.pump();

    // 5. Tap send button
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    // 6. User message bubble appears
    expect(find.text('दीवाली के मौसम में बिक्री कैसे बढ़ाएं?'), findsOneWidget);

    // Wait for response to arrive (mock or real API)
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // 7. AI Counselor response bubble is rendered
    expect(find.textContaining('शिल्पसेतु व्यापार सहायक'), findsWidgets);
  });

  testWidgets('Test 3: MainScreen renders FloatingActionButton and AppBar entry points for Business Assistant', (tester) async {
    await tester.pumpWidget(_buildTestableWidget(
      const MainScreen(),
    ));

    await tester.pumpAndSettle();

    // 1. Verify Floating Action Button exists
    expect(find.text('AI व्यापार सहायक'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    // 2. Verify AppBar Assistant icon exists
    expect(find.byTooltip('व्यापार सहायक (AI Business Assistant)'), findsOneWidget);

    // 3. Verify Quick Action card on Home screen exists
    expect(find.textContaining('AI व्यापार सहायक (Business Guide)'), findsOneWidget);
  });
}
