import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Import for formatting

// --- Enums ---

// Enum to define the type of ride service
enum RideType { daily, rental, acting, multiStop, bookForOther }

// --- Models ---

// Model for Google Places API Autocomplete predictions
class PlaceAutocompletePrediction {
  final String description;
  final String placeId;

  PlaceAutocompletePrediction({
    required this.description,
    required this.placeId,
  });

  factory PlaceAutocompletePrediction.fromJson(Map<String, dynamic> json) {
    final textData = json['placePrediction']?['text'] as Map<String, dynamic>?;
    final description = textData?['text'] as String? ?? 'Unknown Prediction';
    final placeId = json['placePrediction']?['placeId'] as String? ?? '';
    return PlaceAutocompletePrediction(
      description: description,
      placeId: placeId,
    );
  }
}

// Model for Google Places API Details response
class PlaceDetails {
  final String placeId;
  final String name;
  final String address;
  final LatLng location;

  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.address,
    required this.location,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json, String id) {
    final locationData = json['location'] as Map<String, dynamic>?;
    final lat = (locationData?['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (locationData?['longitude'] as num?)?.toDouble() ?? 0.0;

    return PlaceDetails(
      placeId: id,
      name: json['displayName']?['text'] as String? ?? 'Unknown Name',
      address: json['formattedAddress'] as String? ?? 'Unknown Address',
      location: LatLng(lat, lng),
    );
  }
}

// Model for user's favorite places (stored in Firestore)
class FavoritePlace {
  final String id;
  final String name;
  final String address;
  final LatLng location;

  FavoritePlace({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
  });

  factory FavoritePlace.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return FavoritePlace(
      id: doc.id,
      name: data['name'] ?? 'Unnamed Favorite',
      address: data['address'] ?? 'No Address',
      location: LatLng(
        (data['latitude'] as num?)?.toDouble() ?? 0.0,
        (data['longitude'] as num?)?.toDouble() ?? 0.0,
      ),
    );
  }
}

// Model for vehicle types
class VehicleOption {
  final String type; // e.g., 'Hatchback', 'Sedan', 'SUV', 'Auto'
  final String imagePath;
  final String price; // Example static price (used as fallback/display)
  final String eta; // Example static eta (used as fallback/display)

  VehicleOption({
    required this.type,
    required this.imagePath,
    required this.price,
    required this.eta,
  });

  // Static lists for easy access
  static List<VehicleOption> get defaultOptions => [
    VehicleOption(
      type: 'Hatchback',
      imagePath: 'assets/images/car_hatchback.png',
      price: '₹150',
      eta: '5 mins',
    ),
    VehicleOption(
      type: 'Sedan',
      imagePath: 'assets/images/car_sedan.png',
      price: '₹180',
      eta: '7 mins',
    ),
    VehicleOption(
      type: 'SUV',
      imagePath: 'assets/images/car_suv.png',
      price: '₹250',
      eta: '8 mins',
    ),
    VehicleOption(
      type: 'Auto',
      imagePath: 'assets/images/auto_rickshaw.png',
      price: '₹80',
      eta: '4 mins',
    ),
    VehicleOption(
      type: 'ActingDriver',
      imagePath: 'assets/images/acting_driver.png',
      price: '₹250',
      eta: '15 mins',
    ),
  ];

  static List<VehicleOption> get rentalOptions => [
    VehicleOption(
      type: 'Hatchback',
      imagePath: 'assets/images/car_hatchback.png',
      price: 'N/A',
      eta: 'N/A',
    ),
    VehicleOption(
      type: 'Sedan',
      imagePath: 'assets/images/car_sedan.png',
      price: 'N/A',
      eta: 'N/A',
    ),
    VehicleOption(
      type: 'SUV',
      imagePath: 'assets/images/car_suv.png',
      price: 'N/A',
      eta: 'N/A',
    ),
    // Note: 'Auto' is intentionally excluded from rentals
  ];
}

// Model for rental packages (from Firestore)
class RentalPackage {
  final String id;
  final String displayName;
  final int durationHours;
  final int kmLimit;
  final num extraKmCharge;
  final num extraHourCharge;
  final Map<String, num>
  vehiclePrices; // e.g., {'Hatchback': 500, 'Sedan': 600}

  RentalPackage({
    required this.id,
    required this.displayName,
    required this.durationHours,
    required this.kmLimit,
    required this.extraKmCharge,
    required this.extraHourCharge,
    required this.vehiclePrices,
  });

