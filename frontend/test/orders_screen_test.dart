import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/language_provider.dart';
import 'package:frontend/screens/orders_screen.dart';
import 'package:frontend/screens/buyer/buyer_orders_screen.dart';

Widget _buildTestableWidget(Widget child, {LanguageProvider? languageProvider}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppAuthProvider()),
      ChangeNotifierProvider(create: (_) => languageProvider ?? LanguageProvider()),
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

  testWidgets('OrdersScreen renders order tabs, filters, and NO Chat buttons anywhere', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final lang = LanguageProvider();
    await lang.setLanguage('en', updateFirestore: false);

    await tester.pumpWidget(_buildTestableWidget(
      const OrdersScreen(),
      languageProvider: lang,
    ));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify status filter chips exist (in English)
    expect(find.text(lang.getText('order_filter_all')), findsOneWidget);

    // Verify Chat button does NOT exist on the screen
    expect(find.text('Chat'), findsNothing);
    expect(find.byIcon(Icons.chat_rounded), findsNothing);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNothing);
  });

  testWidgets('BuyerOrdersScreen renders buyer order history and NO Chat buttons anywhere', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildTestableWidget(const BuyerOrdersScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify app bar title
    expect(find.text('My Orders'), findsOneWidget);

    // Verify Chat button does NOT exist on the screen
    expect(find.text('Chat'), findsNothing);
    expect(find.byIcon(Icons.chat_rounded), findsNothing);
  });
}
