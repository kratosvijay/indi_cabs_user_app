// ignore_for_file: unnecessary_overrides

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project_taxi_with_ai/widgets/data_models.dart';
import 'package:project_taxi_with_ai/widgets/map_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:project_taxi_with_ai/widgets/location_service.dart';
import 'package:project_taxi_with_ai/widgets/places_service.dart';
import 'package:project_taxi_with_ai/widgets/directions_service.dart';
import 'package:project_taxi_with_ai/widgets/firestore_services.dart';
import 'package:project_taxi_with_ai/widgets/storage.service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_tts/flutter_tts.dart'; // **NEW**

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

  // Addresses
  final RxString pickupAddress = ''.obs;
  final RxString destinationAddress = ''.obs;
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

  Future<void> initialize() async {
    debugPrint("RideController: initialize started");

    // Initialize Services
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    locationService = LocationService(apiKey: apiKey);
    placesService = PlacesService(apiKey: apiKey);
    directionsService = DirectionsService(apiKey: apiKey);

    // Initialize TTS
    flutterTts = FlutterTts();
    await _configureTts(); // **NEW**

    // Load Data
    // Load Data
    try {
      await Future.wait([
        _loadCustomIcons(),
        _getCurrentLocation(showLoader: false),
        _loadSearchHistory(),
        _loadRentalPackages(),
        _loadPricingRules(),
      ]);
    } catch (e) {
      debugPrint("Error during RideController initialization: $e");
    }

    isLoadingLocation.value = false;
    debugPrint("RideController: initialize completed");
  }

  @override
  void onClose() {
    _driversSubscription?.cancel();
    _rideStatusSubscription?.cancel();
    _driverLocationSubscription?.cancel();
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
      pickupIcon = await _getBitmapFromAsset(
        'assets/images/marker_pickup.png',
        width: 64,
      );
      destinationIcon = await _getBitmapFromAsset(
        'assets/images/marker_destination.png',
        width: 64,
      );

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
        // Only show snackbar if Get context is ready
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
          Future.delayed(const Duration(milliseconds: 100), () {
            if (Get.context != null) {
              Get.snackbar("Error", "Location permissions are denied");
            }
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint("Location permissions are permanently denied");
        if (showLoader) isLoadingLocation.value = false;
        Future.delayed(const Duration(milliseconds: 100), () {
          if (Get.context != null) {
            Get.snackbar(
              "Error",
              "Location permissions are permanently denied",
            );
          }
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      currentPosition.value = LatLng(position.latitude, position.longitude);
      updateCurrentPosition(currentPosition.value!, animateMap: true);
      _listenForNearbyDrivers();
    } catch (e) {
      debugPrint("Failed to get location: $e");
      Future.delayed(const Duration(milliseconds: 100), () {
        if (Get.context != null) {
          Get.snackbar("Error", "Failed to get location: $e");
        }
      });
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
    pickupAddress.value = await locationService.getAddressFromLatLng(position);
  }

  void _listenForNearbyDrivers() {
    if (!iconsLoaded.value) {
      return;
    }

    _driversSubscription?.cancel();
    _driversSubscription = FirebaseFirestore.instance
        .collection('drivers')
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
          if (currentPosition.value == null) {
            return;
          }

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

  void updateMapElements({
    List<LatLng>? routePoints,
    required String pickupAddress,
    required String destinationAddress,
  }) {
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
  final HttpsCallable _calculateFaresCallable = FirebaseFunctions.instance
      .httpsCallable('calculateFares');

  void listenToRideStatus(String rideId) {
    _rideStatusSubscription?.cancel();
    currentRideId.value = rideId;
    _rideStatusSubscription = FirebaseFirestore.instance
        .collection('ride_requests')
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

      // 2. Call Cloud Function with distance
      final result = await _calculateFaresCallable.call<Map<dynamic, dynamic>>({
        'distanceMeters': routeDetails.distanceMeters,
        'tollCost': routeDetails.tollCost,
        'pickupLocation': {
          'latitude': pickup.latitude,
          'longitude': pickup.longitude,
        },
      });

      final data = result.data;
      if (data['fares'] != null) {
        return Map<String, num>.from(data['fares']);
      }
      return null;
    } catch (e) {
      debugPrint("Error calculating fare: $e");
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

  Future<void> callDriver() async {
    if (currentRideId.value.isEmpty) {
      Get.snackbar("Error", "No active ride found.");
      return;
    }

    try {
      // Call the Cloud Function
      final result = await FirebaseFunctions.instance
          .httpsCallable('bridgeCall')
          .call({'rideId': currentRideId.value});

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
    try {
      final packages = await firestoreService.getRentalPackages();
      rentalPackages.assignAll(packages);
    } catch (e) {
      debugPrint("Error loading rental packages: $e");
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

  Future<void> addSearchToHistory(String description, String placeId) async {
    final updatedHistory = await storageService.addSearchToHistory(
      description,
      placeId,
      searchHistory,
    );
    searchHistory.assignAll(updatedHistory);
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
}
