import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:project_taxi_with_ai/screens/home_page.dart';
import 'package:project_taxi_with_ai/screens/login_screen.dart';
import 'package:project_taxi_with_ai/screens/language_screen.dart';
import 'package:project_taxi_with_ai/screens/mobile_no_validator.dart';
import 'package:project_taxi_with_ai/google_sign_in.dart';
import 'package:project_taxi_with_ai/controllers/ride_controller.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_taxi_with_ai/screens/onboarding.dart';

class AuthController extends GetxController {
  static AuthController get instance => Get.find();

  // Observable user
  final Rx<User?> _user = Rx<User?>(null);
  User? get user => _user.value;

  // Navigation guard to prevent double navigation
  bool _isNavigating = false;
  
  // Flag to disable auto-navigation during specific flows (like signup)
  bool pauseAutoNavigation = false;

  // Flag to differentiate mobile login from Google/Apple
  bool isPhoneLoginAttempt = false;

  @override
  void onReady() {
    super.onReady();
    _user.bindStream(FirebaseAuth.instance.authStateChanges());
    ever(_user, _setInitialScreen);
  }

  Future<void> _setInitialScreen(User? user) async {
    // Prevent multiple simultaneous navigations
    if (_isNavigating || pauseAutoNavigation) {
      debugPrint("AuthController: Navigation already in progress or paused, skipping");
      return;
    }

    _isNavigating = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? selectedLanguage = prefs.getString('selectedLanguage');

      // 1. Language Check (Always First)
      if (selectedLanguage == null) {
        Get.offAll(() => const LanguageSelectionScreen());
        return;
      }
      Get.updateLocale(Locale(selectedLanguage));

      if (user == null) {
        // 2. Onboarding Check
        final bool hasSeenOnboarding =
            prefs.getBool('hasSeenOnboarding') ?? false;

        if (!hasSeenOnboarding) {
          Get.offAll(() => const OnboardingScreen());
        } else {
          Get.offAll(() => const SignInScreen());
        }
      } else {
        // 3. User Profile Completeness Check
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final phoneNumber = userData['phoneNumber'] as String?;
            debugPrint("DEBUG: User ID: ${user.uid}");
            debugPrint("DEBUG: Firestore Phone Number: '$phoneNumber'");

            // Reduced delay as RideController.initialize() now handles location more efficiently
            await Future.delayed(const Duration(milliseconds: 300));

            if (phoneNumber != null && phoneNumber.isNotEmpty) {
              debugPrint("DEBUG: Phone number found. Navigating to HomePage.");

              // **NEW:** Mark onboarding as seen since user is already fully registered/logged in
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('hasSeenOnboarding', true);

              // **FIX:** Ensure RideController exists and is initialized
              if (!Get.isRegistered<RideController>()) {
                debugPrint("DEBUG: Creating new RideController");
                Get.put(RideController(), permanent: true);
              }
              await RideController.instance.initialize();

              Get.offAll(() => HomePage(user: user));
            } else {
              debugPrint("DEBUG: Phone number missing/empty. Navigating to PhoneAuthScreen.");
              Get.offAll(() => PhoneAuthScreen(user: user));
            }
          } else {
            // Add delay for new users too
            await Future.delayed(const Duration(milliseconds: 100));

            debugPrint("DEBUG: User document does not exist. Navigating to PhoneAuthScreen.");
            if (isPhoneLoginAttempt) {
              isPhoneLoginAttempt = false;
              await FirebaseAuth.instance.signOut();
              Get.snackbar(
                "Error",
                "Account not found. Please sign up.",
                snackPosition: SnackPosition.TOP,
              );
              return; // Another auth state change will be triggered by signOut
            }
            Get.offAll(() => PhoneAuthScreen(user: user));
          }
        } catch (e) {
          Get.snackbar("Error", "Failed to load user profile");
        }
      }
    } catch (e) {
      debugPrint("AuthController: Error in _setInitialScreen: $e");
    } finally {
      // Reset the flag after a short delay to allow navigation to complete
      Future.delayed(const Duration(milliseconds: 500), () {
        _isNavigating = false;
      });
    }
  }

  final RxBool isLoading = false.obs;

  Future<void> logout() async {
    if (Get.isRegistered<RideController>()) {
      debugPrint("DEBUG: Resetting RideController on logout");
      RideController.instance.reset();
    }
    await FirebaseAuth.instance.signOut();
  }

  Future<void> signInWithGoogle() async {
    try {
      isLoading.value = true;
      await GoogleSignInService.signInWithGoogle();
    } catch (e) {
      Get.snackbar("Google Sign In Failed", e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signInWithApple() async {
    try {
      if (!GetPlatform.isIOS) {
        Get.snackbar(
          "Not Supported",
          "Apple Sign-In is only available on iOS devices.",
          snackPosition: SnackPosition.TOP,
        );
        return;
      }

      isLoading.value = true;

      // 1. Perform Apple Sign In request
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // 2. Create Firebase credential
      final OAuthCredential credential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // 3. Sign in to Firebase
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      // 4. Update display name if available (Apple only provides this on first sign in)
      final user = userCredential.user;
      if (user != null &&
          (appleCredential.givenName != null ||
              appleCredential.familyName != null)) {
        final String name =
            "${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}"
                .trim();
        if (name.isNotEmpty) {
          await user.updateDisplayName(name);
        }
      }
    } catch (e) {
      debugPrint("Apple Sign In Error: $e");
      Get.snackbar(
        "Apple Sign In Failed",
        e.toString(),
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
