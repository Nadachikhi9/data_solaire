import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class Env {
  static String get rtdbWriteSecret {
    final secret = dotenv.env['RTDB_WRITE_SECRET'];
    if (secret == null || secret.isEmpty) {
      throw StateError('RTDB_WRITE_SECRET must be set in .env');
    }
    return secret;
  }
}
