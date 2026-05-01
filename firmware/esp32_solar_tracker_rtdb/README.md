# ESP32 — tracker solaire → Firebase Realtime Database

Ce firmware envoie les mesures et l’orientation vers la base **Realtime Database** sous le nœud `tracker`, au même format que l’application Flutter **Data Solaire** (`lib/data/services/rtdb_data_service.dart`).

**Aucune authentification Firebase (e-mail / mot de passe)** : l’ESP envoie un **PATCH REST** HTTPS vers `…/tracker.json`. Il faut donc des **règles RTDB très ouvertes** sur `tracker` (lecture/écriture publiques). C’est pratique pour un prototype et **dangereux** en production (n’importe qui peut effacer ou falsifier les données).

## Prérequis

1. Copier la configuration :

   ```bash
   cp secrets.h.example secrets.h
   ```

   Renseigner Wi‑Fi, `FIREBASE_DATABASE_URL`, et ajuster `CLEANING_POWER_W` (seuil de puissance en **W** attendu quand le panneau est propre).

2. **Firebase Console → Realtime Database → Règles**

   Exemple pour accès **sans auth** (comme demandé) :

   ```json
   {
     "rules": {
       "tracker": {
         ".read": true,
         ".write": true
       }
     }
   }
   ```

   Dès que vous exposez le projet sur Internet, **ne laissez pas** `read`/`write` à `true` sans autre protection.

3. **Bibliothèques Arduino** (Gestionnaire de bibliothèques)

   - *ESP32Servo*
   - *Adafruit INA219* (+ dépendances `Adafruit BusIO`).
   - *DHT sensor library* (Adafruit) + *Adafruit Unified Sensor*.
   - *LiquidCrystal I2C* (ex. Frank de Brabander `LiquidCrystal_I2C`).

   Plus besoin de la bibliothèque **Firebase ESP Client** : l’ESP utilise **HTTPClient** / **WiFiClientSecure** (fournis avec le core ESP32).

4. Carte : **ESP32** (Arduino core Espressif 2.x ou 3.x).

## Câblage (défaut dans le `.ino`)

| Fonction   | GPIO |
|-----------|------|
| Servo X   | 18   |
| Servo Y   | 19   |
| LDR Haut / Bas / Gauche / Droite | 32, 33, 34, 35 |
| DHT22     | 27   |
| Ventilateur | 5  |
| I2C SDA / SCL | 21 / 22 (INA219 + LCD) |

Vérifiez la **feuille ADC** de votre module (certaines broches sont entrée seulement).

## Suivi quad-LDR (deux axes, pas une rotation folle à 360°)

Quatre photo-résistances servent le même asservissement **dual axe** :

| Paire | Rôle servo | Pins (défaut) |
|-------|-------------|---------------|
| **Haut / Bas** | inclinaison (servo **Y**) | 32 / 33 |
| **Gauche / Droite** | pivot horizontal (servo **X**) | 34 / 35 |

Les butées **`kServoXMin`, `kServoXMax`, `kServoYMin`, `kServoYMax`** (dans `esp32_solar_tracker_rtdb.ino`, près des autres réglages) limitent les courses des SG90 : valeur par défaut ≈ axe X 52–128°, axe Y 38–142°. Changez ces constantes selon votre montage ; évite les balayages 0–180° complets lorsque la mécanique ne les permet pas ou n’offre aucun avantage au soleil réel.

Dans RTDB :

- Sous **`aux`** : `ldr_left_ok`, `ldr_right_ok`, `ldr_top_ok`, `ldr_bottom_ok` (`true` si le canal ADC dépasse `kLdrOkMin`).
- Sous **`sun`** : `ldr_quadrants` avec `top`, `bottom`, `left`, `right` (0…1, normalisés sur 4095) pour l’UI (gradient par quadrant).

## Comportement

- **Boucle rapide (~10 ms)** : lecture des quatre LDR, asservissement servos dans les butées logicielles ci-dessus.
- **Boucle lente (~1 s)** : INA219 (tension **V**, courant **A**, puissance **W**), DHT22, ventilateur si T > 30 °C, LCD, **PATCH JSON** sur `…/tracker.json?print=silent`.
- **Horodatage** : NTP (`pool.ntp.org`) ; champs `*_updated_ms` et `last_updated_ms` en **millisecondes** (epoch) comme attendu par l’app.
- **HTTP** : si `ENABLE_HTTP_DATA_ENDPOINT` vaut `1` dans `secrets.h`, `GET http://<IP_ESP>/data` renvoie un JSON compatible avec un tableau de bord HTML local.

## TLS

Par défaut, `RTDB_TLS_INSECURE` vaut `1` : le client HTTPS ne vérifie pas le certificat (simple pour atelier). Pour une vérification stricte, passez à `0` et configurez les certificats racine côté ESP32.

## Chemins JSON (référence)

Les noms de clés sont dupliqués côté Dart dans `lib/core/constants/rtdb_tracker_write_keys.dart` pour éviter les dérives.

## Dépannage

- **401 / Permission denied** : règles RTDB trop restrictives ; pour ce mode sans auth, `tracker` doit autoriser l’écriture sans jeton.
- **Connexion TLS / -1** : tester `RTDB_TLS_INSECURE 1`, vérifier l’URL (`.firebaseio.com` vs `.firebasedatabase.app`).
- **Heap** : augmenter l’intervalle entre deux PATCH si crash.
- **INA219** : adresse I2C par défaut `0x40` ; câblage SDA/SCL commun avec l’écran.