  factory RentalPackage.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    Map<String, num> prices = {
      'Hatchback': data['price_hatchback'] ?? 0,
      'Sedan': data['price_sedan'] ?? 0,
      'SUV': data['price_suv'] ?? 0,
      'Auto': data['price_auto'] ?? 0,
      'ActingDriver': data['price_actingdriver'] ?? 0, // **NEW LINE**
    };
    return RentalPackage(
      id: doc.id,
      displayName:
          data['display_name'] ?? '${data['duration_hours'] ?? '?'} hr Package',
      durationHours: (data['duration_hours'] as num?)?.toInt() ?? 0,
      kmLimit: (data['km_limit'] as num?)?.toInt() ?? 0,
      extraKmCharge: data['extra_km_charge'] ?? 0,
      extraHourCharge: data['extra_hour_charge'] ?? 0,
      vehiclePrices: prices,
    );
  }

  num getPriceForVehicle(String vehicleType) {
    return vehiclePrices[vehicleType] ?? 0;
  }
}

// Model for predefined destinations (local constant)
class PredefinedDestination {
  final String name;
  final LatLng location;
  final IconData icon;

  PredefinedDestination({
    required this.name,
    required this.location,
    required this.icon,
  });

  // Static list for easy access
  static List<PredefinedDestination> get defaultDestinations => [
    PredefinedDestination(
      name: "Chennai International Airport",
      location: const LatLng(12.983106268558108, 80.16399768478037),
      icon: Icons.airplanemode_active,
    ),
    PredefinedDestination(
      name: "Chennai Central Railway Station",
      location: const LatLng(13.082477094001776, 80.27592326678992),
      icon: Icons.train,
    ),
    PredefinedDestination(
      name: "Tambaram Railway Station West",
      location: const LatLng(12.925944864777007, 80.11847372944796),
      icon: Icons.train,
    ),
    PredefinedDestination(
      name: "Tambaram Railway Station East",
      location: const LatLng(12.924428599933577, 80.11937495167811),
      icon: Icons.train,
    ),
    PredefinedDestination(
      name: "Egmore Railway Station",
      location: const LatLng(13.078076195102502, 80.26197966863556),
      icon: Icons.train_outlined,
    ),
    PredefinedDestination(
      name: "Perambur Railway Station",
      location: const LatLng(13.108132175805405, 80.244748639801),
      icon: Icons.tram,
    ),
    PredefinedDestination(
      name: "Koyambedu Bus Stand",
      location: const LatLng(13.068846951539054, 80.20515232445989),
      icon: Icons.directions_bus,
    ),
    PredefinedDestination(
      name: "Kilambakkam Bus Stand",
      location: const LatLng(12.872837416097044, 80.08203966678644),
      icon: Icons.directions_bus_filled,
    ),
    PredefinedDestination(
      name: "Madhavaram Bus Terminus",
      location: const LatLng(13.145484198058359, 80.22142430912086),
      icon: Icons.bus_alert,
    ),
    PredefinedDestination(
      name: "Thiruvanmiyur Bus Depot",
      location: const LatLng(12.98715442977044, 80.25948314374493),
      icon: Icons.departure_board,
    ),
  ];

  static List<PredefinedDestination> get entertainmentDestinations => [
    PredefinedDestination(
      name: "Phoenix Marketcity",
      location: const LatLng(12.993212954376752, 80.21789480781365),
      icon: Icons.local_mall,
    ),
    PredefinedDestination(
      name: "PVR Grand Mall",
      location: const LatLng(12.9786, 80.2223),
      icon: Icons.movie_filter,
    ),
    PredefinedDestination(
      name: "VR Chennai",
      location: const LatLng(13.080692793556372, 80.1971319956616),
      icon: Icons.local_mall,
    ),
    PredefinedDestination(
      name: "Express Avenue",
      location: const LatLng(13.058519891611864, 80.26421317458625),
      icon: Icons.local_mall,
    ),
    PredefinedDestination(
      name: "Marina Beach",
      location: const LatLng(13.0628771453905, 80.28569346166047),
      icon: Icons.beach_access,
    ),
    PredefinedDestination(
      name: "Elliot's Beach",
      location: const LatLng(12.999356424404544, 80.27169469199076),
      icon: Icons.beach_access,
    ),
    PredefinedDestination(
      name: "The Marina Mall OMR",
      location: const LatLng(12.835913619870515, 80.22900612634311),
      icon: Icons.local_mall,
    ),
    PredefinedDestination(
      name: "Mayajaal Multiplex",
      location: const LatLng(12.84832202182495, 80.23984030356263),
      icon: Icons.movie,
    ),
    PredefinedDestination(
      name: "PVR Heritage ECR",
      location: const LatLng(12.863582293193039, 80.24172661036152),
      icon: Icons.movie_filter,
    ),
    PredefinedDestination(
      name: "Sathyam Cinemas",
      location: const LatLng(13.055522311515848, 80.25798815336606),
      icon: Icons.movie,
    ),
  ];
}

