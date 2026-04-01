import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:project_taxi_with_ai/screens/confirm_pickup.dart';
import 'package:project_taxi_with_ai/screens/searching_for_ride.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Auth
import 'package:cloud_functions/cloud_functions.dart';
import 'package:get/get.dart';
import 'package:project_taxi_with_ai/widgets/data_models.dart'; // Import Functions

typedef NavigationCallback = void Function(Widget destination);

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  );

  // **NEW:** Update user location in ride document
  Future<void> updateUserLocation(
    String collection,
    String rideId,
    LatLng location,
  ) async {
    try {
      await _db.collection(collection).doc(rideId).update({
        'userLocation': {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        },
      });
    } catch (e) {
      debugPrint("Error updating user location: $e");
    }
  }

  // --- Favorites ---
  Stream<List<FavoritePlace>> getFavoritesStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) {
                try {
                  return FavoritePlace.fromFirestore(doc);
                } catch (e) {
                  debugPrint("Error parsing favorite: $e");
                  return null;
                }
              })
              .whereType<FavoritePlace>()
              .toList(),
        )
        .handleError((error) {
          debugPrint("Error getting favorites stream: $error");
          return [];
        });
  }

  Future<void> saveFavoritePlace(
    String userId,
    String name,
    String address,
    LatLng location,
  ) {
    return _db.collection('users').doc(userId).collection('favorites').add({
      'name': name,
      'address': address,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateFavoriteName(
    String userId,
    String favoriteId,
    String newName,
  ) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(favoriteId)
        .update({'name': newName});
  }

  Future<void> deleteFavoritePlace(String userId, String favoriteId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(favoriteId)
        .delete();
  }

  // --- Rentals ---
  Future<List<RentalPackage>> getRentalPackages() async {
    try {
      final snapshot = await _db
          .collection('rental_packages')
          .orderBy('duration_hours')
          .get();
      return snapshot.docs
          .map((doc) {
            try {
              return RentalPackage.fromFirestore(doc);
            } catch (e) {
              debugPrint("Error parsing rental package: $e");
              return null;
            }
          })
          .whereType<RentalPackage>()
          .toList();
    } catch (e) {
      debugPrint("Error fetching rental packages: $e");
      rethrow;
    }
  }

  // --- Pricing Rules ---
  Future<PricingRules?> getPricingRules(String city) async {
    try {
      final doc = await _db.collection('pricing_rules').doc(city).get();
      if (doc.exists) {
        return PricingRules.fromFirestore(doc);
      } else {
        debugPrint("Pricing rules document for '$city' not found.");
        return null;
      }
    } catch (e) {
      debugPrint("Error fetching pricing rules: $e");
      rethrow;
    }
  }

  // --- Ride/Rental Request Creation ---

  Future<String> createDailyRideRequest({
    required String userId,
    String? userName,
    String? userPhone,
    required LatLng pickupLocation,
    required String pickupAddress,
    String? pickupPlaceName, // **NEW**
    required LatLng destinationLocation,
    required String destinationAddress,
    String? destinationPlaceName, // **NEW**
    required String vehicleType,
    required num fare,
    required double tip,
    required String paymentMethod,
    RouteDetails? routeDetails,
    List<Map<String, dynamic>>? intermediateStops,
    DateTime? scheduledTime,
    num? convenienceFee,
    num? walletAmountUsed, // **NEW**
    num? cashAmount, // **NEW**
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("ERROR: createDailyRideRequest - User is null!");
        throw Exception("User is not logged in.");
      }

      final idToken = await user.getIdToken(true); // Force refresh
      debugPrint("createDailyRideRequest - User ID: ${user.uid}");
      debugPrint("createDailyRideRequest - Token present: ${idToken != null}");
      if (idToken != null && idToken.isNotEmpty) {
        debugPrint(
          "createDailyRideRequest - Token starts with: ${idToken.substring(0, 5)}...",
        );
      } else {
        debugPrint("createDailyRideRequest - Token is null or empty!");
      }

      final callable = _functions.httpsCallable('createRideRequest');

      final Map<String, dynamic> rideData = {
        'userId': userId,
        'userName': userName ?? 'N/A',
        'userPhone': userPhone ?? 'N/A',
        'pickupLocation': {
          'latitude': pickupLocation.latitude,
          'longitude': pickupLocation.longitude,
        },
        'pickupAddress': pickupAddress,
        'pickupPlaceName': pickupPlaceName ?? (pickupAddress.contains(',') ? pickupAddress.split(',')[0] : pickupAddress), // **NEW**
        'destinationLocation': {
          'latitude': destinationLocation.latitude,
          'longitude': destinationLocation.longitude,
        },
        'destinationAddress': destinationAddress,
        'destinationPlaceName': destinationPlaceName ?? (destinationAddress.contains(',') ? destinationAddress.split(',')[0] : destinationAddress), // **NEW**
        'vehicleClass': vehicleType, // Using vehicleType arg as vehicleClass
        'fare': fare,
        'tip': tip,
        'totalFare': fare + tip + (convenienceFee ?? 0),
        'paymentMethod': paymentMethod,
        'status': scheduledTime == null ? 'searching' : 'scheduled',
        'rideType': 'daily',
        'estimatedDistanceMeters': routeDetails?.distanceMeters,
        'estimatedDurationSeconds': routeDetails?.durationSeconds,
        'intermediateStops': intermediateStops ?? [],
        'scheduledTime': scheduledTime?.toIso8601String(),
        'convenienceFee': convenienceFee ?? 0,
        'walletAmountUsed': walletAmountUsed ?? 0, // **NEW**
        'cashAmount':
            cashAmount ?? (fare + tip + (convenienceFee ?? 0)), // **NEW**
      };

      final result = await callable.call(rideData);

      final rideId = result.data['rideId'] as String?;
      if (rideId == null || rideId.isEmpty) {
        throw Exception("Cloud function did not return a valid rideId.");
      }

      return rideId;
    } catch (e) {
      debugPrint("Error calling createRideRequest function: $e");
      if (e is FirebaseFunctionsException) {
        debugPrint("Code: ${e.code}");
        debugPrint("Message: ${e.message}");
        debugPrint("Details: ${e.details}");
      }
      rethrow;
    }
  }

  Future<String> createRentalRideRequest({
    required String userId,
    String? userName,
    String? userPhone,
    required LatLng pickupLocation,
    required String pickupAddress,
    String? pickupPlaceName, // **NEW**
    required RentalPackage rentalPackage,
    required String rentalVehicleType,
    required num rentalPrice,
    required double tip,
    required String paymentMethod,
    DateTime? scheduledTime,
    num? convenienceFee,
    num? walletAmountUsed, // **NEW**
    num? cashAmount, // **NEW**
  }) async {
    try {
      final callable = _functions.httpsCallable('createRideRequest');

      final Map<String, dynamic> rideData = {
        'userId': userId,
        'userName': userName ?? 'N/A',
        'userPhone': userPhone ?? 'N/A',
        'pickupLocation': {
          'latitude': pickupLocation.latitude,
          'longitude': pickupLocation.longitude,
        },
        'pickupAddress': pickupAddress,
        'pickupPlaceName': pickupPlaceName ?? (pickupAddress.contains(',') ? pickupAddress.split(',')[0] : pickupAddress), // **NEW**
        'packageId': rentalPackage.id,
        'packageName': rentalPackage.displayName,
        'durationHours': rentalPackage.durationHours,
        'kmLimit': rentalPackage.kmLimit,
        'extraKmCharge': rentalPackage.extraKmCharge,
        'extraHourCharge': rentalPackage.extraHourCharge,
        'vehicleClass':
            rentalVehicleType, // Using rentalVehicleType arg as vehicleClass
        'fare': rentalPrice,
        'tip': tip,
        'totalFare': rentalPrice + tip + (convenienceFee ?? 0),
        'paymentMethod': paymentMethod,
        'status': scheduledTime == null ? 'searching' : 'scheduled',
        'rideType': 'rental',
        'scheduledTime': scheduledTime?.toIso8601String(),
        'convenienceFee': convenienceFee ?? 0,
        'walletAmountUsed': walletAmountUsed ?? 0, // **NEW**
        'cashAmount':
            cashAmount ??
            (rentalPrice + tip + (convenienceFee ?? 0)), // **NEW**
      };

      final result = await callable.call(rideData);

      final rideId = result.data['rideId'] as String?;
      if (rideId == null || rideId.isEmpty) {
        throw Exception("Cloud function did not return a valid rideId.");
      }

      return rideId;
    } catch (e) {
      debugPrint("Error calling createRideRequest function (rental): $e");
      rethrow;
    }
  }

  // --- Navigation Helpers (Used by widgets to navigate) ---

  void navigateToConfirmPickup(
    BuildContext context, {
    required User currentUser,
    required LatLng currentPosition,
    required LatLng destinationPosition,
    String? pickupPlaceName, // **NEW**
    String? destinationPlaceName, // **NEW**
    required VehicleOption selectedVehicle,
    required Set<Polyline> polylines,
    num? calculatedFare,
    RouteDetails? routeDetails,
    List<Map<String, dynamic>>? intermediateStops,
    num? walletBalance,
    DateTime? scheduledTime,
    num? convenienceFee,
    String? guestName,
    String? guestPhone,
  }) {
    Get.to(
      () => ConfirmPickupScreen(
        user: currentUser,
        currentPosition: currentPosition,
        destinationPosition: destinationPosition,
        pickupPlaceName: pickupPlaceName, // **NEW**
        destinationPlaceName: destinationPlaceName, // **NEW**
        selectedVehicle: selectedVehicle,
        polylines: polylines,
        calculatedFare: calculatedFare,
        routeDetails: routeDetails,
        intermediateStops: intermediateStops,
        walletBalance: walletBalance,
        scheduledTime: scheduledTime,
        convenienceFee: convenienceFee,
        guestName: guestName,
        guestPhone: guestPhone,
        // Rental params are null for daily ride
      ),
    );
  }

  void navigateToRentalConfirmPickup(
    BuildContext context, {
    required User currentUser,
    required LatLng currentPosition,
    required RentalPackage rentalPackage,
    required String rentalVehicleType,
    required num rentalPrice,
    DateTime? scheduledTime,
    num? convenienceFee,
    num? walletBalance, // **NEW**
    bool useWallet = false, // **NEW**
    String? pickupPlaceName, // **NEW**
  }) {
    Get.to(
      () => ConfirmPickupScreen(
        user: currentUser,
        currentPosition: currentPosition,
        pickupPlaceName: pickupPlaceName, // **NEW**
        destinationPosition: currentPosition,
        polylines: const {},
        selectedVehicle: null,
        rentalPackage: rentalPackage,
        rentalVehicleType: rentalVehicleType,
        rentalPrice: rentalPrice,
        calculatedFare: rentalPrice,
        routeDetails: null,
        walletBalance: walletBalance, // **MODIFIED**
        scheduledTime: scheduledTime,
        convenienceFee: convenienceFee,
        useWallet:
            useWallet, // **NEW** (Make sure ConfirmPickupScreen expects this)
      ),
    );
  }

  void navigateToSearching(
    BuildContext context, {
    required User user,
    required LatLng pickupLocation,
    required LatLng destinationPosition,
    required double fare,
    required double tip,
    required Set<Polyline> polylines,
    required bool isRental,
    String? rideRequestId, // Made nullable
    Future<String>? rideRequestIdFuture, // **NEW**
    VehicleOption? selectedVehicle,
    RentalPackage? rentalPackage,
    String? rentalVehicleType,
    List<Map<String, dynamic>>? intermediateStops,
    DateTime? scheduledTime,
    String? destinationAddress, // **NEW**
    String? initialEta, // **NEW**
    bool isBookForOther = false, // **NEW**
  }) {
    Get.offAll(
      () => SearchingForRideScreen(
        user: user,
        pickupLocation: pickupLocation,
        destinationPosition: destinationPosition,
        fare: fare,
        tip: tip,
        polylines: polylines,
        isRental: isRental,
        rideRequestId: rideRequestId,
        rideRequestIdFuture: rideRequestIdFuture,
        selectedVehicle: selectedVehicle,
        rentalPackage: rentalPackage,
        rentalVehicleType: rentalVehicleType,
        intermediateStops: intermediateStops,
        scheduledTime: scheduledTime,
        destinationAddress: destinationAddress,
        initialEta: initialEta,
        isBookForOther: isBookForOther, // **NEW**
      ),
    );
  }

  // --- Metro Bookings ---
  // **NEW:** Save metro ticket to ride history using Cloud Function for synced IDs
  Future<String> createSyncedMetroBooking({
    required String userId,
    required String orderId,
    required String transactionId,
    required String status,
    required String sourceStation,
    required LatLng sourceLocation,
    required String destStation,
    required LatLng destLocation,
    required double totalFare,
    required String qrCodeData,
    required String ticketType,
  }) async {
    try {
      final callable = _functions.httpsCallable('createMetroBooking');
      final result = await callable.call({
        'userId': userId,
        'orderId': orderId,
        'transactionId': transactionId,
        'status': status,
        'sourceStation': sourceStation,
        'sourceLocation': {
          'latitude': sourceLocation.latitude,
          'longitude': sourceLocation.longitude,
        },
        'destStation': destStation,
        'destLocation': {
          'latitude': destLocation.latitude,
          'longitude': destLocation.longitude,
        },
        'totalFare': totalFare,
        'qrCodeData': qrCodeData,
        'ticketType': ticketType,
      });

      final rideId = result.data['rideId'] as String;
      debugPrint("Metro booking synced with ride history: $rideId");
      return rideId;
    } catch (e) {
      debugPrint("Error syncing metro booking: $e");
      rethrow;
    }
  }
}
