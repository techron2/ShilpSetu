import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('KalaVistar renders the unauthenticated entry point', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ShilpSetuApp());

    expect(find.text('KalaVistar'), findsOneWidget);
    expect(find.textContaining('Demo Artisan Access'), findsOneWidget);
  });
}
