/// État abonnement Realtime Database côté client.
enum RtdbConnectionStatus {
  /// Pas encore d’écoute ou Firebase indisponible.
  idle,

  /// Abonnement actif au nœud tracker.
  listening,

  /// Erreur réseau, permissions, etc.
  error,
}
