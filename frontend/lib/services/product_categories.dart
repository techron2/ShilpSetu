/// Canonical product-category vocabulary for HunarSathi.
///
/// Single frontend source of truth mirroring `backend/services/categories.py`.
/// Backend normalization remains authoritative for API/storage correctness.
const List<String> canonicalProductCategories = [
  'Textiles',
  'Pottery',
  'Jewellery',
  'Embroidery',
  'Wood Craft',
  'Leather',
  'Painting',
  'Metal Craft',
  'Other',
];

const Map<String, String> _legacyCategoryAliases = {
  'jewelry': 'Jewellery',
  'woodwork': 'Wood Craft',
  'wood work': 'Wood Craft',
  'metalwork': 'Metal Craft',
  'metal work': 'Metal Craft',
  'accessories': 'Other',
  'accessory': 'Other',
  'stonework': 'Other',
  'basketry': 'Other',
  'handicraft': 'Other',
};

/// Maps any input to its canonical category spelling.
///
/// - Canonical values pass through with canonical casing.
/// - Known legacy spellings map to canonical.
/// - Unknown non-empty values pass through untouched.
/// - Null/empty returns [fallback] (defaults to 'Other').
String normalizeProductCategory(Object? value, {String fallback = 'Other'}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  if (text.isEmpty) return fallback;
  final lower = text.toLowerCase();
  for (final canonical in canonicalProductCategories) {
    if (canonical.toLowerCase() == lower) return canonical;
  }
  final aliased = _legacyCategoryAliases[lower];
  if (aliased != null) return aliased;
  return text;
}

/// True when [value] exactly matches a canonical category (case-insensitive).
bool isCanonicalProductCategory(Object? value) {
  if (value == null) return false;
  final lower = value.toString().trim().toLowerCase();
  return canonicalProductCategories.any((c) => c.toLowerCase() == lower);
}
