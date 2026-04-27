import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:project_taxi_with_ai/widgets/data_models.dart';

class SharedRidesController extends GetxController {
  final _db = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');

  final RxList<SharedRide> rides = <SharedRide>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isBooking = false.obs;
  final RxList<RideBooking> myBookings = <RideBooking>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchUpcomingRides();
    fetchMyBookings();
  }

  void fetchUpcomingRides() {
    isLoading.value = true;
    _db
        .collection('shared_rides')
        .where('status', isEqualTo: 'upcoming')
        .where('available_seats', isGreaterThan: 0)
        .orderBy('available_seats')
        .orderBy('departure_time')
        .snapshots()
        .listen(
          (snapshot) {
            rides.value = snapshot.docs
                .map((doc) => SharedRide.fromFirestore(doc))
                .where((r) => r.departureTime.isAfter(DateTime.now()))
                .toList();
            isLoading.value = false;
          },
          onError: (e) {
            debugPrint('Error fetching shared rides: $e');
            isLoading.value = false;
          },
        );
  }

  void fetchMyBookings() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _db
        .collection('ride_bookings')
        .where('user_id', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            myBookings.value = snapshot.docs
                .map((doc) => RideBooking.fromFirestore(doc))
                .toList();
          },
          onError: (e) => debugPrint('Error fetching bookings: $e'),
        );
  }

  Future<bool> bookRide({
    required String rideId,
    required int seatsToBook,
    required double pricePerSeat,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    isBooking.value = true;
    try {
      final callable = _functions.httpsCallable('bookSharedRide');
      await callable.call({
        'ride_id': rideId,
        'seats_booked': seatsToBook,
        'user_name': user.displayName ?? 'User',
      });
      isBooking.value = false;
      return true;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('bookSharedRide error: ${e.code} - ${e.message}');
      Get.snackbar(
        'Booking Failed',
        e.message ?? 'Something went wrong. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
      isBooking.value = false;
      return false;
    } catch (e) {
      debugPrint('bookSharedRide unexpected error: $e');
      Get.snackbar(
        'Booking Failed',
        'Something went wrong. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
      isBooking.value = false;
      return false;
    }
  }

  bool hasBookedRide(String rideId) {
    return myBookings.any((b) => b.rideId == rideId && b.status != 'cancelled');
  }
}
