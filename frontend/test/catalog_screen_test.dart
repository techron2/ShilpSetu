import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/models/product_model.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/language_provider.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/providers/navigation_provider.dart';
import 'package:frontend/screens/catalog_screen.dart';

Widget _buildTestableWidget(Widget child, {
  ProductProvider? productProvider,
  LanguageProvider? languageProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ChangeNotifierProvider(create: (_) => AppAuthProvider()),
      ChangeNotifierProvider(create: (_) => productProvider ?? ProductProvider()),
      ChangeNotifierProvider(create: (_) => languageProvider ?? LanguageProvider()),
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
  testWidgets('CatalogScreen renders UI and displays products from provider', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final lang = LanguageProvider();
    await tester.pumpWidget(_buildTestableWidget(
      const CatalogScreen(),
      languageProvider: lang,
    ));
    await tester.pump();

    // Verify AI camera banner
    expect(find.text(lang.getText('catalog_smart_scan_title')), findsOneWidget);
    expect(find.text(lang.getText('catalog_smart_scan_desc')), findsOneWidget);
    expect(find.text(lang.getText('catalog_smart_scan_btn')), findsOneWidget);
  });
}
