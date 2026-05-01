import 'package:get/get.dart';
import 'package:data_solaire/modules/splash/controllers/splash_controller.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() {
    // put (pas lazyPut) : la vue n’appelle pas `controller`, donc lazyPut ne
    // instancierait jamais le contrôleur et [onReady] ne lancerait pas la navigation.
    Get.put(SplashController());
  }
}
