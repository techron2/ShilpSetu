import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/rfq_model.dart';
import 'package:frontend/screens/buyer/rfq_screen.dart';
import 'package:frontend/screens/buyer/supplier_comparison_screen.dart';

void _setLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Map<String, dynamic> _match({required int rank, required double score}) => {
  'rank': rank,
  'similarity_score': score,
  'product': {
    'id': 'product-$rank',
    'title': 'Pottery cup $rank',
    'price': 300,
    'stock_quantity': 10,
  },
  'artisan': {'name': 'Artisan $rank', 'region': 'Bihar'},
};

void main() {
  test(
    'RFQ model preserves true/false and defaults missing provenance false',
    () {
      RfqModel parse(Map<String, dynamic> json) => RfqModel.fromJson({
        'id': 'rfq-1',
        'buyer_id': 'buyer-1',
        'requirement_text': '20 pottery cups',
        ...json,
      });

      final geminiRfq = parse({'ai_parsed': true});
      final fallbackRfq = parse({'ai_parsed': false});
      expect(geminiRfq.aiParsed, isTrue);
      expect(geminiRfq.toJson()['ai_parsed'], isTrue);
      expect(fallbackRfq.aiParsed, isFalse);
      expect(fallbackRfq.toJson()['ai_parsed'], isFalse);
      expect(parse({}).aiParsed, isFalse);
    },
  );

  testWidgets('RFQ result labels reflect whether Gemini actually parsed it', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RfqParsingStatus(aiParsed: true))),
    );
    expect(find.text('AI-Structured RFQ'), findsOneWidget);
    expect(find.text('AI Parsed'), findsOneWidget);
    expect(find.text('Rule-based fallback'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RfqParsingStatus(aiParsed: false)),
      ),
    );
    expect(find.text('Structured RFQ'), findsOneWidget);
    expect(find.text('Rule-based fallback'), findsOneWidget);
    expect(find.text('AI Parsed'), findsNothing);
  });

  testWidgets('RFQ invocation copy does not promise AI before parsing', (
    tester,
  ) async {
    _setLargeViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: RfqScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Generate RFQ'), findsOneWidget);
    expect(find.text('AI-assisted RFQ'), findsOneWidget);
    expect(find.text('AI-Powered RFQ Generator'), findsNothing);
    expect(find.text('Generate RFQ with AI'), findsNothing);
    expect(
      find.textContaining(
        'uses AI when available and falls back to basic structuring',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'supplier screen calls cosine scores requirement matches, not AI',
    (tester) async {
      _setLargeViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: SupplierComparisonScreen(
            matches: [
              _match(rank: 1, score: 0.82),
              _match(rank: 2, score: 0.64),
            ],
            requirement: const {'category': 'Pottery', 'quantity': 2},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('2 suppliers ranked by requirement match'),
        findsOneWidget,
      );
      expect(find.text('Requirement Match: 82%'), findsOneWidget);
      expect(find.text('Requirement Match'), findsOneWidget);
      expect(find.textContaining('AI Match'), findsNothing);
      expect(find.textContaining('AI matching'), findsNothing);
    },
  );
}
