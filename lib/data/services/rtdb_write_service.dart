import 'package:firebase_database/firebase_database.dart';
import 'package:data_solaire/core/constants/rtdb_paths.dart';
import 'package:data_solaire/core/constants/rtdb_tracker_write_keys.dart';
import 'package:data_solaire/core/env.dart';

/// Small helper service to perform writes to `tracker/` that include the
/// shared secret required by the RTDB rules (prototype option 3).
class RtdbWriteService {
  RtdbWriteService({FirebaseDatabase? database, String? secret})
    : _db = database ?? FirebaseDatabase.instance,
      _secret = secret ?? Env.rtdbWriteSecret;

  final FirebaseDatabase _db;
  final String _secret;

  /// Persist the shared secret at `tracker/secret`.
  Future<void> setSecret(String secret) async {
    final ref = _db.ref('${RtdbPaths.trackerRoot}/secret');
    await ref.set(secret);
  }

  /// Update thresholds under `tracker/thresholds` and include `secret` in the
  /// payload so that prototype devices using the shared secret can write.
  Future<void> updateThresholds({required double cleaningPowerW}) async {
    await _db.ref(RtdbPaths.thresholds('')).update({
      RtdbTrackerWriteKeys.cleaningPowerW: cleaningPowerW,
      'secret': _secret,
    });
  }

  /// Convenience: update orientation under `tracker/orientation` with secret.
  Future<void> updateOrientation({
    required double pitchDeg,
    required double yawDeg,
    required double rollDeg,
  }) async {
    await _db.ref(RtdbPaths.orientation('')).update({
      RtdbTrackerWriteKeys.pitchDeg: pitchDeg,
      RtdbTrackerWriteKeys.yawDeg: yawDeg,
      RtdbTrackerWriteKeys.rollDeg: rollDeg,
      'secret': _secret,
    });
  }
}
