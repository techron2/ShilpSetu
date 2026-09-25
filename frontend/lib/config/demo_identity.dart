import '../models/user_model.dart';

/// Deterministic identity used by the explicit artisan demo entry point.
///
/// The uid matches the curated Firestore seed in
/// `backend/seed_demo_catalog.py`, so every artisan surface reads the same
/// catalog, order, analytics, and profile records during a demo.
abstract final class DemoIdentity {
  static const artisanId = 'demo_artisan_radha';

  static const artisan = UserModel(
    uid: artisanId,
    name: 'Radha Devi',
    email: 'demo.radha@kalavistar.demo',
    role: 'artisan',
    phone: '+91-9839001122',
    languagePreference: 'hi',
    artisanCluster: 'Gorakhpur Terracotta Heritage Cluster',
    region: 'Gorakhpur, Uttar Pradesh',
  );
}
