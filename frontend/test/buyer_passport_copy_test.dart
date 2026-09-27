import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:frontend/screens/buyer/buyer_product_detail_screen.dart';

void _setLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Map<String, dynamic> _listing({bool includeId = true}) => {
  if (includeId) 'id': 'sparse-passport-item',
  'title': 'Blue clay bowl',
  'description': 'A listing description.',
  'price': 450,
  'stock_quantity': 3,
  'category': 'Pottery',
};

void main() {
  testWidgets(
    'Passport copy describes available recorded details and keeps its QR',
    (tester) async {
      _setLargeViewport(tester);
      await tester.pumpWidget(
        MaterialApp(home: BuyerProductDetailScreen(product: _listing())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsOneWidget);
      expect(
        find.text(
          'Scan this QR code to view recorded product, artisan, region, and provenance details when available.',
        ),
        findsOneWidget,
      );
      expect(find.text('View Web Passport'), findsOneWidget);
      expect(find.textContaining('verify GI certification'), findsNothing);
      expect(
        find.textContaining('authentic sustainable materials'),
        findsNothing,
      );
      expect(find.textContaining('100% Handcrafted'), findsNothing);
    },
  );

  testWidgets('local share fallback uses listing facts without trust claims', (
    tester,
  ) async {
    _setLargeViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: BuyerProductDetailScreen(product: _listing(includeId: false)),
      ),
    );
    await tester.pumpAndSettle();

    final shareButton = find.text('📲 Share');
    await tester.ensureVisible(shareButton);
    await tester.tap(shareButton);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Discover Blue clay bowl on HunarSathi'),
      findsOneWidget,
    );
    expect(find.textContaining('Price: ₹450'), findsOneWidget);
    expect(
      find.textContaining('Support artisans through HunarSathi.'),
      findsOneWidget,
    );
    expect(find.textContaining('authentic'), findsNothing);
    expect(find.textContaining('handcrafted'), findsNothing);
    expect(find.textContaining('sustainable'), findsNothing);
    expect(find.textContaining('certified'), findsNothing);
  });
}
