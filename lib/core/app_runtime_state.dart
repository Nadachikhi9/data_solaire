import 'package:get/get.dart';

/// État global de démarrage (Firebase, messages d’échec pour l’UI).
class AppRuntimeState extends GetxService {
  final RxBool firebaseReady = false.obs;
  final RxnString firebaseInitError = RxnString();
}
