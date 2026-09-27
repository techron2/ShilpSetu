import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/models/order_model.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/language_provider.dart';
import 'package:frontend/screens/orders_screen.dart';

Widget _buildTestWidget(Widget child, {LanguageProvider? languageProvider}) {
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

  testWidgets(
      'TEST 1: Shipped advances through delivery and updates filters immediately',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final lang = LanguageProvider();
    await lang.setLanguage('en', updateFirestore: false);

    final initialOrders = [
      const OrderModel(
        id: 'ord_shipped_123',
        productId: 'prod_1',
        buyerId: 'buyer_1',
        artisanId: 'artisan_1',
        quantity: 2,
        totalPrice: 700.0,
        status: 'shipped',
        productTitle: 'Madhubani Handcrafted Painting',
        buyerName: 'Ramesh Kumar',
        deliveryAddress: 'New Delhi, India',
      ),
    ];

    // Mount screen with initial shipped order and mock status update success
    await tester.pumpWidget(_buildTestWidget(
      OrdersScreen(
        initialOrders: initialOrders,
        onCustomUpdateStatus: (orderId, newStatus) async => true,
      ),
      languageProvider: lang,
    ));
    await tester.pumpAndSettle();

    // Verify the shipped order's next action is out for delivery.
    expect(find.widgetWithText(ElevatedButton, '📍 Out for Delivery'), findsOneWidget);
    expect(find.text('Madhubani Handcrafted Painting'), findsOneWidget);

    // Tap "Out for Delivery"
    await tester.tap(find.widgetWithText(ElevatedButton, '📍 Out for Delivery'));
    await tester.pumpAndSettle();

    expect(find.text('🚚 Out for Delivery'), findsWidgets);
    expect(find.widgetWithText(ElevatedButton, '📦 Mark Delivered'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, '📦 Mark Delivered'));
    await tester.pumpAndSettle();
    expect(find.text('📦 Delivered'), findsWidgets);
    expect(find.widgetWithText(ElevatedButton, '📦 Mark Delivered'), findsNothing);

    // 2. Switch to the "Shipped" filter ChoiceChip
    await tester.tap(find.widgetWithText(ChoiceChip, lang.getText('order_filter_shipped')));
    await tester.pumpAndSettle();

    // Confirm that the same order is NO LONGER listed under "Shipped" (empty state shows)
    expect(find.text('Madhubani Handcrafted Painting'), findsNothing);
    expect(find.text(lang.getText('order_no_orders')), findsOneWidget);

    // 3. Switch to the "Delivered" filter ChoiceChip
    await tester.tap(find.widgetWithText(ChoiceChip, lang.getText('order_filter_delivered')));
    await tester.pumpAndSettle();

    // Confirm the order is present under "Delivered"
    expect(find.text('Madhubani Handcrafted Painting'), findsOneWidget);
    expect(find.text('📦 Delivered'), findsWidgets);
  });

  testWidgets(
      'TEST 2: On "Shipped" tab, Out for Delivery immediately removes the order from view',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final lang = LanguageProvider();
    await lang.setLanguage('en', updateFirestore: false);

    final initialOrders = [
      const OrderModel(
        id: 'ord_shipped_456',
        productId: 'prod_2',
        buyerId: 'buyer_2',
        artisanId: 'artisan_1',
        quantity: 1,
        totalPrice: 350.0,
        status: 'shipped',
        productTitle: 'Blue Pottery Vase',
        buyerName: 'Sunita Sharma',
      ),
    ];

    await tester.pumpWidget(_buildTestWidget(
      OrdersScreen(
        initialOrders: initialOrders,
        onCustomUpdateStatus: (orderId, newStatus) async => true,
      ),
      languageProvider: lang,
    ));
    await tester.pumpAndSettle();

    // Switch to "Shipped" filter ChoiceChip
    await tester.tap(find.widgetWithText(ChoiceChip, lang.getText('order_filter_shipped')));
    await tester.pumpAndSettle();

    // Verify order is present
    expect(find.text('Blue Pottery Vase'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '📍 Out for Delivery'), findsOneWidget);

    // Tap "Out for Delivery" while filtered by Shipped
    await tester.tap(find.widgetWithText(ElevatedButton, '📍 Out for Delivery'));
    await tester.pumpAndSettle();

    // Order must immediately vanish from the Shipped view without manual refresh
    expect(find.text('Blue Pottery Vase'), findsNothing);
    expect(find.text(lang.getText('order_no_orders')), findsOneWidget);
  });

  testWidgets(
      'TEST 3: Confirm Order and Mark Shipped immediately auto-refresh UI and update filter tabs',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final lang = LanguageProvider();
    await lang.setLanguage('en', updateFirestore: false);

    final initialOrders = [
      const OrderModel(
        id: 'ord_pending_789',
        productId: 'prod_3',
        buyerId: 'buyer_3',
        artisanId: 'artisan_1',
        quantity: 1,
        totalPrice: 500.0,
        status: 'pending',
        productTitle: 'Terracotta Lamp',
        buyerName: 'Anil Patel',
      ),
    ];

    await tester.pumpWidget(_buildTestWidget(
      OrdersScreen(
        initialOrders: initialOrders,
        onCustomUpdateStatus: (orderId, newStatus) async => true,
      ),
      languageProvider: lang,
    ));
    await tester.pumpAndSettle();

    // Initially pending action button exists
    expect(find.widgetWithText(ElevatedButton, '✅ Accept Order'), findsOneWidget);

    // Tap "Accept Order"
    await tester.tap(find.widgetWithText(ElevatedButton, '✅ Accept Order'));
    await tester.pumpAndSettle();

    // Status immediately updates to confirmed and the next action is shipped.
    expect(find.widgetWithText(ElevatedButton, '🚚 Mark Shipped'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '✅ Accept Order'), findsNothing);

    // Tap "Mark Shipped"
    await tester.tap(find.widgetWithText(ElevatedButton, '🚚 Mark Shipped'));
    await tester.pumpAndSettle();

    // Status immediately updates to shipped and the next action is out for delivery.
    expect(find.widgetWithText(ElevatedButton, '📍 Out for Delivery'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '🚚 Mark Shipped'), findsNothing);
  });
}
