// ignore_for_file: unused_local_variable

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:project_taxi_with_ai/screens/ride_in_progress.dart';
import 'package:project_taxi_with_ai/widgets/data_models.dart';
import '../widgets/snackbar.dart'; // Import snackbar
// Import Home Page for cancellation navigation
import 'home_page.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart'; // Import Pro Library
import 'package:project_taxi_with_ai/app_colors.dart'; // Import AppColors
import 'package:project_taxi_with_ai/widgets/liftable_banner_ad.dart';
import 'package:project_taxi_with_ai/widgets/location_service.dart'; // **NEW**
import 'package:project_taxi_with_ai/widgets/firestore_services.dart'; // **NEW**
import 'package:geolocator/geolocator.dart'; // **NEW**

class SearchingForRideScreen extends StatefulWidget {
  final User user;
  final LatLng pickupLocation;
  final LatLng destinationPosition;
  final double fare;
  final double tip;
  final Set<Polyline> polylines;
  final bool isRental; // Flag to indicate ride type
  final String? rideRequestId; // Made nullable
  final Future<String>?
  rideRequestIdFuture; // **NEW:** Future for optimistic navigation
  final String? destinationAddress; // **NEW**
  final String? initialEta; // **NEW**

  // --- Daily Ride Specific (optional) ---
  final VehicleOption? selectedVehicle;

  // --- Rental Ride Specific (optional) ---
  final RentalPackage? rentalPackage;
  final String? rentalVehicleType;

  final List<Map<String, dynamic>>? intermediateStops;
  final DateTime? scheduledTime; // For scheduled rides
  final bool isBookForOther; // **NEW:** Flag to skip live tracking
  final String? pickupAddress; // **NEW**
  final String? pickupPlaceName;
  final String? destinationPlaceName;
  final String? paymentMethod;
  final num? convenienceFee;
  final num? walletAmountUsed;
  final num? cashAmount;
  final RouteDetails? routeDetails; // **NEW**

  const SearchingForRideScreen({
    super.key,
    required this.user,
    required this.pickupLocation,
    required this.destinationPosition,
    required this.fare,
    required this.tip,
    required this.polylines,
    required this.isRental,
    this.rideRequestId, // Nullable
    this.rideRequestIdFuture,
    this.destinationAddress,
    this.initialEta,
    this.selectedVehicle,
    this.rentalPackage,
    this.rentalVehicleType,
    this.intermediateStops,
    this.scheduledTime,
    this.isBookForOther = false,
    this.pickupAddress,
    this.pickupPlaceName,
    this.destinationPlaceName,
    this.paymentMethod,
    this.convenienceFee,
    this.walletAmountUsed,
    this.cashAmount,
    this.routeDetails,
  }) : assert(
         isRental
             ? (rentalPackage != null && rentalVehicleType != null)
             : (selectedVehicle != null) || (intermediateStops != null),
       ),
       assert(
         rideRequestId != null || rideRequestIdFuture != null,
         "Either rideRequestId or rideRequestIdFuture must be provided",
       );

  @override
  State<SearchingForRideScreen> createState() => _SearchingForRideScreenState();
}

class _SearchingForRideScreenState extends State<SearchingForRideScreen> {
  bool _showTipCard = false;
  late double _currentTip;
  StreamSubscription? _rideStatusSubscription;
  late Set<Marker> _markers;
  LatLngBounds? _routeBounds;
  Timer? _tipTimer;
  String? _resolvedRideRequestId; // To store the ID once resolved
  bool _isCancelling = false; // **NEW**
  bool _canCancel = false; // **NEW:** Tap guard for accidental cancellation
  Timer? _cancelTapGuardTimer; // **NEW:** Timer for tap guard
  bool _isDriverFound =
      false; // Track if driver is found for immediate UI feedback
  bool _isRidePosted = false; // **NEW:** Track if ride was created in Firestore

  // **NEW:** Location Service for live tracking
  StreamSubscription<Position>? _locationSubscription;
  Timer? _searchTimeoutTimer; // **NEW:** 5-minute timeout
  late final LocationService _locationService;
  final FirestoreService _firestoreService = FirestoreService(); // Instance

  // Add Audio/Tts
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();

