// ignore_for_file: unnecessary_overrides

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project_taxi_with_ai/config/env_config.dart';
import 'package:project_taxi_with_ai/widgets/data_models.dart';
import 'package:project_taxi_with_ai/widgets/map_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:project_taxi_with_ai/widgets/location_service.dart';
import 'package:project_taxi_with_ai/widgets/places_service.dart';
import 'package:project_taxi_with_ai/widgets/directions_service.dart';
import 'package:project_taxi_with_ai/widgets/firestore_services.dart';
import 'package:project_taxi_with_ai/widgets/storage.service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RideController extends GetxController {
  static RideController get instance => Get.find();

  // Services
  // Services
  final MapService mapService = MapService();
  late final LocationService locationService;
  late final PlacesService placesService;
  late final DirectionsService directionsService;
  final FirestoreService firestoreService = FirestoreService();
  final StorageService storageService = StorageService();

  // Map & Location State
  final Rx<GoogleMapController?> mapController = Rx<GoogleMapController?>(null);
  final Rx<LatLng?> currentPosition = Rx<LatLng?>(null);
  final RxSet<Marker> markers = <Marker>{}.obs;
  final RxSet<Polyline> polylines = <Polyline>{}.obs;
  final RxBool isLoadingLocation = true.obs;
  final RxnString mapStyleJson = RxnString(null); // Reactive map style for GoogleMap.style

  // Addresses
  final RxString pickupAddress = ''.obs;
  final RxString pickupPlaceName = ''.obs;
  final RxString destinationAddress = ''.obs;
  final RxString destinationPlaceName = ''.obs;
  final Rx<LatLng?> destinationLocation = Rx<LatLng?>(null);

  // Ride State
  final RxString currentRideId = ''.obs;
  final RxString rideStatus = ''.obs;
  final Rx<RideType> selectedServiceType = RideType.daily.obs;

  // Driver State
  final RxSet<Marker> driverMarkers = <Marker>{}.obs;
  final RxList<Driver> nearbyDrivers = <Driver>[].obs;
  StreamSubscription<QuerySnapshot>? _driversSubscription;
  StreamSubscription<DocumentSnapshot>? _rideStatusSubscription;
  StreamSubscription<DocumentSnapshot>? _driverLocationSubscription;
  StreamSubscription<DocumentSnapshot>? _walletSubscription; // **NEW**
  StreamSubscription<List<FavoritePlace>>? _favoritesSubscription; // **NEW**

  // Assigned Driver (Ride In Progress)
  final Rx<Driver?> assignedDriver = Rx<Driver?>(null);
  final Rx<LatLng?> driverLocation = Rx<LatLng?>(null);
  final RxDouble driverBearing = 0.0.obs;

  // Custom Icons
  final Map<String, BitmapDescriptor> _carIcons = {};
  BitmapDescriptor? pickupIcon;
  BitmapDescriptor? destinationIcon;
  final RxBool iconsLoaded = false.obs;

  // Search & Places
  final RxList<PlaceAutocompletePrediction> predictions =
      <PlaceAutocompletePrediction>[].obs;
  final RxList<SearchHistoryItem> searchHistory = <SearchHistoryItem>[].obs;

  // Fares & Pricing
  final RxBool isCalculatingFares = false.obs;
  final Rx<PricingRules?> pricingRules = Rx<PricingRules?>(null);
  final RxNum walletBalance = RxNum(0);
  final RxList<FavoritePlace> favoritePlaces = <FavoritePlace>[].obs; // **NEW**

  // Rentals
  final RxList<RentalPackage> rentalPackages = <RentalPackage>[].obs;
  final RxBool isLoadingRentals = false.obs;

  // TTS
  late FlutterTts flutterTts; // **NEW**

  @override
  void onInit() {
    super.onInit();
    // Initialization is now handled explicitly via initialize()
  }

  bool _isInitialized = false;

  Future<void> initialize() async {
    debugPrint("RideController: initialize started");

    if (_isInitialized) {
      debugPrint("RideController: Already initialized, skipping.");
      return;
    }

    // Initialize Services
    final apiKey = EnvConfig.instance.googleMapsKey;
    // Use try-catch or check if already assigned to be extra safe, though _isInitialized should handle it.
    try {
      locationService = LocationService(apiKey: apiKey);
      placesService = PlacesService(apiKey: apiKey);
      directionsService = DirectionsService(apiKey: apiKey);
    } catch (e) {
      debugPrint(
        "RideController: Service initialization error (or already initialized): $e",
      );
    }

    // Initialize TTS
    flutterTts = FlutterTts();
    await _configureTts();

    // Load Data
    try {
      await Future.wait([
        _loadCustomIcons(),
        _getCurrentLocation(showLoader: false),
        _loadSearchHistory(),
        _loadRentalPackages(),
        _loadPricingRules(),
        _listenToWallet(), // **NEW**
        _listenToFavorites(), // **NEW**
      ]);
    } catch (e) {
      debugPrint("Error during RideController initialization: $e");
    }

    isLoadingLocation.value = false;
    _isInitialized = true;
    debugPrint("RideController: initialize completed");
  }

  void reset() {
    debugPrint("RideController: Resetting state...");
    markers.clear();
    polylines.clear();
    pickupAddress.value = '';
    pickupPlaceName.value = '';
    destinationAddress.value = '';
    destinationPlaceName.value = '';
    destinationLocation.value = null;
    currentRideId.value = '';
    rideStatus.value = '';
    selectedServiceType.value = RideType.daily;
    driverMarkers.clear();
    nearbyDrivers.clear();
    assignedDriver.value = null;
    driverLocation.value = null;
    driverBearing.value = 0.0;
    predictions.clear();
    searchHistory.clear();
    isCalculatingFares.value = false;
    pricingRules.value = null;
    walletBalance.value = 0;
    // Don't clear rentalPackages as they are static data, but ok to reload if needed.
    // Don't dispose services/controllers.

    // Stop listeners
    _driversSubscription?.cancel();
    _rideStatusSubscription?.cancel();
    _driverLocationSubscription?.cancel();
    _walletSubscription?.cancel(); // **NEW**
    _favoritesSubscription?.cancel(); // **NEW**

    _isInitialized = false; // Allow re-initialization
  }

  @override
  void onClose() {
    _driversSubscription?.cancel();
    _rideStatusSubscription?.cancel();
    _driverLocationSubscription?.cancel();
    _walletSubscription?.cancel(); // **NEW**
    _favoritesSubscription?.cancel(); // **NEW**
    mapController.value?.dispose();
    super.onClose();
  }

  Future<void> _loadCustomIcons() async {
    try {
      _carIcons['Auto'] = await _getBitmapFromAsset(
        'assets/images/marker_auto.png',
      );
      _carIcons['Hatchback'] = await _getBitmapFromAsset(
        'assets/images/marker_car.png',
      );
      _carIcons['Sedan'] = await _getBitmapFromAsset(
        'assets/images/marker_car.png',
      );
      _carIcons['SUV'] = await _getBitmapFromAsset(
        'assets/images/marker_car.png',
      );
      _carIcons['ActingDriver'] = await _getBitmapFromAsset(
        'assets/images/marker_driver.png',
      );

      // Load Pickup & Destination Icons (smaller size for pins)
      /*
      pickupIcon = await _getBitmapFromAsset(
        'assets/images/marker_pickup.png',
        width: 64,
      );
      destinationIcon = await _getBitmapFromAsset(
        'assets/images/marker_destination.png',
        width: 64,
      );
      */

      iconsLoaded.value = true;
      // Refresh drivers if already listening
      if (nearbyDrivers.isNotEmpty) {
        _listenForNearbyDrivers();
      }
    } catch (e) {
      debugPrint("Error loading icons: $e");
    }
  }

  BitmapDescriptor getVehicleIcon(String vehicleType) {
    return _carIcons[vehicleType] ?? BitmapDescriptor.defaultMarker;
  }

  Future<BitmapDescriptor> _getBitmapFromAsset(
    String path, {
    int width = 80,
  }) async {
    final ByteData data = await rootBundle.load(path);
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    final ui.FrameInfo fi = await codec.getNextFrame();
    final Uint8List bytes = (await fi.image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    return BitmapDescriptor.bytes(bytes);
  }

  Future<void> _getCurrentLocation({bool showLoader = true}) async {
    if (showLoader) {
      isLoadingLocation.value = true;
    }
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("Location services are disabled");
        if (showLoader) isLoadingLocation.value = false;
        Future.delayed(const Duration(milliseconds: 100), () {
          if (Get.context != null) {
            Get.snackbar("Error", "Location services are disabled.");
          }
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint("Location permissions are denied");
          if (showLoader) isLoadingLocation.value = false;
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint("Location permissions are permanently denied");
        if (showLoader) isLoadingLocation.value = false;
        return;
      }

      // **NEW:** Try last known position first for instant map loading
      Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        debugPrint("RideController: Using last known location for initial view");
        currentPosition.value = LatLng(lastKnown.latitude, lastKnown.longitude);
        updateCurrentPosition(currentPosition.value!, animateMap: true);
        _listenForNearbyDrivers();
        // If we have any location, hide the big spinner so user sees the map
        if (showLoader) isLoadingLocation.value = false;
      }

      // **NEW:** Get current position with a timeout to prevent infinite spinning
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15), // Don't wait forever
        ),
      );

      currentPosition.value = LatLng(position.latitude, position.longitude);
      updateCurrentPosition(currentPosition.value!, animateMap: true);
      _listenForNearbyDrivers();
    } catch (e) {
      debugPrint("RideController: Failed to get precise location: $e");
      // If we couldn't get a precise fix but have a last known, we're still okay
      if (currentPosition.value == null && showLoader) {
        Get.snackbar("Location Error", "Could not get current location. Please check GPS.");
      }
    } finally {
      if (showLoader) {
        isLoadingLocation.value = false;
      }
    }
  }

  void onMapCreated(GoogleMapController controller) {
    mapController.value = controller;
    mapService.onMapCreated(controller);
    if (currentPosition.value != null) {
      mapService.animateCamera(currentPosition.value!, zoom: 15);
    }
  }

  Future<void> updateMapStyle(bool isDarkMode) async {
    try {
      if (isDarkMode) {
        mapStyleJson.value = await rootBundle.loadString('assets/json/map_style_dark.json');
      } else {
        mapStyleJson.value = null; // null resets to default light style
      }
    } catch (e) {
      debugPrint("RideController: Error loading map style asset: $e");
    }
  }

  Future<void> updateCurrentPosition(
    LatLng position, {
    bool animateMap = false,
  }) async {
    // Update markers
    markers.removeWhere((m) => m.markerId.value == 'pickup');
    markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: position,
        infoWindow: const InfoWindow(
          title: "Pickup",
          snippet: "Current Location",
        ),
        icon:
            pickupIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    );

    if (animateMap && mapController.value != null) {
      mapService.animateCamera(position);
    }

    // Reverse geocoding
    final address = await locationService.getAddressFromLatLng(position);
    pickupAddress.value = address;
    
    // Fallback: extract a place name if possible, or use the first part of address
    if (address.isNotEmpty) {
      pickupPlaceName.value = address.split(',')[0];
    }
  }

  DateTime? _lastDriverUpdateTime;

  void _listenForNearbyDrivers() {
    if (!iconsLoaded.value) {
      return;
    }

    _driversSubscription?.cancel();
    _driversSubscription = FirebaseFirestore.instance
        .collection('drivers')
        .where('isOnline', isEqualTo: true)
        .limit(50) // Limit to prevent ANR from too many docs
        .snapshots()
        .listen((snapshot) {
          if (currentPosition.value == null) {
            return;
          }

          // Throttle updates to prevent ANR
          final now = DateTime.now();
          if (_lastDriverUpdateTime != null &&
              now.difference(_lastDriverUpdateTime!) <
                  const Duration(milliseconds: 1000)) {
            return;
          }
          _lastDriverUpdateTime = now;

          final Set<Marker> newDriverMarkers = {};
          final List<Driver> newNearbyDrivers = [];
          const double radiusInMeters = 5000;

          for (var doc in snapshot.docs) {
            try {
              final driver = Driver.fromFirestore(doc);
              final double distance = Geolocator.distanceBetween(
                currentPosition.value!.latitude,
                currentPosition.value!.longitude,
                driver.currentLocation.latitude,
                driver.currentLocation.longitude,
              );

              if (distance <= radiusInMeters) {
                newNearbyDrivers.add(driver);
                String iconType = driver.isActingDriver
                    ? 'ActingDriver'
                    : driver.vehicleType;

                newDriverMarkers.add(
                  Marker(
                    markerId: MarkerId(driver.id),
                    position: driver.currentLocation,
                    icon: _carIcons[iconType] ?? BitmapDescriptor.defaultMarker,
                    rotation: driver.bearing,
                    anchor: const Offset(0.5, 0.5),
                    flat: true,
                  ),
                );
              }
            } catch (e) {
              debugPrint("Error parsing driver: $e");
            }
          }

          driverMarkers.assignAll(newDriverMarkers);
          nearbyDrivers.assignAll(newNearbyDrivers);
        });
  }

  Map<String, bool> getDriverAvailability() {
    Map<String, bool> availability = {
      'Auto': false,
      'Hatchback': false,
      'Sedan': false,
      'SUV': false,
      'ActingDriver': false,
    };

    if (selectedServiceType.value == RideType.acting) {
      availability['ActingDriver'] = nearbyDrivers.any((d) => d.isActingDriver);
    } else {
      availability['Auto'] = nearbyDrivers.any((d) => d.vehicleType == 'Auto');
      availability['Hatchback'] = nearbyDrivers.any(
        (d) => d.vehicleType == 'Hatchback',
      );
      availability['Sedan'] = nearbyDrivers.any(
        (d) => d.vehicleType == 'Sedan',
      );
      availability['SUV'] = nearbyDrivers.any((d) => d.vehicleType == 'SUV');
    }
    return availability;
  }

  String getNearestDriverEta(String vehicleType) {
    if (currentPosition.value == null) return "N/A";

    final relevantDrivers = nearbyDrivers.where((d) {
      if (vehicleType == 'ActingDriver') {
        return d.isActingDriver;
      }
      return d.vehicleType == vehicleType && !d.isActingDriver;
    }).toList();

    if (relevantDrivers.isEmpty) return "N/A";

    double minDistance = double.infinity;

    for (var driver in relevantDrivers) {
      final double distance = Geolocator.distanceBetween(
        currentPosition.value!.latitude,
        currentPosition.value!.longitude,
        driver.currentLocation.latitude,
        driver.currentLocation.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    if (minDistance == double.infinity) return "N/A";

    // Assume average city speed of 25 km/h
    // 25 km/h = 25000 meters / 60 minutes ≈ 416 meters/minute
    final int etaMinutes = (minDistance / 416).ceil();

    if (etaMinutes <= 1) return "1 min";
    return "$etaMinutes mins";
  }

  void updateMapElements({
    List<LatLng>? routePoints,
    required String pickupAddress,
    String? pickupPlaceName,
    required String destinationAddress,
    String? destinationPlaceName,
  }) {
    if (pickupPlaceName != null) this.pickupPlaceName.value = pickupPlaceName;
    if (destinationPlaceName != null) this.destinationPlaceName.value = destinationPlaceName;

    markers.assignAll(
      mapService.createMarkers(
        pickupLocation: currentPosition.value,
        pickupAddress: pickupAddress,
        destinationLocation: destinationLocation.value,
        destinationAddress: destinationAddress,
        pickupIcon: pickupIcon,
        destinationIcon: destinationIcon,
      ),
    );
    polylines.assignAll(mapService.createPolylines(routePoints));
  }

  Future<void> goToCurrentUserLocation() async {
    await _getCurrentLocation(showLoader: false);
  }

  final RxMap<String, dynamic> rideData = <String, dynamic>{}.obs;
  final HttpsCallable _calculateFaresCallable = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  ).httpsCallable('calculateFares');

  void listenToRideStatus(String rideId, {bool isRental = false}) {
    _rideStatusSubscription?.cancel();
    currentRideId.value = rideId;
    _rideStatusSubscription = FirebaseFirestore.instance
        .collection(isRental ? 'rental_requests' : 'ride_requests')
        .doc(rideId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data();
            if (data != null) {
              rideData.value = data; // Update full ride data
              final newStatus = data['status'] as String? ?? '';
              // Trigger audio if status changes to 'arrived'
              if (rideStatus.value != 'arrived' && newStatus == 'arrived') {
                _playArrivalNotification();
              }
              rideStatus.value = newStatus;
            }
          }
        });
  }

  Future<Map<String, num>?> calculateFare({
    required LatLng pickup,
    required LatLng destination,
  }) async {
    debugPrint("!!! DEBUG START: calculateFare !!!");
    String currentProjectId = "Unknown";
    try {
      currentProjectId = Firebase.app().options.projectId;
      debugPrint("!!! DEBUG: Firebase Project ID: $currentProjectId !!!");
    } catch (e) {
      debugPrint("!!! DEBUG ERROR: Could not get Project ID: $e !!!");
    }

    debugPrint("!!! DEBUG: Checking Firestore for pricing_rules/Chennai !!!");
    try {
      final doc = await FirebaseFirestore.instance
          .collection('pricing_rules')
          .doc('Chennai')
          .get();
      if (doc.exists) {
        debugPrint("!!! DEBUG: FOUND 'Chennai' doc. Data: ${doc.data()} !!!");
      } else {
        debugPrint(
          "!!! DEBUG: CRITICAL MISSING - 'Chennai' doc does NOT exist in $currentProjectId !!!",
        );
      }
    } catch (e) {
      debugPrint("!!! DEBUG ERROR: Firestore Check Failed: $e !!!");
    }
    debugPrint("!!! DEBUG END: Pre-check complete !!!");

    try {
      // 1. Get Directions to calculate distance
      final routeDetails = await directionsService.getDirections(
        pickup,
        destination,
      );

      if (routeDetails == null) {
        debugPrint("Could not calculate route for fare update.");
        return null;
      }

      // 2. Call Cloud Function with distance and polyline for geofence toll calculation
      final result = await _calculateFaresCallable.call<Map<dynamic, dynamic>>({
        'distanceMeters': routeDetails.distanceMeters,
        'durationSeconds': routeDetails.durationSeconds,
        'tollCost': routeDetails.tollCost,
        'pickupLocation': {
          'latitude': pickup.latitude,
          'longitude': pickup.longitude,
        },
        'routePolyline': routeDetails.polylinePoints
            .map((p) => {'latitude': p.latitude, 'longitude': p.longitude})
            .toList(),
      });

      final data = result.data;
      if (data['fares'] != null) {
        return Map<String, num>.from(data['fares']);
      }
      return null;
    } catch (e) {
      debugPrint("DEBUG MODIFIED: Error calling calculateFares function: $e");
      debugPrint("Error Runtime Type: ${e.runtimeType}");
      if (e is FirebaseFunctionsException) {
        debugPrint(
          "Code: ${e.code}, Message: ${e.message}, Details: ${e.details}",
        );
      } else {
        debugPrint("Exception is NOT FirebaseFunctionsException. It is: $e");
      }
      return null;
    }
  }

  void listenToDriverLocation(String driverId) {
    _driverLocationSubscription?.cancel();
    _driverLocationSubscription = FirebaseFirestore.instance
        .collection('drivers')
        .doc(driverId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            final driver = Driver.fromFirestore(snapshot);
            assignedDriver.value = driver;
            driverLocation.value = driver.currentLocation;
            driverBearing.value = driver.bearing;
          }
        });
  }

  // **NEW:** Check for active rides (Daily & Rental)
  Future<List<Map<String, dynamic>>> checkActiveRides() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final activeStatuses = [
      'searching',
      'accepted',
      'arrived',
      'in_progress',
      'started',
      'scheduled',
    ];

    try {
      debugPrint("DEBUG: checkActiveRides started for user: ${user.uid}");

      // **OPTIMIZATION:** Run queries in parallel
      final results = await Future.wait([
        // 1. Check Daily Rides
        FirebaseFirestore.instance
            .collection('ride_requests')
            .where('userId', isEqualTo: user.uid)
            .where('status', whereIn: activeStatuses)
            .get(),
        // 2. Check Rental Rides
        FirebaseFirestore.instance
            .collection('rental_requests')
            .where('userId', isEqualTo: user.uid)
            .where('status', whereIn: activeStatuses)
            .get(),
      ]);

      final dailyQuery = results[0];
      final rentalQuery = results[1];

      debugPrint("DEBUG: Found ${dailyQuery.docs.length} active daily rides");
      debugPrint("DEBUG: Found ${rentalQuery.docs.length} active rental rides");

      List<Map<String, dynamic>> activeRides = [];

      for (var doc in dailyQuery.docs) {
        final data = doc.data();
        final status = data['status'] ?? 'unknown';
        // Defensive check: skip completed/cancelled
        if (status == 'completed' || status == 'cancelled') continue;

        activeRides.add({
          'id': doc.id,
          'type': 'daily',
          'data': data,
          'createdAt': data['createdAt'], // For sorting if needed
        });
      }

      for (var doc in rentalQuery.docs) {
        final data = doc.data();
        final status = data['status'] ?? 'unknown';
        // Defensive check: skip completed/cancelled
        if (status == 'completed' || status == 'cancelled') continue;

        activeRides.add({
          'id': doc.id,
          'type': 'rental',
          'data': data,
          'createdAt': data['createdAt'],
        });
      }

      return activeRides;
    } catch (e) {
      debugPrint("Error checking active rides: $e");
      return [];
    }
  }

  Future<void> callDriver() async {
    if (currentRideId.value.isEmpty) {
      Get.snackbar("Error", "No active ride found.");
      return;
    }

    try {
      // Call the Cloud Function
      final result = await FirebaseFunctions.instanceFor(
        region: 'asia-south1',
      ).httpsCallable('bridgeCall').call({'rideId': currentRideId.value});

      final data = result.data as Map<dynamic, dynamic>;
      if (data['success'] == true) {
        Get.snackbar("Success", "Connecting you to the driver...");
      } else {
        Get.snackbar("Error", "Failed to connect call.");
      }
    } catch (e) {
      debugPrint("Error calling driver: $e");
      Get.snackbar("Error", "Could not initiate call. Please try again.");
    }
  }

  // --- Data Loading Helpers ---
  Future<void> _loadSearchHistory() async {
    try {
      final history = await storageService.loadSearchHistory();
      searchHistory.assignAll(history);
    } catch (e) {
      debugPrint("Error loading search history: $e");
    }
  }

  Future<void> _loadRentalPackages() async {
    isLoadingRentals.value = true;
    try {
      final packages = await firestoreService.getRentalPackages();
      debugPrint("RideController: Loaded ${packages.length} rental packages");
      if (packages.isEmpty) {
        debugPrint("RideController: WARNING - No rental packages found in Firestore!");
      }
      rentalPackages.assignAll(packages);
    } catch (e) {
      debugPrint("RideController: Error loading rental packages: $e");
    } finally {
      isLoadingRentals.value = false;
    }
  }

  Future<void> _loadPricingRules() async {
    try {
      final rules = await firestoreService.getPricingRules("Chennai");
      pricingRules.value = rules;
    } catch (e) {
      debugPrint("Error loading pricing rules: $e");
    }
  }

  Future<void> addSearchToHistory({
    required String description,
    required String placeId,
    required String mainText,
    required String secondaryText,
  }) async {
    final updatedHistory = await storageService.addSearchToHistory(
      description: description,
      placeId: placeId,
      mainText: mainText,
      secondaryText: secondaryText,
      currentHistory: searchHistory,
    );
    searchHistory.assignAll(updatedHistory);
  }

  Future<void> _listenToWallet() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _walletSubscription?.cancel();
    _walletSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data();
            final balance = (data?['wallet_balance'] as num?) ?? 0;
            walletBalance.value = balance;
            debugPrint(
              "RideController: Wallet balance updated to ${walletBalance.value}",
            );
          }
        });
  }

  Future<void> _listenToFavorites() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _favoritesSubscription?.cancel();
    _favoritesSubscription = firestoreService
        .getFavoritesStream(user.uid)
        .listen((favorites) {
          favoritePlaces.assignAll(favorites);
        });
  }

  // --- TTS Helpers ---
  Future<void> _configureTts() async {
    try {
      await flutterTts.setLanguage("en-US");
      await flutterTts.setVolume(1.0);
      await flutterTts.setPitch(1.0);

      // iOS: Playback category ensures audio plays even in silent mode
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await flutterTts
            .setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
              IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
              IosTextToSpeechAudioCategoryOptions.allowBluetooth,
              IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            ]);
      }
    } catch (e) {
      debugPrint("Error configuring TTS: $e");
    }
  }

  Future<void> _playArrivalNotification() async {
    try {
      debugPrint("Playing arrival notification...");
      // Ensure volume is max before playing (best effort)
      await flutterTts.setVolume(1.0);
      await flutterTts.speak(
        "Your driver has arrived, please meet the driver at the pickup location",
      );
    } catch (e) {
      debugPrint("Error playing TTS: $e");
    }
  }

  Future<void> addRentalStop(
    String rideId,
    LatLng location,
    String address,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('rental_requests')
          .doc(rideId)
          .update({
            'stops': FieldValue.arrayUnion([
              {
                'latitude': location.latitude,
                'longitude': location.longitude,
                'address': address,
                'status': 'pending',
                'addedAt': Timestamp.now(),
              },
            ]),
          });
      debugPrint("Rental stop added successfully to ride $rideId");
    } catch (e) {
      debugPrint("Error adding rental stop: $e");
      rethrow;
    }
  }
}
