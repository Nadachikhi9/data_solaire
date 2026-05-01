/// Flags de compilation / runtime.
///
/// **Données simulées (démo)** : par défaut `USE_MOCK_RTD` vaut `true` (aucun argument).
/// Désactiver : `flutter run --dart-define=USE_MOCK_RTD=false`
///
/// En production, changez [useMockRealtimeData] en `defaultValue: false` ci-dessous
/// pour ne jamais activer la démo par défaut.
abstract final class FeatureFlags {
  /// Flux télémétrie factice (sans Firebase Realtime Database).
  static const bool useMockRealtimeData = bool.fromEnvironment(
    'USE_MOCK_RTD',
    defaultValue: true,
  );

  /// Si vrai et [useMockRealtimeData] : pas d’appel à `Firebase.initializeApp`
  /// (évite erreurs avec des clés placeholder).
  static const bool mockSkipsFirebaseInit = bool.fromEnvironment(
    'MOCK_SKIP_FIREBASE_INIT',
    defaultValue: true,
  );
}
