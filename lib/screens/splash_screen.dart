import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:project_taxi_with_ai/config/env_config.dart';
import 'package:project_taxi_with_ai/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
// import 'package:firebase_app_check/firebase_app_check.dart';

import 'package:project_taxi_with_ai/controllers/ride_controller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:project_taxi_with_ai/screens/permissions_screen.dart';

import 'package:project_taxi_with_ai/bindings/controller_binding.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // 1. Load Env
      await dotenv.load(fileName: "dotenv.env");

      // 2. Initialize Firebase
      await Firebase.initializeApp();

      // 3. Initialize Google Sign-In
      await GoogleSignInService.initialize(
        serverClientId: EnvConfig.instance.serverClientId,
      );

      // 4. Activate App Check
      // await FirebaseAppCheck.instance.activate(
      //   providerAndroid: AndroidDebugProvider(),
      //   providerApple: AppleDebugProvider(),
      // );

      // 5. Check Permissions (BEFORE Controllers)
      final locStatus = await Permission.location.status;
      final notifStatus = await Permission.notification.status;

      debugPrint("Permissions Check:");
      debugPrint("Location: $locStatus");
      debugPrint("Notification: $notifStatus");

      if (!locStatus.isGranted) {
        debugPrint("Redirecting to PermissionsScreen");
        if (mounted) {
          Get.offAll(() => const PermissionsScreen());
        }
        return;
      }

      // 6. Initialize Controllers (Auth & Ride)
      // Only init controllers if permissions are granted to avoid race conditions
      ControllerBinding().dependencies();

      // 7. Initialize RideController Data
      if (Get.isRegistered<RideController>()) {
        await RideController.instance.initialize();
      } else {
        debugPrint("RideController not found!");
      }

      // 8. User State & Navigation will be handled by AuthController's onReady
      debugPrint("Initialization complete. Waiting for AuthController...");
    } catch (e) {
      debugPrint("Initialization Error: $e");
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    }
  }

  void _showErrorDialog(String error) {
    Get.dialog(
      AlertDialog(
        title: const Text("Initialization Failed"),
        content: Text("An error occurred while starting the app:\n$error"),
        actions: [
          TextButton(
            onPressed: () {
              Get.back(); // Close dialog
              _initializeApp(); // Retry
            },
            child: const Text("Retry"),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final contentColor = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Placeholder for app logo. Replace 'assets/images/car_sedan.png' with your actual logo asset path.
            Image.asset(
              'assets/logos/app_logo.png',
              width: 150, // Adjust size as needed
              height: 150,
            ),
            const SizedBox(height: 20),
            CircularProgressIndicator(color: contentColor),
            const SizedBox(height: 20),
            Text(
              "Initializing...",
              style: TextStyle(
                color: contentColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