// Model for search history items (stored locally)
class SearchHistoryItem {
  final String description;
  final String placeId;

  SearchHistoryItem({required this.description, required this.placeId});

  factory SearchHistoryItem.fromJson(Map<String, dynamic> json) {
    return SearchHistoryItem(
      description: json['description'] ?? 'Unknown Location',
      placeId: json['placeId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'description': description, 'placeId': placeId};
  }
}

// Model for route details from Directions API
class RouteDetails {
  final int distanceMeters;
  final int durationSeconds;
  final List<LatLng> polylinePoints;
  final num tollCost;

  RouteDetails({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.polylinePoints,
    required this.tollCost,
  });

  RouteDetails copyWith({
    int? distanceMeters,
    int? durationSeconds,
    List<LatLng>? polylinePoints,
    num? tollCost,
  }) {
    return RouteDetails(
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      polylinePoints: polylinePoints ?? this.polylinePoints,
      tollCost: tollCost ?? this.tollCost,
    );
  }
}

// Model for pricing rules (from Firestore)
class PricingRules {
  final String cityName;
  final String currencySymbol;
  final Map<String, VehiclePricing> vehiclePricing;

  PricingRules({
    required this.cityName,
    required this.currencySymbol,
    required this.vehiclePricing,
  });

  factory PricingRules.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    Map<String, dynamic> vehicleTypesData = data['vehicle_types'] ?? {};

    Map<String, VehiclePricing> pricingMap = {};
    vehicleTypesData.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        pricingMap[key] = VehiclePricing.fromMap(value);
      }
    });

    return PricingRules(
      cityName: data['city_name'] ?? 'N/A',
      currencySymbol: data['currency_symbol'] ?? '₹',
      vehiclePricing: pricingMap,
    );
  }
}

// Model for pricing details of a single vehicle type
class VehiclePricing {
  final num baseFare;
  final num minimumFare;
  final num perKilometer;
  final num perMinute;
  final String description;

  VehiclePricing({
    required this.baseFare,
    required this.minimumFare,
    required this.perKilometer,
    required this.perMinute,
    required this.description,
  });

  factory VehiclePricing.fromMap(Map<String, dynamic> map) {
    return VehiclePricing(
      baseFare: map['baseFare'] ?? 0,
      minimumFare: map['minimumFare'] ?? 0,
      perKilometer: map['perKilometer'] ?? 0,
      perMinute: map['perMinute'] ?? 0,
      description: map['description'] ?? 'A comfortable and affordable ride.',
    );
  }
}

class Driver {
  final String id;
  final String name;
  final String carModel;
  final String carNumber;
  final String photoUrl;
  final String phoneNumber;
  LatLng currentLocation;
  final String vehicleType; // "Sedan", "Auto", "Hatchback", "SUV"
  final bool isActingDriver;
  final double bearing; // Direction of travel
  final bool isOnline;
  final bool isAvailable;

  // **NEW FIELDS**
  final String vehicleBrand;
  final String vehicleModel;

  Driver({
    required this.id,
    required this.name,
    required this.carModel,
    required this.carNumber,
    required this.photoUrl,
    required this.phoneNumber,
    required this.currentLocation,
    required this.vehicleType,
    this.isActingDriver = false,
    this.bearing = 0.0,
    required this.isOnline,
    required this.isAvailable,
    this.vehicleBrand = '',
    this.vehicleModel = '',
  });

  factory Driver.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    GeoPoint location = data['currentLocation'] ?? const GeoPoint(0, 0);

    // Map 'vehicleClass' (from new format) to 'vehicleType' (app internal)
    // Fallback to 'vehicleType' if 'vehicleClass' is missing.
    String vType = data['vehicleClass'] ?? data['vehicleType'] ?? 'Hatchback';

    // Handle 'vehicleType' being 'Car' in new format -> Default to Hatchback or use vehicleClass
    if (vType == 'Car') {
      vType = data['vehicleClass'] ?? 'Hatchback';
    }

