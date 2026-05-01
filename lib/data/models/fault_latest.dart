import 'package:flutter/foundation.dart';

@immutable
class FaultLatest {
  const FaultLatest({
    this.hasError = false,
    this.code,
    this.message,
    this.timestampMs,
  });

  final bool hasError;
  final String? code;
  final String? message;
  final int? timestampMs;

  static FaultLatest? fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return null;
    return FaultLatest(
      hasError: map['hasError'] as bool? ?? false,
      code: map['code']?.toString(),
      message: map['message']?.toString(),
      timestampMs: _toInt(map['timestamp_ms']),
    );
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}
