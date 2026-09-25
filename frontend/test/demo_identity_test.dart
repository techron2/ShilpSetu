import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/config/demo_identity.dart';
import 'package:frontend/providers/auth_provider.dart';

void main() {
  test('artisan demo session uses the curated Radha identity', () {
    final auth = AppAuthProvider();

    auth.enterArtisanDemo();

    expect(auth.isDemoMode, isTrue);
    expect(auth.isSignedIn, isTrue);
    expect(auth.effectiveUserId, DemoIdentity.artisanId);
    expect(auth.effectiveArtisanId, DemoIdentity.artisanId);
    expect(auth.userModel?.name, 'Radha Devi');
    expect(
      auth.userModel?.artisanCluster,
      'Gorakhpur Terracotta Heritage Cluster',
    );
  });

  test('sign out clears demo state without Firebase initialization', () async {
    final auth = AppAuthProvider()..enterArtisanDemo();

    await auth.signOut();

    expect(auth.isDemoMode, isFalse);
    expect(auth.isSignedIn, isFalse);
    expect(auth.effectiveUserId, isNull);
    expect(auth.userModel, isNull);
  });
}
