import 'package:get/get.dart';
import 'package:data_solaire/modules/dashboard/bindings/dashboard_binding.dart';
import 'package:data_solaire/modules/dashboard/views/dashboard_view.dart';
import 'package:data_solaire/modules/splash/bindings/splash_binding.dart';
import 'package:data_solaire/modules/splash/views/splash_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const initial = Routes.splash;

  static final routes = <GetPage>[
    GetPage(
      name: Routes.splash,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: Routes.dashboard,
      page: () => const DashboardView(),
      binding: DashboardBinding(),
    ),
  ];
}
