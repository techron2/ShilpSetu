// File generated for ShilpSetu Firebase integration.
//
// HOW TO CONFIGURE REAL KEYS LATER:
// 1. Install FlutterFire CLI: dart pub global activate flutterfire_cli
// 2. Run: flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
// 3. Or simply replace the placeholder strings below with your project values from the Firebase Console.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your ShilpSetu Firebase app.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  // Web Firebase configuration placeholder
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSy_PLACEHOLDER_WEB_API_KEY_1234567890',
    appId: '1:123456789012:web:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'shilpsetu-artisan-app',
    authDomain: 'shilpsetu-artisan-app.firebaseapp.com',
    storageBucket: 'shilpsetu-artisan-app.appspot.com',
  );

  // Android Firebase configuration placeholder
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSy_PLACEHOLDER_ANDROID_API_KEY_123456',
    appId: '1:123456789012:android:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'shilpsetu-artisan-app',
    storageBucket: 'shilpsetu-artisan-app.appspot.com',
  );

  // iOS Firebase configuration placeholder
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSy_PLACEHOLDER_IOS_API_KEY_1234567890',
    appId: '1:123456789012:ios:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'shilpsetu-artisan-app',
    storageBucket: 'shilpsetu-artisan-app.appspot.com',
    iosBundleId: 'com.shilpsetu.frontend',
  );

  // Windows Firebase configuration placeholder
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSy_PLACEHOLDER_WINDOWS_API_KEY_123456',
    appId: '1:123456789012:web:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'shilpsetu-artisan-app',
    authDomain: 'shilpsetu-artisan-app.firebaseapp.com',
    storageBucket: 'shilpsetu-artisan-app.appspot.com',
  );
}
