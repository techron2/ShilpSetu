import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/models/order_model.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/language_provider.dart';
import 'package:frontend/screens/buyer/buyer_orders_screen.dart';
import 'package:frontend/screens/orders_screen.dart';
import 'package:frontend/widgets/order_placed_dialog.dart';

OrderModel _order({String id = 'order-1', String status = 'pending'}) {
  return OrderModel(
    id: id,
    productId: 'product-1',
    buyerId: 'buyer-1',
    artisanId: 'artisan-1',
    quantity: 2,
    totalPrice: 6800,
    status: status,
    productTitle: 'Blue Pottery Vase',
    buyerName: 'Buyer',
    artisanName: 'Artisan',
    deliveryAddress: 'Jaipur, Rajasthan',
    createdAt: '2026-09-10T10:00:00.000Z',
    updatedAt: '2026-09-10T10:00:00.000Z',
    statusHistory: const [
      StatusHistoryEntry(
        status: 'placed',
        timestamp: '2026-09-10T10:00:00.000Z',
      ),
    ],
  );
}

Widget _testable(Widget child, {LanguageProvider? language}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppAuthProvider()),
      ChangeNotifierProvider(create: (_) => language ?? LanguageProvider()),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'successful order confirmation opens the real Buyer Orders screen',
    (tester) async {
      await tester.pumpWidget(
        _testable(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => OrderPlacedDialog(order: _order()),
                ),
                child: const Text('Show successful order'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show successful order'));
      await tester.pumpAndSettle();

      expect(find.text('Order Placed! 🎉'), findsOneWidget);
      expect(find.text('Blue Pottery Vase'), findsOneWidget);
      expect(find.text('Quantity: 2 units'), findsOneWidget);
      expect(find.text('Total: ₹6,800'), findsOneWidget);
      expect(find.text('Shipping to: Jaipur, Rajasthan'), findsOneWidget);
      expect(find.text('View My Orders'), findsOneWidget);

      await tester.tap(find.text('View My Orders'));
      await tester.pumpAndSettle();

      expect(find.byType(BuyerOrdersScreen), findsOneWidget);
      expect(
        tester
            .widget<BuyerOrdersScreen>(find.byType(BuyerOrdersScreen))
            .initialOrders,
        isNull,
      );
      expect(find.text('My Orders'), findsOneWidget);
      expect(find.text('Sign in to view your orders'), findsOneWidget);
    },
  );

  testWidgets(
    'artisan can progress an order through every backend fulfillment stage',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final language = LanguageProvider();
      await language.setLanguage('en', updateFirestore: false);
      final transitions = <String>[];

      await tester.pumpWidget(
        _testable(
          OrdersScreen(
            initialOrders: [_order()],
            onCustomUpdateStatus: (id, status) async {
              transitions.add(status);
              return true;
            },
          ),
          language: language,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('₹6,800'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, '✅ Accept Order'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(ElevatedButton, '✅ Accept Order'));
      await tester.pumpAndSettle();
      expect(find.text('✅ Confirmed'), findsWidgets);
      expect(
        find.widgetWithText(ElevatedButton, '🚚 Mark Shipped'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(ElevatedButton, '🚚 Mark Shipped'));
      await tester.pumpAndSettle();
      expect(find.text('🚚 Shipped'), findsWidgets);
      expect(
        find.widgetWithText(ElevatedButton, '📍 Out for Delivery'),
        findsOneWidget,
      );

      await tester.tap(
        find.widgetWithText(ElevatedButton, '📍 Out for Delivery'),
      );
      await tester.pumpAndSettle();
      expect(find.text('🚚 Out for Delivery'), findsWidgets);
      expect(
        find.widgetWithText(ElevatedButton, '📦 Mark Delivered'),
        findsOneWidget,
      );

      await tester.tap(
        find.widgetWithText(ElevatedButton, '📦 Mark Delivered'),
      );
      await tester.pumpAndSettle();
      expect(find.text('📦 Delivered'), findsWidgets);
      expect(
        find.widgetWithText(ElevatedButton, '📦 Mark Delivered'),
        findsNothing,
      );
      expect(transitions, [
        'confirmed',
        'shipped',
        'out_for_delivery',
        'delivered',
      ]);
    },
  );

  testWidgets(
    'buyer sees out-for-delivery status, stage four, and a working filter',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final outForDelivery = _order(id: 'out-1', status: 'out_for_delivery')
          .copyWith(
            updatedAt: '2026-09-12T10:00:00.000Z',
            statusHistory: const [
              StatusHistoryEntry(
                status: 'placed',
                timestamp: '2026-09-10T10:00:00.000Z',
              ),
              StatusHistoryEntry(
                status: 'confirmed',
                timestamp: '2026-09-10T11:00:00.000Z',
              ),
              StatusHistoryEntry(
                status: 'shipped',
                timestamp: '2026-09-11T09:00:00.000Z',
              ),
              StatusHistoryEntry(
                status: 'out_for_delivery',
                timestamp: '2026-09-12T10:00:00.000Z',
              ),
            ],
          );
      final shipped = _order(
        id: 'shipped-1',
        status: 'shipped',
      ).copyWith(productTitle: 'Woven Table Runner');

      await tester.pumpWidget(
        MaterialApp(
          home: BuyerOrdersScreen(initialOrders: [outForDelivery, shipped]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('🚚 Out for Delivery'), findsOneWidget);
      expect(find.text('Out for Delivery'), findsWidgets);
      expect(find.text('Woven Table Runner'), findsOneWidget);
      final stageFourColors = find
          .byIcon(Icons.location_on_rounded)
          .evaluate()
          .map((element) => (element.widget as Icon).color)
          .toList();
      final deliveredStageColors = find
          .byIcon(Icons.home_rounded)
          .evaluate()
          .map((element) => (element.widget as Icon).color)
          .toList();
      expect(stageFourColors, [Colors.white, const Color(0xFF9CA3AF)]);
      expect(deliveredStageColors, [
        const Color(0xFF9CA3AF),
        const Color(0xFF9CA3AF),
      ]);
      expect(find.text('Total Amount'), findsWidgets);
      expect(find.text('₹6,800'), findsWidgets);

      await tester.tap(find.widgetWithText(ChoiceChip, '📦 Out for Delivery'));
      await tester.pumpAndSettle();
      expect(find.text('Blue Pottery Vase'), findsOneWidget);
      expect(find.text('Woven Table Runner'), findsNothing);
    },
  );

  test('OrderModel lifecycle and labels include the backend out-for-delivery stage', () {
    expect(OrderModel.statusFlow, [
      'pending',
      'confirmed',
      'shipped',
      'out_for_delivery',
      'delivered',
      'paid',
    ]);
    expect(
      _order(status: 'out_for_delivery').statusLabel,
      '🚚 Out for Delivery',
    );
    expect(_order(status: 'paid').statusLabel, '💰 Paid');
    expect(_order(status: 'cancelled').statusLabel, '❌ Cancelled');
  });

  testWidgets(
    'delivered, paid, and cancelled orders have no fulfillment action',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final language = LanguageProvider();
      await language.setLanguage('en', updateFirestore: false);
      await tester.pumpWidget(
        _testable(
          OrdersScreen(
            initialOrders: [
              _order(id: 'delivered', status: 'delivered'),
              _order(id: 'paid', status: 'paid'),
              _order(id: 'cancelled', status: 'cancelled'),
            ],
          ),
          language: language,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ElevatedButton), findsNothing);
    },
  );
}
