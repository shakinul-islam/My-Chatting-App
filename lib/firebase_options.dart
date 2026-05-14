import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError('iOS configuration not provided.');
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Web Configuration
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDN3s19-TJZbq5OW_nEta6laRbOLscrVfs',
    authDomain: 'my-chatting-app-53cc0.firebaseapp.com',
    projectId: 'my-chatting-app-53cc0',
    storageBucket: 'my-chatting-app-53cc0.firebasestorage.app',
    messagingSenderId: '523782177281',
    appId: '1:523782177281:web:9d4c14c1880a30c6057600',
    measurementId: 'G-18GVPHNH48',
  );

  // Android Configuration
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCZDd2miJtQubtDk_FrR2a1Nl0JjqS5eYo',
    appId: '1:523782177281:android:d2b24ced5efbb7d9057600',
    messagingSenderId: '523782177281',
    projectId: 'my-chatting-app-53cc0',
    storageBucket: 'my-chatting-app-53cc0.appspot.com',
  );
}
