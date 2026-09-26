import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/utils/inr.dart';

void main() {
  test('Indian grouping for whole rupees', () {
    expect(formatInr(350), '₹350');
    expect(formatInr(6800), '₹6,800');
    expect(formatInr(150000), '₹1,50,000');
    expect(formatInr(1250000), '₹12,50,000');
    expect(formatInr(0), '₹0');
  });

  test('decimals, negatives, and paise rounding edges', () {
    expect(formatInr(1500.5), '₹1,500.50');
    expect(formatInr(99.999), '₹100');
    expect(formatInr(-6800), '-₹6,800');
    expect(formatInr(-150000.75), '-₹1,50,000.75');
    // No double-prefix: caller passes raw numbers only.
    expect(formatInr(350).startsWith('₹₹'), isFalse);
  });
}
