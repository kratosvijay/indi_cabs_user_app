import 'package:flutter/material.dart';
import 'package:project_taxi_with_ai/config/env_config.dart';
import 'package:project_taxi_with_ai/config/secrets_config.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:project_taxi_with_ai/app_colors.dart';
import 'package:project_taxi_with_ai/utils/app_translations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:project_taxi_with_ai/screens/splash_screen.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:upgrader/upgrader.dart';
import 'package:flutter/services.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
      
      // Load environment variables from .env file
      try {
        await dotenv.load(fileName: "dotenv.env");
        debugPrint("DEBUG: dotenv loaded. Keys found: ${dotenv.env.keys.join(', ')}");
      } catch (e) {
        debugPrint("DEBUG: Failed to load dotenv.env: $e");
      }
      
      // Enable edge-to-edge support (wrapped for stability on older Android versions)
      try {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } catch (e) {
        debugPrint("DEBUG: Failed to set edge-to-edge mode: $e");
      }
      
      // Default to dev if no configuration is set (e.g. running main.dart directly)
      if (!EnvConfig.isSet) {
        final packageInfo = await PackageInfo.fromPlatform();
        final bool isProd = packageInfo.packageName == 'com.indicabs.userapp';

        // Helper to resolve API key from dotenv or fallback to SecretsConfig
        String getMapsKey(String fallback) {
          final envKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
          if (envKey != null && envKey.isNotEmpty && !envKey.contains('REPLACE')) {
            return envKey;
          }
          return fallback;
        }

        if (isProd) {
          EnvConfig.setConfig(
            EnvConfig(
              environment: Environment.prod,
              appName: 'Indi Cabs',
              googleMapsKey: getMapsKey(SecretsConfig.googleMapsKeyProd),
              serverClientId: SecretsConfig.serverClientIdProd,
              ondcSubscriberId: SecretsConfig.ondcSubscriberId,
              ondcSigningPublicKey: SecretsConfig.ondcSigningPublicKey,
              ondcEncryptionPublicKey: SecretsConfig.ondcEncryptionPublicKey,
              ondcUniqueKeyId: SecretsConfig.ondcUniqueKeyId,
              ondcDomain: SecretsConfig.ondcDomain,
              ondcCityCode: SecretsConfig.ondcCityCode,
              trackingUrl: SecretsConfig.trackingUrlProd,
            ),
          );
        } else {
          EnvConfig.setConfig(
            EnvConfig(
              environment: Environment.dev,
              appName: 'Indi Cabs Dev',
              googleMapsKey: getMapsKey(SecretsConfig.googleMapsKeyDev),
              serverClientId: SecretsConfig.serverClientIdDev,
              ondcSubscriberId: SecretsConfig.ondcSubscriberId,
              ondcSigningPublicKey: SecretsConfig.ondcSigningPublicKey,
              ondcEncryptionPublicKey: SecretsConfig.ondcEncryptionPublicKey,
              ondcUniqueKeyId: SecretsConfig.ondcUniqueKeyId,
              ondcDomain: SecretsConfig.ondcDomain,
              ondcCityCode: SecretsConfig.ondcCityCode,
              trackingUrl: SecretsConfig.trackingUrlDev,
            ),
          );
        }
      }
      try {
        await Firebase.initializeApp();
        
        debugPrint("DEBUG: Activating App Check. Mode: ${kDebugMode ? 'Debug' : 'Release'}");
        // Wrap App Check activation separately to prevent crashing the whole app
        try {
          await FirebaseAppCheck.instance.activate(
            providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
            providerApple: kDebugMode ? const AppleDebugProvider() : const AppleDeviceCheckProvider(),
          );
          debugPrint("DEBUG: App Check activated.");
        } catch (appCheckError) {
          debugPrint("DEBUG: App Check activation failed (non-fatal): $appCheckError");
          // Firebase will still work, just without App Check enforcement for this session
        }
        
        debugPrint("--------------------------------------------------");
        debugPrint("CHECK CONSOLE LOGS FOR THE APP CHECK DEBUG TOKEN");
        debugPrint("AND ADD IT TO FIREBASE > APP CHECK > MANAGE DEBUG TOKENS");
        debugPrint("--------------------------------------------------");

        // Pass all uncaught "fatal" errors from the framework to Crashlytics
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;

        // **NEW:** Android Notification Channel for High Importance
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'high_importance_channel', // id
          'High Importance Notifications', // title
          description: 'This channel is used for important notifications.', // description
          importance: Importance.max,
        );

        final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
            FlutterLocalNotificationsPlugin();

        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);

        // Background message handler setup
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );

        // Print App Signature for SMS Autofill (wrapped for stability)
        try {
          SmsAutoFill().getAppSignature.then((signature) {
            debugPrint("--------------------------------------------------");
            debugPrint("USER APP SIGNATURE HASH: $signature");
            debugPrint("--------------------------------------------------");
          }).catchError((e) {
            debugPrint("DEBUG: SMS Autofill Error: $e");
          });
        } catch (e) {
          debugPrint("DEBUG: Failed to initiate SMS Autofill: $e");
        }

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
