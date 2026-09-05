import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('ShilpSetuApp renders smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ShilpSetuApp());

    // Verify that the bottom navigation items exist
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Catalog'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
