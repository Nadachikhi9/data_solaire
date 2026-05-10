/// Flags de compilation / runtime.
///
/// **Firebase / RTDB réel** par défaut (`USE_MOCK_RTD` absent ou `false`).
/// **Démo hors-ligne** : `flutter run --dart-define=USE_MOCK_RTD=true`
/// (éventuellement `--dart-define=MOCK_SKIP_FIREBASE_INIT=false` pour tenter
/// quand même Firebase malgré mock — rare).
abstract final class FeatureFlags {
  /// Flux télémétrie factice (sans Firebase Realtime Database).
  static const bool useMockRealtimeData = bool.fromEnvironment(
    'USE_MOCK_RTD',
    defaultValue: false,
  );

  /// Si vrai et [useMockRealtimeData] : pas d’appel à `Firebase.initializeApp`
  /// (évite erreurs avec des clés placeholder).
  static const bool mockSkipsFirebaseInit = bool.fromEnvironment(
    'MOCK_SKIP_FIREBASE_INIT',
    defaultValue: true,
  );

  /// Avec données mock : notifier (navigateur / Android) au premier tick d’anomalie
  /// lorsque les phases factices cassent quelque chose.
  ///
  /// Désactivation : `--dart-define=MOCK_ALERT_NOTIF=false`
  static const bool mockAlertNotifications = bool.fromEnvironment(
    'MOCK_ALERT_NOTIF',
    defaultValue: true,
  );
}
