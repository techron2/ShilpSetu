import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/utils/buyer_metadata.dart';

void main() {
  test('missing rating does not become 4.0', () {
    expect(parseProductRating({}), isNull);
    expect(parseProductRating({'rating': null}), isNull);
    expect(parseProductRating({'title': 'Pot'}), isNull);
  });

  test('actual rating is displayed', () {
    expect(parseProductRating({'rating': 4.6}), 4.6);
    expect(parseProductRating({'rating': '4.5'}), 4.5);
    expect(parseReviewCount({'review_count': 88}), 88);
  });

  test('missing verification does not display Verified', () {
    expect(shouldShowVerifiedBadge({}), isFalse);
    expect(shouldShowVerifiedBadge({'title': 'Pot'}), isFalse);
    expect(shouldShowVerifiedBadge({'verified': true}), isTrue);
    expect(shouldShowVerifiedBadge({'verification_status': 'verified'}), isTrue);
  });

  test('missing cluster metadata does not display Cluster', () {
    expect(shouldShowClusterBadge({}), isFalse);
    expect(shouldShowClusterBadge({'category': 'Pottery'}), isFalse);
    expect(
      shouldShowClusterBadge({'cluster_id': 'cluster_1'}),
      isTrue,
    );
  });

  test('missing trust fields do not become Master/4.8/100', () {
    expect(trustBadgeText(null), isNull);
    expect(trustBadgeText({}), isNull);
    expect(trustScoreValue(null), isNull);
    expect(trustFulfillmentPct({}), isNull);
    expect(
      trustBadgeText({'badge': '🌟 Master Artisan'}),
      '🌟 Master Artisan',
    );
    expect(trustScoreValue({'trust_score': 4.8}), 4.8);
    expect(trustFulfillmentPct({'completion_rate_pct': 100}), 100);
    expect(isPositiveTrustBadge('✅ Verified Artisan'), isTrue);
    expect(isPositiveTrustBadge('🌱 New Artisan'), isFalse);
  });
}
