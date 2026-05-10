import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:data_solaire/core/constants/rtdb_paths.dart';
import 'package:data_solaire/core/feature_flags.dart';
import 'package:data_solaire/data/models/tracker_rtdb_state.dart';
import 'package:data_solaire/data/services/mock_tracker_stream.dart';

/// Accès Realtime Database — pas de logique métier.
/// En mode mock ([useMock]), aucun accès à [FirebaseDatabase] (évite crash Web si Firebase non initialisé).
class RtdbDataService {
  RtdbDataService({FirebaseDatabase? database, bool? useMock})
    : _databaseOverride = database,
      useMock = useMock ?? FeatureFlags.useMockRealtimeData;

  final FirebaseDatabase? _databaseOverride;
  final bool useMock;

  /// Flux des données `tracker`. Ne propage pas d'erreur dans [map] ; les erreurs Firebase
  /// restent sur le stream natif (gérées par le controller avec [onError]).
  Stream<TrackerRtdbState> watchTracker() {
    if (useMock) {
      return MockTrackerStream.createStream();
    }

    if (Firebase.apps.isEmpty) {
      return Stream<TrackerRtdbState>.empty();
    }

    final db = _databaseOverride ?? FirebaseDatabase.instance;
    final ref = db.ref(RtdbPaths.trackerRoot);
    return ref.onValue.map((event) {
      try {
        final v = event.snapshot.value;
        return TrackerRtdbState.fromRootMap(v);
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('RtdbDataService parse: $e\n$st');
        }
        return TrackerRtdbState.fromRootMap(null);
      }
    });
  }
}
