import 'package:flutter/foundation.dart';

@immutable
class AuxState {
  const AuxState({
    this.ventilationOn,
    this.ldrTopOk,
    this.ldrBottomOk,
    this.ldrLeftOk,
    this.ldrRightOk,
  });

  final bool? ventilationOn;
  final bool? ldrTopOk;
  final bool? ldrBottomOk;
  final bool? ldrLeftOk;
  final bool? ldrRightOk;

  static AuxState fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const AuxState();
    return AuxState(
      ventilationOn: map['ventilation_on'] as bool?,
      ldrTopOk: map['ldr_top_ok'] as bool?,
      ldrBottomOk: map['ldr_bottom_ok'] as bool?,
      ldrLeftOk: map['ldr_left_ok'] as bool?,
      ldrRightOk: map['ldr_right_ok'] as bool?,
    );
  }
}