    return Driver(
      id: doc.id,
      name: data['displayName'] ?? data['name'] ?? 'N/A',
      // Map 'carName' (full name) to carModel. Fallback to vehicleModel if carName missing.
      carModel:
          data['carName'] ?? data['vehicleModel'] ?? data['carModel'] ?? 'N/A',
      carNumber: data['vehicleNumber'] ?? data['carNumber'] ?? 'N/A',
      photoUrl: data['photoUrl'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      currentLocation: LatLng(location.latitude, location.longitude),
      vehicleType: vType,
      isActingDriver: data['isActingDriver'] ?? false,
      bearing: (data['bearing'] as num?)?.toDouble() ?? 0.0,
      isOnline: data['isOnline'] ?? false,
      // Default isAvailable to isOnline if missing, as new format doesn't seem to have it explicitly
      isAvailable: data['isAvailable'] ?? data['isOnline'] ?? false,
      vehicleBrand: data['vehicleBrand'] ?? '',
      vehicleModel: data['vehicleModel'] ?? '',
    );
  }
}

// **NEW:** Model for Ride History
class Ride {
  final String rideId;
  final String userId;
  final String? driverId;
  final String rideType; // e.g., "Sedan", "Auto", "Rental Hatchback"
  final String status; // "completed", "cancelled"
  final DateTime timestamp;
  final DateTime? startTime; // **NEW**
  final DateTime? endTime; // **NEW**

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
  final bool isRental; // **NEW**

  // Actual Ride Stats (for completed rides)
  final LatLng? actualDropoffLocation;
  final String? actualDropoffAddress;
  final num? actualDistance;
  final num? actualDuration;

  Ride({
    required this.rideId,
    required this.userId,
    this.driverId,
    this.intermediateStops = const [],
    required this.rideType,
    required this.status,
    required this.timestamp,
    this.startTime, // **NEW**
    this.endTime, // **NEW**
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.totalFare,
    this.baseFare = 0,
    this.tip = 0,
    this.toll = 0,
    this.surcharge = 0,
    this.isRental = false, // **NEW**
    this.actualDropoffLocation,
    this.actualDropoffAddress,
    this.actualDistance,
    this.actualDuration,
  });

  // Helper for display
  String get formattedTotalFare {
    // Use NumberFormat for proper currency formatting
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(totalFare);
  }

  factory Ride.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    GeoPoint pickupGeo = data['pickupLocation'] ?? const GeoPoint(0, 0);
    GeoPoint dropoffGeo =
        data['destinationLocation'] ??
        data['pickupLocation'] ??
        const GeoPoint(0, 0); // Use pickup if dest is null (e.g., rental)

    // Determine ride type string
    String type = data['vehicleType'] ?? data['vehicleClass'] ?? 'Ride';
    bool isRental = false; // **NEW**
    if (data['rideType'] == 'rental') {
      type = data['packageName'] ?? 'Rental';
      isRental = true; // **NEW**
    }

    // Parse timestamps
    DateTime? start =
        (data['startTime'] as Timestamp?)?.toDate() ??
        (data['pickedUpAt'] as Timestamp?)?.toDate();
    DateTime? end =
        (data['endTime'] as Timestamp?)?.toDate() ??
        (data['droppedOffAt'] as Timestamp?)?.toDate() ??
        (data['completedAt'] as Timestamp?)?.toDate();

    // Parse actual dropoff if available
    LatLng? actualDropoff;
    if (data['actualDropoffLocation'] != null) {
      GeoPoint p = data['actualDropoffLocation'];
      actualDropoff = LatLng(p.latitude, p.longitude);
    } else if (data['dropoffLocation'] != null &&
        data['status'] == 'completed') {
      // Fallback: if status is completed, check if dropoffLocation is different from destinationLocation
      // But usually 'actualDropoffLocation' is explicitly set on completion.
      // We'll stick to explicit field to avoid confusion.
    }

