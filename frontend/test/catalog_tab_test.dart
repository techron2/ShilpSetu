import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/navigation_provider.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/screens/artisan/my_products_screen.dart';
import 'package:frontend/screens/main_screen.dart';

/// Regression tests for Phase 1.3: the artisan Catalog tab must resolve to
/// the live My Products experience, never to hardcoded demo content.
Widget _artisanShell() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ChangeNotifierProvider(create: (_) => AppAuthProvider()),
      ChangeNotifierProvider(create: (_) => ProductProvider()),
    ],
    child: const MaterialApp(home: MainScreen()),
  );
}

void main() {
  testWidgets('Catalog tab shows live My Products, not hardcoded items',
      (tester) async {
    await tester.pumpWidget(_artisanShell());
    await tester.pump();

    // Open the Catalog tab (label kept for navigation continuity).
    await tester.tap(find.text('Catalog'));
    await tester.pump();

    // Legacy hardcoded catalog content must be gone.
    expect(find.text('आपकी शिल्प सूची (Your Catalog)'), findsNothing);
    expect(find.text('स्मार्ट AI कैमरा स्कैन'), findsNothing);
    expect(find.text('फोटो खींचकर नया उत्पाद जोड़ें'), findsNothing);

    // The live product-management experience is present instead:
    // its Add action exists in every state (loading/error/empty/list).
    expect(find.text('Add Product'), findsOneWidget);
  });

  testWidgets('MyProductsScreen embedded mode drops inner AppBar',
      (tester) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
      ],
      child: const MaterialApp(
        home: MyProductsScreen(embedded: true),
      ),
    ));
    await tester.pump();

    expect(find.text('My Products'), findsNothing);
    expect(find.text('Add Product'), findsOneWidget);
  });

  testWidgets('MyProductsScreen standalone keeps its AppBar', (tester) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
      ],
      child: const MaterialApp(
        home: MyProductsScreen(),
      ),
    ));
    await tester.pump();

    // Standalone (pushed from Home) keeps title + refresh action.
    expect(find.text('My Products'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
  });
}