    // **NEW:** Accidental Cancellation Guard (1 second)
    _cancelTapGuardTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _canCancel = true);
    });

    // Initialize services
    _locationService = LocationService(apiKey: "");

    debugPrint("SearchingForRideScreen: initState started");
    _currentTip = widget.tip;
    _resolvedRideRequestId = widget.rideRequestId;
    _isRidePosted = _resolvedRideRequestId != null;

    // Start live location updates if allowed
    if (!widget.isBookForOther && !widget.isRental) {
      _startLocationUpdates();
    }

    try {
      _buildMarkersAndBounds();
      debugPrint("SearchingForRideScreen: _buildMarkersAndBounds completed");
    } catch (e) {
      debugPrint("SearchingForRideScreen: Error in _buildMarkersAndBounds: $e");
    }

    // Check if the ride is scheduled or "book now"
    if (widget.scheduledTime == null) {
      if (_resolvedRideRequestId != null) {
        _listenForDriverAssignment();
      } else if (widget.rideRequestIdFuture != null) {
        _waitForRideRequestId();
      }

      _tipTimer = Timer(const Duration(seconds: 10), () {
        if (mounted &&
            (_rideStatusSubscription != null ||
                widget.rideRequestIdFuture != null)) {
          setState(() => _showTipCard = true);
        }
      });

      // **NEW:** Start the 5-minute timeout timer
      _startSearchTimeoutTimer();
    } else {
      _showScheduledMessage();
    }
    debugPrint("SearchingForRideScreen: initState completed");

    // **NEW:** Show wallet usage notification if balance was used
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.walletAmountUsed != null && widget.walletAmountUsed! > 0) {
        displaySnackBar(
          context,
          "₹${widget.walletAmountUsed?.toStringAsFixed(0)} paid using wallet balance.",
          isError: false,
        );
      }
    });
  }

  Future<void> _waitForRideRequestId() async {
    try {
      final id = await widget.rideRequestIdFuture!;
      if (mounted) {
        setState(() {
          _resolvedRideRequestId = id;
          _isRidePosted = true;
        });
        _listenForDriverAssignment();
      }
    } catch (e) {
      debugPrint("Error resolving ride request ID: $e");
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text("rideRequestFailed".tr),
            content: Text("${"rideRequestFailedDesc".tr} $e"),
            actions: [
              TextButton(
                onPressed: () {
                  Get.offAll(() => HomePage(user: widget.user));
                },
                child: Text("goToHome".tr),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showScheduledMessage() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Get.offAll(() => HomePage(user: widget.user));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          displaySnackBar(
            context,
            "Your ride has been scheduled!",
            isError: false,
          );
        });
      }
    });
  }

  void _buildMarkersAndBounds() {
    final Set<Marker> markers = {};
    final List<LatLng> allPoints = [];

    markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: widget.pickupLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: "Pickup"),
      ),
    );
    allPoints.add(widget.pickupLocation);

    if (widget.intermediateStops != null) {
      int stopNumber = 1;
      for (var stopData in widget.intermediateStops!) {
        try {
          final locationMap = stopData['location'] as Map<String, dynamic>;
          final lat = locationMap['latitude'] as double;
          final lng = locationMap['longitude'] as double;
          final stopLatLng = LatLng(lat, lng);

          markers.add(
            Marker(
              markerId: MarkerId('stop_$stopNumber'),
              position: stopLatLng,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange,
              ),
              infoWindow: InfoWindow(
                title: "Stop $stopNumber",
                snippet: stopData['address'] as String?,
              ),
            ),
          );
          allPoints.add(stopLatLng);
          stopNumber++;
        } catch (e) {
          debugPrint("Error parsing intermediate stop: $e");
        }
      }
    }

    if (widget.destinationPosition != widget.pickupLocation) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: widget.destinationPosition,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed,
          ),
          infoWindow: const InfoWindow(title: "Drop-off"),
        ),
      );
    }
    allPoints.add(widget.destinationPosition);

    for (var polyline in widget.polylines) {
      allPoints.addAll(polyline.points);
    }

    LatLngBounds bounds;
    if (allPoints.isEmpty) {
      bounds = LatLngBounds(
        southwest: widget.pickupLocation,
        northeast: widget.pickupLocation,
      );
    } else if (allPoints.length == 1) {
      bounds = LatLngBounds(southwest: allPoints[0], northeast: allPoints[0]);
    } else {
      double minLat = allPoints[0].latitude;
      double maxLat = allPoints[0].latitude;
      double minLng = allPoints[0].longitude;
      double maxLng = allPoints[0].longitude;

      for (var p in allPoints) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }

      bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
    }

    setState(() {
      _markers = markers;
      _routeBounds = bounds;
    });
  }

  void _listenForDriverAssignment() {
    if (_resolvedRideRequestId == null) return;

    String collectionPath = widget.isRental ? 'rental_requests' : 'ride_requests';
    DocumentReference rideRef = FirebaseFirestore.instance
        .collection(collectionPath)
        .doc(_resolvedRideRequestId!);

    _rideStatusSubscription = rideRef.snapshots().listen(
      (snapshot) {
        if (!mounted) return;

        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          final status = data['status'] as String?;
          final driverId = data['driverId'] as String?;

          // ── Navigate to RideInProgress ──
          // Requires BOTH: an active status (not just any snapshot with driverId)
          // AND a valid driverId. This prevents old completed rides from triggering nav.
          const activeStatuses = ['accepted', 'arrived', 'started'];
          final bool isActiveStatus = status != null && activeStatuses.contains(status);

          if (isActiveStatus && driverId != null && driverId.isNotEmpty && !_isDriverFound) {
            setState(() => _isDriverFound = true);
            _tipTimer?.cancel();
            _showTipCard = false;
            _searchTimeoutTimer?.cancel();

            if (mounted) {
              displaySnackBar(context, "A cab has been booked!", isError: false);
            }
            _playBookingSuccessAudio();

            _rideStatusSubscription?.cancel();
            _rideStatusSubscription = null;

            Get.off(
              () => RideInProgressScreen(
                user: widget.user,
                pickupLocation: widget.pickupLocation,
                destinationPosition: widget.destinationPosition,
                isRental: widget.isRental,
                rideRequestId: _resolvedRideRequestId!,
                selectedVehicleType: widget.isRental
                    ? widget.rentalVehicleType!
                    : (widget.selectedVehicle?.type ?? "Multi-Stop"),
                rentalPackage: widget.rentalPackage,
                driverId: driverId,
                intermediateStops: widget.intermediateStops,
              ),
            );
            return;
          }


          // ── Cancelled or no drivers ──
          if (status == 'cancelled' ||
              status == 'cancelled_by_driver' ||
              status == 'no_drivers_found') {
            _rideStatusSubscription?.cancel();
            _rideStatusSubscription = null;
            _searchTimeoutTimer?.cancel();
            displaySnackBar(
              context,
              status == 'cancelled'
                  ? "Ride cancelled."
                  : status == 'cancelled_by_driver'
                      ? "Driver cancelled the ride. Please book again."
                      : "No drivers found. Please try again.",
            );
            if (mounted) {
              Get.offAll(() => HomePage(user: widget.user));
            }
          }
        } else {
          debugPrint("Snapshot does not exist yet. Waiting for remote sync...");
        }
      },
      onError: (error) {
        debugPrint("Error listening to ride status: $error");
        _rideStatusSubscription?.cancel();
        _rideStatusSubscription = null;
      },
    );
  }


  // **NEW:** Search Timeout logic
  void _startSearchTimeoutTimer() {
    _searchTimeoutTimer?.cancel();
    _searchTimeoutTimer = Timer(const Duration(minutes: 5), () {
      if (mounted && !_isDriverFound && !_isCancelling) {
        _handleSearchTimeout();
      }
    });
  }

  Future<void> _handleSearchTimeout() async {
    debugPrint("SearchingForRideScreen: Search timed out (5 mins)");

    if (_resolvedRideRequestId != null) {
      try {
        String collectionPath =
            widget.isRental ? 'rental_requests' : 'ride_requests';
        await FirebaseFirestore.instance
            .collection(collectionPath)
            .doc(_resolvedRideRequestId!)
            .update({'status': 'timeout'});
      } catch (e) {
        debugPrint("Error updating status to timeout: $e");
      }
    }

    await _rideStatusSubscription?.cancel();
    _rideStatusSubscription = null;

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text("No Cabs Found"),
          content: const Text(
            "We couldn't find a cab for you at the moment. Would you like to try again?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Get.back();
                Get.offAll(() => HomePage(user: widget.user));
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Get.back();
                _retrySearch();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _retrySearch() async {
    if (mounted) {
      setState(() {
        _isCancelling = false;
        _isRidePosted = false;
        _resolvedRideRequestId = null;
        _canCancel = false;
        _showTipCard = false;
      });
    }

    try {
      if (widget.isRental) {
        final String id = await _firestoreService.createRentalRideRequest(
          userId: widget.user.uid,
          userName: widget.user.displayName,
          userPhone: widget.user.phoneNumber,
          pickupLocation: widget.pickupLocation,
          pickupAddress: widget.pickupAddress ?? "N/A",
          pickupPlaceName: widget.pickupPlaceName,
          rentalPackage: widget.rentalPackage!,
          rentalVehicleType: widget.rentalVehicleType!,
          rentalPrice: widget.fare,
          tip: widget.tip,
          paymentMethod: widget.paymentMethod ?? "Cash",
          scheduledTime: widget.scheduledTime,
          convenienceFee: widget.convenienceFee,
          walletAmountUsed: widget.walletAmountUsed,
          cashAmount: widget.cashAmount,
        );
        if (mounted) {
          setState(() {
            _resolvedRideRequestId = id;
            _isRidePosted = true;
            _canCancel = true;
          });
          _listenForDriverAssignment();
          _startSearchTimeoutTimer();
        }
      } else {
        final String id = await _firestoreService.createDailyRideRequest(
          userId: widget.user.uid,
          userName: widget.user.displayName,
          userPhone: widget.user.phoneNumber,
          pickupLocation: widget.pickupLocation,
          pickupAddress: widget.pickupAddress ?? "N/A",
          pickupPlaceName: widget.pickupPlaceName,
          destinationLocation: widget.destinationPosition,
          destinationAddress: widget.destinationAddress ?? "",
          destinationPlaceName: widget.destinationPlaceName,
          vehicleType: widget.selectedVehicle?.type ?? "Hatchback",
          fare: widget.fare,
          tip: widget.tip,
          paymentMethod: widget.paymentMethod ?? "Cash",
          routeDetails: widget.routeDetails,
          intermediateStops: widget.intermediateStops,
          scheduledTime: widget.scheduledTime,
          convenienceFee: widget.convenienceFee,
          walletAmountUsed: widget.walletAmountUsed,
          cashAmount: widget.cashAmount,
        );
        if (mounted) {
          setState(() {
            _resolvedRideRequestId = id;
            _isRidePosted = true;
            _canCancel = true;
          });
          _listenForDriverAssignment();
          _startSearchTimeoutTimer();
        }
      }
    } catch (e) {
      debugPrint("Error retrying search: $e");
      if (mounted) displaySnackBar(context, "Error restarting search: $e");
    }
  }

  Future<void> _cancelRide() async {
    if (_isCancelling) return;
    if (mounted) setState(() => _isCancelling = true);

    _searchTimeoutTimer?.cancel();
    await _rideStatusSubscription?.cancel();
    _rideStatusSubscription = null;

    try {
      String? idToCancel = _resolvedRideRequestId;
      if (idToCancel == null && widget.rideRequestIdFuture != null) {
        idToCancel = await widget.rideRequestIdFuture;
      }

      if (idToCancel != null) {
        String collectionPath = widget.isRental ? 'rental_requests' : 'ride_requests';
        DocumentReference rideRef = FirebaseFirestore.instance
            .collection(collectionPath)
            .doc(idToCancel);

        int attempts = 0;
        const int maxAttempts = 3;
        bool success = false;
        while (attempts < maxAttempts && !success) {
          try {
            await rideRef.update({'status': 'cancelled_by_user'});
            success = true;
          } catch (e) {
            attempts++;
            if (attempts < maxAttempts) {
              await Future.delayed(const Duration(milliseconds: 500));
            } else {
              rethrow;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error cancelling ride: $e");
      if (mounted && !e.toString().contains('not-found')) {
        displaySnackBar(context, "Error cancelling ride.");
      }
    } finally {
      if (mounted) {
        Get.offAll(() => HomePage(user: widget.user));
      } else {
        _isCancelling = false;
      }
    }
  }

  Future<void> _updateTipInFirestore(double newTip) async {
    if (_resolvedRideRequestId == null) return;
    try {
      String collectionPath = widget.isRental ? 'rental_requests' : 'ride_requests';
      DocumentReference rideRef = FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(_resolvedRideRequestId!);
      await rideRef.update({'tip': newTip, 'totalFare': widget.fare + newTip});
      if (mounted) {
        displaySnackBar(context, "Tip updated to ₹${newTip.round()}!", isError: false);
      }
    } catch (e) {
      debugPrint("Error updating tip: $e");
    }
  }

  void _startLocationUpdates() {
    _locationSubscription?.cancel();
    try {
      _locationSubscription = _locationService.getPositionStream().listen(
        (Position position) {
          if (!mounted || _resolvedRideRequestId == null) return;
          _firestoreService.updateUserLocation(
            widget.isRental ? 'rental_requests' : 'ride_requests',
            _resolvedRideRequestId!,
            LatLng(position.latitude, position.longitude),
          );
        },
      );
    } catch (e) {
      debugPrint("Error starting location updates: $e");
    }
  }

  void _playBookingSuccessAudio() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.speak("Your cab has been booked successfully.");
    } catch (e) {
      debugPrint("Error playing audio: $e");
    }
  }

  @override
  void dispose() {
    _searchTimeoutTimer?.cancel();
    _rideStatusSubscription?.cancel();
    _locationSubscription?.cancel();
    _tipTimer?.cancel();
    _cancelTapGuardTimer?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  Widget _buildTripDetailsCard(bool isDark) {
    if (widget.isRental) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900]!.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.redAccent, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.destinationAddress ?? "destination".tr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.access_time_filled,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.initialEta ?? "-- mins",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[300] : Colors.black87,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "₹${(widget.fare + _currentTip).round()}",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.volunteer_activism,
                  color: Colors.amber,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "boostRequest".tr,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "boostRequestDesc".tr,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [10.0, 20.0, 50.0].map((tipValue) {
              bool isSelected = _currentTip == tipValue;
              return GestureDetector(
                onTap: () {
                  setState(() => _currentTip = tipValue);
                  _updateTipInFirestore(tipValue);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : (isDark ? Colors.grey[800] : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    "+₹${tipValue.round()}",
                    style: TextStyle(
                      color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isScheduled = widget.scheduledTime != null;
    String title = isScheduled
        ? "rideScheduled".tr
        : _isDriverFound
            ? "driverFound".tr
            : "searchingForRide".tr;

    if (!isScheduled && !_isDriverFound && _isRidePosted) {
      title = "Ride Posted! \nSearching for Driver...";
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (!isScheduled) {
            _cancelRide();
          }
        },
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: widget.pickupLocation,
                zoom: 14,
              ),
              polylines: widget.polylines,
              markers: _markers,
              myLocationEnabled: false,
              mapType: MapType.normal,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              scrollGesturesEnabled: false,
              tiltGesturesEnabled: false,
              rotateGesturesEnabled: false,
              zoomGesturesEnabled: false,
              onMapCreated: (GoogleMapController controller) {
                if (_routeBounds != null) {
                  controller.animateCamera(CameraUpdate.newLatLngBounds(_routeBounds!, 100.0));
                }
              },
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  stops: const [0.0, 0.5, 0.8],
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: _buildTripDetailsCard(isDark),
                            ),
                            const SizedBox(height: 20),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 10.0,
                                      color: Colors.black45,
                                      offset: Offset(2.0, 2.0),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (isScheduled)
                              FadeInSlide(
                                child: const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.greenAccent,
                                  size: 120,
                                ),
                              )
                            else
                              const Center(child: PulsingWaveAnimation()),
                            const Spacer(),
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 500),
                              opacity: _showTipCard && !isScheduled ? 1.0 : 0.0,
                              child: (_showTipCard && !isScheduled)
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                      child: _buildTipCard(isDark),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            if (!isScheduled)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                                child: ProButton(
                                  text: "cancelRide".tr,
                                  onPressed: (_isCancelling || !_canCancel) ? null : _cancelRide,
                                  isLoading: _isCancelling,
                                  backgroundColor: Colors.redAccent.shade400,
                                  icon: const Icon(Icons.close, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: LiftableBannerAd(),
            ),
          ],
        ),
      ),
    );
  }
}

class PulsingWaveAnimation extends StatefulWidget {
  const PulsingWaveAnimation({super.key});

  @override
  State<PulsingWaveAnimation> createState() => _PulsingWaveAnimationState();
}

class _PulsingWaveAnimationState extends State<PulsingWaveAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            _buildWave(1.0 + _controller.value),
            _buildWave(1.5 + _controller.value),
            _buildWave(2.0 + _controller.value),
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.local_taxi,
                size: 40,
                color: AppColors.primary,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWave(double scale) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: (2.0 - scale).clamp(0.0, 1.0) * 0.3),
        ),
      ),
    );
  }
}
