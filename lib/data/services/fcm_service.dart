import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:data_solaire/core/constants/app_strings.dart';
import 'package:data_solaire/firebase_options.dart';
import 'package:data_solaire/util/browser_notify.dart';

/// FCM : topic (mobile), token, notifications locales Android. Ne lance aucune exception vers [main].
/// Ne touche pas à [FirebaseMessaging.instance] tant qu’aucune app Firebase n’est initialisée (évite crash Web en démo).
class FcmService extends GetxService {
  FcmService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _messagingOverride = messaging,
       _local = localNotifications ?? FlutterLocalNotificationsPlugin();

  final FirebaseMessaging? _messagingOverride;
  final FlutterLocalNotificationsPlugin _local;
  final AndroidNotificationChannel _androidChannel =
      const AndroidNotificationChannel(
        AppStrings.notificationChannel,
        AppStrings.notificationChannelTitle,
        description: 'Notifications de pannes et alertes tracker solaire.',
        importance: Importance.high,
        playSound: true,
      );

  bool _localReady = false;
  StreamSubscription<RemoteMessage>? _onMessageSub;

  /// Indique si un token FCM a été obtenu (utile push ; sur Web dépend du SW + VAPID).
  final RxBool messagingAvailable = false.obs;
  final RxnString messagingLastError = RxnString();

  /// Résout [FirebaseMessaging] uniquement si une app [Firebase] existe (injectable pour les tests).
  FirebaseMessaging? _resolveMessaging() {
    if (_messagingOverride != null) return _messagingOverride;
    if (Firebase.apps.isEmpty) return null;
    try {
      return FirebaseMessaging.instance;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('FCM _resolveMessaging: $e\n$st');
      }
      return null;
    }
  }

  /// init() historique — préférez [initSafe].
  Future<void> init() => initSafe();

  Future<void> initSafe() async {
    messagingAvailable.value = false;
    messagingLastError.value = null;

    final m = _resolveMessaging();
    if (m == null) {
      messagingLastError.value = AppStrings.fcmSkippedNoFirebase;
      if (kDebugMode) {
        debugPrint('FCM : aucune app Firebase — init ignorée.');
      }
      return;
    }

    try {
      await m.setAutoInitEnabled(true);
    } catch (e, st) {
      _recordError('FCM setAutoInitEnabled : $e', st);
      return;
    }

    NotificationSettings? settings;
    try {
      settings = await m.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e, st) {
      // Souvent « Unable to detect current Android Activity » si trop tôt ; initSafe
      // est rappelé après la première frame depuis [DataSolaireApp].
      if (kDebugMode) {
        debugPrint('FCM requestPermission : $e\n$st');
      }
    }

    if (kDebugMode) {
      debugPrint('FCM permission: ${settings?.authorizationStatus}');
    }

    try {
      if (!kIsWeb) {
        await _initLocalNotifications();
      }

      await _onMessageSub?.cancel();
      _onMessageSub = FirebaseMessaging.onMessage.listen(
        _onForegroundMessage,
        onError: (e, st) {
          if (kDebugMode) {
            debugPrint('FCM onMessage stream: $e\n$st');
          }
        },
      );

      if (!kIsWeb) {
        try {
          await m.subscribeToTopic(AppStrings.fcmTopic);
          if (kDebugMode) {
            debugPrint('FCM abonné au topic ${AppStrings.fcmTopic}');
          }
        } catch (e, st) {
          if (kDebugMode) {
            debugPrint('FCM subscribeToTopic : $e\n$st');
          }
          messagingLastError.value = 'Abonnement topic impossible : $e';
        }
      } else {
        if (kDebugMode) {
          debugPrint(
            'FCM Web : subscribeToTopic non supporté par le plugin ; '
            'voir documentation Firebase pour les topics côté JS ou envoi par token.',
          );
        }
      }

      try {
        final token = await m.getToken();
        if (token != null && token.isNotEmpty) {
          messagingAvailable.value = true;
          messagingLastError.value = null;
        } else {
          messagingLastError.value = AppStrings.fcmTokenEmpty;
        }
        if (kDebugMode) {
          debugPrint('FCM token: $token');
        }
      } catch (e, st) {
        _recordError('FCM getToken : $e', st);
      }
    } catch (e, st) {
      _recordError('FCM init interne : $e', st);
    }
  }

  void _recordError(String message, StackTrace st) {
    messagingLastError.value = message;
    messagingAvailable.value = false;
    if (kDebugMode) {
      debugPrint('$message\n$st');
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _local.initialize(initSettings);

    final android = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(_androidChannel);
    await android?.requestNotificationsPermission();
    _localReady = true;
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    if (kIsWeb || !_localReady) return;

    final title =
        message.notification?.title ?? message.data['title'] ?? 'Alerte';
    final body =
        message.notification?.body ??
        message.data['body'] ??
        message.data['message'] ??
        '';

    try {
      await _local.show(
        message.hashCode,
        title,
        body.isEmpty ? null : body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
          ),
        ),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Notification locale : $e\n$st');
      }
    }
  }

  /// Alerte hors FCM — utile en **mode mock** (Chrome : API Notification après permission).
  /// Sur Android initialise le plugin local si Firebase n’a pas encore tourné.
  Future<void> showDiagnosticForegroundAlert({
    required String title,
    required String body,
  }) async {
    if (kDebugMode) {
      debugPrint('Alerte diagnostics : $title — $body');
    }
    if (kIsWeb) {
      await requestAndShowBrowserNotification(title, body);
      return;
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    await _ensureLocalNotificationsInitialized();
    if (!_localReady) {
      return;
    }

    try {
      await _local.show(
        title.hashCode ^ body.hashCode,
        title,
        body.isEmpty ? null : body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
          ),
        ),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('showDiagnosticForegroundAlert : $e\n$st');
      }
    }
  }

  Future<void> _ensureLocalNotificationsInitialized() async {
    if (kIsWeb || _localReady) {
      return;
    }
    try {
      await _initLocalNotifications();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('_ensureLocalNotificationsInitialized : $e\n$st');
      }
    }
  }

  @override
  void onClose() {
    unawaited(_onMessageSub?.cancel() ?? Future<void>.value());
    super.onClose();
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) {
    debugPrint('FCM background: ${message.messageId} ${message.data}');
  }

  // Message « notification » : la barre d’état Android affiche déjà ; éviter doublon.
  if (kIsWeb || message.notification != null) {
    return;
  }
  if (defaultTargetPlatform != TargetPlatform.android) {
    return;
  }

  final title =
      message.data['title'] ?? message.notification?.title ?? 'Alerte';
  final body =
      message.data['body'] ??
      message.data['message'] ??
      message.notification?.body ??
      '';
  if (title.isEmpty && body.isEmpty) {
    return;
  }

  final plugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await plugin.initialize(const InitializationSettings(android: androidInit));

  final android = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  const channel = AndroidNotificationChannel(
    AppStrings.notificationChannel,
    AppStrings.notificationChannelTitle,
    description: 'Notifications de pannes et alertes tracker solaire.',
    importance: Importance.high,
    playSound: true,
  );
  await android?.createNotificationChannel(channel);

  try {
    final id = message.messageId?.hashCode ?? message.hashCode;
    await plugin.show(
      id,
      title,
      body.isEmpty ? null : body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
      ),
    );
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('FCM background notification locale : $e\n$st');
    }
  }
}
