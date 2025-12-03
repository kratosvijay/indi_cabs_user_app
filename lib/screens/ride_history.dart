import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:project_taxi_with_ai/screens/ride_detail.dart';
import 'package:project_taxi_with_ai/screens/ride_in_progress.dart';
import 'package:project_taxi_with_ai/widgets/data_models.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';
import '../widgets/snackbar.dart';

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
    try {
      Stream<QuerySnapshot> dailyRides = FirebaseFirestore.instance
          .collection('ride_requests')
          .where('userId', isEqualTo: widget.user.uid)
          // Only show completed or cancelled rides in history
          .where(
            'status',
            whereIn: [
              'accepted',
              'arrived',
              'started',
              'completed',
              'cancelled',
              'cancelled_by_driver',
              'cancelled_by_user',
            ],
          )
          // **FIXED:** Removed .orderBy('createdAt', ...)
          .limit(25)
          .snapshots();

      Stream<QuerySnapshot> rentalRides = FirebaseFirestore.instance
          .collection('rental_requests')
          .where('userId', isEqualTo: widget.user.uid)
          .where(
            'status',
            whereIn: [
              'accepted',
              'arrived',
              'started',
              'completed',
              'cancelled',
              'cancelled_by_driver',
              'cancelled_by_user',
            ],
          )
          // **FIXED:** Removed .orderBy('createdAt', ...)
          .limit(25)
          .snapshots();

      // Combine the two streams
      // This is a simple (but not perfectly real-time) way to merge
      // A better way uses the rxdart package's CombineLatestStream.
      return Stream<List<QuerySnapshot>>.periodic(
            const Duration(seconds: 2),
            (i) => [],
          )
          .asyncMap((_) async {
            // Fetch the latest data from both streams
            final dailySnapshot = await dailyRides.first;
            final rentalSnapshot = await rentalRides.first;
            return [dailySnapshot, rentalSnapshot];
          })
          .map((snapshots) {
            final dailyDocs = snapshots[0].docs;
            final rentalDocs = snapshots[1].docs;

            final allDocs = [...dailyDocs, ...rentalDocs];

            // **FIXED:** Sort the combined list in Dart
            allDocs.sort((a, b) {
              Timestamp? aTimestamp =
                  (a.data() as Map<String, dynamic>)['createdAt'];
              Timestamp? bTimestamp =
                  (b.data() as Map<String, dynamic>)['createdAt'];
              return (bTimestamp ?? Timestamp.now()).compareTo(
                aTimestamp ?? Timestamp.now(),
              );
            });

            return allDocs
                .map((doc) {
                  try {
                    return Ride.fromFirestore(doc);
                  } catch (e) {
                    debugPrint(
                      "Error parsing ride document: ${doc.id}, Error: $e",
                    );
                    return null;
                  }
                })
                .whereType<Ride>()
                .toList();
          })
          .handleError((error) {
            debugPrint("Error fetching ride history stream: $error");
            if (mounted) {
              displaySnackBar(context, 'Error loading ride history: $error');
            }
            return <Ride>[]; // Return empty list on error
          });
    } catch (e) {
      debugPrint("Error setting up ride history stream: $e");
      if (mounted) {
        displaySnackBar(context, 'Error loading ride history: $e');
      }
      return Stream.value([]); // Return an empty stream on initial error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ProAppBar(titleText: 'Ride History'),
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
                  'Error loading history: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              );
            }

            // 3. Empty State
            final rides = snapshot.data;
            if (rides == null || rides.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 80, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No Ride History',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Your rides will appear here.',
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
                "ID: ${ride.rideId}",
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
