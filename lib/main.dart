import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:data_solaire/app/routes/app_pages.dart';
import 'package:data_solaire/app/theme/app_theme.dart';
import 'package:data_solaire/core/app_runtime_state.dart';
import 'package:data_solaire/core/constants/app_strings.dart';
import 'package:data_solaire/core/feature_flags.dart';
import 'package:data_solaire/data/services/fcm_service.dart';
import 'package:data_solaire/data/services/rtdb_data_service.dart';
import 'package:data_solaire/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint(details.exceptionAsString());
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('Erreur non gérée: $error\n$stack');
    }
    return true;
  };

  final appRuntime = AppRuntimeState();
  Get.put(appRuntime, permanent: true);

  final useMock = FeatureFlags.useMockRealtimeData;
  final skipFirebaseForMock = useMock && FeatureFlags.mockSkipsFirebaseInit;

  if (!skipFirebaseForMock) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      appRuntime.firebaseReady.value = true;
      appRuntime.firebaseInitError.value = null;
    } catch (e, st) {
      appRuntime.firebaseReady.value = false;
      appRuntime.firebaseInitError.value =
          'Impossible d’initialiser Firebase. Vérifiez firebase_options / clés : $e';
      if (kDebugMode) {
        debugPrint('Firebase.initializeApp: $e\n$st');
      }
    }
  } else {
    if (kDebugMode) {
      debugPrint(
        'Mode démo : Firebase.initializeApp ignoré (mockSkipsFirebaseInit).',
      );
    }
  }

  if (useMock) {
    appRuntime.firebaseReady.value = true;
    appRuntime.firebaseInitError.value = null;
  }

  if (!kIsWeb && Firebase.apps.isNotEmpty) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  Get.put(RtdbDataService(useMock: useMock), permanent: true);

  final fcm = FcmService();
  Get.put(fcm, permanent: true);
  if (Firebase.apps.isEmpty && kDebugMode) {
    debugPrint(
      'FCM non initialisé : aucune app Firebase (mode démo ou échec).',
    );
  }

  runApp(const DataSolaireApp());
}

class DataSolaireApp extends StatefulWidget {
  const DataSolaireApp({super.key});

  @override
  State<DataSolaireApp> createState() => _DataSolaireAppState();
}

class _DataSolaireAppState extends State<DataSolaireApp> {
  @override
  void initState() {
    super.initState();
    // FCM requestPermission() needs an Android Activity — absent before first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initFcmWhenActivityReady());
    });
  }

  Future<void> _initFcmWhenActivityReady() async {
    if (Firebase.apps.isEmpty || !Get.isRegistered<FcmService>()) {
      return;
    }
    try {
      await Get.find<FcmService>().initSafe();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('FcmService.initSafe inattendu: $e\n$st');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final runtime = Get.find<AppRuntimeState>();

    return GetMaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
      defaultTransition: Transition.fadeIn,
      builder: (context, child) {
        return Obx(() {
          final err = runtime.firebaseInitError.value;
          final ready = runtime.firebaseReady.value;
          Widget body = child ?? const SizedBox.shrink();

          if (!ready && err != null && err.isNotEmpty) {
            body = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  color: AppTheme.danger.withValues(alpha: 0.15),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.danger),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            err,
                            style: const TextStyle(
                              color: AppTheme.onDark,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(child: body),
              ],
            );
          }

          return Directionality(textDirection: TextDirection.ltr, child: body);
        });
      },
    );
  }
}
