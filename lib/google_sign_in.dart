// ignore_for_file: unnecessary_nullable_for_final_variable_declarations

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'
    show kDebugMode; // For printing errors in debug mode

class GoogleSignInService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Attempts to sign in the user with Google.
  /// Returns a [UserCredential] if successful, otherwise returns `null`.
  /// This method also handles creating the user document in Firestore
  /// if it's their first time logging in.
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // 1. Trigger the Google Authentication flow
      // **FIXED:** Changed 'signIn()' to 'authenticate()'
      final GoogleSignInAccount? googleUser = await _googleSignIn
          .authenticate();

      // If the user cancelled the sign-in, return null
      if (googleUser == null) {
        if (kDebugMode) print('Google Sign-In was cancelled by the user.');
        return null;
      }

      // 2. Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // 3. Create a new Firebase credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // 4. Sign in to Firebase with the credential
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      // 5. If sign-in is successful, create/update the user document in Firestore
      if (user != null) {
        final DocumentReference userDoc = _db.collection('users').doc(user.uid);
        final DocumentSnapshot docSnapshot = await userDoc.get();

        // If the user document doesn't exist, create it (first-time sign-in)
        if (!docSnapshot.exists) {
          // Extract first and last name from display name
          String firstName = '';
          String lastName = '';
          if (user.displayName != null && user.displayName!.isNotEmpty) {
            final nameParts = user.displayName!.split(' ');
            firstName = nameParts.first;
            if (nameParts.length > 1) {
              lastName = nameParts.sublist(1).join(' ');
            }
          }

          final userData = {
            'uid': user.uid,
            'firstName': firstName,
            'lastName': lastName,
            'email': user.email ?? '',
            'photoURL': user.photoURL ?? '',
            'provider': 'google', // To know how they signed up
            'createdAt': FieldValue.serverTimestamp(),
            'phoneNumber':
                user.phoneNumber ??
                '', // Might be null, will be checked by signin_screen
            'wallet_balance': 0, // **NEW:** Initialize wallet balance
          };

          await userDoc.set(userData);
        } else {
          // If user exists, maybe update photoURL in case it changed
          await userDoc.set({
            'photoURL': user.photoURL ?? '',
          }, SetOptions(merge: true));
        }

        // Add small delay to ensure Firestore writes complete before navigation
        await Future.delayed(const Duration(milliseconds: 300));

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