    return Ride(
      rideId: doc.id,
      userId: data['userId'] ?? '',
      driverId: data['driverId'], // Can be null
      rideType: type,
      status: data['status'] ?? 'unknown',
      timestamp: (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      pickupAddress: data['pickupAddress'] ?? 'Unknown Pickup',
      dropoffAddress:
          data['destinationAddress'] ??
          data['pickupAddress'] ??
          'Unknown Dropoff',
      pickupLocation: LatLng(pickupGeo.latitude, pickupGeo.longitude),
      dropoffLocation: LatLng(dropoffGeo.latitude, dropoffGeo.longitude),
      intermediateStops: List<Map<String, dynamic>>.from(
        data['intermediateStops'] ?? [],
      ),
      totalFare: data['totalFare'] ?? 0,
      baseFare: data['fare'] ?? 0,
      tip: data['tip'] ?? 0,
      toll: data['appliedToll'] ?? 0, // From Cloud Function
      surcharge: data['appliedSurcharge'] ?? 0, // From Cloud Function
      isRental: isRental, // **NEW**
      actualDropoffLocation: actualDropoff,
      actualDropoffAddress: data['actualDropoffAddress'],
      actualDistance:
          data['distance'] ??
          data['actualDistance'] ??
          data['distanceTraveled'],
      actualDuration:
          data['duration'] ??
          data['actualDuration'] ??
          data['timeTaken'] ??
          data['travelTime'] ??
          (start != null && end != null
              ? end.difference(start).inSeconds
              : null),
      startTime: start,
      endTime: end,
    );
  }
}

// --- Constants ---

// Geofence for Chennai
const List<LatLng> chennaiBoundary = [
  LatLng(13.289375, 80.5609776),
  LatLng(13.292048, 80.5046726),
  LatLng(13.2933845, 80.4469944),
  LatLng(13.292048, 80.3797032),
  LatLng(13.2933845, 80.3330113),
  LatLng(13.2960575, 80.2794529),
  LatLng(13.3401573, 80.2506138),
  LatLng(13.3521831, 80.2190281),
  LatLng(13.3628722, 80.1682163),
  LatLng(13.3561916, 80.1160313),
  LatLng(13.3294672, 80.0610996),
  LatLng(13.2800192, 79.9677158),
  LatLng(13.2546231, 79.9292637),
  LatLng(13.1984749, 79.8894383),
  LatLng(13.1851044, 79.8605991),
  LatLng(13.1021909, 79.7740818),
  LatLng(13.0807893, 79.7122837),
  LatLng(13.0647369, 79.671085),
  LatLng(13.0125594, 79.638126),
  LatLng(12.938957, 79.6257664),
  LatLng(12.8666718, 79.6230198),
  LatLng(12.817131, 79.6312595),
  LatLng(12.7689197, 79.6463658),
  LatLng(12.7287367, 79.6724583),
  LatLng(12.7153409, 79.7328831),
  LatLng(12.7046238, 79.7658421),
  LatLng(12.7046238, 79.8345066),
  LatLng(12.6939062, 79.8866917),
  LatLng(12.6349515, 79.9169041),
  LatLng(12.6215508, 79.9443699),
  LatLng(12.5893863, 79.9718357),
  LatLng(12.5304075, 79.982822),
  LatLng(12.4821421, 79.9993015),
  LatLng(12.3185092, 80.0267674),
  LatLng(12.4472781, 80.0871922),
  LatLng(12.458006, 80.2107884),
  LatLng(12.5384508, 80.2821995),
  LatLng(12.6081494, 80.350864),
  LatLng(12.7501684, 80.3728367),
  LatLng(12.8840757, 80.3975559),
  LatLng(12.9162028, 80.4332615),
  LatLng(12.9884737, 80.4662205),
  LatLng(13.0500213, 80.4964329),
  LatLng(13.1596984, 80.5101658),
  LatLng(13.289375, 80.5609776),
];

// Model for Wallet Transactions
class WalletTransaction {
  final String id;
  final double amount;
  final String type; // 'credit' or 'debit'
  final DateTime createdAt;
  final String description;
  final String status; // 'success', 'pending', 'failed'

  WalletTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.createdAt,
    required this.description,
    required this.status,
  });

  factory WalletTransaction.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return WalletTransaction(
      id: doc.id,
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      type: data['type'] ?? 'unknown',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: data['description'] ?? '',
      status:
          data['status'] ??
          'success', // Default to success for backward compatibility
    );
  }
}

// **NEW:** Shared state for booking flow (Home & BookForOther)
class BookingState {
  final bool isLoading;
  final Map<String, num>? fares;
  final RouteDetails? route;
  final DateTime? scheduledTime;

  BookingState({
    this.isLoading = false,
    this.fares,
    this.route,
    this.scheduledTime,
  });

  BookingState copyWith({
    bool? isLoading,
    Map<String, num>? fares,
    RouteDetails? route,
    DateTime? scheduledTime,
  }) {
    return BookingState(
      isLoading: isLoading ?? this.isLoading,
      fares: fares ?? this.fares,
      route: route ?? this.route,
      scheduledTime: scheduledTime ?? this.scheduledTime,
    );
  }
}
