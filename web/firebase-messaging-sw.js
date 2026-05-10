/* eslint-disable no-undef */
/**
 * Service Worker Firebase Cloud Messaging (Web).
 * — Les clés ci-dessous doivent correspondre à lib/firebase_options.dart (plateforme web).
 * — Ajoutez une paire de clés Web Push (VAPID) dans la console Firebase : Paramètres du projet > Cloud Messaging.
 * — Version JS : alignez avec la doc FlutterFire si besoin (https://firebase.flutter.dev/docs/messaging/overview).
 */
importScripts('https://www.gstatic.com/firebasejs/11.0.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.0.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'REPLACE_WEB_API_KEY',
  authDomain: 'datasolaire-e6696.firebaseapp.com',
  projectId: 'datasolaire-e6696',
  databaseURL:
    'https://datasolaire-e6696-default-rtdb.europe-west1.firebasedatabase.app',
  storageBucket: 'datasolaire-e6696.firebasestorage.app',
  messagingSenderId: 'REPLACE_SENDER_ID',
  appId: 'REPLACE_WEB_APP_ID',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Message reçu en arrière-plan', payload);
});
