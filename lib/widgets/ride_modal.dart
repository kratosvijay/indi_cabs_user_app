import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

enum RideType { daily, rental, acting, multiStop, bookForOther, metro }

// --- Models ---
// ... (PlaceAutocompletePrediction, PlaceDetails, FavoritePlace, VehicleOption, RentalPackage, PredefinedDestination, SearchHistoryItem, RouteDetails, PricingRules, VehiclePricing) ...

// **MODIFIED:** Model for Ride History
class Ride {
  final String rideId;
  final String userId;
  final String? driverId;
  final String rideType; // e.g., "Sedan", "Multi-Stop Ride", "Rental"
  final String status; // "completed", "cancelled", "scheduled"
  final DateTime timestamp; // This is the createdAt time
  final DateTime? scheduledTime; // **NEW:** The time the ride is for
  
  final String pickupAddress;
  final String dropoffAddress;
  final LatLng pickupLocation;
  final LatLng dropoffLocation;
  
  final List<Map<String, dynamic>> intermediateStops;
  
  final num totalFare;
  final num baseFare; // Base ride fare or package price
  final num tip;
  final num toll;
  final num surcharge; // Airport, night charge, etc.

  Ride({
    required this.rideId,
    required this.userId,
    this.driverId,
    required this.rideType,
    required this.status,
    required this.timestamp,
    this.scheduledTime, // **NEW**
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupLocation,
    required this.dropoffLocation,
    this.intermediateStops = const [], 
    required this.totalFare,
    this.baseFare = 0,
    this.tip = 0,
    this.toll = 0,
    this.surcharge = 0,
  });

  // Helper for display
  String get formattedTotalFare {
    // Use NumberFormat for proper currency formatting
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(totalFare);
  }

  factory Ride.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    GeoPoint pickupGeo = data['pickupLocation'] ?? const GeoPoint(0, 0);
    GeoPoint dropoffGeo = data['destinationLocation'] ?? data['pickupLocation'] ?? const GeoPoint(0, 0); // Use pickup if dest is null (e.g., rental)
    List<Map<String, dynamic>> stops = List<Map<String, dynamic>>.from(data['intermediateStops'] ?? []);

    // **MODIFIED:** Determine ride type string
    String type;
    if (data['rideType'] == 'rental') {
      type = data['packageName'] ?? 'Rental';
    } else if (stops.isNotEmpty) {
      type = "Multi-Stop Ride"; 
    } else {
      type = data['vehicleType'] ?? 'Daily Ride';
    }

    return Ride(
      rideId: doc.id,
      userId: data['userId'] ?? '',
      driverId: data['driverId'], // Can be null
      rideType: type,
      status: data['status'] ?? 'unknown',
      timestamp: (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      // **NEW:** Read scheduledTime
      scheduledTime: (data['scheduledTime'] as Timestamp?)?.toDate(),
      pickupAddress: data['pickupAddress'] ?? 'Unknown Pickup',
      dropoffAddress: data['destinationAddress'] ?? data['pickupAddress'] ?? 'Unknown Dropoff',
      pickupLocation: LatLng(pickupGeo.latitude, pickupGeo.longitude),
      dropoffLocation: LatLng(dropoffGeo.latitude, dropoffGeo.longitude),
      intermediateStops: stops, 
      totalFare: data['totalFare'] ?? 0,
      baseFare: data['fare'] ?? 0,
      tip: data['tip'] ?? 0,
      toll: data['appliedToll'] ?? 0, // From Cloud Function
      surcharge: data['appliedSurcharge'] ?? 0, // From Cloud Function
    );
  }
}
