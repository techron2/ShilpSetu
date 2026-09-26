import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/services/product_categories.dart';

void main() {
  test('canonical list has 9 unique SIH demo categories', () {
    expect(canonicalProductCategories.length, 9);
    expect(canonicalProductCategories.toSet().length, 9);
    for (final expected in [
      'Textiles',
      'Pottery',
      'Jewellery',
      'Embroidery',
      'Wood Craft',
      'Leather',
      'Painting',
      'Metal Craft',
      'Other',
    ]) {
      expect(canonicalProductCategories, contains(expected));
    }
  });

  test('legacy aliases normalize to canonical', () {
    expect(normalizeProductCategory('Jewelry'), 'Jewellery');
    expect(normalizeProductCategory('jewellery'), 'Jewellery');
    expect(normalizeProductCategory('Woodwork'), 'Wood Craft');
    expect(normalizeProductCategory('wood work'), 'Wood Craft');
    expect(normalizeProductCategory('Metalwork'), 'Metal Craft');
    expect(normalizeProductCategory('METAL WORK'), 'Metal Craft');
    expect(normalizeProductCategory('Accessories'), 'Other');
    expect(normalizeProductCategory('Stonework'), 'Other');
    expect(normalizeProductCategory('Basketry'), 'Other');
  });

  test('canonical values keep canonical casing, empty falls back to Other', () {
    expect(normalizeProductCategory('pottery'), 'Pottery');
    expect(normalizeProductCategory('TEXTILES'), 'Textiles');
    expect(normalizeProductCategory('Wood Craft'), 'Wood Craft');
    expect(normalizeProductCategory(''), 'Other');
    expect(normalizeProductCategory(null), 'Other');
    expect(normalizeProductCategory('Other'), 'Other');
  });
}
