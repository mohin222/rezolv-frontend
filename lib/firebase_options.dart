import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web not supported');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('This platform is not supported');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAYjjpORQ7rTkhRSs9Q-eHDp0YQZYhOhfc',
    appId: '1:689654192973:android:6595400a7682c912e2b504',
    messagingSenderId: '689654192973',
    projectId: 'romina-8e4d6',
    storageBucket: 'romina-8e4d6.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDdaKB7FH_PxmycleRnExsT__ttdcUzYiY',
    appId: '1:689654192973:ios:1519577ee9012d6be2b504',
    messagingSenderId: '689654192973',
    projectId: 'romina-8e4d6',
    storageBucket: 'romina-8e4d6.firebasestorage.app',
    iosBundleId: 'com.rezolvhospitality.inventory',
  );
}
