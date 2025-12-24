import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:project_taxi_with_ai/screens/home_page.dart';
import 'package:project_taxi_with_ai/screens/login_screen.dart';
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

  @override
  void onReady() {
    super.onReady();
    _user.bindStream(FirebaseAuth.instance.authStateChanges());
    ever(_user, _setInitialScreen);
  }

  Future<void> _setInitialScreen(User? user) async {
    // Prevent multiple simultaneous navigations
    if (_isNavigating) {
      debugPrint("AuthController: Navigation already in progress, skipping");
      return;
    }

    _isNavigating = true;
    try {
      if (user == null) {
        // Check Onboarding
        final prefs = await SharedPreferences.getInstance();
        final bool hasSeenOnboarding =
            prefs.getBool('hasSeenOnboarding') ?? false;

        if (!hasSeenOnboarding) {
          Get.offAll(() => const OnboardingScreen());
        } else {
          Get.offAll(() => const SignInScreen());
        }
      } else {
        // Check if user profile is complete (has phone number)
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

            // Add delay to ensure Google Sign-In fully completes before loading Google Maps
            await Future.delayed(const Duration(milliseconds: 1000));

            if (phoneNumber != null && phoneNumber.isNotEmpty) {
              debugPrint("DEBUG: Phone number found. Navigating to HomePage.");

              // **FIX:** Fully recreate RideController to ensure fresh state
              if (Get.isRegistered<RideController>()) {
                debugPrint("DEBUG: Deleting existing RideController");
                await Get.delete<RideController>(force: true);
              }
              debugPrint("DEBUG: Creating new RideController");
              Get.put(RideController(), permanent: true);
              await RideController.instance.initialize();

              Get.offAll(() => HomePage(user: user));
            } else {
              debugPrint(
                "DEBUG: Phone number missing/empty. Navigating to PhoneAuthScreen.",
              );
              Get.offAll(() => PhoneAuthScreen(user: user));
            }
          } else {
            // Add delay for new users too
            await Future.delayed(const Duration(milliseconds: 500));

            debugPrint(
              "DEBUG: User document does not exist. Navigating to PhoneAuthScreen.",
            );
            Get.offAll(() => PhoneAuthScreen(user: user));
          }
        } catch (e) {
          Get.snackbar("Error", "Failed to load user profile");
          // Fallback to login or stay?
        }
      }
    } finally {
      // Reset the flag after a short delay to allow navigation to complete
      Future.delayed(const Duration(milliseconds: 500), () {
        _isNavigating = false;
      });
    }
  }

  final RxBool isLoading = false.obs;

  Future<void> register(
    String email,
    String password,
    String firstName,
    String lastName,
  ) async {
    try {
      isLoading.value = true;
      // Block auto-navigation from authStateChanges
      _isNavigating = true;

      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        await userCredential.user!.updateDisplayName("$firstName $lastName");
        await userCredential.user!.sendEmailVerification();

        // Show verification dialog
        await Get.defaultDialog(
          title: "Verify Email",
          middleText:
              "A verification email has been sent to $email. Please verify your email address.",
          textConfirm: "OK",
          confirmTextColor: Colors.white,
          onConfirm: () {
            Get.back(); // Close dialog
            // Allow navigation and proceed
            _isNavigating = false;
            _setInitialScreen(userCredential.user);
          },
          barrierDismissible: false,
        );
      }
    } on FirebaseAuthException catch (e) {
      _isNavigating = false; // Reset flag on error
      Get.snackbar(
        "Account Creation Failed",
        e.message ?? "Unknown error occurred",
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      _isNavigating = false; // Reset flag on generic error
      Get.snackbar("Error", e.toString(), snackPosition: SnackPosition.TOP);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> login(String email, String password) async {
    try {
      isLoading.value = true;
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      Get.snackbar(
        "Login Failed",
        e.message ?? "Unknown error occurred",
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    // **FIX:** Delete RideController on logout
    if (Get.isRegistered<RideController>()) {
      debugPrint("DEBUG: Deleting RideController on logout");
      await Get.delete<RideController>(force: true);
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
      if (userCredential.user != null &&
          (appleCredential.givenName != null ||
              appleCredential.familyName != null)) {
        final String name =
            "${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}"
                .trim();
        if (name.isNotEmpty) {
          await userCredential.user!.updateDisplayName(name);
        }
      }

      // Navigation is handled by _setInitialScreen listener
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
