import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import '../core/config/app_config.dart';

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static FirebaseOptions get web => FirebaseOptions(
        apiKey: AppConfig.firebaseWebApiKey,
        appId: '1:433949018756:web:803421adb82fb48e9e10d1',
        messagingSenderId: '433949018756',
        projectId: 'nexora-bee78',
        authDomain: 'nexora-bee78.firebaseapp.com',
        storageBucket: 'nexora-bee78.firebasestorage.app',
        measurementId: 'G-0MD2JRV5B1',
      );

  static FirebaseOptions get android => FirebaseOptions(
        apiKey: AppConfig.firebaseAndroidApiKey,
        appId: '1:433949018756:android:6c9e6253e42e222b9e10d1',
        messagingSenderId: '433949018756',
        projectId: 'nexora-bee78',
        authDomain: 'nexora-bee78.firebaseapp.com',
        storageBucket: 'nexora-bee78.appspot.com',
      );

}
