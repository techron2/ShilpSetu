import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/utils/inr.dart';

void main() {
  test('formatInr groups Indian digits without decimals', () {
    expect(formatInr(0), '₹0');
    expect(formatInr(350), '₹350');
    expect(formatInr(999), '₹999');
    expect(formatInr(1000), '₹1,000');
    expect(formatInr(6800), '₹6,800');
    expect(formatInr(24000), '₹24,000');
    expect(formatInr(150000), '₹1,50,000');
    expect(formatInr(6800000), '₹68,00,000');
  });

  test('formatInr handles paise and negatives', () {
    expect(formatInr(1499.5), '₹1,499.50');
    expect(formatInr(99.05), '₹99.05');
    expect(formatInr(-2500), '-₹2,500');
  });
}
