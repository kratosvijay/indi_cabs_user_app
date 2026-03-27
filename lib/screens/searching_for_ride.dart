// ignore_for_file: unused_local_variable

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:math';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:volume_controller/volume_controller.dart';
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
    this.isBookForOther = false, // **NEW** Default false
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

  // **NEW:** Location Service for live tracking
  StreamSubscription<Position>? _locationSubscription;
  late final LocationService _locationService;
  final FirestoreService _firestoreService = FirestoreService(); // Instance

  final FlutterTts _flutterTts = FlutterTts();
  bool _audioPlayed = false;

  void _playBookingSuccessAudio() async {
    if (_audioPlayed) return;
    _audioPlayed = true;

    final List<String> messages = [
      "Whoo whoo! A cab has been booked. Please wait while the driver is on the way.",
      "Great news! Your cab is confirmed. The driver is heading your way.",
      "Success! We've found a driver for you. They will be arriving shortly.",
      "Buckle up! Your cab is booked and the driver is en route.",
      "Ride booked successfully! Please hold on while your driver arrives.",
    ];

    final random = Random();
    String messageToPlay = messages[random.nextInt(messages.length)];

    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVolume(1.0);

    // Override iOS silent mode and set audio session to playback
    await _flutterTts
        .setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        ], IosTextToSpeechAudioMode.defaultMode);

    // Save current volume
    double currentVolume = await VolumeController.instance.getVolume();

    // Set volume to max silently (without showing system UI)
    VolumeController.instance.showSystemUI = false;
    VolumeController.instance.setVolume(1.0);

    // Await the TTS completion to restore volume
    _flutterTts.setCompletionHandler(() {
      VolumeController.instance.setVolume(currentVolume);
    });

    await _flutterTts.speak(messageToPlay);
  }

  @override
  void initState() {
    super.initState();

    // **NEW:** Accidental Cancellation Guard (1 second)
    _cancelTapGuardTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _canCancel = true);
    });

    // Initialize services (Assuming API Key is handled inside LocationService or passed globally)
    // For now we just instantiate it, the key is mainly for geocoding
    _locationService = LocationService(apiKey: "");

    debugPrint("SearchingForRideScreen: initState started");
    _currentTip = widget.tip;
    _resolvedRideRequestId = widget.rideRequestId; // Initialize if available
    debugPrint(
      "SearchingForRideScreen: _resolvedRideRequestId at start: $_resolvedRideRequestId",
    );

    // **NEW:** Start live location updates if allowed
    if (!widget.isBookForOther && !widget.isRental) {
      _startLocationUpdates();
    }

    try {
      _buildMarkersAndBounds();
      debugPrint("SearchingForRideScreen: _buildMarkersAndBounds completed");
    } catch (e) {
      debugPrint("SearchingForRideScreen: Error in _buildMarkersAndBounds: $e");
    }

    // **MODIFIED:** Check if the ride is scheduled or "book now"
    if (widget.scheduledTime == null) {
      // --- BOOK NOW LOGIC ---
      if (_resolvedRideRequestId != null) {
        debugPrint(
          "SearchingForRideScreen: Listening for driver assignment with existing ID",
        );
        _listenForDriverAssignment();
      } else if (widget.rideRequestIdFuture != null) {
        debugPrint(
          "SearchingForRideScreen: Waiting for ride request ID future",
        );
        _waitForRideRequestId();
      } else {
        debugPrint("SearchingForRideScreen: No ID and no Future provided!");
      }

      _tipTimer = Timer(const Duration(seconds: 10), () {
        if (mounted &&
            (_rideStatusSubscription != null ||
                widget.rideRequestIdFuture != null)) {
          // Show tip card even if still waiting for ID, as long as we haven't failed
          setState(() => _showTipCard = true);
        }
      });
    } else {
      // --- SCHEDULED RIDE LOGIC ---
      debugPrint("SearchingForRideScreen: Scheduled ride logic");
      _showScheduledMessage();
    }
    debugPrint("SearchingForRideScreen: initState completed");
  }

  Future<void> _waitForRideRequestId() async {
    debugPrint("SearchingForRideScreen: _waitForRideRequestId started");
    try {
      final id = await widget.rideRequestIdFuture!;
      debugPrint("SearchingForRideScreen: Ride request ID resolved: $id");
      if (mounted) {
        setState(() {
          _resolvedRideRequestId = id;
        });
        _listenForDriverAssignment();
      } else {
        debugPrint(
          "SearchingForRideScreen: Widget unmounted after ID resolution",
        );
      }
    } catch (e) {
      debugPrint("Error resolving ride request ID: $e");
      if (mounted) {
        // Show error dialog instead of immediately navigating
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

  // **NEW:** Handles the "Scheduled" UI flow
  void _showScheduledMessage() {
    // Wait 3 seconds and pop back to home
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        // Find the HomePage and pop until it
        Get.offAll(() => HomePage(user: widget.user));

        // Show a confirmation snackbar *after* the navigation
        // Show a confirmation snackbar *after* the navigation
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
    debugPrint("SearchingForRideScreen: _buildMarkersAndBounds started");
    final Set<Marker> markers = {};
    final List<LatLng> allPoints = [];

    // 1. Add Pickup
    markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: widget.pickupLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: "Pickup"),
      ),
    );
    allPoints.add(widget.pickupLocation);

    // 2. Add Intermediate Stops
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

    // 3. Add Final Destination
    if (widget.destinationPosition != widget.pickupLocation) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: widget.destinationPosition,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: const InfoWindow(title: "Drop-off"),
        ),
      );
    }
    allPoints.add(widget.destinationPosition);

    // **NEW:** Add Polyline points to bounds
    debugPrint(
      "SearchingForRideScreen: Polyline count: ${widget.polylines.length}",
    );
    for (var polyline in widget.polylines) {
      allPoints.addAll(polyline.points);
    }

    // 4. Calculate Bounds
    LatLngBounds bounds;
    if (allPoints.isEmpty) {
      // Fallback if absolutely no points
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
    debugPrint(
      "SearchingForRideScreen: Markers and bounds built. Marker count: ${_markers.length}, Points count: ${allPoints.length}",
    );
  }

  // --- Listen for Firestore changes ---
  void _listenForDriverAssignment() {
    debugPrint("SearchingForRideScreen: _listenForDriverAssignment started");
    if (_resolvedRideRequestId == null) {
      debugPrint(
        "SearchingForRideScreen: _resolvedRideRequestId is null in _listenForDriverAssignment",
      );
      return; // Safety check
    }

    String collectionPath;
    if (widget.isRental) {
      collectionPath = 'rental_requests';
    } else {
      collectionPath = 'ride_requests';
    }
    debugPrint(
      "SearchingForRideScreen: Listening to collection: $collectionPath, doc: $_resolvedRideRequestId",
    );

    DocumentReference rideRef = FirebaseFirestore.instance
        .collection(collectionPath)
        .doc(_resolvedRideRequestId!);

    _rideStatusSubscription = rideRef.snapshots().listen(
      (snapshot) {
        if (!mounted) {
          debugPrint(
            "SearchingForRideScreen: Widget unmounted during snapshot listen",
          );
          return;
        }

        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          final status = data['status'] as String?;
          final driverId = data['driverId'] as String?;
          debugPrint(
            "SearchingForRideScreen: Snapshot received. Status: $status, DriverId: $driverId",
          );

          if (status == 'accepted') {
            // **NEW:** Immediate UI Feedback
            if (!_isDriverFound) {
              setState(() => _isDriverFound = true);
              // Also stop the tip timer as we don't need to boost anymore
              _tipTimer?.cancel();
              _showTipCard = false;

              if (mounted) {
                displaySnackBar(
                  context,
                  "A cab has been booked!",
                  isError: false,
                );
              }
              _playBookingSuccessAudio();
            }

            if (driverId != null && driverId.isNotEmpty) {
              debugPrint("Driver found! Navigating to RideInProgressScreen.");
              _rideStatusSubscription?.cancel();
              _rideStatusSubscription = null;

              // **OPTIMIZATION:** Small delay to let the UI update show "Driver Found!" briefly
              // unless it's critical to move instanly.
              // But the user complained about delay, so we move instantly.
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
            } else {
              debugPrint("Status accepted but DriverID is missing/empty!");
            }
          } else if (status == 'cancelled' || status == 'no_drivers_found') {
            debugPrint(
              "SearchingForRideScreen: Ride cancelled or no drivers found",
            );
            _rideStatusSubscription?.cancel();
            _rideStatusSubscription = null;
            displaySnackBar(
              context,
              status == 'cancelled'
                  ? "Ride cancelled."
                  : "No drivers found. Please try again.",
            );
            if (mounted) {
              Get.offAll(() => HomePage(user: widget.user));
            }
          }
        } else {
          debugPrint("SearchingForRideScreen: Snapshot does not exist");
          _rideStatusSubscription?.cancel();
          _rideStatusSubscription = null;
          // Only show snackbar if we are not already cancelling
          if (mounted) {
            displaySnackBar(context, "Ride request not found.");
            Get.offAll(() => HomePage(user: widget.user));
          }
        }
      },
      onError: (error) {
        debugPrint("Error listening to ride status: $error");
        if (mounted) {
          displaySnackBar(context, "Error listening to ride status.");
        }
        _rideStatusSubscription?.cancel();
        _rideStatusSubscription = null;
      },
    );
  }

  // --- Cancel Ride ---
  Future<void> _cancelRide() async {
    if (_isCancelling) return; // Prevent double taps
    if (mounted) setState(() => _isCancelling = true);

    debugPrint("SearchingForRideScreen: _cancelRide called");
    await _rideStatusSubscription?.cancel();
    _rideStatusSubscription = null;

    try {
      String? idToCancel = _resolvedRideRequestId;
      if (idToCancel == null && widget.rideRequestIdFuture != null) {
        debugPrint(
          "Waiting for ride request ID to resolve before cancelling...",
        );
        idToCancel = await widget.rideRequestIdFuture;
      }

      if (idToCancel != null) {
        String collectionPath = widget.isRental
            ? 'rental_requests'
            : 'ride_requests';
        DocumentReference rideRef = FirebaseFirestore.instance
            .collection(collectionPath)
            .doc(idToCancel);
        await rideRef.update({'status': 'cancelled_by_user'});
        debugPrint(
          "SearchingForRideScreen: Ride cancelled in Firestore ($idToCancel)",
        );
      } else {
        debugPrint(
          "SearchingForRideScreen: Cannot cancel, ride ID could not be resolved",
        );
      }
    } catch (e) {
      debugPrint("Error cancelling ride: $e");
      // Don't show snackbar for "not found" errors as we are leaving anyway
      if (mounted && !e.toString().contains('not-found')) {
        displaySnackBar(context, "Error cancelling ride.");
      }
    } finally {
      if (mounted) {
        // Use Get.offAll to ensure clean stack reset
        Get.offAll(() => HomePage(user: widget.user));
      } else {
        // Even if unmounted, ensure we don't leave the flag hanging if the object somehow survives (rare)
        _isCancelling = false;
      }
    }
  }

  // --- Update Tip ---
  Future<void> _updateTipInFirestore(double newTip) async {
    if (_resolvedRideRequestId == null) return; // Guard against null ID

    try {
      String collectionPath = widget.isRental
          ? 'rental_requests'
          : 'ride_requests';
      DocumentReference rideRef = FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(_resolvedRideRequestId);
      await rideRef.update({'tip': newTip, 'totalFare': widget.fare + newTip});
      if (mounted) {
        displaySnackBar(
          context,
          "Tip updated to ₹${newTip.round()}!",
          isError: false,
        );
      }
    } catch (e) {
      debugPrint("Error updating tip: $e");
      if (mounted) displaySnackBar(context, "Failed to update tip.");
    }
  }

  // **NEW:** Start streaming location updates
  void _startLocationUpdates() {
    debugPrint("SearchingForRideScreen: Starting location updates");
    // Cancel any existing subscription first
    _locationSubscription?.cancel();

    try {
      _locationSubscription = _locationService.getPositionStream().listen(
        (Position position) {
          if (!mounted) return;
          if (_resolvedRideRequestId == null) {
            return; // Don't write if no ID yet
          }

          // Update Firestore
          // NOTE: We don't need to await this as it's a stream
          _firestoreService.updateUserLocation(
            widget.isRental ? 'rental_requests' : 'ride_requests',
            _resolvedRideRequestId!,
            LatLng(position.latitude, position.longitude),
          );
        },
        onError: (e) {
          debugPrint("SearchingForRideScreen: Location stream error: $e");
        },
      );
    } catch (e) {
      debugPrint("SearchingForRideScreen: Error starting location stream: $e");
    }
  }

  @override
  void dispose() {
    debugPrint("SearchingForRideScreen: dispose called");
    _rideStatusSubscription?.cancel();
    _locationSubscription?.cancel(); // **NEW:** Cancel location stream
    _tipTimer?.cancel();
    _cancelTapGuardTimer?.cancel(); // **NEW**
    try {
      // map controller disposal logic if any
    } catch (e) {
      debugPrint("Error disposing elements: $e");
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("SearchingForRideScreen: build called");
    // **NEW:** Dynamic UI based on scheduled time
    final bool isScheduled = widget.scheduledTime != null;
    final String title = isScheduled
        ? "rideScheduled".tr
        : _isDriverFound
        ? "driverFound".tr
        : "searchingForRide".tr;

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true, // Allow map to show behind status bar
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (!isScheduled) {
            // Only allow cancel if it's not a scheduled ride
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
              mapType: MapType.normal, // Changed to normal for cleaner look
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              scrollGesturesEnabled: false,
              tiltGesturesEnabled: false,
              rotateGesturesEnabled: false,
              zoomGesturesEnabled: false,
              onMapCreated: (GoogleMapController controller) {
                try {
                  debugPrint("SearchingForRideScreen: Map created");
                  Future.delayed(const Duration(milliseconds: 100), () async {
                    if (mounted && _routeBounds != null) {
                      try {
                        await controller.animateCamera(
                          CameraUpdate.newLatLngBounds(_routeBounds!, 100.0),
                        );
                      } catch (e) {
                        debugPrint(
                          "Error animating bounds in Searching screen: $e",
                        );
                        if (mounted) {
                          try {
                            await controller.animateCamera(
                              CameraUpdate.newLatLngZoom(
                                widget.pickupLocation,
                                15,
                              ),
                            );
                          } catch (e2) {
                            debugPrint("Error animating camera fallback: $e2");
                          }
                        }
                      }
                    }
                  });
                } catch (e) {
                  debugPrint("Error in onMapCreated: $e");
                }
              },
            ),
            // Gradient overlay for better text visibility
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10), // Reduced top spacing
                  // **NEW:** Trip Details Top Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildTripDetailsCard(isDark),
                  ),

                  const SizedBox(height: 20),

                  // **RESTORED:** Title Text
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

                  // **NEW:** Show different icon/animation
                  if (isScheduled)
                    FadeInSlide(
                      child: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.greenAccent,
                        size: 120,
                      ),
                    )
                  else
                    const Center(child: PulsingWaveAnimation()), // Animation

                  const Spacer(),

                  // **NEW:** Only show tip card if NOT scheduled
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 500),
                    opacity: _showTipCard && !isScheduled ? 1.0 : 0.0,
                    child: (_showTipCard && !isScheduled)
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                            ),
                            child: _buildTipCard(isDark),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // **NEW:** Only show cancel button if NOT scheduled
                  if (!isScheduled)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                      child: ProButton(
                        text: "cancelRide".tr,
                        onPressed: (_isCancelling || !_canCancel)
                            ? null
                            : _cancelRide, // Disable if cancelling or guard active
                        isLoading: _isCancelling, // Show loading
                        backgroundColor: Colors.redAccent.shade400,
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                ],
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

  // **NEW:** Trip Details Card Widget
  Widget _buildTripDetailsCard(bool isDark) {
    if (widget.isRental) return const SizedBox.shrink(); // Hide for rentals

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey[900]!.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.95),
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
          // Destination Row
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
          // ETA & Fare Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ETA
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
              // Dynamic Fare
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
                    Text(
                      "tipDesc".tr,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "tipAmount".tr,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                ),
              ),
              Text(
                "₹${_currentTip.round()}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.blueAccent,
              inactiveTrackColor: Colors.blueAccent.withValues(alpha: 0.2),
              thumbColor: Colors.blueAccent,
              overlayColor: Colors.blueAccent.withValues(alpha: 0.2),
              trackHeight: 4.0,
            ),
            child: Slider(
              value: _currentTip,
              min: 0,
              max: 100,
              divisions: 10,
              label: '₹${_currentTip.round()}',
              onChanged: (double value) => setState(() => _currentTip = value),
              onChangeEnd: (double value) => _updateTipInFirestore(value),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Animated Pulsing Wave Widget ---
// ... (PulsingWaveAnimation and PulsingWavePainter are unchanged) ...
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
    return CustomPaint(
      painter: PulsingWavePainter(_controller),
      size: const Size(200, 200),
    );
  }
}

class PulsingWavePainter extends CustomPainter {
  final Animation<double> animation;

  PulsingWavePainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final double value = animation.value;

    final Paint paint = Paint()
      ..color = Colors.blueAccent.withAlpha(10 + (200 * (1.0 - value)).toInt())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0 * (1.0 - value);

    canvas.drawCircle(center, value * size.width / 2, paint);
  }

  @override
  bool shouldRepaint(covariant PulsingWavePainter oldDelegate) {
    return true;
  }
}
