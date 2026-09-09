import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/language_provider.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/screens/artisan/add_product_screen.dart';

Widget _buildTestableWidget() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppAuthProvider()),
      ChangeNotifierProvider(create: (_) => ProductProvider()),
      ChangeNotifierProvider(create: (_) => LanguageProvider()),
    ],
    child: const MaterialApp(
      home: AddProductScreen(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AddProductScreen removes orange banner and URL text input, shows image picker', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildTestableWidget());
    await tester.pumpAndSettle();

    // 1. Confirm top orange banner label is REMOVED
    expect(
      find.textContaining('Your product will be visible to buyers on ShilpSetu Marketplace'),
      findsNothing,
    );
    expect(
      find.textContaining('बाज़ार में प्रदर्शित होगा'),
      findsNothing,
    );

    // 2. Confirm "Image URL (optional)" text field is REMOVED
    expect(
      find.textContaining('Image URL'),
      findsNothing,
    );
    expect(
      find.textContaining('फोटो लिंक'),
      findsNothing,
    );

    // 3. Confirm native photo upload / picker card is PRESENT
    expect(find.textContaining('Product Image (उत्पाद फोटो)'), findsOneWidget);
    expect(find.textContaining('फोटो चुनें (Choose Photo)'), findsOneWidget);

    // 4. Tap the upload card to open bottom sheet
    await tester.tap(find.textContaining('फोटो चुनें (Choose Photo)'));
    await tester.pumpAndSettle();

    // 5. Verify bottom sheet offers Camera and Gallery options
    expect(find.textContaining('Take Photo'), findsOneWidget);
    expect(find.textContaining('Gallery / Files'), findsOneWidget);
  });
}
