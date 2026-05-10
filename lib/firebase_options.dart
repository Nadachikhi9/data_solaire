// RTDB régional : projet `datasolaire-e6696`. Remplacez les clés/apiKey/appId par la console
// ou `dart run flutterfire_cli:flutterfire configure` sur votre compte.
//
// ignore_for_file: lines_longer_than_80_chars

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// URL Realtime Database (europe-west1, hôte *.firebasedatabase.app).
const _kFirebaseDatabaseUrl =
    'https://datasolaire-e6696-default-rtdb.europe-west1.firebasedatabase.app';

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
    projectId: 'datasolaire-e6696',
    authDomain: 'datasolaire-e6696.firebaseapp.com',
    databaseURL: _kFirebaseDatabaseUrl,
    storageBucket: 'datasolaire-e6696.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_ANDROID_API_KEY',
    appId: 'REPLACE_ANDROID_APP_ID',
    messagingSenderId: 'REPLACE_SENDER_ID',
    projectId: 'datasolaire-e6696',
    databaseURL: _kFirebaseDatabaseUrl,
    storageBucket: 'datasolaire-e6696.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_IOS_API_KEY',
    appId: 'REPLACE_IOS_APP_ID',
    messagingSenderId: 'REPLACE_SENDER_ID',
    projectId: 'datasolaire-e6696',
    databaseURL: _kFirebaseDatabaseUrl,
    storageBucket: 'datasolaire-e6696.firebasestorage.app',
    iosBundleId: 'com.example.dataSolaire',
  );
}
