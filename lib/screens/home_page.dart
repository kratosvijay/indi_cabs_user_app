// ignore_for_file: unused_field, unused_element

import 'dart:async';
import 'dart:math'; // For min/max used in bounds calculation

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart' hide Route;
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:flutter/foundation.dart'; // For defaultTargetPlatform
import 'package:flutter/gestures.dart'; // For gestureRecognizers
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project_taxi_with_ai/screens/about.dart';
import 'package:project_taxi_with_ai/widgets/liftable_banner_ad.dart';

// Import Models, Services, Widgets
import 'package:project_taxi_with_ai/screens/login_screen.dart';
import 'package:project_taxi_with_ai/controllers/ride_controller.dart';
import 'package:get/get.dart';

import 'package:project_taxi_with_ai/screens/multistop_ride.dart';
import 'package:project_taxi_with_ai/screens/ride_in_progress.dart';
import 'package:project_taxi_with_ai/screens/searching_for_ride.dart';
import 'package:project_taxi_with_ai/screens/book_for_other_screen.dart'; // **NEW IMPORT**
import 'package:project_taxi_with_ai/screens/notifications.dart';
import 'package:project_taxi_with_ai/screens/ride_history.dart';

import 'package:project_taxi_with_ai/google_sign_in.dart';
import 'package:project_taxi_with_ai/screens/support_hub.dart';
import 'package:project_taxi_with_ai/screens/wallet.dart';
import 'package:project_taxi_with_ai/widgets/bottom_bar.dart';
import 'package:project_taxi_with_ai/widgets/data_models.dart';

import 'package:project_taxi_with_ai/widgets/favorites.dart';

// Import Other Screens
import 'package:project_taxi_with_ai/screens/profile_page.dart';
import 'package:project_taxi_with_ai/screens/edit_location.dart';
import 'package:project_taxi_with_ai/screens/language_screen.dart';
import 'package:project_taxi_with_ai/widgets/location_service.dart';
import 'package:project_taxi_with_ai/widgets/map_service.dart';
import 'package:project_taxi_with_ai/widgets/rental_botomsheet.dart';
import 'package:project_taxi_with_ai/widgets/ride_confirm_sheet.dart';
import 'package:project_taxi_with_ai/widgets/search_bar.dart';
import 'package:project_taxi_with_ai/widgets/review_dialog.dart'; // **NEW IMPORT**
import 'package:project_taxi_with_ai/widgets/custom_showcase.dart';

import '../widgets/snackbar.dart';


// --- Main HomePage Widget ---
class HomePage extends StatefulWidget {
  final User user;
  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // --- Controllers & Keys ---

  // --- Controllers & Keys ---
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _pickupController = TextEditingController();
  final FocusNode _destinationFocusNode = FocusNode();
  final RideController _rideController = RideController.instance; // **NEW**

  // **MODIFIED:** Keys for the feature tour
  final GlobalKey _searchBarKey = GlobalKey();
  final GlobalKey _bottomBarKey = GlobalKey();
  final GlobalKey _walletKey = GlobalKey();

  final GlobalKey _walletShowcaseKey = GlobalKey();
  final GlobalKey _rideLaterShowcaseKey = GlobalKey();
  final GlobalKey _searchShowcaseKey = GlobalKey();
  bool _hasTriggeredOnboarding = false;

  // --- Services ---
  // --- Services ---
  // Services are now accessed via _rideController
  // late final LocationService _locationService;
  // late final PlacesService _placesService;
  // late final DirectionsService _directionsService;
  // late final FirestoreService _firestoreService;
  // late final StorageService _storageService;

