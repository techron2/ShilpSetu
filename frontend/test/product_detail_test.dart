import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/models/product_model.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/providers/navigation_provider.dart';
import 'package:frontend/screens/artisan/product_detail_screen.dart';
import 'package:frontend/screens/artisan/add_product_screen.dart';

Widget _buildTestableWidget(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ChangeNotifierProvider(create: (_) => AppAuthProvider()),
      ChangeNotifierProvider(create: (_) => ProductProvider()),
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(800, 1200)),
        child: child,
      ),
    ),
  );
}

void main() {
  const sampleProduct1 = Product(
    id: 'prod_001',
    artisanId: 'artisan_001',
    title: 'हस्तनिर्मित पारंपरिक टेराकोटा कुल्हड़',
    description: 'शुद्ध लाल मिट्टी से बने पारंपरिक कुल्हड़ चाय सेट।\n\n[English]: Authentic handmade terracotta clay tea kulhad set.',
    imageUrl: '',
    price: 350.0,
    stockQuantity: 18,
    category: 'Pottery',
    createdAt: '2026-09-08T10:00:00Z',
  );

  const sampleProduct2 = Product(
    id: 'prod_002',
    artisanId: 'artisan_001',
    title: 'हस्तशिल्प: यह स्कार्फ एक मलमल के कपड़े का',
    description: 'प्राकृतिक रंगों से बना पारंपरिक मलमल दुपट्टा।\n\n[English]: Pure handcrafted mulmul cotton stole with natural block prints.',
    imageUrl: '',
    price: 850.0,
    stockQuantity: 10,
    category: 'Textiles',
    createdAt: '2026-09-08T10:30:00Z',
  );

  testWidgets('Test 1: ProductDetailScreen displays product 1 details accurately', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildTestableWidget(
      const ProductDetailScreen(
        productId: 'prod_001',
        initialProduct: sampleProduct1,
      ),
    ));

    await tester.pumpAndSettle();

    // Verify Title
    expect(find.textContaining('हस्तनिर्मित'), findsOneWidget);

    // Verify Category badge
    expect(find.text('Pottery'), findsOneWidget);

    // Verify Price and Stock
    expect(find.text('₹350'), findsOneWidget);
    expect(find.textContaining('18'), findsOneWidget);

    // Verify Bilingual tabs exist
    expect(find.textContaining('हिंदी'), findsOneWidget);
    expect(find.textContaining('English'), findsOneWidget);

    // Switch to English tab
    await tester.tap(find.textContaining('English'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Authentic handmade terracotta'), findsOneWidget);

    // Verify Human-readable date
    expect(find.textContaining('08 Sep 2026'), findsOneWidget);

    // Verify Edit and Delete buttons exist
    expect(find.textContaining('संपादित करें'), findsOneWidget);
    expect(find.textContaining('हटाएं'), findsOneWidget);
  });

  testWidgets('Test 2: ProductDetailScreen displays product 2 details accurately', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildTestableWidget(
      const ProductDetailScreen(
        productId: 'prod_002',
        initialProduct: sampleProduct2,
      ),
    ));

    await tester.pumpAndSettle();

    // Verify Title of Product 2
    expect(find.textContaining('हस्तशिल्प: यह स्कार्फ'), findsOneWidget);

    // Verify Category
    expect(find.text('Textiles'), findsOneWidget);

    // Verify Price and Stock
    expect(find.text('₹850'), findsOneWidget);
    expect(find.text('10 उपलब्ध'), findsOneWidget);

    // Verify Date
    expect(find.textContaining('08 Sep 2026'), findsOneWidget);
  });

  testWidgets('Test 3: Edit button opens AddProductScreen prefilled with product data', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildTestableWidget(
      const ProductDetailScreen(
        productId: 'prod_001',
        initialProduct: sampleProduct1,
      ),
    ));

    await tester.pumpAndSettle();

    // Tap Edit
    await tester.tap(find.textContaining('संपादित करें'));
    await tester.pumpAndSettle();

    // Verify Edit form is open
    expect(find.byType(AddProductScreen), findsOneWidget);
    expect(find.textContaining('उत्पाद संपादित करें'), findsOneWidget);
    expect(find.textContaining('हस्तनिर्मित'), findsOneWidget);
  });

  testWidgets('Test 4: Delete button opens confirmation dialog', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildTestableWidget(
      const ProductDetailScreen(
        productId: 'prod_001',
        initialProduct: sampleProduct1,
      ),
    ));

    await tester.pumpAndSettle();

    // Tap Delete
    await tester.tap(find.textContaining('हटाएं'));
    await tester.pumpAndSettle();

    // Verify confirmation dialog
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('उत्पाद हटाएं?'), findsOneWidget);
    expect(find.text('रद्द करें (Cancel)'), findsOneWidget);
  });
}
