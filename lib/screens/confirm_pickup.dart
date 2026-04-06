// ignore_for_file: unused_field, unused_element

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv
import 'package:cloud_functions/cloud_functions.dart'; // Import for fare calculation
import 'package:geolocator/geolocator.dart'; // For distance calculation
import 'dart:math'; // For min/max

import 'package:project_taxi_with_ai/widgets/data_models.dart';
import 'package:project_taxi_with_ai/widgets/directions_service.dart';
import 'package:project_taxi_with_ai/widgets/firestore_services.dart';
import 'package:project_taxi_with_ai/widgets/location_service.dart';
import 'package:project_taxi_with_ai/widgets/map_service.dart';
import 'payment_screen.dart';
import '../widgets/snackbar.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart'; // Import snackbar
import 'package:project_taxi_with_ai/app_colors.dart';

// **MODIFIED:** Removed GeofenceZone model, as logic is now in onCameraIdle
// **MODIFIED:** Removed GeofenceZone model, as logic is now in onCameraIdle
class GeofenceZone {
  final String id;
  final String type;
  final List<LatLng> boundary;
  final List<Map<String, dynamic>>
  pickupPoints; // List of {'name': String, 'location': GeoPoint}
  final num surchargeAmount;

  GeofenceZone({
    required this.id,
    required this.type,
    required this.boundary,
    required this.pickupPoints,
    required this.surchargeAmount,
  });

  factory GeofenceZone.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Parse boundary points
    List<LatLng> boundary = [];
    (data['boundary'] as List<dynamic>?)?.forEach((point) {
      if (point is GeoPoint) {
        boundary.add(LatLng(point.latitude, point.longitude));
      }
    });

    // Parse pickup points
    List<Map<String, dynamic>> pickups = [];
    (data['pickup_points'] as List<dynamic>?)?.forEach((point) {
      if (point is Map<String, dynamic> &&
          point['name'] is String &&
          point['location'] is GeoPoint) {
        pickups.add({
          'name': point['name'],
          'location':
              point['location'], // Keep as GeoPoint for distance calculation
        });
      }
    });

    return GeofenceZone(
      id: doc.id,
      type: data['type'] ?? '',
      boundary: boundary,
      pickupPoints: pickups,
      surchargeAmount: data['surcharge_amount'] ?? 0,
    );
  }
}

class ConfirmPickupScreen extends StatefulWidget {
  final User user;
  final LatLng currentPosition; // Initial pickup pin position
  final LatLng destinationPosition; // Only relevant for daily rides
  final Set<Polyline> polylines; // Only relevant for daily rides

  // --- Daily Ride Specific ---
  final VehicleOption? selectedVehicle; // Made optional
  final num? calculatedFare; // **FIXED:** Added calculatedFare
  final RouteDetails? routeDetails; // **FIXED:** Added routeDetails

  // --- Rental Ride Specific ---
  final RentalPackage? rentalPackage; // Added for rental
  final String? rentalVehicleType; // Added for rental
  final num?
  rentalPrice; // Added for rental (use this as the calculatedFare for rentals)

  // **NEW:** Add intermediate stops
  final List<Map<String, dynamic>>? intermediateStops;
  final num? walletBalance; // **NEW:** Add parameter
  final DateTime? scheduledTime; // **NEW**
  final num? convenienceFee; // **NEW**
  final String? guestName;
  final String? guestPhone;
  final bool useWallet; // **NEW**
  final String? pickupPlaceName; // **NEW**
  final String? destinationPlaceName; // **NEW**

  const ConfirmPickupScreen({
    super.key,
    required this.user,
    required this.currentPosition,
    required this.destinationPosition,
    this.selectedVehicle,
    required this.polylines,
    this.calculatedFare,
    this.routeDetails,
    this.rentalPackage,
    this.rentalVehicleType,
    this.rentalPrice,
    this.intermediateStops,
    this.walletBalance,
    this.scheduledTime,
    this.convenienceFee,
    this.guestName,
    this.guestPhone,
    this.useWallet = false, // **NEW**
    this.pickupPlaceName, // **NEW**
    this.destinationPlaceName, // **NEW**
  }) : assert(
         (selectedVehicle != null && calculatedFare != null) ||
             (rentalPackage != null &&
                 rentalVehicleType != null &&
                 rentalPrice != null),
         "Either daily ride data or rental data must be provided.",
       );

  // Helper to determine ride type
  bool get isRental => rentalPackage != null;

  @override
  State<ConfirmPickupScreen> createState() => _ConfirmPickupScreenState();
}

