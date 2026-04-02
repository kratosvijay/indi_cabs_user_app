// ignore_for_file: unnecessary_nullable_for_final_variable_declarations

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:flutter/foundation.dart'
    show kDebugMode; // For printing errors in debug mode

class GoogleSignInService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final gsi.GoogleSignIn _googleSignIn = gsi.GoogleSignIn.instance;
  
  /// Initializes Google Sign-In with configuration.
  static Future<void> initialize({required String serverClientId}) async {
    // Note: The specific version of GoogleSignIn in this project 
    // uses a custom .instance and .initialize() method.
    await _googleSignIn.initialize(serverClientId: serverClientId);
  }

  /// Attempts to sign in the user with Google.
  /// Returns a [UserCredential] if successful, otherwise returns `null`.
  /// This method also handles creating the user document in Firestore
  /// if it's their first time logging in.
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // 1. Trigger the Google Authentication flow
      // **FIXED:** Changed 'signIn()' to 'authenticate()'
      final gsi.GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();

      // If the user cancelled the sign-in, return null
      if (googleUser == null) {
        if (kDebugMode) print('Google Sign-In was cancelled by the user.');
        return null;
      }

      // 2. Obtain the auth details from the request
      final gsi.GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // 3. Create a new Firebase credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // 4. Sign in to Firebase with the credential
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      // 5. Return user credentials to let AuthController handle the rest
      if (user != null) {
        return userCredential;
      }

      return null;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) print('Firebase Auth Exception: ${e.message}');
      return null;
    } catch (e) {
      if (kDebugMode) print('Error during Google Sign-In: $e');
      return null;
    }
  }

  /// Signs the user out of both Firebase and Google.
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      if (kDebugMode) print('Error signing out: $e');
      // Even if Google sign-out fails, try to sign out of Firebase
      if (_auth.currentUser != null) {
        await _auth.signOut();
      }
    }
  }

  /// Gets the currently signed-in Firebase user.
  static User? getCurrentUser() {
    return _auth.currentUser;
  }
}
