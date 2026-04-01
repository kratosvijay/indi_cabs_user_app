import 'package:get/get.dart';
import 'package:project_taxi_with_ai/controllers/auth_controller.dart';
import 'package:project_taxi_with_ai/controllers/ride_controller.dart';
import 'package:project_taxi_with_ai/controllers/metro_controller.dart';
import 'package:project_taxi_with_ai/services/deep_link_service.dart';

class ControllerBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<AuthController>(AuthController(), permanent: true);
    Get.put<RideController>(RideController(), permanent: true);
    Get.put<DeepLinkService>(DeepLinkService(), permanent: true);
    Get.put<MetroController>(MetroController(), permanent: true);
  }
}
