import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/models/product_model.dart';
import 'package:frontend/models/user_model.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/screens/artisan/listing_review_screen.dart';

class _CapturingProductProvider extends ProductProvider {
  Product? addedProduct;

  @override
  Future<bool> addProduct(Product product) async {
    addedProduct = product;
    return true;
  }
}

Future<Product?> _publishListing(
  WidgetTester tester,
  AppAuthProvider auth,
) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final products = _CapturingProductProvider();
  addTearDown(products.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppAuthProvider>.value(value: auth),
        ChangeNotifierProvider<ProductProvider>.value(value: products),
      ],
      child: const MaterialApp(
        home: ListingReviewScreen(
          imageUrl: 'https://example.com/craft.jpg',
          initialTitleEn: 'Handcrafted Cup',
          initialTitleHi: 'हस्तनिर्मित कप',
          initialDescEn: 'A handmade craft item.',
          initialDescHi: 'हाथ से बनी शिल्प वस्तु।',
          initialCategory: 'Pottery',
          keyFeatures: [],
          transcript: '',
        ),
      ),
    ),
  );

  // The title, description, and pricing inputs appear before price in form order.
  final priceField = find.byType(TextFormField).at(3);
  await tester.ensureVisible(priceField);
  await tester.enterText(priceField, '475');

  final saveButton = find.text('दुकान में जोड़ें (Save Product to Store)');
  await tester.ensureVisible(saveButton);
  await tester.pumpAndSettle();
  await tester.tap(saveButton);
  await tester.pumpAndSettle();

  return products.addedProduct;
}

void main() {
  testWidgets(
    'listing publish saves under the profile-backed active artisan, not artisan_001',
    (tester) async {
      final auth = AppAuthProvider();
      addTearDown(auth.dispose);
      auth.updateUserModel(
        const UserModel(
          uid: 'profile-artisan-uid',
          name: 'Demo Artisan',
          email: '',
          role: 'artisan',
        ),
      );

      expect(auth.firebaseUser, isNull);
      expect(auth.currentArtisanId, 'profile-artisan-uid');

      final savedProduct = await _publishListing(tester, auth);

      expect(savedProduct, isNotNull);
      expect(savedProduct!.artisanId, auth.currentArtisanId);
      expect(savedProduct.artisanId, 'profile-artisan-uid');
      expect(savedProduct.artisanId, isNot('artisan_001'));
    },
  );

  testWidgets(
    'listing publish uses the established one-tap demo artisan identity',
    (tester) async {
      final auth = AppAuthProvider();
      addTearDown(auth.dispose);

      expect(auth.firebaseUser, isNull);
      expect(auth.userModel, isNull);
      expect(auth.currentArtisanId, 'XatExY7HGxd71WbhBoHiF7wMuVm2');

      final savedProduct = await _publishListing(tester, auth);

      expect(savedProduct, isNotNull);
      expect(savedProduct!.artisanId, auth.currentArtisanId);
      expect(savedProduct.artisanId, 'XatExY7HGxd71WbhBoHiF7wMuVm2');
      expect(savedProduct.artisanId, isNot('artisan_001'));
    },
  );
}
