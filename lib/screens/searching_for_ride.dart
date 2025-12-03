// ignore_for_file: unused_local_variable

import 'dart:async';
import 'dart:math'; // For min/max
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:project_taxi_with_ai/screens/ride_in_progress.dart';
import 'package:project_taxi_with_ai/widgets/data_models.dart';
import '../widgets/snackbar.dart'; // Import snackbar
// Import Home Page for cancellation navigation
import 'home_page.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart'; // Import Pro Library

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

  // --- Daily Ride Specific (optional) ---
  final VehicleOption? selectedVehicle;

  // --- Rental Ride Specific (optional) ---
  final RentalPackage? rentalPackage;
  final String? rentalVehicleType;

  // **NEW:** For Multi-stop
  final List<Map<String, dynamic>>? intermediateStops;
  final DateTime? scheduledTime; // **NEW:** For scheduled rides

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
    this.rideRequestIdFuture, // **NEW**
    this.selectedVehicle,
    this.rentalPackage,
    this.rentalVehicleType,
    this.intermediateStops,
    this.scheduledTime, // **NEW**
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

  @override
  void initState() {
    super.initState();
    _currentTip = widget.tip;
    _resolvedRideRequestId = widget.rideRequestId; // Initialize if available
    _buildMarkersAndBounds();

    // **MODIFIED:** Check if the ride is scheduled or "book now"
    if (widget.scheduledTime == null) {
      // --- BOOK NOW LOGIC ---
      if (_resolvedRideRequestId != null) {
        _listenForDriverAssignment();
      } else if (widget.rideRequestIdFuture != null) {
        _waitForRideRequestId();
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
      _showScheduledMessage();
    }
  }

  Future<void> _waitForRideRequestId() async {
    try {
      final id = await widget.rideRequestIdFuture!;
      if (mounted) {
        setState(() {
          _resolvedRideRequestId = id;
        });
        _listenForDriverAssignment();
      }
    } catch (e) {
      debugPrint("Error resolving ride request ID: $e");
      if (mounted) {
        displaySnackBar(context, "Failed to create ride request: $e");
        Get.offAll(() => HomePage(user: widget.user));
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

    // 4. Calculate Bounds
    LatLngBounds bounds;
    if (allPoints.length == 1) {
      bounds = LatLngBounds(southwest: allPoints[0], northeast: allPoints[0]);
    } else {
      bounds = LatLngBounds(
        southwest: LatLng(
          allPoints.map((p) => p.latitude).reduce(min),
          allPoints.map((p) => p.longitude).reduce(min),
        ),
        northeast: LatLng(
          allPoints.map((p) => p.latitude).reduce(max),
          allPoints.map((p) => p.longitude).reduce(max),
        ),
      );
    }

    setState(() {
      _markers = markers;
      _routeBounds = bounds;
    });
  }

  // --- Listen for Firestore changes ---
  void _listenForDriverAssignment() {
    if (_resolvedRideRequestId == null) return; // Safety check

    String collectionPath;
    if (widget.isRental) {
      collectionPath = 'rental_requests';
    } else {
      collectionPath = 'ride_requests';
    }

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

          if (status == 'accepted' && driverId != null && driverId.isNotEmpty) {
            debugPrint("Driver found! Navigating to RideInProgressScreen.");
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
          } else if (status == 'cancelled' || status == 'no_drivers_found') {
            _rideStatusSubscription?.cancel();
            _rideStatusSubscription = null;
            displaySnackBar(
              context,
              status == 'cancelled'
                  ? "Ride cancelled."
                  : "No drivers found. Please try again.",
            );
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => HomePage(user: widget.user),
                ),
                (route) => false,
              );
            }
          }
        } else {
          _rideStatusSubscription?.cancel();
          _rideStatusSubscription = null;
          // Only show snackbar if we are not already cancelling
          if (mounted) {
            displaySnackBar(context, "Ride request not found.");
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => HomePage(user: widget.user),
              ),
              (route) => false,
            );
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
    await _rideStatusSubscription?.cancel();
    _rideStatusSubscription = null;

    try {
      if (_resolvedRideRequestId != null) {
        String collectionPath = widget.isRental
            ? 'rental_requests'
            : 'ride_requests';
        DocumentReference rideRef = FirebaseFirestore.instance
            .collection(collectionPath)
            .doc(_resolvedRideRequestId);
        await rideRef.update({'status': 'cancelled_by_user'});
      }
    } catch (e) {
      debugPrint("Error cancelling ride: $e");
      // Don't show snackbar for "not found" errors as we are leaving anyway
      if (mounted && !e.toString().contains('not-found')) {
        displaySnackBar(context, "Error cancelling ride.");
      }
    } finally {
      if (mounted) {
        // Use Navigator instead of Get.offAll to ensure clean stack reset
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => HomePage(user: widget.user)),
          (route) => false,
        );
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

  @override
  void dispose() {
    _rideStatusSubscription?.cancel();
    _tipTimer?.cancel(); // **NEW:** Cancel tip timer
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // **NEW:** Dynamic UI based on scheduled time
    final bool isScheduled = widget.scheduledTime != null;
    final String title = isScheduled
        ? "Your Ride is Scheduled!"
        : "Searching for a Ride...";

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
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (mounted && _routeBounds != null) {
                    try {
                      controller.animateCamera(
                        CameraUpdate.newLatLngBounds(_routeBounds!, 100.0),
                      );
                    } catch (e) {
                      debugPrint(
                        "Error animating bounds in Searching screen: $e",
                      );
                      controller.animateCamera(
                        CameraUpdate.newLatLngZoom(widget.pickupLocation, 15),
                      );
                    }
                  }
                });
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
                        text: "Cancel Ride",
                        onPressed: _cancelRide,
                        backgroundColor: Colors.redAccent.shade400,
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
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
                      "Boost your request",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      "Add a tip to find drivers faster",
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
                "Tip Amount",
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
