import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:project_taxi_with_ai/screens/ride_detail.dart';
import 'package:project_taxi_with_ai/screens/ride_in_progress.dart';
import 'package:project_taxi_with_ai/widgets/data_models.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';

class RideHistoryScreen extends StatefulWidget {
  final User user;

  const RideHistoryScreen({super.key, required this.user});

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  late Stream<List<Ride>> _rideHistoryStream;

  @override
  void initState() {
    super.initState();
    _rideHistoryStream = _fetchRideHistoryStream();
  }

  /// Fetches the user's ride history from Firestore as a Stream.
  Stream<List<Ride>> _fetchRideHistoryStream() {
    final controller = StreamController<List<Ride>>();
    final List<String> statusFilter = [
      'searching',
      'scheduled',
      'accepted',
      'arrived',
      'started',
      'completed',
      'cancelled',
      'cancelled_by_driver',
      'cancelled_by_user',
    ];

    List<Ride> dailyRides = [];
    List<Ride> rentalRides = [];

    void emitMerged() {
      if (controller.isClosed) return;
      final combined = [...dailyRides, ...rentalRides];
      combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      controller.add(combined);
    }

    final dailySub = FirebaseFirestore.instance
        .collection('ride_requests')
        .where('userId', isEqualTo: widget.user.uid)
        .where('status', whereIn: statusFilter)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .listen((snapshot) {
      dailyRides = snapshot.docs.map((doc) {
        try {
          return Ride.fromFirestore(doc);
        } catch (e) {
          debugPrint("Error parsing daily ride ${doc.id}: $e");
          return null;
        }
      }).whereType<Ride>().toList();
      emitMerged();
    }, onError: (error) => debugPrint("Daily rides error: $error"));

    final rentalSub = FirebaseFirestore.instance
        .collection('rental_requests')
        .where('userId', isEqualTo: widget.user.uid)
        .where('status', whereIn: statusFilter)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .listen((snapshot) {
      rentalRides = snapshot.docs.map((doc) {
        try {
          return Ride.fromFirestore(doc);
        } catch (e) {
          debugPrint("Error parsing rental ride ${doc.id}: $e");
          return null;
        }
      }).whereType<Ride>().toList();
      emitMerged();
    }, onError: (error) => debugPrint("Rental rides error: $error"));

    controller.onCancel = () {
      dailySub.cancel();
      rentalSub.cancel();
      controller.close();
    };

    return controller.stream;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProAppBar(titleText: 'rideHistory'.tr),
      body: FadeInSlide(
        child: StreamBuilder<List<Ride>>(
          stream: _rideHistoryStream,
          builder: (context, snapshot) {
            // 1. Loading State
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // 2. Error State
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  '${'errorLoadingHistory'.tr}: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              );
            }

            // 3. Empty State
            final rides = snapshot.data;
            if (rides == null || rides.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 80, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'noRideHistory'.tr,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'noRideHistoryDesc'.tr,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            // 4. Data State
            return ListView.builder(
              itemCount: rides.length,
              itemBuilder: (context, index) {
                return _RideHistoryCard(ride: rides[index]);
              },
            );
          },
        ),
      ),
    );
  }
}

/// A card widget to display a single ride history item.
class _RideHistoryCard extends StatelessWidget {
  final Ride ride;

  const _RideHistoryCard({required this.ride});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'arrived':
      case 'started':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
      case 'cancelled_by_driver':
      case 'cancelled_by_user':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'arrived':
      case 'started':
        return Icons.directions_car;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
      case 'cancelled_by_driver':
      case 'cancelled_by_user':
        return Icons.cancel;
      default:
        return Icons.hourglass_empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Format the timestamp
    final String formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(ride.timestamp);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior:
          Clip.antiAlias, // Ensures the InkWell ripple respects the border
      child: InkWell(
        onTap: () {
          if (['accepted', 'arrived', 'started'].contains(ride.status)) {
            // Resume active ride
            Get.to(
              () => RideInProgressScreen(
                user: FirebaseAuth.instance.currentUser!,
                pickupLocation: ride.pickupLocation,
                destinationPosition: ride.dropoffLocation,
                selectedVehicleType: ride.rideType,
                isRental: ride.isRental,
                rideRequestId: ride.rideId,
                driverId: ride.driverId ?? '',
                intermediateStops: ride.intermediateStops,
              ),
            );
          } else {
            // View details for past ride
            Get.to(() => RideDetailScreen(ride: ride));
          }
          debugPrint("Tapped ride: ${ride.rideId}");
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Ride Type and Fare
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ride.rideType, // e.g., "Sedan", "Auto"
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    ride.formattedTotalFare, // e.g., "₹180"
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Middle Row: Date
              Text(
                formattedDate,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              // **NEW:** Show Ride ID
              const SizedBox(height: 4),
              Text(
                "${'id'.tr}: ${ride.rideId}",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Divider(height: 20),

              // Location Info
              _buildLocationRow(
                icon: Icons.my_location,
                color: Colors.green,
                text: ride.pickupAddress,
              ),
              const SizedBox(height: 8),
              _buildLocationRow(
                icon: Icons.location_on,
                color: Colors.red,
                text: ride.dropoffAddress,
              ),
              const SizedBox(height: 12),

              // Status Chip
              Align(
                alignment: Alignment.bottomRight,
                child: Chip(
                  avatar: Icon(
                    _getStatusIcon(ride.status),
                    color: _getStatusColor(ride.status),
                    size: 18,
                  ),
                  label: Text(
                    ride.status
                        .replaceAll('_', ' ')
                        .toUpperCase(), // Format "cancelled_by_driver"
                    style: TextStyle(
                      color: _getStatusColor(ride.status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: _getStatusColor(ride.status).withAlpha(10),
                  side: BorderSide.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
