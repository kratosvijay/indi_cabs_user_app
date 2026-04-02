import 'package:flutter/material.dart';
import 'package:project_taxi_with_ai/config/env_config.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:project_taxi_with_ai/app_colors.dart';
import 'package:project_taxi_with_ai/utils/app_translations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:project_taxi_with_ai/screens/splash_screen.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:upgrader/upgrader.dart';
import 'package:flutter/services.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'dart:async'; // For runZonedGuarded

// **NEW:** Background message handler (must be a top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");

  try {
    // Note: FirebaseAuth might need a moment to initialize or might be null in background isolate
    // depending on platform and persistence.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .add({
            'title': message.notification?.title ?? 'New Notification',
            'body': message.notification?.body ?? '',
            'data': message.data,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
      debugPrint("Background message saved to Firestore");
    } else {
      debugPrint("User not logged in, cannot save background message");
    }
  } catch (e) {
    debugPrint("Error saving background message: $e");
  }
}

void main() {
  // Wrap app execution in a zone to catch errors
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      
      // Enable edge-to-edge support for Android 15+
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      
      // Default to dev if no configuration is set (e.g. running main.dart directly)
      if (!EnvConfig.isSet) {
        final packageInfo = await PackageInfo.fromPlatform();
        final bool isProd = packageInfo.packageName == 'com.indicabs.userapp';

        if (isProd) {
          EnvConfig.setConfig(
            EnvConfig(
              environment: Environment.prod,
              appName: 'Indi Cabs',
              googleMapsKey: 'AIzaSyBnMfTqInBrDqPnq06CbMkIyGomOwboFto',
              serverClientId: '404641872366-iu3c35ku51jp9mt85a1j0ult661tnvot.apps.googleusercontent.com',
              ondcSubscriberId: 'api.indicabs.net',
              ondcSigningPublicKey: '5z256FcRsaWzX8ngCo1tbx0QjrtFC7q0cBeAFifDrRA=',
              ondcEncryptionPublicKey: 'MCowBQYDK2VuAyEAMNf/3bNxKAYlvBWnS7xeRLsn+dJ1IUyAGvP8EDtMDR8=',
              ondcUniqueKeyId: '0b35d6b4-ed03-478f-9ad3-a8b3528026ef',
              ondcDomain: 'ONDC:TRV11',
              ondcCityCode: '*', // All Cities
              trackingUrl: 'https://indicabs-prod.web.app/track',
            ),
          );
        } else {
          EnvConfig.setConfig(
            EnvConfig(
              environment: Environment.dev,
              appName: 'Indi Cabs Dev',
              googleMapsKey: 'AIzaSyDxGUTTcU-yMjVfqbhSPeg8GGvfSrqtmSo',
              serverClientId: '854114457795-d0hns7g6jnhnoba53v178lomsvop234i.apps.googleusercontent.com',
              ondcSubscriberId: 'api.indicabs.net',
              ondcSigningPublicKey: '5z256FcRsaWzX8ngCo1tbx0QjrtFC7q0cBeAFifDrRA=',
              ondcEncryptionPublicKey: 'MCowBQYDK2VuAyEAMNf/3bNxKAYlvBWnS7xeRLsn+dJ1IUyAGvP8EDtMDR8=',
              ondcUniqueKeyId: '0b35d6b4-ed03-478f-9ad3-a8b3528026ef',
              ondcDomain: 'ONDC:TRV11',
              ondcCityCode: '*', // All Cities
              trackingUrl: 'https://projecttaxi-df0d2.web.app/track',
            ),
          );
        }
      }
      try {
        await Firebase.initializeApp();
        
        await FirebaseAppCheck.instance.activate(
          providerAndroid: AndroidDebugProvider(),
          providerApple: AppleDebugProvider(),
        );

        // Pass all uncaught "fatal" errors from the framework to Crashlytics
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;

        // Background message handler setup
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );

        // Print App Signature for SMS Autofill
        SmsAutoFill().getAppSignature.then((signature) {
          debugPrint("--------------------------------------------------");
          debugPrint("USER APP SIGNATURE HASH: $signature");
          debugPrint("--------------------------------------------------");
        });

      } catch (e) {
        debugPrint("Firebase Initialization Error: $e");
      }

      runApp(const MyApp());
    },
    (error, stack) {
      // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      // initialBinding: ControllerBinding(), // Moved to SplashScreen
      title: EnvConfig.instance.appName,
      debugShowCheckedModeBanner: false,
      translations: AppTranslations(),
      locale: Get.deviceLocale,
      fallbackLocale: const Locale('en', 'US'),
      themeMode: ThemeMode.system,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: GoogleFonts.notoSans(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.notoSansTextTheme(Theme.of(context).textTheme),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: GoogleFonts.notoSans(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.notoSansTextTheme(
          Theme.of(context).textTheme,
        ).apply(bodyColor: Colors.white, displayColor: Colors.white),
        useMaterial3: true,
      ),
      home: UpgradeAlert(
        upgrader: Upgrader(),
        showIgnore: false,
        showLater: false,
        barrierDismissible: false,
        child: const SplashScreen(),
      ),
    );
  }
}
