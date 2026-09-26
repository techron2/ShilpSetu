/// Pure presentation helpers for the buyer marketplace.
///
/// Missing data must look like missing data, not like positive verified data.
/// These helpers never fabricate ratings, verification, or cluster membership.
library;

/// Returns the real numeric rating when present, otherwise null.
///
/// Accepts num or numeric strings. Zero/negative values are treated as
/// absent because live ratings are 4.4-4.8 when present.
double? parseProductRating(Map<String, dynamic> product) {
  final raw = product['rating'];
  if (raw == null) return null;
  double? value;
  if (raw is num) {
    value = raw.toDouble();
  } else {
    value = double.tryParse(raw.toString().trim());
  }
  if (value == null || value <= 0) return null;
  return value;
}

/// Returns the real review count when present, otherwise null.
int? parseReviewCount(Map<String, dynamic> product) {
  final raw = product['review_count'];
  if (raw == null) return null;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw.toString().trim());
}

/// True only when the product carries explicit verification metadata.
///
/// Live products currently carry no verified/is_verified/verification_status
/// fields, so this is false for all of them (truthful: hide the badge).
bool shouldShowVerifiedBadge(Map<String, dynamic> product) {
  final verified = product['verified'];
  if (verified == true) return true;
  if (verified is String && verified.trim().toLowerCase() == 'true') return true;

  final isVerified = product['is_verified'];
  if (isVerified == true) return true;
  if (isVerified is String && isVerified.trim().toLowerCase() == 'true') {
    return true;
  }

  final status = product['verification_status']?.toString().trim().toLowerCase();
  if (status == 'verified' || status == 'approved' || status == 'true') {
    return true;
  }
  return false;
}

/// True only when the product carries explicit cluster membership metadata.
///
/// Search results contain no cluster/cluster_id fields, so grid badges stay
/// hidden rather than implying membership. No extra API fetch per card.
bool shouldShowClusterBadge(Map<String, dynamic> product) {
  for (final key in ['cluster', 'cluster_id', 'cluster_name']) {
    final raw = product[key]?.toString().trim() ?? '';
    if (raw.isNotEmpty) return true;
  }
  return false;
}

/// Truthful trust-badge text from a trust-score API object, or null.
///
/// Never falls back to 'Master Artisan' when the field is absent.
String? trustBadgeText(Map<String, dynamic>? trust) {
  final raw = trust?['badge']?.toString().trim() ?? '';
  return raw.isEmpty ? null : raw;
}

/// Truthful numeric trust score, or null when absent.
double? trustScoreValue(Map<String, dynamic>? trust) {
  final raw = trust?['trust_score'];
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw.toString());
}

/// Truthful fulfillment percentage, or null when absent.
int? trustFulfillmentPct(Map<String, dynamic>? trust) {
  final raw = trust?['completion_rate_pct'];
  if (raw == null) return null;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw.toString());
}

/// Whether a trust badge string represents a positive verified claim.
bool isPositiveTrustBadge(String? badge) {
  if (badge == null) return false;
  final lower = badge.toLowerCase();
  return lower.contains('verified') || lower.contains('master');
}
