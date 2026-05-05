// ⚠️  PLACEHOLDER — replace by running:
//
//   npm install -g firebase-tools
//   firebase login
//   flutterfire configure --platforms=android,ios
//
// The command above will overwrite this file with your real Firebase project
// values and place google-services.json in android/app/.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCdp9qRmPtRRRHEOY0L8Aaxktj6HkwDlmQ',
    appId: '1:325764829403:android:4342bb6a678ebe41343cfe',
    messagingSenderId: '325764829403',
    projectId: 'screenx-ee8de',
    storageBucket: 'screenx-ee8de.firebasestorage.app',
  );

  // ── Replace these with real values from Firebase Console ──────────────────

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC5As4oQEckgAhsZM5eM8twzqByvKEo2oY',
    appId: '1:325764829403:ios:2a46ca254b3d3c3f343cfe',
    messagingSenderId: '325764829403',
    projectId: 'screenx-ee8de',
    storageBucket: 'screenx-ee8de.firebasestorage.app',
    iosClientId: '325764829403-50sjtt6i94b1pscregpsss1hp8itpl01.apps.googleusercontent.com',
    iosBundleId: 'com.vizapp.vizFlutter',
  );

}