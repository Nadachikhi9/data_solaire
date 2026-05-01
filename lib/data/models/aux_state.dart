import 'package:flutter/foundation.dart';

@immutable
class AuxState {
  const AuxState({
    this.ventilationOn,
    this.ldrLeftOk,
    this.ldrRightOk,
  });

  final bool? ventilationOn;
  final bool? ldrLeftOk;
  final bool? ldrRightOk;

  static AuxState fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const AuxState();
    return AuxState(
      ventilationOn: map['ventilation_on'] as bool?,
      ldrLeftOk: map['ldr_left_ok'] as bool?,
      ldrRightOk: map['ldr_right_ok'] as bool?,
    );
  }
}
