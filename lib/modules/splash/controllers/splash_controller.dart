import 'package:get/get.dart';
import 'package:data_solaire/app/routes/app_pages.dart';

class SplashController extends GetxController {
  @override
  void onReady() {
    super.onReady();
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      Get.offNamed(Routes.dashboard);
    });
  }
}
