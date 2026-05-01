// Fichier généré manuellement : exécutez `dart run flutterfire_cli:flutterfire configure`
// pour remplacer par les vraies valeurs du projet Firebase.
//
// ignore_for_file: lines_longer_than_80_chars

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return ios;
      default:
        return android;
    }
  }

  /// Web : renseigner la clé VAPID dans la console FCM pour les notifications.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_WEB_API_KEY',
    appId: 'REPLACE_WEB_APP_ID',
    messagingSenderId: 'REPLACE_SENDER_ID',
    projectId: 'REPLACE_PROJECT_ID',
    authDomain: 'REPLACE_PROJECT_ID.firebaseapp.com',
    databaseURL: 'https://REPLACE_PROJECT_ID-default-rtdb.firebaseio.com',
    storageBucket: 'REPLACE_PROJECT_ID.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_ANDROID_API_KEY',
    appId: 'REPLACE_ANDROID_APP_ID',
    messagingSenderId: 'REPLACE_SENDER_ID',
    projectId: 'REPLACE_PROJECT_ID',
    databaseURL: 'https://REPLACE_PROJECT_ID-default-rtdb.firebaseio.com',
    storageBucket: 'REPLACE_PROJECT_ID.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_IOS_API_KEY',
    appId: 'REPLACE_IOS_APP_ID',
    messagingSenderId: 'REPLACE_SENDER_ID',
    projectId: 'REPLACE_PROJECT_ID',
    databaseURL: 'https://REPLACE_PROJECT_ID-default-rtdb.firebaseio.com',
    storageBucket: 'REPLACE_PROJECT_ID.firebasestorage.app',
    iosBundleId: 'com.example.dataSolaire',
  );
}
