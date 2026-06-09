/// Chaînes interface utilisateur (français).
abstract final class AppStrings {
  static const String appTitle = 'Data Solaire';
  static const String appSubtitle = 'Surveillance tracker solaire';
  static const String dashboardTitle = 'Tableau de bord';
  static const String telemetrySection = 'Télémétrie en direct';
  static const String diagnosticsSection = 'État des pannes et diagnostics';
  static const String performanceSection = 'Performances (puissance)';
  static const String tracker3dSection = 'Visualisation 3D du tracker';
  static const String voltage = 'Tension';
  static const String current = 'Courant';
  static const String power = 'Puissance';
  static const String temperature = 'Température';
  static const String cleaningRequired = 'Nettoyage du panneau solaire requis';
  static const String panelFault = 'Panne du panneau solaire : pas de production malgré éclairage';
  static const String cleaningWarning = 'Alerte nettoyage : forte luminosité LDR et puissance trop basse';
  static const String sensorVoltageNa = 'Panne capteur tension : valeur introuvable (NA)';
  static const String sensorCurrentNa = 'Panne capteur courant : valeur introuvable (NA)';
  static const String sensorPowerNa = 'Panne capteur puissance : valeur introuvable (NA)';
  static const String sensorTemperatureNa = 'Panne capteur température : valeur introuvable (NA)';
  static const String sensorIna219 = 'Module INA219';
  static const String sensorIna219Detail = 'Tension, courant, puissance';
  static const String sensorDht22 = 'DHT22';
  static const String sensorDht22Detail = 'Température';
  static const String ventilation = 'Ventilation';
  static const String ldrTop = 'LDR haut';
  static const String ldrBottom = 'LDR bas';
  static const String ldrLeft = 'LDR gauche';
  static const String ldrRight = 'LDR droite';
  static const String statusOk = 'OK';
  static const String statusFault = 'Panne';
  static const String statusOn = 'ON';
  static const String statusOff = 'OFF';
  static const String statusUnknown = 'Inconnu';
  static const String offlineTitle = 'Connexion système perdue';
  static const String offlineHint =
      'Aucune donnée reçue depuis plus de 5 secondes.';
  static const String fcmTopic = 'solar_alerts';
  static const String notificationChannel = 'alertes_solaires';
  static const String notificationChannelTitle = 'Alertes solaires';

  static const String fcmTokenEmpty =
      'Jeton FCM vide — vérifiez le service worker Web et la clé VAPID.';
  static const String fcmDegradedBanner =
      'Notifications push limitées sur ce navigateur (Web). Les alertes en arrière-plan reposent sur le service worker et la configuration VAPID.';
  static const String fcmSkippedNoFirebase =
      'Notifications push désactivées : Firebase n’est pas initialisé (démo sans clés ou configuration en attente).';

  static const String rtdbFirebaseNotInitialized =
      'Firebase n’est pas initialisé : les données temps réel sont indisponibles.';
  static const String rtdbListenError = 'Écoute Realtime Database interrompue';
  static const String rtdbMaxRetries =
      'Nombre maximal de tentatives de reconnexion RTDB atteint. Rechargez la page ou vérifiez le réseau.';
  static const String rtdbConnected = 'Connecté à Firebase';
  static const String rtdbAwaitingData = 'Connecté, en attente de données';
  static const String rtdbStaleData = 'Connecté, données obsolètes';
  static const String rtdbConnecting = 'Connexion Firebase…';
  static const String rtdbStatusUnknown = 'Statut Firebase inconnu';
  static const String rtdbStatusUnavailable = 'Impossible de lire le statut Firebase';
  static const String blueCraftByline = 'Blue Craft';
  static const String telemetryAwaitingHub =
      'En attente des données du gateway (PC / station)';
  static const String chartNoPowerYet =
      'Aucun historique de puissance pour le moment.';
  static const String chartWaitingSerial =
      'Le graphique se remplira lorsque la puissance (mW) arrivera depuis Firebase.';
  static const String demoModeBanner =
      'Données démo : scénarios périodiques (capteurs, perte liaison, « nettoyage », défaut équipement, LDR). '
      'Pour les alertes hors app : autorisez les notifications du navigateur. '
      'Couper les notifications : `--dart-define=MOCK_ALERT_NOTIF=false`.';
  static const String tracker3dHint =
      'Scène 3D perspective (rendu Canvas) : glisser pour orbiter la caméra. '
      'Éclairage relié aux LDR / irradiance Firebase lorsque disponible.';
}