  final HttpsCallable _calculateFaresCallable = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  ).httpsCallable('calculateFares');
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // --- State Variables ---
  late User _currentUser;
  // LatLng? _rideController.currentPosition.value; // REMOVED
  LatLng? _destinationPosition;
  bool _isDropoffInServiceArea = true;
  RideType _selectedServiceType = RideType.daily;
  bool _isMapReadyToRender = false; // **NEW:** Delay map rendering
  bool _isVehicleSheetOpen = false; // Track if vehicle sheet is visible
  bool _isProcessingSelection = false; // **NEW:** Prevent multiple rapid selections
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  final ValueNotifier<double> _sheetExtent = ValueNotifier<double>(0.4);

  // **NEW:** Reactive booking state
  final ValueNotifier<BookingState> _bookingState = ValueNotifier(
    BookingState(),
  );

  bool _wasKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;

    // Initialize Services - REMOVED (Handled in Splash/RideController)
    /*
    try {
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
      debugPrint("HomePage: Initializing services");
      _locationService = LocationService(apiKey: apiKey);
      _placesService = PlacesService(apiKey: apiKey);
      _directionsService = DirectionsService(apiKey: apiKey);
      _firestoreService = FirestoreService();
      _storageService = StorageService();
      debugPrint("HomePage: Services initialized successfully");
    } catch (e) {
      debugPrint("HomePage: Error initializing services: $e");
    }

    // Load Data - REMOVED (Handled in Splash/RideController)
    _loadSearchHistory().catchError((e) {
      debugPrint("HomePage: Error loading search history: $e");
    });
    _loadRentalPackages().catchError((e) {
      debugPrint("HomePage: Error loading rental packages: $e");
    });
    _loadPricingRules().catchError((e) {
      debugPrint("HomePage: Error loading pricing rules: $e");
    });
    */

    // **NEW:** Delay map rendering to prevent freeze on startup
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isMapReadyToRender = true;
        });
      }
    });

    // **NEW:** Check for notification permission prompt & reviews
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _checkNotificationPermission();
      _checkForPendingReviews();

      if (!_hasTriggeredOnboarding && mounted) {
        _hasTriggeredOnboarding = true;
        final prefs = await SharedPreferences.getInstance();
        final hasSeen = prefs.getBool('hasSeenAppOnboarding') ?? false;
        if (!hasSeen) {
          if (mounted) {
            ShowcaseView.get().startShowCase([
              _searchShowcaseKey
            ]);
          }
          await prefs.setBool('hasSeenAppOnboarding', true);
        }
      }
    });

    ShowcaseView.register(
      hideFloatingActionWidgetForShowcase: [],
      onFinish: () async {
        final prefs = await SharedPreferences.getInstance();
        final hasSeenWallet = prefs.getBool('hasSeenWalletTour') ?? false;
        if (!hasSeenWallet && mounted && _destinationPosition == null) {
          _scaffoldKey.currentState?.openDrawer();
          await prefs.setBool('hasSeenWalletTour', true);
        }
      },
    );


    // **NEW:** Sync pickup address from controller
    ever(_rideController.pickupAddress, (address) {
      if (mounted && _pickupController.text != address) {
        _pickupController.text = address;
      }
    });

    // **NEW:** Foreground FCM Listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("Foreground message received: ${message.messageId}");
      _saveNotificationToFirestore(message);

      // Show local notification/snackbar
      if (message.notification != null && mounted) {
        Get.snackbar(
          message.notification!.title ?? 'New Notification',
          message.notification!.body ?? '',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.white,
          colorText: Colors.black,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 4),
          boxShadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        );
      }
    });
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _destinationFocusNode.dispose();
    // _markersFocusNode.dispose();
    ShowcaseView.get().unregister();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rideController.updateMapStyle(Theme.of(context).brightness == Brightness.dark);
  }

  // **NEW:** Helper to save notification to Firestore
  Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .add({
              'title': message.notification?.title ?? 'New Notification',
              'body': message.notification?.body ?? '',
              'data': message.data,
              'timestamp': FieldValue.serverTimestamp(),
              'isRead': false,
            });
        debugPrint("Foreground message saved to Firestore");
      }
    } catch (e) {
      debugPrint("Error saving foreground message: $e");
    }
  }

  Future<void> _onSearchFocusChange() async {
    // Just trigger a rebuild when focus changes
    // The actual check is handled in _handleSearchBarTap before focusing
    if (mounted) setState(() {});
  }

  Future<void> _checkForPendingReviews() async {
    if (!mounted) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check ride requests
      final rideSnapshot = await FirebaseFirestore.instance
          .collection('ride_requests')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      for (var doc in rideSnapshot.docs) {
        final data = doc.data();
        if (data['status'] == 'completed' && data['reviewed'] != true) {
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => ReviewDialog(
                rideRequestId: doc.id,
                driverId: data['driverId'] ?? '',
                userId: user.uid,
                isRental: false,
              ),
            );
          }
          return; // Show one and exit
        }
      }

      // Check rental requests
      final rentalSnapshot = await FirebaseFirestore.instance
          .collection('rental_requests')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      for (var doc in rentalSnapshot.docs) {
        final data = doc.data();
        if (data['status'] == 'completed' && data['reviewed'] != true) {
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => ReviewDialog(
                rideRequestId: doc.id,
                driverId: data['driverId'] ?? '',
                userId: user.uid,
                isRental: true,
              ),
            );
          }
          return; // Show one and exit
        }
      }
    } catch (e) {
      debugPrint("Error checking for pending reviews: $e");
    }
  }

  /// Returns true if user can proceed with booking, false otherwise
  Future<bool> _checkAndShowActiveRideDialog() async {
    final activeRides = await _rideController.checkActiveRides();
    debugPrint("DEBUG: Check complete. Active rides: ${activeRides.length}");
    if (!mounted) return false;

    // Case 1: Max concurrent rides reached
    if (activeRides.length >= 2) {
      debugPrint("DEBUG: Max rides reached, showing snackbar");
      Get.snackbar(
        "Limit Reached",
        "Max concurrent rides reached (2). Please finish a ride first.",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return false;
    }

    // Case 2: One active ride - show dialog
    if (activeRides.length == 1) {
      debugPrint("DEBUG: 1 active ride found, showing dialog");
      final ride = activeRides[0];
      final rideData = ride['data'] as Map<String, dynamic>;
      final rideId = ride['id'];
      final isRental = ride['type'] == 'rental';
      final status = rideData['status'] ?? 'unknown';

      bool shouldProceed = false;

      try {
        await Get.dialog(
          AlertDialog(
            title: const Text("Active Ride Found"),
            content: const Text(
              "You have already booked a ride. Do you want to open the ongoing ride?",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  debugPrint("DEBUG: User selected 'No'");
                  Get.back(result: false);
                },
                child: const Text("No"),
              ),
              TextButton(
                onPressed: () {
                  debugPrint("DEBUG: User selected 'Book Another Ride'");
                  shouldProceed = true;
                  Get.back(result: true);
                },
                child: const Text("Book Another Ride"),
              ),
              TextButton(
                onPressed: () {
                  debugPrint("DEBUG: User selected 'Yes, Open Ride'");
                  Get.back(result: false);
                  _navigateToRide(rideId, rideData, isRental, status);
                },
                child: const Text("Yes, Open Ride"),
              ),
            ],
          ),
          barrierDismissible: false,
        );
        debugPrint("DEBUG: Dialog closed. ShouldProceed: $shouldProceed");
      } catch (e) {
        debugPrint("DEBUG: Error showing dialog: $e");
        return false;
      }

      return shouldProceed;
    }

    // Case 3: No active rides
    debugPrint("DEBUG: No active rides, proceed");
    return true;
  }

  void _navigateToRide(
    String rideId,
    Map<String, dynamic> rideData,
    bool isRental,
    String status,
  ) {
    try {
      final pickupMap = rideData['pickupLocation'];
      final pickup = LatLng(pickupMap['latitude'], pickupMap['longitude']);

      // Handle missing dropoff for rentals or undefined
      LatLng dropoff = const LatLng(0, 0);
      if (rideData['dropoffLocation'] != null) {
        final dMap = rideData['dropoffLocation'];
        dropoff = LatLng(dMap['latitude'], dMap['longitude']);
      }

      final fare = (rideData['fare'] as num?)?.toDouble() ?? 0.0;
      final vehicleType = rideData['vehicleType'] ?? '';

      // Determine screen based on status
      if (['searching', 'scheduled'].contains(status)) {
        Get.to(
          () => SearchingForRideScreen(
            user: _currentUser,
            pickupLocation: pickup,
            destinationPosition:
                dropoff, // Might be 0,0 for rental without dest
            fare: fare,
            tip: 0.0,
            polylines: const {}, // Empty is fine
            isRental: isRental,
            rideRequestId: rideId,
            destinationAddress:
                rideData['dropoffAddress'] ?? (isRental ? 'Rental Ride' : ''),
            initialEta: "Calculating...",
          ),
        );
      } else {
        // Accepted/In Progress
        final driverId = rideData['driverId'] ?? '';
        Get.to(
          () => RideInProgressScreen(
            user: _currentUser,
            pickupLocation: pickup,
            destinationPosition: dropoff,
            selectedVehicleType: vehicleType,
            isRental: isRental,
            rideRequestId: rideId,
            driverId: driverId,
            rentalPackage:
                null, // Hard to reconstruct fully without query, maybe optional?
            // intermediateStops: ...
          ),
        );
      }
    } catch (e) {
      debugPrint("Error navigating to ride: $e");
      Get.snackbar("Error", "Could not open ride details.");
    }
  }

  // --- Search & Selection Callbacks ---

  void _handleSearchChanged(String query) {
    if (!mounted) return;
    if (_selectedServiceType != RideType.daily &&
        _selectedServiceType != RideType.acting) {
      return;
    }
    _rideController.placesService.fetchAutocompleteDebounced(
      query,
      _rideController.currentPosition.value,
      (results) {
        if (mounted) {
          setState(() => _rideController.predictions.assignAll(results));
        }
      },
    );
  }

  void _handleClearSearch() {
    if (!mounted) return;
    _destinationController.clear();
    _rideController.placesService.cancelDebounce();
    setState(() {
      _rideController.predictions.clear();
    });
    _handleSearchChanged('');
  }

  Future<void> _handlePredictionTap(String placeId) async {
    try {
      if (!mounted) return;
      final placeDetails = await _rideController.placesService.getPlaceDetails(
        placeId,
      );
      if (!mounted) return;

      if (placeDetails == null) {
        displaySnackBar(context, "Could not get location details.");
        return;
      }
      await _handlePlaceSelection(placeDetails);
    } catch (e) {
      debugPrint("Error in _handlePredictionTap: $e");
    }
  }

  void _handleHistoryTap(SearchHistoryItem item) {
    if (!mounted) return;
    if (item.placeId.isNotEmpty) {
      _handlePredictionTap(item.placeId);
    } else {
      setState(() {
        _destinationController.text = item.description;
        _rideController.predictions.clear();
      });
      FocusScope.of(context).unfocus();
      displaySnackBar(
        context,
        "Select location on map or search again to confirm route for '${item.description}'.",
      );
    }
  }

  Future<void> _handleSelectOnMap() async {
    final initialPos =
        _rideController.currentPosition.value ?? const LatLng(13.0827, 80.2707);

    FocusScope.of(context).unfocus();
    await SystemChannels.textInput.invokeMethod('TextInput.hide');
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;
    final result = await Get.to<Map<String, dynamic>>(
      () => EditLocationScreen(initialLocation: initialPos),
    );

    if (result != null && mounted) {
      final selectedLatLng = result['location'] as LatLng;
      final selectedAddress = result['address'] as String;

      _handlePlaceSelection(
        PlaceDetails(
          placeId: '',
          name: 'Selected on Map',
          address: selectedAddress,
          location: selectedLatLng,
        ),
        displayOverrideName: selectedAddress,
      );
    }
  }

  Future<void> _handlePickupLocationTap() async {
    final initialPos =
        _rideController.currentPosition.value ?? const LatLng(13.0827, 80.2707);

    FocusScope.of(context).unfocus();
    await SystemChannels.textInput.invokeMethod('TextInput.hide');
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;
    final result = await Get.to<Map<String, dynamic>>(
      () => EditLocationScreen(initialLocation: initialPos),
    );

    if (result != null && mounted) {
      final selectedLatLng = result['location'] as LatLng;
      final selectedAddress = result['address'] as String;

      _pickupController.text = selectedAddress;
      _rideController.pickupAddress.value = selectedAddress;
      _rideController.currentPosition.value = selectedLatLng;

      // Update map if destination is already selected
      if (_destinationPosition != null) {
        _calculateFaresAndRoute();
      } else {
        final controller = _rideController.mapController.value;
        if (controller != null) {
          controller.animateCamera(
            CameraUpdate.newLatLngZoom(selectedLatLng, 15),
          );
        }
      }
    }
  }

  Future<void> _handlePlaceSelection(
    PlaceDetails placeDetails, {
    String? displayOverrideName,
  }) async {
    if (_isProcessingSelection) return;
    setState(() => _isProcessingSelection = true);

    try {
      if (!mounted) return;

      // **NEW:** Check Wallet Balance Before Proceeding
      if (_rideController.walletBalance.value < -50) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Low Wallet Balance"),
            content: const Text(
              "Your wallet balance is in negative. You cannot book a ride until you make it positive. Please recharge your wallet to book a ride.",
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () {
                  Get.back(); // Close dialog
                  Get.to(() => WalletScreen(user: widget.user));
                },
                child: const Text("Recharge"),
              ),
            ],
          ),
        );
        return;
      }

      FocusScope.of(context).unfocus();
      // Explicitly hide keyboard to be sure
      await SystemChannels.textInput.invokeMethod('TextInput.hide');

      if (!mounted) return; // **FIX:** Check mounted after async gap

      // **OPTIMIZATION:** Only wait if keyboard was likely open
      if (MediaQuery.of(context).viewInsets.bottom > 0) {
        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (!mounted) return;

      _isDropoffInServiceArea = _rideController.locationService
          .isPointInServiceArea(placeDetails.location);

      if (placeDetails.placeId.isNotEmpty) {
        _addSearchToHistory(
          description: displayOverrideName ?? placeDetails.address,
          placeId: placeDetails.placeId,
          mainText: placeDetails.name,
          secondaryText: placeDetails.address,
        );
      }

      setState(() {
        _destinationPosition = placeDetails.location;
        _destinationController.text = displayOverrideName ?? placeDetails.address;
        _rideController.predictions.clear();
        _rideController.isCalculatingFares.value = true;
      });

      _rideController.updateMapElements(
        pickupAddress: _pickupController.text,
        pickupPlaceName: _rideController.pickupPlaceName.value, // **NEW**
        destinationAddress: _destinationController.text,
        destinationPlaceName: placeDetails.name, // **NEW**
      );

      // **MODIFIED:** Create a dummy "all available" map to bypass the check
      final Map<String, bool> availability = {
        'Auto': true,
        'Hatchback': true,
        'Sedan': true,
        'SUV': true,
        'ActingDriver': true,
      };

      // Show loading sheet immediately with ValueListenableBuilder
      _showRideConfirmationSheet(
        _isDropoffInServiceArea,
        // isLoadingFares: true, // Removed
        walletBalance: _rideController.walletBalance.value,
        rideType: _selectedServiceType,
        availability: availability,
      );

      // --- Start background calculation ---
      _calculateFaresAndRoute();
    } catch (e) {
      debugPrint("Error in _handlePlaceSelection: $e");
    } finally {
      if (mounted) setState(() => _isProcessingSelection = false);
    }
  }

  // **NEW:** Separated logic for calculation
  Future<void> _calculateFaresAndRoute() async {
    _bookingState.value = _bookingState.value.copyWith(
      isLoading: true,
      fares: null,
    );

    RouteDetails? routeDetails;
    Map<String, num>? calculatedFares;
    num appliedSurcharge = 0;

    if (_rideController.currentPosition.value != null &&
        _destinationPosition != null) {
      if (_isDropoffInServiceArea) {
        routeDetails = await _rideController.directionsService.getDirections(
          _rideController.currentPosition.value!,
          _destinationPosition!,
        );

        if (routeDetails != null) {
          // Update route immediately
          _bookingState.value = _bookingState.value.copyWith(
            route: routeDetails,
          );

          final calculationResult = await _calculateFares(
            distanceMeters: routeDetails.distanceMeters,
            durationSeconds: routeDetails.durationSeconds,
            tollCost: routeDetails.tollCost,
            pickupLocation: _rideController.currentPosition.value!,
            destinationLocation: _destinationPosition,
            routePolyline: routeDetails.polylinePoints,
          );

          if (calculationResult != null) {
            calculatedFares = calculationResult.fares;
            appliedSurcharge = calculationResult.appliedSurcharge;

            // Update route details with the newly calculated surcharge/toll
            routeDetails = routeDetails.copyWith(tollCost: appliedSurcharge);
          }
        } else {
          if (mounted) displaySnackBar(context, "Could not get route details.");
          _bookingState.value = _bookingState.value.copyWith(isLoading: false);
          // Allow sheet to remain nicely or close? For now, just stop loading.
          return;
        }
      } else {
        if (mounted) {
          displaySnackBar(
            context,
            "Drop-off location is outside the service area.",
          );
        }
        _bookingState.value = _bookingState.value.copyWith(isLoading: false);
        return;
      }

      // **FIX:** Check if still mounted and positions are valid before updating map
      if (!mounted ||
          _destinationPosition == null ||
          _rideController.currentPosition.value == null) {
        return;
      }

      // Update Map
      _rideController.updateMapElements(
        pickupAddress: _pickupController.text,
        pickupPlaceName: _rideController.pickupPlaceName.value,
        destinationAddress: _destinationController.text,
        destinationPlaceName: _rideController.destinationPlaceName.value,
        routePoints: routeDetails.polylinePoints,
      );
      _rideController.mapService.animateCameraToBounds(
        LatLngBounds(
          southwest: LatLng(
            min(
              _rideController.currentPosition.value!.latitude,
              _destinationPosition!.latitude,
            ),
            min(
              _rideController.currentPosition.value!.longitude,
              _destinationPosition!.longitude,
            ),
          ),
          northeast: LatLng(
            max(
              _rideController.currentPosition.value!.latitude,
              _destinationPosition!.latitude,
            ),
            max(
              _rideController.currentPosition.value!.longitude,
              _destinationPosition!.longitude,
            ),
          ),
        ),
      );

      // Update State with Fares
      _bookingState.value = _bookingState.value.copyWith(
        isLoading: false,
        fares: calculatedFares,
        route: routeDetails,
      );

      // **NEW:** Show toll warning if applicable
      if (routeDetails.tollCost > 0 && mounted) {
        displaySnackBar(
          context,
          "Note: Toll of ₹${routeDetails.tollCost.toStringAsFixed(0)} will only be added to your bill if the toll plaza is crossed.",
          isError: false,
        );
      }
    }
  }

  /*
    // --- Start background tasks: Get Route and Calculate Fares ---
    RouteDetails? routeDetails;
    Map<String, num>? calculatedFares;

    if (_rideController.currentPosition.value != null) {
      if (_isDropoffInServiceArea) {
        routeDetails = await _rideController.directionsService.getDirections(
          _rideController.currentPosition.value!,
          _destinationPosition!,
        );

        if (routeDetails != null) {
          final calculationResult = await _calculateFares(
            distanceMeters: routeDetails.distanceMeters,
            durationSeconds: routeDetails.durationSeconds,
            tollCost: routeDetails.tollCost,
            pickupLocation: _rideController.currentPosition.value!,
          );
          
          if (calculationResult != null) {
            calculatedFares = calculationResult.fares;
            appliedSurcharge = calculationResult.appliedSurcharge;
            
            // Update route details with the newly calculated surcharge/toll
            routeDetails = routeDetails.copyWith(
              tollCost: appliedSurcharge,
            );
          }
        } else {
          if (mounted) displaySnackBar(context, "Could not get route details.");
        }
      } else {
        if (mounted) {
          displaySnackBar(
            context,
            "Drop-off location is outside the service area.",
          );
        }
      }

      // **FIX:** Check if still mounted and positions are valid before updating map
      if (!mounted ||
          _destinationPosition == null ||
          _rideController.currentPosition.value == null) {
        return;
      }

      _rideController.updateMapElements(
        pickupAddress: _pickupController.text,
        destinationAddress: _destinationController.text,
        routePoints: routeDetails?.polylinePoints,
      );
      _rideController.mapService.animateCameraToBounds(
        LatLngBounds(
          southwest: LatLng(
            min(
              _rideController.currentPosition.value!.latitude,
              _destinationPosition!.latitude,
            ),
            min(
              _rideController.currentPosition.value!.longitude,
              _destinationPosition!.longitude,
            ),
          ),
          northeast: LatLng(
            max(
              _rideController.currentPosition.value!.latitude,
              _destinationPosition!.latitude,
            ),
            max(
              _rideController.currentPosition.value!.longitude,
              _destinationPosition!.longitude,
            ),
          ),
        ),
      );
    }

    if (mounted) {
      Get.back(); // Close the loading sheet

      // Ensure focus is cleared again as closing the sheet might restore it
      _destinationFocusNode.unfocus(); // Explicitly unfocus the node
      FocusScope.of(context).unfocus();
      await SystemChannels.textInput.invokeMethod('TextInput.hide');
      await Future.delayed(const Duration(milliseconds: 300));

      final prefs = await SharedPreferences.getInstance();
      final bool hasSeenScheduleTour =
          prefs.getBool(kHasSeenScheduleTour) ?? false;

      await _showRideConfirmationSheet(
        _isDropoffInServiceArea,
        isLoadingFares: false,
        calculatedFares: calculatedFares,
        routeDetails: routeDetails,
        pricingRules: _rideController.pricingRules.value,
        walletBalance: _rideController.walletBalance.value,
        rideType: _selectedServiceType,
        availability: availability,
        showScheduleTour: !hasSeenScheduleTour,
      );

      if (mounted) {
        _resetMapAndSearch();
      }
    }

    if (mounted) {
      setState(() => _rideController.isCalculatingFares.value = false);
    }
  }
  */

  Future<void> _handlePredefinedTap(PredefinedDestination destination) async {
    try {
      if (!mounted) return;

      // Check for active rides before allowing destination selection
      final shouldProceed = await _checkAndShowActiveRideDialog();
      if (!shouldProceed || !mounted) return;

      await _handlePlaceSelection(
        PlaceDetails(
          placeId: '',
          name: destination.name,
          address: destination.name,
          location: destination.location,
        ),
      );
    } catch (e) {
      debugPrint("Error in _handlePredefinedTap: $e");
    }
  }

  Future<void> _handleFavoriteTap(FavoritePlace favorite) async {
    try {
      if (!mounted) return;

      // Check for active rides before allowing destination selection
      final shouldProceed = await _checkAndShowActiveRideDialog();
      if (!shouldProceed || !mounted) return;

      await _handlePlaceSelection(
        PlaceDetails(
          placeId: '',
          name: favorite.name,
          address: favorite.address,
          location: favorite.location,
        ),
        displayOverrideName: favorite.name,
      );
    } catch (e) {
      debugPrint("Error in _handleFavoriteTap: $e");
    }
  }

  Future<void> _handleHistoryFavoriteToggle(
    SearchHistoryItem item,
    bool isFavorite,
  ) async {
    if (isFavorite) {
      // Find the favorite and delete it
      try {
        final favorite = _rideController.favoritePlaces.firstWhere(
          (fav) =>
              fav.address == item.description || fav.name == item.description,
        );
        await _deleteFavoritePlace(favorite);
      } catch (e) {
        debugPrint('Could not find favorite to delete: $e');
      }
    } else {
      // Ask user for a name
      final name = await _showSaveFavoriteNameDialog();
      if (name != null && name.trim().isNotEmpty && mounted) {
        // Fetch LatLng before saving
        final placeDetails = await _rideController.placesService
            .getPlaceDetails(item.placeId);
        if (placeDetails == null) {
          if (mounted) {
            displaySnackBar(
              context,
              "Could not get location details to save favorite.",
            );
          }
          return;
        }
        // Save favorite
        await _saveFavoritePlace(
          name.trim(),
          placeDetails.location,
          item.description,
        );
      }
    }
  }

  // --- Service Type Selection ---
  Future<void> _handleServiceTypeSelected(RideType rideType) async {
    if (!mounted) return;

    if (rideType == _selectedServiceType) {
      if (rideType == RideType.daily && !_destinationFocusNode.hasFocus) {
         _destinationFocusNode.requestFocus();
      }
      return;
    }

    setState(() {
      _selectedServiceType = rideType;
    });

    FocusScope.of(context).unfocus();

    // Allow animation to start/complete partially before transition
    await Future.delayed(const Duration(milliseconds: 180));

    if (rideType == RideType.rental) {
      await _showRentalBottomSheet();
    } else if (rideType == RideType.acting) {
      await _showRentalBottomSheet(isActingDriver: true);
    } else if (rideType == RideType.bookForOther) {
      await Get.to(
        () => BookForOtherScreen(
          user: _currentUser,
          currentPosition:
              _rideController.currentPosition.value ??
              LocationService.defaultLocation,
          pricingRules: _rideController.pricingRules.value,
          walletBalance: _rideController.walletBalance.value,
        ),
      );
    } else if (rideType == RideType.multiStop) {
      await Get.to(
        () => MultiStopScreen(
          user: _currentUser,
          currentPosition:
              _rideController.currentPosition.value ??
              LocationService.defaultLocation,
          pricingRules: _rideController.pricingRules.value,
          walletBalance: _rideController.walletBalance.value,
        ),
      );
    }

    // Reset to daily after returning from any other mode
    if (mounted) {
      setState(() {
        _selectedServiceType = RideType.daily;
      });
    }
  }

  // --- Cloud Function Call ---
  Future<({Map<String, num> fares, num appliedSurcharge})?> _calculateFares({
    required int distanceMeters,
    required int durationSeconds,
    required num tollCost,
    required LatLng pickupLocation,
    LatLng? destinationLocation,
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
        '--- _calculateFares DEBUG (home_page) ---\n'
        'fares: $fares\n'
        'appliedSurcharge: $appliedSurcharge\n'
        'appliedToll: $appliedToll\n'
        'totalExtras: $totalExtras\n'
        '-----------------------------------------',
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

  // --- Bottom Sheet Triggers ---
  void _showRideConfirmationSheet(
    bool isDropoffInServiceArea, {
    required num walletBalance,
    required RideType rideType,
    Map<String, bool> availability = const {},
  }) {
    final currentPos = _rideController.currentPosition.value;
    final destPos = _destinationPosition;

    if (!mounted || currentPos == null || destPos == null) return;

    // Open the inline vehicle sheet — map will shrink via AnimatedPositioned
    setState(() {
      _isVehicleSheetOpen = true;
      _sheetExtent.value = 0.4; // Reverted from 0.72
    });

    // After map shrink animation completes, re-animate camera to fit route
    _animateCameraToRoute();
  }

  void _animateCameraToRoute() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _rideController.currentPosition.value != null && _destinationPosition != null) {
        _rideController.mapService.animateCameraToBounds(
          _rideController.mapService.calculateBounds(
            _rideController.currentPosition.value!,
            _destinationPosition!,
          ),
          padding: 20.0,
        );
      }
    });
  }



  void _dismissVehicleSheet() {
    if (!mounted) return;
    setState(() {
      _isVehicleSheetOpen = false;
      _sheetExtent.value = 0.0;
    });
    _resetMapAndSearch();
    _rideController.isCalculatingFares.value = false;
  }

  // Builds the inline vehicle selection sheet content


  Future<void> _showRentalBottomSheet({bool isActingDriver = false}) {
    final currentPos = _rideController.currentPosition.value;
    if (!mounted || currentPos == null) {
      displaySnackBar(
        context,
        "Cannot determine current location for rental pickup.",
      );
      return Future.value();
    }
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Obx(() => RentalBottomSheet(
        rentalPackages: _rideController.rentalPackages,
        isLoadingRentals: _rideController.isLoadingRentals.value,
        rentalVehicleOptions: VehicleOption.rentalOptions,
        currentUser: _currentUser,
        currentPosition: currentPos,
        isActingDriver: isActingDriver,
        pricingRules: _rideController.pricingRules.value,
        walletBalance: _rideController.walletBalance.value,
        pickupPlaceName: _rideController.pickupPlaceName.value,
      )),
    );
  }

  // --- Edit Location ---
  Future<void> _handleEditLocation(
    LatLng initialLocation, {
    required bool isPickup,
  }) async {
    _dismissVehicleSheet(); // Close the inline vehicle sheet if open


    final result = await Get.to<Map<String, dynamic>>(
      () => EditLocationScreen(initialLocation: initialLocation),
    );

    if (result == null || !mounted) return;

    final newLocation = result['location'] as LatLng?;
    final newAddress = result['address'] as String?;

    if (newLocation != null && newAddress != null) {
      // Removed fragile areLocationsClose check

      if (isPickup) {
        setState(() {
          _pickupController.text = newAddress;
          _rideController.pickupAddress.value = newAddress;
        });
        await _rideController.updateCurrentPosition(
          newLocation,
          animateMap: true,
        );
      } else {
        setState(() {
          _destinationPosition = newLocation;
          _destinationController.text = newAddress;
        });
        _rideController.updateMapElements(
          pickupAddress: _pickupController.text,
          pickupPlaceName: _rideController.pickupPlaceName.value,
          destinationAddress: _destinationController.text,
          destinationPlaceName: _rideController.destinationPlaceName.value,
        );
        if (_rideController.currentPosition.value != null) {
          _rideController.mapService.animateCameraToBounds(
            LatLngBounds(
              southwest: LatLng(
                min(
                  _rideController.currentPosition.value!.latitude,
                  newLocation.latitude,
                ),
                min(
                  _rideController.currentPosition.value!.longitude,
                  newLocation.longitude,
                ),
              ),
              northeast: LatLng(
                max(
                  _rideController.currentPosition.value!.latitude,
                  newLocation.latitude,
                ),
                max(
                  _rideController.currentPosition.value!.longitude,
                  newLocation.longitude,
                ),
              ),
            ),
          );
        }
      }

      // **MODIFIED:** If destination is already set, recalculate instead of reset
      if (_destinationPosition != null) {
        // Trigger recalculation with existing destination
        await _handlePlaceSelection(
          PlaceDetails(
            placeId: '', // Not needed for recalculation
            name: _destinationController.text,
            address: _destinationController.text,
            location: _destinationPosition!,
          ),
          displayOverrideName: _destinationController.text,
        );
      } else {
        // Only reset if no destination was selected (e.g. just editing pickup on empty map)
        _resetMapAndSearch();
      }

      if (mounted) {
        displaySnackBar(context, "Location updated.");
      }
    }
  }

  // --- Data Loading ---
  // --- Data Loading Helpers (Now delegated to RideController, keeping wrappers if needed or removing) ---
  /*
  Future<void> _loadSearchHistory() async {
    final history = await _storageService.loadSearchHistory();
    if (mounted) {
      setState(() => _rideController.searchHistory.assignAll(history));
    }
  }
  */

  Future<void> _addSearchToHistory({
    required String description,
    required String placeId,
    required String mainText,
    required String secondaryText,
  }) async {
    // Delegated to RideController
    await _rideController.addSearchToHistory(
      description: description,
      placeId: placeId,
      mainText: mainText,
      secondaryText: secondaryText,
    );
  }

  /*
  Future<void> _loadRentalPackages() async {
    if (!mounted) return;
    setState(() => _rideController.isLoadingRentals.value = true);
    try {
      final packages = await _firestoreService.getRentalPackages();
      if (mounted) {
        setState(() => _rideController.rentalPackages.assignAll(packages));
      }
    } catch (e) {
      debugPrint("Error loading rental packages: $e");
      if (mounted) displaySnackBar(context, "Could not load rental options.");
    } finally {
      if (mounted) {
        setState(() => _rideController.isLoadingRentals.value = false);
      }
    }
  }

  Future<void> _loadPricingRules() async {
    try {
      final rules = await _firestoreService.getPricingRules(
        "Chennai",
      ); // Assumes "Chennai"
      if (mounted) {
        setState(() => _rideController.pricingRules.value = rules);
      }
    } catch (e) {
      debugPrint("Error loading pricing rules: $e");
    }
  }
  */

  // --- Other Actions ---
  void _resetMapAndSearch() {
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    _destinationController.clear();
    _rideController.placesService.cancelDebounce();
    setState(() {
      _destinationPosition = null;
      _rideController.polylines.clear();
      _rideController.markers.removeWhere(
        (m) => m.markerId.value == 'destination',
      );
      _rideController.predictions.clear();
      _isDropoffInServiceArea = true;
      _selectedServiceType = RideType.daily;
    });
    if (_rideController.currentPosition.value != null) {
      _rideController.mapService.animateCamera(
        _rideController.currentPosition.value!,
      );
    }
  }

  Future<void> _signOut() async {
    try {
      await GoogleSignInService.signOut();
    } catch (e) {
      debugPrint("Error signing out: $e");
    }
    if (mounted) {
      Get.offAll(() => const SignInScreen());
    }
  }

  // --- Main Build Method ---
  Future<void> _checkNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) {
        Get.dialog(
          AlertDialog(
            title: const Text("Enable Notifications"),
            content: const Text(
              "We need notification permissions to keep you updated on your ride status and driver arrival.",
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text("Not Now"),
              ),
              TextButton(
                onPressed: () async {
                  Get.back();
                  if (status.isPermanentlyDenied) {
                    openAppSettings();
                  } else {
                    await Permission.notification.request();
                  }
                },
                child: const Text("Enable"),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // **NEW:** Automatically dismiss search bar if keyboard closes (e.g., system swipe)
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    if (_wasKeyboardVisible && !isKeyboardVisible && _destinationFocusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _destinationFocusNode.hasFocus) {
          _destinationFocusNode.unfocus();
        }
      });
    }
    _wasKeyboardVisible = isKeyboardVisible;

    final double statusBarHeight = MediaQuery.of(context).padding.top;
    double mapBottomPadding = (_destinationPosition == null)
        ? (_selectedServiceType == RideType.daily ||
                  _selectedServiceType == RideType.acting
              ? MediaQuery.of(context).size.height * 0.40
              : 140)
        : MediaQuery.of(context).size.height * 0.45;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final systemOverlayStyle = isDark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayStyle,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_isVehicleSheetOpen) {
            _dismissVehicleSheet();
          } else if (_destinationFocusNode.hasFocus) {
            FocusScope.of(context).unfocus();
          } else if (_rideController.predictions.isNotEmpty) {
            setState(() {
              _rideController.predictions.clear();
            });
          } else {
            _showExitConfirmationDialog();
          }
        },
        child: Scaffold(
              key: _scaffoldKey,
            onDrawerChanged: (isOpen) async {
              setState(() {}); // **NEW:** Ensure SearchBarWidget updates its enabled state
              if (isOpen && mounted) {
                final prefs = await SharedPreferences.getInstance();
                final hasSeen = prefs.getBool('hasSeenWalletTour') ?? false;
                if (!hasSeen) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ShowcaseView.get().startShowCase([_walletShowcaseKey]);
                  });
                  await prefs.setBool('hasSeenWalletTour', true);
                }
              }
            },
            drawerEnableOpenDragGesture: false, // **NEW:** Only open drawer via button
        resizeToAvoidBottomInset: false, // Prevents MapView stutter during keyboard animation
        // AppBar removed — hamburger + notification are now floating over the map
        drawer: Builder(builder: (context) => _buildDrawer()),
        body: Obx(() {
          return _rideController.isLoadingLocation.value
              ? const Center(child: CircularProgressIndicator())
              : GestureDetector(
                  onTap: () {
                    if (_destinationFocusNode.hasFocus) {
                      FocusScope.of(context).unfocus();
                      SystemChannels.textInput.invokeMethod('TextInput.hide');
                    }
                  },
                  child: SizedBox.expand(
                    child: Stack(
                      children: [
                        // Google Map
                        if (_isMapReadyToRender)
                          ValueListenableBuilder<double>(
                            valueListenable: _sheetExtent,
                            builder: (context, extent, child) {
                              final double currentBottom = _isVehicleSheetOpen 
                                  ? MediaQuery.of(context).size.height * extent 
                                  : 0;
                              // Map scales down slightly as sheet expands (Swiggy effect)
                              final double scale = _isVehicleSheetOpen ? (1.0 + ((extent - 0.4).clamp(0, 1.0) * 0.3)) : 1.0;
                              
                              return AnimatedPositioned(
                                duration: const Duration(milliseconds: 50),
                                curve: Curves.easeOut,
                                top: 0,
                                left: 0,
                                right: 0,
                                bottom: currentBottom,
                                child: Transform.scale(
                                  scale: scale,
                                  alignment: Alignment.topCenter,
                                  child: ClipRRect(
                                    borderRadius: _isVehicleSheetOpen
                                        ? const BorderRadius.only(
                                            bottomLeft: Radius.circular(20),
                                            bottomRight: Radius.circular(20),
                                          )
                                        : BorderRadius.zero,
                                    child: GoogleMap(
                                      initialCameraPosition: MapService.initialPosition,
                                      mapType: MapType.normal,
                                      style: _rideController.mapStyleJson.value,
                                      myLocationEnabled: false,
                                      myLocationButtonEnabled: false,
                                      zoomControlsEnabled: false,
                                      markers: _rideController.markers.union(
                                        _rideController.driverMarkers,
                                      ),
                                      polylines: _rideController.polylines,
                                      onTap: (_) => FocusScope.of(context).unfocus(),
                                      onMapCreated: (controller) {
                                        debugPrint("!!! MAP CREATED CALLBACK FIRED !!!");
                                        _rideController.onMapCreated(controller);
                                      },
                                      padding: EdgeInsets.only(
                                        bottom: _isVehicleSheetOpen ? 10 : mapBottomPadding,
                                        top: statusBarHeight + 80,
                                      ),
                                      gestureRecognizers:
                                          <Factory<OneSequenceGestureRecognizer>>{
                                            Factory<OneSequenceGestureRecognizer>(
                                              () => EagerGestureRecognizer(),
                                            ),
                                            Factory<PanGestureRecognizer>(
                                              () => PanGestureRecognizer(),
                                            ),
                                            Factory<ScaleGestureRecognizer>(
                                              () => ScaleGestureRecognizer(),
                                            ),
                                            Factory<TapGestureRecognizer>(
                                              () => TapGestureRecognizer(),
                                            ),
                                            Factory<VerticalDragGestureRecognizer>(
                                              () => VerticalDragGestureRecognizer(),
                                            ),
                                          },
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                        else
                          const Center(child: CircularProgressIndicator()),
                        // Custom GPS Button
                        Positioned(
                          bottom: mapBottomPadding + 60,
                          right: 16,
                          child: IgnorePointer(
                            ignoring: _destinationFocusNode.hasFocus,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: _destinationFocusNode.hasFocus
                                  ? 0.0
                                  : 1.0,
                              child: Visibility(
                                visible: _destinationPosition == null,
                                child: FloatingActionButton(
                                  heroTag: 'gpsButton',
                                  onPressed:
                                      _rideController.goToCurrentUserLocation,
                                  backgroundColor:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[800]
                                      : Colors.white,
                                  elevation: 4,
                                  child: Icon(
                                    Icons.gps_fixed,
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Colors.blueAccent,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Bottom Bar
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IgnorePointer(
                                ignoring: _destinationFocusNode.hasFocus,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: _destinationFocusNode.hasFocus
                                      ? 0.0
                                      : 1.0,
                                  child: Visibility(
                                    visible: _destinationPosition == null,
                                    replacement: Container(),
                                    child: BottomBarWidget(
                                      key: _bottomBarKey,
                                      selectedServiceType: _selectedServiceType,
                                      onServiceTypeSelected:
                                          _handleServiceTypeSelected,
                                      onPredefinedDestinationTap:
                                          _handlePredefinedTap,
                                    ),
                                  ),
                                ),
                              ),
                              const LiftableBannerAd(),
                            ],
                          ),
                        ),
                        // Floating top row: Menu + Search + Notification
                        Positioned(
                          top: statusBarHeight + 10,
                          left: 12,
                          right: 12,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Unified Search Bar with integrated Menu
                              Expanded(
                                child: CustomShowcase(
                                  showcaseKey: _searchShowcaseKey,
                                  title: 'whereTo'.tr,
                                  description:
                                      'enterPickupDrop'.tr,
                                  isLastStep: true,
                                  targetShapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                  child: Obx(
                                    () => SearchBarWidget(
                                      key: _searchBarKey,
                                      isDrawerOpen: _scaffoldKey.currentState?.isDrawerOpen ?? false,
                                      destinationController: _destinationController,
                                      destinationFocusNode: _destinationFocusNode,
                                      isSearchEnabled:
                                          _selectedServiceType == RideType.daily ||
                                          _selectedServiceType == RideType.acting,
                                      isDestinationSelected: _destinationPosition != null,
                                      predictions: _rideController.predictions.toList(),
                                      searchHistory: _rideController.searchHistory.toList(),
                                      favoritePlaces: _rideController.favoritePlaces.toList(),
                                      pickupAddress: _rideController.pickupAddress.value,
                                      onPickupTap: _handlePickupLocationTap,
                                      onSearchChanged: _handleSearchChanged,
                                      onPredictionTap: _handlePredictionTap,
                                      onHistoryTap: _handleHistoryTap,
                                      onFocusChange: (hasFocus) {
                                        setState(() {});
                                      },
                                      onClearSearch: _handleClearSearch,
                                      onFavoriteToggle: _handleHistoryFavoriteToggle,
                                      onSelectOnMap: _handleSelectOnMap,
                                      onMenuTap: () {
                                        FocusScope.of(context).unfocus();
                                        FocusManager.instance.primaryFocus?.unfocus();
                                        SystemChannels.textInput.invokeMethod('TextInput.hide');
                                        _scaffoldKey.currentState?.openDrawer();
                                        setState(() {}); // **NEW:** Force update to disable search bar
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Favorites List
                        Positioned(
                          top: statusBarHeight + 75,
                          left: 16,
                          right: 16,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity:
                                !_destinationFocusNode.hasFocus &&
                                    _destinationPosition == null &&
                                    (_selectedServiceType == RideType.daily ||
                                        _selectedServiceType ==
                                            RideType.acting ||
                                        _selectedServiceType ==
                                            RideType.bookForOther ||
                                        _selectedServiceType ==
                                            RideType.multiStop)
                                ? 1.0
                                : 0.0,
                            child: IgnorePointer(
                              ignoring:
                                  _destinationFocusNode.hasFocus ||
                                  _destinationPosition != null ||
                                  (_selectedServiceType != RideType.daily &&
                                      _selectedServiceType != RideType.acting &&
                                      _selectedServiceType !=
                                          RideType.bookForOther &&
                                      _selectedServiceType !=
                                          RideType.multiStop),
                              child: FavoritesWidget(
                                userId: _currentUser.uid,
                                firestoreService:
                                    _rideController.firestoreService,
                                onFavoriteTap: _handleFavoriteTap,
                                onFavoriteLongPress: _showFavoriteOptions,
                              ),
                            ),
                          ),
                        ),
                        // Swiggy Style Draggable Sheet
                        if (_isVehicleSheetOpen)
                          NotificationListener<DraggableScrollableNotification>(
                            onNotification: (notification) {
                              _sheetExtent.value = notification.extent;
                              // Auto-dismiss if dragged to the bottom
                              if (notification.extent <= 0.15) {
                                _dismissVehicleSheet();
                              }
                              return true;
                            },
                            child: DraggableScrollableSheet(
                              controller: _sheetController,
                              initialChildSize: 0.65,
                                                              minChildSize: 0.1, // **MODIFIED:** Allow collapsing lower for dismissal
                                snapSizes: const [0.1, 0.3, 0.65, 0.8],
                              maxChildSize: 0.8,
                              snap: true,
                              builder: (context, scrollController) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey[900]
                                        : Colors.white,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, -2),
                                      ),
                                    ],
                                  ),
                                  child: ValueListenableBuilder<BookingState>(
                                    valueListenable: _bookingState,
                                    builder: (context, state, _) {
                                      return RideConfirmationBottomSheet(
                                        currentUser: _currentUser,
                                        currentPosition: _rideController.currentPosition.value!,
                                        destinationPosition: _destinationPosition!,
                                        pickupAddress: _pickupController.text,
                                        destinationAddress: _destinationController.text,
                                        isDropoffInServiceArea: _isDropoffInServiceArea,
                                        vehicleOptions: VehicleOption.defaultOptions.map((option) {
                                          final realEta = _rideController.getNearestDriverEta(option.type);
                                          return VehicleOption(
                                            type: option.type,
                                            imagePath: option.imagePath,
                                            price: option.price,
                                            eta: realEta,
                                          );
                                        }).toList(),
                                        polylines: state.route != null
                                            ? {
                                                Polyline(
                                                  polylineId: const PolylineId("route"),
                                                  points: state.route!.polylinePoints,
                                                  color: Colors.black,
                                                  width: 5,
                                                ),
                                              }
                                            : _rideController.polylines,
                                        isLoadingFares: state.isLoading,
                                        calculatedFares: state.fares,
                                        eta: state.route != null ? "${(state.route!.durationSeconds / 60).round()} min" : null,
                                        routeDetails: state.route,
                                        pricingRules: _rideController.pricingRules.value,
                                        walletBalance: _rideController.walletBalance.value,
                                        rideType: _selectedServiceType,
                                        showcaseKey: _rideLaterShowcaseKey,
                                        showScheduleTour: true, // Only triggers if not already seen in BottomSheet initState logic
                                        availability: const {
                                          'Auto': true, 'Hatchback': true, 'Sedan': true, 'SUV': true, 'ActingDriver': false,
                                        },
                                        pickupPlaceName: _rideController.pickupPlaceName.value,
                                        destinationPlaceName: _rideController.destinationPlaceName.value,
                                        scrollController: scrollController,
                                        onEditPickup: () => _handleEditLocation(_rideController.currentPosition.value!, isPickup: true),
                                        onEditDropoff: () => _handleEditLocation(_destinationPosition!, isPickup: false),
                                        onSaveDropoffFavorite: _handleSaveDropoffFavorite,
                                        onSavePickupFavorite: _handleSavePickupFavorite,
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      );
  }

  // --- Helper Methods ---
  Widget _buildDrawer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      child: Column(
        children: [
          // --- Custom Header ---
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [Colors.black, const Color(0xFF2C2C2C)]
                    : [Colors.blueAccent, Colors.blue.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white,
                    child: Text(
                      _currentUser.displayName?.isNotEmpty == true
                          ? _currentUser.displayName![0].toUpperCase()
                          : "U",
                      style: TextStyle(
                        fontSize: 28.0,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.black : Colors.blueAccent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentUser.displayName ?? "User",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentUser.email ?? "No Email",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- Drawer Items ---
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildProDrawerItem(
                  icon: Icons.history,
                  text: 'rideHistory'.tr,
                  onTap: () {
                    Get.back();
                    Get.to(() => RideHistoryScreen(user: _currentUser));
                  },
                ),
                CustomShowcase(
                  showcaseKey: _walletShowcaseKey,
                  title: "My Wallet",
                  description: "Manage your balance and recharge easily",
                  isLastStep: true,
                  child: _buildProDrawerItem(
                    key: _walletKey,
                    icon: Icons.account_balance_wallet_outlined,
                    text: 'myWallet'.tr,
                    onTap: () {
                      Get.back();
                      Get.to(() => WalletScreen(user: _currentUser));
                    },
                  ),
                ),
                _buildProDrawerItem(
                  icon: Icons.person_outline,
                  text: 'profile'.tr,
                  onTap: () async {
                    Get.back();
                    final result = await Get.to(
                      () => ProfilePage(user: _currentUser),
                    );
                    if (result == true && mounted) {
                      try {
                        await FirebaseAuth.instance.currentUser?.reload();
                        final updatedUser = FirebaseAuth.instance.currentUser;
                        if (updatedUser != null && mounted) {
                          setState(() => _currentUser = updatedUser);
                        }
                      } catch (e) {
                        debugPrint(
                          "Error reloading user after profile update: $e",
                        );
                      }
                    }
                  },
                ),
                _buildProDrawerItem(
                  icon: Icons.notifications_none_rounded,
                  text: 'notifications'.tr,
                  onTap: () {
                    Get.back();
                    Get.to(() => NotificationsScreen(user: _currentUser));
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Divider(height: 1),
                ),
                _buildProDrawerItem(
                  icon: Icons.support_agent,
                  text: 'support'.tr,
                  onTap: () {
                    Get.back();
                    Get.to(() => const SupportHubScreen());
                  },
                ),
                _buildProDrawerItem(
                  icon: Icons.language,
                  text: 'language'.tr,
                  onTap: () {
                    Get.back();
                    Get.to(() => const LanguageSelectionScreen(isFromProfile: true));
                  },
                ),
                _buildProDrawerItem(
                  icon: Icons.info_outline,
                  text: 'about'.tr,
                  onTap: () {
                    Get.back();
                    Get.to(() => const AboutScreen());
                  },
                ),
              ],
            ),
          ),

          // --- Footer ---
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildProDrawerItem(
                  icon: Icons.logout,
                  text: 'logout'.tr,
                  onTap: _signOut,
                  isDestructive: true,
                ),
                const SizedBox(height: 16),
                Text(
                  "${'version'.tr} 1.2.1",
                  style: TextStyle(
                    color: Theme.of(context).disabledColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProDrawerItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    Key? key,
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDestructive
        ? Colors.redAccent
        : (isDark ? Colors.white : Colors.black87);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (!isDestructive)
                Icon(
                  Icons.arrow_forward_ios,
                  color: isDark ? Colors.white24 : Colors.black12,
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSaveDropoffFavorite() async {
    if (_destinationPosition == null ||
        _selectedServiceType != RideType.daily) {
      displaySnackBar(
        context,
        "Select a destination for a Daily Ride to save as favorite.",
      );
      return;
    }
    final name = await _showSaveFavoriteNameDialog();
    if (name != null && name.isNotEmpty) {
      _saveFavoritePlace(
        name,
        _destinationPosition!,
        _destinationController.text,
      );
    }
  }

  Future<void> _handleSavePickupFavorite() async {
    if (_rideController.currentPosition.value == null) {
      displaySnackBar(context, "Current location not available to save.");
      return;
    }
    final name = await _showSaveFavoriteNameDialog();
    if (name != null && name.isNotEmpty) {
      _saveFavoritePlace(
        name,
        _rideController.currentPosition.value!,
        _pickupController.text,
      );
    }
  }

  Future<String?> _showSaveFavoriteNameDialog() async {
    final nameController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Save Favorite Place'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Enter a name (e.g., Home, Work)",
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Get.back(result: name);
              } else {
                debugPrint("Favorite name cannot be empty");
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveFavoritePlace(
    String name,
    LatLng location,
    String address,
  ) async {
    if (!mounted) return;
    try {
      await _rideController.firestoreService.saveFavoritePlace(
        _currentUser.uid,
        name,
        address,
        location,
      );
      if (mounted) {
        displaySnackBar(context, '$name saved to favorites!', isError: false);
      }
    } catch (e) {
      debugPrint("Error saving favorite: $e");
      if (mounted) displaySnackBar(context, 'Failed to save favorite.');
    }
  }

  Future<void> _showFavoriteOptions(FavoritePlace favorite) async {
    if (!mounted) return;
    _showDeleteConfirmationDialog(favorite);
  }

  Future<void> _showDeleteConfirmationDialog(FavoritePlace favorite) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Favorite?'),
        content: Text('Are you sure you want to delete "${favorite.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () => Get.back(result: true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) _deleteFavoritePlace(favorite);
  }

  Future<void> _showEditFavoriteNameDialog(FavoritePlace favorite) async {
    final nameController = TextEditingController(text: favorite.name);
    final newName = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Edit Favorite Name'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Enter new name"),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) Get.back(result: name);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != favorite.name) {
      _updateFavoritePlaceName(favorite.id, newName);
    }
  }

  Future<void> _showExitConfirmationDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App'),
        content: const Text('Do you want to exit?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
              FocusScope.of(context).unfocus();
            },
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              SystemNavigator.pop();
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateFavoritePlaceName(
    String favoriteId,
    String newName,
  ) async {
    try {
      await _rideController.firestoreService.updateFavoriteName(
        _currentUser.uid,
        favoriteId,
        newName,
      );
      if (mounted) {
        displaySnackBar(context, 'Favorite updated!', isError: false);
      }
    } catch (e) {
      debugPrint("Error updating favorite: $e");
      if (mounted) displaySnackBar(context, 'Failed to update favorite.');
    }
  }

  Future<void> _deleteFavoritePlace(FavoritePlace favorite) async {
    try {
      await _rideController.firestoreService.deleteFavoritePlace(
        _currentUser.uid,
        favorite.id,
      );
      if (mounted) {
        displaySnackBar(
          context,
          '${favorite.name} removed from favorites.',
          isError: false,
        );
      }
    } catch (e) {
      debugPrint("Error deleting favorite: $e");
      if (mounted) displaySnackBar(context, 'Failed to remove favorite.');
    }
  }
} // End of _HomePageState
