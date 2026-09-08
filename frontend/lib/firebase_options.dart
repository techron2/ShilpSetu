// File generated for ShilpSetu Firebase integration.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your ShilpSetu Firebase app.
///
/// Uses manual Firebase configuration for shilpsetu-37bcd across all platforms.
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
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA5GiBRYuIXq6JcXM08i5hCWaDndBaJGJg',
    appId: '1:358442929186:web:1d286c62125793cb95ce7b',
    messagingSenderId: '358442929186',
    projectId: 'shilpsetu-37bcd',
    authDomain: 'shilpsetu-37bcd.firebaseapp.com',
    storageBucket: 'shilpsetu-37bcd.firebasestorage.app',
    measurementId: 'G-2EJCFT7NRJ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA5GiBRYuIXq6JcXM08i5hCWaDndBaJGJg',
    appId: '1:358442929186:web:1d286c62125793cb95ce7b',
    messagingSenderId: '358442929186',
    projectId: 'shilpsetu-37bcd',
    authDomain: 'shilpsetu-37bcd.firebaseapp.com',
    storageBucket: 'shilpsetu-37bcd.firebasestorage.app',
    measurementId: 'G-2EJCFT7NRJ',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA5GiBRYuIXq6JcXM08i5hCWaDndBaJGJg',
    appId: '1:358442929186:web:1d286c62125793cb95ce7b',
    messagingSenderId: '358442929186',
    projectId: 'shilpsetu-37bcd',
    authDomain: 'shilpsetu-37bcd.firebaseapp.com',
    storageBucket: 'shilpsetu-37bcd.firebasestorage.app',
    measurementId: 'G-2EJCFT7NRJ',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyA5GiBRYuIXq6JcXM08i5hCWaDndBaJGJg',
    appId: '1:358442929186:web:1d286c62125793cb95ce7b',
    messagingSenderId: '358442929186',
    projectId: 'shilpsetu-37bcd',
    authDomain: 'shilpsetu-37bcd.firebaseapp.com',
    storageBucket: 'shilpsetu-37bcd.firebasestorage.app',
    measurementId: 'G-2EJCFT7NRJ',
  );
}
