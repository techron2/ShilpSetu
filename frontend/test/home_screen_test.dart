import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/language_provider.dart';
import 'package:frontend/providers/navigation_provider.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/screens/home_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

Widget _buildTestWidget(Widget child, {LanguageProvider? languageProvider}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ChangeNotifierProvider(create: (_) => AppAuthProvider()),
      ChangeNotifierProvider(create: (_) => ProductProvider()),
      ChangeNotifierProvider(create: (_) => languageProvider ?? LanguageProvider()),
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(800, 1600)),
        child: child,
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('HomeScreen renders all 8 sections and respects LanguageProvider', (tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final lang = LanguageProvider();
    await tester.pumpWidget(_buildTestWidget(const HomeScreen(), languageProvider: lang));
    await tester.pump();

    // 1. Header
    expect(find.text(lang.getText('app_title')), findsOneWidget);
    expect(find.text(lang.getText('app_tagline')), findsOneWidget);

    // 2. Greeting
    expect(find.textContaining(lang.getText('home_greeting_prefix')), findsOneWidget);
    expect(find.text(lang.getText('home_overview_subtitle')), findsOneWidget);

    // 3. Carousel
    expect(find.text(lang.getText('banner_sell_title')), findsOneWidget);

    // 4. Three Stat Cards
    expect(find.text(lang.getText('stat_products_listed')), findsOneWidget);
    expect(find.text(lang.getText('stat_orders_to_pack')), findsOneWidget);
    expect(find.text(lang.getText('stat_earnings_month')), findsOneWidget);

    // 5. Quick Actions
    expect(find.text(lang.getText('quick_actions_title')), findsOneWidget);
    expect(find.text(lang.getText('qa_add_craft_title')), findsOneWidget);
    expect(find.text(lang.getText('qa_orders_title')), findsOneWidget);
    expect(find.text(lang.getText('qa_analytics_title')), findsOneWidget);
    expect(find.text(lang.getText('qa_cluster_title')), findsOneWidget);

    // 6. AI Business Guide
    expect(find.text(lang.getText('ai_guide_title')), findsOneWidget);
    expect(find.text(lang.getText('ai_guide_btn')), findsOneWidget);

    // 7. Recent Orders Header
    expect(find.text(lang.getText('recent_orders_title')), findsOneWidget);

    // 8. Top Products Header
    expect(find.text(lang.getText('top_products_title')), findsOneWidget);

    // Test Language Switch to English
    await lang.setLanguage('en', updateFirestore: false);
    await tester.pump();

    expect(find.text('ShilpSetu'), findsOneWidget);
    expect(find.text('Tradition • Craft • Tomorrow'), findsOneWidget);
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('AI Business Guide'), findsOneWidget);
    expect(find.text('Ask AI'), findsOneWidget);
    expect(find.text('Recent Orders'), findsOneWidget);
    expect(find.text('Top Products'), findsOneWidget);
  });
}