class _ConfirmPickupScreenState extends State<ConfirmPickupScreen>
    with SingleTickerProviderStateMixin {
  final Completer<GoogleMapController> _mapController = Completer();
  late LatLng _adjustablePickupLocation;
  late String _pickupAddress;
  late String? _pickupPlaceName; // **NEW**
  late String? _destinationPlaceName; // **NEW**
  final Set<Marker> _markers = {};
  late Set<Polyline> _polylines;
  final Set<Polygon> _polygons = {};
  List<GeofenceZone> _geofenceZones = [];

  // --- Payment State ---
  double _tipValue = 0.0;
  String _selectedPaymentMethod = 'Cash';
  bool _isBooking = false;
  bool _isRefreshingFare = false;
  late bool _useWalletBalance; // **MODIFIED**
  bool _hasMovedPin = false;
  late final String _apiKey;

  double _getAdaptiveFontSize(double baseSize) {
    if (Get.locale?.languageCode != 'en') {
      return baseSize * 0.85; // Reduce by 15% for non-English
    }
    return baseSize;
  }

  // --- Confirm Ride Handler ---

  late num _currentCalculatedFare;
  late TextEditingController _addressSheetController;
  RouteDetails? _currentRouteDetails;
  late num _currentConvenienceFee; // **NEW**
  late DateTime? _currentScheduledTime; // **NEW**

  // **NEW:** Common Pickup Zone Support
  GeofenceZone? _activePickupZone;
  Map<String, dynamic>? _selectedPickupPoint;

  late LatLngBounds _routeBounds;

  // --- Services ---
  late final LocationService _locationService;
  late final FirestoreService _firestoreService;
  late final DirectionsService _directionsService;
  late final MapService _mapService;
  final HttpsCallable _calculateFaresCallable = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  ).httpsCallable('calculateFares');

  @override
  void initState() {
    super.initState();
    _adjustablePickupLocation = widget.currentPosition;
    _pickupAddress = "Getting address...";
    _useWalletBalance = widget.useWallet; // **NEW**
    _currentConvenienceFee = widget.convenienceFee ?? 0;
    
    // **NEW:** Calculate initial tolls from Firestore zones if not rental, and NOT Auto
    num initialTolls = 0;
    final String vehicleType = _vehicleTypeForFare();
    if (!widget.isRental && _currentRouteDetails != null && vehicleType != 'Auto') {
      // Note: _geofenceZones might be empty here as it's loaded async in _loadGeofencePolygons.
      // We will re-run this logic in _loadGeofencePolygons to ensure tolls are applied.
    }

    // Pass the raw calculated fare to _currentCalculatedFare
    _currentCalculatedFare =
        (widget.isRental ? widget.rentalPrice! : widget.calculatedFare!) +
        initialTolls;
    
    // If calculatedFare already included convenienceFee, we keep it as is, 
    // but we'll be careful in _confirmRide to subtract it if needed.
    // However, looking at _refreshFare, it seems we regenerate it.
    _currentScheduledTime = widget.scheduledTime; // **NEW**
    _addressSheetController = TextEditingController(text: _pickupAddress);
    _pickupPlaceName = widget.pickupPlaceName; // **NEW**
    _destinationPlaceName = widget.destinationPlaceName; // **NEW**

    _apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    if (_apiKey.isEmpty) {
      debugPrint("ERROR: ConfirmPickupScreen - GOOGLE_MAPS_API_KEY not found!");
    }

    // Initialize services
    _locationService = LocationService(apiKey: _apiKey);
    _firestoreService = FirestoreService();
    _directionsService = DirectionsService(apiKey: _apiKey);
    _mapService = MapService();

    _polylines = widget.isRental ? {} : widget.polylines;

    _calculateInitialBounds();

    // Set initial markers
    _updateMarkers();

    // Fetch initial address for the pin
    _getAddressFromLatLng(_adjustablePickupLocation);

    _loadGeofencePolygons();
  }

  void _calculateInitialBounds() {
    if (widget.isRental) {
      _routeBounds = LatLngBounds(
        southwest: _adjustablePickupLocation,
        northeast: _adjustablePickupLocation,
      );
    } else {
      LatLng southwest = LatLng(
        min(
          _adjustablePickupLocation.latitude,
          widget.destinationPosition.latitude,
        ),
        min(
          _adjustablePickupLocation.longitude,
          widget.destinationPosition.longitude,
        ),
      );
      LatLng northeast = LatLng(
        max(
          _adjustablePickupLocation.latitude,
          widget.destinationPosition.latitude,
        ),
        max(
          _adjustablePickupLocation.longitude,
          widget.destinationPosition.longitude,
        ),
      );
      _routeBounds = LatLngBounds(southwest: southwest, northeast: northeast);
    }
  }

  @override
  void dispose() {
    _addressSheetController.dispose();
    super.dispose();
  }

  // Updates markers based on current state (destination only)
  void _updateMarkers() {
    if (!mounted) return;
    setState(() {
      _markers.clear();

      // **FIXED:** Removed the 'adjustablePickup' marker.
      // The green pin in the Center() widget is now the only pickup indicator.

      // **NEW:** Unless we are in a Common Pickup Zone, then explicitly draw it.
      if (_activePickupZone != null && _selectedPickupPoint != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('common_pickup'),
            position: _adjustablePickupLocation,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
            infoWindow: InfoWindow(title: _selectedPickupPoint!['name']),
          ),
        );
      }

      if (!widget.isRental) {
        _markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: widget.destinationPosition,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
            infoWindow: const InfoWindow(title: "Drop-off Location"),
          ),
        );
      }
    });
  }

  // --- Geocoding to get address from LatLng ---
  Future<void> _getAddressFromLatLng(LatLng position) async {
    final address = await _locationService.getAddressFromLatLng(position);
    if (mounted) {
      setState(() {
        _pickupAddress = address;
        _addressSheetController.text = address;
        // **MODIFIED:** No longer need to update markers here
      });
    }
  }

  Future<void> _loadGeofencePolygons() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('geofenced_zones')
          .get();
      if (!mounted) return;

      debugPrint(
        "=== GEOFENCE DEBUG: Loaded ${snapshot.docs.length} zones from Firestore ===",
      );
      debugPrint(
        "=== GEOFENCE DEBUG: User position = ${widget.currentPosition.latitude}, ${widget.currentPosition.longitude} ===",
      );

      Set<Polygon> fetchedPolygons = {};
      List<GeofenceZone> fetchedZones = [];

      for (var doc in snapshot.docs) {
        final zone = GeofenceZone.fromFirestore(doc);
        fetchedZones.add(zone);

        debugPrint(
          "--- Zone: ${zone.id} | type='${zone.type}' | boundary=${zone.boundary.length} points | pickupPoints=${zone.pickupPoints.length} ---",
        );

        if (zone.boundary.length > 2) {
          fetchedPolygons.add(
            Polygon(
              polygonId: PolygonId(doc.id),
              points: zone.boundary,
              strokeWidth: 2,
              strokeColor: Colors.redAccent,
              fillColor: Colors.redAccent.withAlpha(15),
            ),
          );

          // Check if the user's initial position is inside this zone
          // AND it is a common pickup type.
          if (zone.type == 'common_pickup' && _activePickupZone == null) {
            bool isInside = _locationService.isPointInPolygon(
              widget.currentPosition,
              zone.boundary,
            );
            debugPrint(
              "--- Zone ${zone.id}: type matches 'common_pickup'. isInside=$isInside ---",
            );

            if (isInside && zone.pickupPoints.isNotEmpty) {
              _activePickupZone = zone;
              // Auto-select the first pickup point
              _selectedPickupPoint = zone.pickupPoints.first;
              final geo = _selectedPickupPoint!['location'] as GeoPoint;
              _adjustablePickupLocation = LatLng(geo.latitude, geo.longitude);
              debugPrint(
                "*** MATCH FOUND! Zone: ${zone.id}. Auto-selected: ${_selectedPickupPoint?['name']} ***",
              );
            }
          } else if (zone.type != 'common_pickup') {
            debugPrint(
              "--- Zone ${zone.id}: type='${zone.type}' != 'common_pickup', skipping ---",
            );
          }
        }
      }

      setState(() {
        _polygons.addAll(fetchedPolygons);
        _geofenceZones = fetchedZones;
      });

      // If we found a common pickup zone, move the camera and update markers
      if (_activePickupZone != null && _selectedPickupPoint != null) {
        debugPrint(
          "*** Activating Common Pickup UI for zone: ${_activePickupZone!.id} ***",
        );
        _updateMarkers();
        if (_mapController.isCompleted) {
          final geo = _selectedPickupPoint!['location'] as GeoPoint;
          final target = LatLng(geo.latitude, geo.longitude);
          final controller = await _mapController.future;
          controller.animateCamera(CameraUpdate.newLatLngZoom(target, 17.5));
          _getAddressFromLatLng(target);
        }
      } else {
        debugPrint("*** No Common Pickup Zone matched for user position. ***");
      }

      // **NEW:** Recalculate tolls now that zones are loaded
      if (!widget.isRental && _currentRouteDetails != null) {
        final double customTolls = _calculateTollsForRoute(_currentRouteDetails!.polylinePoints).toDouble();
        if (customTolls > 0) {
          setState(() {
            _currentCalculatedFare += customTolls;
            _currentRouteDetails = _currentRouteDetails!.copyWith(tollCost: customTolls);
          });
          debugPrint("Applied initial tolls from Firestore: $customTolls");
        }
      }
    } catch (e) {
      debugPrint("Error loading geofence polygons: $e");
    }
  }

  Map<String, dynamic>? _findClosestPickupPoint(LatLng currentPin) {
    for (var zone in _geofenceZones) {
      if (zone.type == 'common_pickup' &&
          _locationService.isPointInPolygon(currentPin, zone.boundary)) {
        if (zone.pickupPoints.isEmpty) continue;

        Map<String, dynamic>? closestPoint;
        double minDistance = double.infinity;

        for (var pointData in zone.pickupPoints) {
          final geoPoint = pointData['location'] as GeoPoint;
          final distance = Geolocator.distanceBetween(
            currentPin.latitude,
            currentPin.longitude,
            geoPoint.latitude,
            geoPoint.longitude,
          );

          if (distance < minDistance) {
            minDistance = distance;
            closestPoint = pointData;
          }
        }
        return closestPoint;
      }
    }
    return null;
  }

  // **NEW:** Calculate tolls based on Firestore geofence zones
  num _calculateTollsForRoute(List<LatLng> polyline) {
    if (polyline.isEmpty) return 0;
    num totalToll = 0;

    // Filter zones that have a surcharge > 0
    final tollZones =
        _geofenceZones.where((z) => z.surchargeAmount > 0).toList();

    for (var zone in tollZones) {
      // Check if any point in the polyline is inside the zone
      bool crossed = false;
      for (var point in polyline) {
        if (_locationService.isPointInPolygon(point, zone.boundary)) {
          crossed = true;
          break;
        }
      }
      if (crossed) {
        totalToll += zone.surchargeAmount;
        debugPrint("Toll Crossed: ${zone.id} | Amount: ${zone.surchargeAmount}");
      }
    }
    return totalToll;
  }

  Future<void> _refreshFare() async {
    if (widget.isRental || _isRefreshingFare) return;

    setState(() {
      _isRefreshingFare = true;
    });

    try {
      // **MODIFIED:** Get route for all stops if they exist
      List<LatLng>? intermediateLatLngs;
      if (widget.intermediateStops != null) {
        intermediateLatLngs = widget.intermediateStops!.map((stopData) {
          final locationMap = stopData['location'] as Map<String, dynamic>;
          return LatLng(
            locationMap['latitude'] as double,
            locationMap['longitude'] as double,
          );
        }).toList();
      }

      var newRouteDetails = await _directionsService.getDirections(
        _adjustablePickupLocation,
        widget.destinationPosition,
        intermediates: intermediateLatLngs,
      );

      if (newRouteDetails == null) {
        throw Exception("Could not get new route details.");
      }

      final calculationResult = await _calculateFares(
        distanceMeters: newRouteDetails.distanceMeters,
        durationSeconds: newRouteDetails.durationSeconds,
        tollCost: newRouteDetails.tollCost,
        pickupLocation: _adjustablePickupLocation,
        destinationLocation: widget.destinationPosition,
        intermediateStops: intermediateLatLngs,
        routePolyline: newRouteDetails.polylinePoints,
      );

      if (calculationResult == null ||
          calculationResult.fares[_vehicleTypeForFare()] == null) {
        throw Exception("Could not calculate new fares.");
      }

      final faresResult = calculationResult.fares;
      final appliedSurcharge = calculationResult.appliedSurcharge;
      final String vehicleType = _vehicleTypeForFare();
      num customTolls = _calculateTollsForRoute(newRouteDetails.polylinePoints);
      
      // **NEW:** Exclude tolls for Auto
      if (vehicleType == 'Auto') {
        customTolls = 0;
      }

      // Update route details with the newly calculated custom toll
      newRouteDetails = newRouteDetails.copyWith(tollCost: customTolls);

      // **FIXED:** Subtract initial surcharge AND initial toll to get base fare, then use our summed custom tolls
      // This ensures we don't double charge if the backend provided a toll.
      final num backendToll = faresResult['appliedToll'] ?? 0;
      num finalFare = (faresResult[vehicleType]! - (appliedSurcharge + backendToll)) + customTolls;

      if (widget.intermediateStops != null &&
          widget.intermediateStops!.isNotEmpty) {
        final multiStopFee = widget.intermediateStops!.length * 30;
        finalFare += multiStopFee;
      }

      // **NEW:** Add convenience fee
      finalFare += _currentConvenienceFee;

      if (mounted) {
        setState(() {
          _currentCalculatedFare = finalFare;
          _currentRouteDetails = newRouteDetails;
          _polylines = _mapService.createPolylines(
            newRouteDetails?.polylinePoints ?? [],
          );
          _hasMovedPin = false;
          _isRefreshingFare = false;
        });
        displaySnackBar(context, "Fare updated successfully!", isError: false);
      }
    } catch (e) {
      debugPrint("Error refreshing fare: $e");
      if (mounted) {
        setState(() {
          _isRefreshingFare = false;
        });
        displaySnackBar(context, "Could not update fare. Please try again.");
      }
    }
  }

  String _vehicleTypeForFare() {
    if (widget.isRental) {
      return widget.rentalVehicleType!;
    }
    // **MODIFIED:** Handle multi-stop
    return widget.selectedVehicle?.type ??
        'Hatchback'; // Default to Hatchback for multi-stop
  }

  Future<({Map<String, num> fares, num appliedSurcharge})?> _calculateFares({
    required int distanceMeters,
    required int durationSeconds,
    required num tollCost,
    required LatLng pickupLocation,
    LatLng? destinationLocation,
    List<LatLng>? intermediateStops,
    List<LatLng>? routePolyline,
  }) async {
    try {
      final result = await _calculateFaresCallable.call<Map<dynamic, dynamic>>({
        'distanceMeters': distanceMeters,
        'durationSeconds': durationSeconds,
        'tollCost': tollCost,
        'pickupLocation': {
          'latitude': pickupLocation.latitude,
          'longitude': pickupLocation.longitude,
        },
        if (destinationLocation != null)
          'destinationLocation': {
            'latitude': destinationLocation.latitude,
            'longitude': destinationLocation.longitude,
          },
        if (intermediateStops != null && intermediateStops.isNotEmpty)
          'intermediateStops': intermediateStops
              .map(
                (stop) => {
                  'location': {
                    'latitude': stop.latitude,
                    'longitude': stop.longitude,
                  },
                },
              )
              .toList(),
        if (routePolyline != null)
          'routePolyline': routePolyline
              .map((p) => {'latitude': p.latitude, 'longitude': p.longitude})
              .toList(),
      });
      final fares = result.data['fares'] as Map<dynamic, dynamic>?;
      final appliedSurcharge = result.data['appliedSurcharge'] as num? ?? 0;
      final appliedToll = result.data['appliedToll'] as num? ?? 0;
      final totalExtras = appliedSurcharge + appliedToll;

      debugPrint(
        '--- _calculateFares DEBUG (confirm_pickup) ---\n'
        'fares: $fares\n'
        'appliedSurcharge: $appliedSurcharge\n'
        'appliedToll: $appliedToll\n'
        'totalExtras: $totalExtras\n'
        '----------------------------------------------',
      );

      if (fares != null) {
        return (
          fares: fares.map(
            (key, value) => MapEntry(key.toString(), value as num),
          ),
          appliedSurcharge: totalExtras,
        );
      }
      return null;
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        "Error calling calculateFares function: ${e.code} ${e.message}",
      );
      if (mounted) {
        displaySnackBar(
          context,
          "Error calculating fares: ${e.message ?? 'Cloud function failed'}",
        );
      }
      return null;
    } catch (e) {
      debugPrint("Generic error calling calculateFares: $e");
      if (mounted) {
        displaySnackBar(
          context,
          "An unexpected error occurred while calculating fares.",
        );
      }
      return null;
    }
  }

  /// Creates the ride/rental request in Firestore
  Future<void> _confirmRide({StateSetter? setSheetState}) async {
    if (_isBooking) return;
    if (setSheetState != null) {
      setSheetState(() => _isBooking = true);
    } else {
      setState(() => _isBooking = true);
    }

    final String finalPickupAddress =
        _addressSheetController.text.trim().isNotEmpty
        ? _addressSheetController.text.trim()
        : _pickupAddress;

    try {
      Future<String> rideRequestIdFuture;
      num finalFare = _currentCalculatedFare;
      String? destinationAddressString; // **NEW:** Hoisted variable

      // **NEW:** strict auth check & refresh
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          displaySnackBar(context, "User not logged in. Please log in again.");
          if (setSheetState != null) {
            setSheetState(() => _isBooking = false);
          } else {
            setState(() => _isBooking = false);
          }
        }
        return;
      }
      // Force token refresh to ensure valid session for Cloud Function
      await user.getIdToken(true);

      // **NEW:** Calculate split payment
      num walletUsed = 0;
      num cashToPay = finalFare + _tipValue; // Initialize with full amount

      if (_useWalletBalance &&
          widget.walletBalance != null &&
          widget.walletBalance! > 0) {
        walletUsed = min(widget.walletBalance!, cashToPay);
        cashToPay -= walletUsed;
      }

      // **NEW:** Determine final payment method string
      String finalPaymentMethod = _selectedPaymentMethod;
      if (walletUsed > 0) {
        if (cashToPay > 0) {
          finalPaymentMethod = 'Cash + Wallet';
        } else {
          finalPaymentMethod = 'Wallet';
        }
      }

      if (widget.isRental) {
        // --- Create Rental Request ---
        rideRequestIdFuture = _firestoreService.createRentalRideRequest(
          userId: user.uid, // Use current user uid
          userName: user.displayName,
          userPhone: user.phoneNumber,
          pickupLocation: _adjustablePickupLocation,
          pickupAddress: finalPickupAddress,
          pickupPlaceName: _pickupPlaceName, // **NEW**
          rentalPackage: widget.rentalPackage!,
          rentalVehicleType: widget.rentalVehicleType!,
          rentalPrice: finalFare,
          tip: _tipValue,
          paymentMethod: finalPaymentMethod, // **MODIFIED**
          scheduledTime: _currentScheduledTime, // **NEW**
          convenienceFee: _currentConvenienceFee, // **NEW**
          walletAmountUsed: walletUsed, // **NEW**
          cashAmount: cashToPay, // **NEW**
        );
      } else {
        // --- Create Daily/Multi-Stop Ride Request ---
        // **MODIFIED:** Assign to hoisted variable
        destinationAddressString = await _locationService.getAddressFromLatLng(
          widget.destinationPosition,
        );

        // **NEW:** Determine final payment method string
        finalPaymentMethod = _selectedPaymentMethod;
        if (walletUsed > 0) {
          if (cashToPay > 0) {
            finalPaymentMethod = 'Cash + Wallet';
          } else {
            finalPaymentMethod = 'Wallet';
          }
        }

        num baseFare = finalFare;
        // Subtract items that firestore_services.dart will re-add
        // finalFare already excludes tipValue, so we only subtract tolls and convenienceFee
        baseFare -= (_currentRouteDetails?.tollCost ?? 0);
        baseFare -= _currentConvenienceFee;

        rideRequestIdFuture = _firestoreService.createDailyRideRequest(
          userId: user.uid, // Use current user uid
          userName: user.displayName,
          userPhone: user.phoneNumber,
          pickupLocation: _adjustablePickupLocation,
          pickupAddress: finalPickupAddress,
          pickupPlaceName: _pickupPlaceName, // **NEW**
          destinationLocation: widget.destinationPosition,
          destinationAddress:
              destinationAddressString, // Use non-null asserted string
          destinationPlaceName: _destinationPlaceName, // **NEW**
          vehicleType: widget.selectedVehicle?.type ?? "Multi-Stop",
          fare: baseFare, // Passing the pure base fare (plus multi-stop if any)
          tip: _tipValue,
          paymentMethod: finalPaymentMethod, // **MODIFIED**
          routeDetails: _currentRouteDetails,
          intermediateStops: widget.intermediateStops,
          scheduledTime: _currentScheduledTime, // **NEW**
          convenienceFee: _currentConvenienceFee, // **NEW**
          walletAmountUsed: walletUsed, // **NEW**
          cashAmount: cashToPay, // **NEW**
        );
      }

      if (mounted) {
        // **NEW:** Calculate ETA
        String? initialEta;
        if (_currentRouteDetails != null) {
          final int mins = (_currentRouteDetails!.durationSeconds / 60).round();
          initialEta = "$mins mins";
        } else if (widget.selectedVehicle?.eta != null) {
          initialEta = widget.selectedVehicle!.eta;
        }

        // Navigate to the SearchingForRideScreen
        _firestoreService.navigateToSearching(
          context,
          user: widget.user,
          pickupLocation: _adjustablePickupLocation,
          destinationPosition: widget.destinationPosition,
          fare: finalFare.toDouble(),
          tip: _tipValue,
          polylines: _polylines,
          isRental: widget.isRental,
          rideRequestIdFuture: rideRequestIdFuture, // **MODIFIED:** Pass Future
          selectedVehicle: widget.selectedVehicle,
          rentalPackage: widget.rentalPackage,
          rentalVehicleType: widget.rentalVehicleType,
          intermediateStops: widget.intermediateStops,
          scheduledTime: _currentScheduledTime,
          destinationAddress: destinationAddressString,
          initialEta: initialEta,
          isBookForOther: widget.guestName != null,
          // **NEW:** Pass all data for possible retry
          pickupAddress: finalPickupAddress,
          pickupPlaceName: _pickupPlaceName,
          destinationPlaceName: _destinationPlaceName,
          paymentMethod: finalPaymentMethod,
          convenienceFee: _currentConvenienceFee,
          walletAmountUsed: walletUsed,
          cashAmount: cashToPay,
          routeDetails: _currentRouteDetails,
        );
      }
    } catch (e) {
      debugPrint("Error confirming ride: $e");
      if (mounted) {
        displaySnackBar(context, "Failed to book ride: ${e.toString()}");
      }
    } finally {
      if (mounted) {
        if (setSheetState != null) {
          setSheetState(() => _isBooking = false);
        } else {
          setState(() => _isBooking = false);
        }
      }
    }
  }

  void _showBookingSheet(
    BuildContext scaffoldContext, {
    required bool isRefreshing,
    required num walletBalance,
  }) {
    num finalFare = _currentCalculatedFare; // This now includes convenience fee

    showModalBottomSheet(
      context: scaffoldContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isDismissible: !isRefreshing,
      enableDrag: !isRefreshing,
      builder: (context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final Color backgroundColor = isDark ? Colors.grey[900]! : Colors.white;
        final Color textColor = isDark ? Colors.white : Colors.black87;
        final Color subTextColor = isDark
            ? Colors.grey[400]!
            : Colors.grey[700]!;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            // **MODIFIED:** Total fare includes tip + convenience fee (already in finalFare)
            num totalFare = finalFare + _tipValue;

            return PopScope(
              canPop: !isRefreshing,
              onPopInvokedWithResult: (bool didPop, dynamic result) {
                if (didPop) return;
                if (isRefreshing) {
                  displaySnackBar(context, "Please wait, refreshing fare...");
                }
              },
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Container(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 24,
                  right: 24,
                  top: 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[700] : Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),

                      // --- Title and Fare Row ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              widget.isRental
                                  ? 'confirmRental'.tr
                                  : (widget.intermediateStops != null
                                        ? 'confirmMultiStop'.tr
                                        : 'confirmRide'.tr),
                              style: TextStyle(
                                fontSize: _getAdaptiveFontSize(18),
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isRefreshing)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            )
                          else
                            // **MODIFIED:** Show total, not base fare
                            Text(
                              "₹${totalFare.toStringAsFixed(0)}",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                        ],
                      ),
                      if (!isRefreshing)
                        Text(
                          widget.isRental
                              ? "${widget.rentalVehicleType} • ${widget.rentalPackage!.displayName}"
                              : (widget.selectedVehicle?.type ??
                                    "Multi-Stop Ride"),
                          style: TextStyle(
                            fontSize: _getAdaptiveFontSize(15),
                            color: subTextColor,
                          ),
                        ),
                      // **NEW:** Show convenience fee if applied
                      if (_currentConvenienceFee > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            "+ ₹${_currentConvenienceFee.toStringAsFixed(0)} ${'convenienceFee'.tr}",
                            style: TextStyle(
                              fontSize: _getAdaptiveFontSize(12),
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      const Divider(),

                      // **NEW:** Wallet Usage Toggle (Moved to Top for Visibility)
                      if (widget.walletBalance != null)
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark 
                                ? AppColors.primary.withValues(alpha: 0.15) 
                                : AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: Icon(
                              Icons.account_balance_wallet,
                              color: (widget.walletBalance ?? 0) > 0 
                                  ? AppColors.primary 
                                  : Colors.grey,
                              size: 28,
                            ),
                            title: Text(
                              "useWalletBalance".tr,
                              style: TextStyle(
                                fontSize: _getAdaptiveFontSize(16),
                                color: (widget.walletBalance ?? 0) > 0 
                                    ? textColor 
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              "${"available".tr}: ₹${widget.walletBalance!.toStringAsFixed(0)}",
                              style: TextStyle(
                                fontSize: _getAdaptiveFontSize(12),
                                color: subTextColor,
                              ),
                            ),
                            value: (widget.walletBalance ?? 0) > 0 && _useWalletBalance,
                            activeThumbColor: AppColors.primary,
                            onChanged: (isRefreshing || (widget.walletBalance ?? 0) <= 0)
                                ? null
                                : (bool value) {
                                    setSheetState(() {
                                      _useWalletBalance = value;
                                      if (!value && _selectedPaymentMethod == 'Wallet') {
                                        _selectedPaymentMethod = 'Cash';
                                      }
                                    });
                                  },
                          ),
                        ),
                      const SizedBox(height: 8),

                      // --- Tip Slider ---
                      const SizedBox(height: 16),
                      Text(
                        '${'addATip'.tr}: ₹${_tipValue.round()}',
                        style: TextStyle(
                          fontSize: _getAdaptiveFontSize(16),
                          color: textColor,
                        ),
                      ),
                      Slider(
                        value: _tipValue,
                        min: 0,
                        max: 150,
                        divisions: 15,
                        label: '₹${_tipValue.round()}',
                        activeColor: AppColors.primary,
                        onChanged: isRefreshing
                            ? null
                            : (double value) {
                                double snappedValue =
                                    (value / 10).round() * 10.0;
                                setSheetState(() => _tipValue = snappedValue);
                              },
                      ),
                      const SizedBox(height: 16),

                      const SizedBox(height: 16),

                      // --- Payment Method Button ---
                      OutlinedButton.icon(
                        icon: const Icon(Icons.payment),
                        label: Text(_selectedPaymentMethod),
                        onPressed: isRefreshing
                            ? null
                            : () async {
                                final result = await Get.to<Map<String, dynamic>>(
                                  () => PaymentScreen(
                                    currentPaymentMethod:
                                        _selectedPaymentMethod,
                                    currentBalance: widget.walletBalance ?? 0,
                                    totalFare: totalFare,
                                    initialUseWallet: _useWalletBalance,
                                  ),
                                );
                                if (result != null) {
                                  setSheetState(() {
                                    _selectedPaymentMethod = result['method'] ?? 'Cash';
                                    _useWalletBalance = result['useWallet'] ?? false;
                                    if (_selectedPaymentMethod == 'Wallet') {
                                      _useWalletBalance = true;
                                    }
                                  });
                                }
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textColor,
                          side: BorderSide(
                            color: isRefreshing
                                ? (isDark
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade200)
                                : (isDark
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade600),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- Confirm Booking Button ---
                      ProButton(
                        text: _useWalletBalance
                            ? (widget.walletBalance != null && widget.walletBalance! >= totalFare)
                                ? "${'bookNow'.tr} (${'wallet'.tr})"
                                : "${'bookNow'.tr} (₹${min(widget.walletBalance ?? 0, totalFare).toStringAsFixed(0)} ${'wallet'.tr} + ₹${max(0, (totalFare - (widget.walletBalance ?? 0))).toStringAsFixed(0)} ${'cash'.tr})"
                            : "${'bookNow'.tr} (${'total'.tr}: ₹${totalFare.toStringAsFixed(0)})",
                        isLoading: _isBooking || isRefreshing,
                        fontSize: _getAdaptiveFontSize(18),
                        // backgroundColor: Colors.blueAccent, // Use default gradient
                        onPressed: (_isBooking || isRefreshing)
                            ? null
                            : () => _confirmRide(setSheetState: setSheetState),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ));
          },
        );
      },
    );
  }

  Future<void> _goToCurrentPosition() async {
    final LatLng gpsLocation = await _locationService.getCurrentLocation();
    if (!mounted) return;

    if (gpsLocation == LocationService.defaultLocation) {
      displaySnackBar(context, "Could not get your current location.");
    }

    if (!_mapController.isCompleted) return;
    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(gpsLocation, 17.5));

    setState(() {
      _adjustablePickupLocation = gpsLocation;
      _hasMovedPin = false; // Pin is back to original
    });
    _getAddressFromLatLng(gpsLocation);
    // **FIXED:** Call _updateMarkers here to reset destination marker
    _updateMarkers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProAppBar(
        title: Text(
          widget.isRental
              ? "confirmRental".tr
              : "confirmRide".tr,
        ),
      ),
      body: Builder(
        // Use Builder to get context for bottom sheet
        builder: (scaffoldContext) {
          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: widget.currentPosition,
                  zoom: 17.5,
                ),
                myLocationEnabled: true, // Show the blue dot
                mapType: MapType.terrain,
                myLocationButtonEnabled: false, // We use our custom button
                polylines: _polylines,
                markers: _markers,
                polygons: _polygons,
                zoomControlsEnabled: false,
                onMapCreated: (GoogleMapController controller) {
                  _mapController.complete(controller);
                  controller.animateCamera(
                    CameraUpdate.newLatLngZoom(widget.currentPosition, 17.5),
                  );
                },
                onCameraMove: (CameraPosition position) {
                  // **MODIFIED:** Disable dragging if in a common pickup zone
                  if (mounted &&
                      !_isRefreshingFare &&
                      _activePickupZone == null) {
                    setState(() {
                      _adjustablePickupLocation = position.target;
                    });
                  }
                },
                onCameraIdle: () async {
                  if (_isRefreshingFare || !mounted) return;

                  // **MODIFIED:** Don't process idle fetches if in a common pickup zone
                  if (_activePickupZone != null) return;

                  bool hasMoved = !_locationService.areLocationsClose(
                    widget.currentPosition,
                    _adjustablePickupLocation,
                    toleranceInMeters: 50,
                  );

                  await _getAddressFromLatLng(_adjustablePickupLocation);

                  // **FIXED:** Call _updateMarkers to update destination pin
                  _updateMarkers();

                  // **FIXED:** Latching logic
                  // Only set to true if it's a daily ride and has moved
                  if (hasMoved && !widget.isRental) {
                    if (mounted) setState(() => _hasMovedPin = true);
                  }
                },
              ),

              // Stationary Green Pin in the center
              // **MODIFIED:** Only show stationary pin if NOT in a common pickup zone
              if (_activePickupZone == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 40.0),
                    child: Icon(
                      Icons.location_pin,
                      color: Colors.green,
                      size: 40,
                    ),
                  ),
                ),

              // **NEW:** GPS Button
              // **MODIFIED:** Hide if in common pickup zone
              if (_activePickupZone == null)
                Positioned(
                  bottom: 100, // Positioned above the "Proceed" button
                  right: 16,
                  child: FloatingActionButton(
                    heroTag: 'gpsButtonConfirm',
                    onPressed: _goToCurrentPosition,
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.white,
                    elevation: 4,
                    child: Icon(
                      Icons.gps_fixed,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.blueAccent,
                    ),
                  ),
                ),

              // **NEW/RESTORED:** Proceed/Update Button or Custom Selector
              if (_activePickupZone != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              "selectPickupPoint".tr,
                              style: TextStyle(
                                fontSize: _getAdaptiveFontSize(18),
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight:
                                  (_activePickupZone!.pickupPoints.length *
                                          56.0)
                                      .clamp(56.0, 250.0),
                            ),
                            child: RadioGroup<Map<String, dynamic>>(
                              groupValue: _selectedPickupPoint,
                              onChanged: (value) async {
                                setState(() {
                                  _selectedPickupPoint = value;
                                });
                                if (value != null &&
                                    _mapController.isCompleted) {
                                  final geo = value['location'] as GeoPoint;
                                  final target = LatLng(
                                    geo.latitude,
                                    geo.longitude,
                                  );
                                  final controller =
                                      await _mapController.future;

                                  setState(() {
                                    _adjustablePickupLocation = target;
                                    _hasMovedPin = true;
                                  });
                                  controller.animateCamera(
                                    CameraUpdate.newLatLngZoom(target, 17.5),
                                  );
                                  _getAddressFromLatLng(target);
                                  _updateMarkers();
                                }
                              },
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount:
                                    _activePickupZone!.pickupPoints.length,
                                itemBuilder: (context, index) {
                                  final point =
                                      _activePickupZone!.pickupPoints[index];
                                  return RadioListTile<Map<String, dynamic>>(
                                    value: point,
                                    title: Text(point['name']),
                                    activeColor: AppColors.primary,
                                  );
                                },
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: ProButton(
                              text: "confirmPickupPoint".tr,
                              isLoading: _isRefreshingFare || _isBooking,
                              onPressed:
                                  _selectedPickupPoint == null ||
                                      _isRefreshingFare ||
                                      _isBooking
                                  ? null
                                  : () => _showBookingSheet(
                                      scaffoldContext,
                                      isRefreshing: false,
                                      walletBalance: widget.walletBalance ?? 0,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ProButton(
                        text: _hasMovedPin
                            ? "updatePickupRefreshFare".tr
                            : (widget.isRental
                                  ? "proceedWithRentalDetails".tr
                                  : "proceedToPayment".tr),
                        isLoading: _isRefreshingFare,
                        backgroundColor: _hasMovedPin
                            ? Colors.orange.shade700
                            : null,
                        onPressed: (_isRefreshingFare || _isBooking)
                            ? null // Disable button if loading
                            : (_hasMovedPin
                                  ? _refreshFare
                                  : () => _showBookingSheet(
                                      scaffoldContext,
                                      isRefreshing: false,
                                      walletBalance: widget.walletBalance ?? 0,
                                    )),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
