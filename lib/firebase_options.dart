import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web not supported');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('This platform is not supported');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCo2m4DqFZGu9rmgS29JRoZGNpEBnnD6ws',
    appId: '1:119621775160:android:aef5bc4705bfcf0cad9bcd',
    messagingSenderId: '119621775160',
    projectId: 'rezolv-inventory',
    storageBucket: 'rezolv-inventory.firebasestorage.app',
  );
}