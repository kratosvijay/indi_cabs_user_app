// ignore_for_file: unused_field, unused_element, unnecessary_to_list_in_spreads, use_build_context_synchronously

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart' hide Route;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:project_taxi_with_ai/widgets/data_models.dart';
import 'package:project_taxi_with_ai/widgets/directions_service.dart';
import 'package:project_taxi_with_ai/widgets/location_service.dart';

import '../widgets/snackbar.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';
import 'package:project_taxi_with_ai/widgets/rental_timer_slider.dart';
import 'package:project_taxi_with_ai/app_colors.dart';
import 'home_page.dart';
import 'chat_box.dart';
import 'package:project_taxi_with_ai/controllers/ride_controller.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:project_taxi_with_ai/widgets/slide_to_cancel.dart';
import 'edit_location.dart';
import 'package:project_taxi_with_ai/widgets/liftable_banner_ad.dart';

class RideInProgressScreen extends StatefulWidget {
  final User user;
  final LatLng pickupLocation;
  final LatLng destinationPosition;
  final String selectedVehicleType;
  final bool isRental;
  final String rideRequestId;
  final String driverId;
  final RentalPackage? rentalPackage;
  final List<Map<String, dynamic>>? intermediateStops;

  const RideInProgressScreen({
    super.key,
    required this.user,
    required this.pickupLocation,
    required this.destinationPosition,
    required this.selectedVehicleType,
    required this.isRental,
    required this.rideRequestId,
    required this.driverId,
    this.rentalPackage,
    this.intermediateStops,
  });

  @override
  State<RideInProgressScreen> createState() => _RideInProgressScreenState();
}

class _RideInProgressScreenState extends State<RideInProgressScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  GoogleMapController? _liveMapController;
  final RideController _rideController = RideController.instance;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  String? _startRidePin;
  String? _endRidePin;
  String? _dailySafetyPin;
  bool _isRideStarted = false;

  String get _currentRideStatus => _rideController.rideStatus.value;
  Driver? get _driver => _rideController.assignedDriver.value;

  late LatLng _currentPickupLocation;
  LatLng? _pickupLocation;
  LatLng get pickupLocation => _pickupLocation ?? widget.pickupLocation;

  LatLng? _destinationLocation;
  LatLng get destinationLocation =>
      _destinationLocation ?? widget.destinationPosition;

  bool _isEditingPickup = false;
  late LatLng _newlyAdjustedPickup;
  String _pickupAddress = "Fetching address...";
  String _destinationAddress = "Fetching address...";

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  Timer? _driverMoveTimer;
  late final String _apiKey;
  List<LatLng> _routePointsToPickup = [];
  List<LatLng> _routePointsToDestination = [];
  bool _driverHasArrived = false;
  bool _isMapReady = false; // Flag to delay map rendering
  bool _isCameraLocked = true; // Auto-follow driver by default
  bool _isAnimating = false; // To distinguish gestures
  Key _sliderKey = UniqueKey(); // To reset slider

  Timer? _waitingTimer;
  int _elapsedSeconds = 0;
  final int _freeWaitingTimeSeconds = 180;

  late final LocationService _locationService;
  late final DirectionsService _directionsService;

  StreamSubscription? _statusSub;
  StreamSubscription? _driverSub;
  final ValueNotifier<double> _sheetExtentNotifier = ValueNotifier(
    0.45,
  ); // **FIX:** Initialize at declaration
  @override
  void initState() {
    super.initState();
    // _sheetExtentNotifier initialized at declaration
    _currentPickupLocation = widget.pickupLocation;
    _pickupLocation = widget.pickupLocation; // Initialize _pickupLocation
    _newlyAdjustedPickup = widget.pickupLocation;
    _apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    _locationService = LocationService(apiKey: _apiKey);
    _directionsService = DirectionsService(apiKey: _apiKey);
    // Defer heavy initialization and map rendering
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _isMapReady = true);
        _setupInitialMapState();
        _fetchRideDetails(); // Ensure we get the PINs
      }
    });

    // **FIX:** Support rental requests collection
    _rideController.listenToRideStatus(
      widget.rideRequestId,
      isRental: widget.isRental,
    );
    _rideController.listenToDriverLocation(widget.driverId);

    _statusSub = _rideController.rideStatus.listen(_handleRideStatusChange);
    _driverSub = _rideController.assignedDriver.listen((d) {
      if (d != null) _updateDriverMarker(d);
    });

    // Check initial status
    final currentStatus = _rideController.rideStatus.value;
    if (currentStatus == 'arrived') {
      _driverHasArrived = true;
      _startWaitingTimer();
    } else if (currentStatus == 'started' || currentStatus == 'on_trip') {
      _driverHasArrived = true;
      _isRideStarted = true;
    }
  }

  Future<void> _setupInitialMapState() async {
    try {
      await _loadInitialAddresses();
      _setupMarkers();
      if (_driver != null) {
        await _getDriverToPickupRoute();
        if (!widget.isRental && _isRideStarted) {
          await _getPickupToDestinationRoute();
        }
        _animateCameraToBounds();
      }
    } catch (e) {
      debugPrint("Error in _setupInitialMapState: $e");
    }
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _driverSub?.cancel();
    _driverMoveTimer?.cancel();
    _waitingTimer?.cancel();
    _sheetController.dispose();
    _sheetExtentNotifier.dispose(); // **FIX:** Dispose here
    super.dispose();
  }

  void _handleRideStatusChange(String rawStatus) async {
    if (!mounted) return;
    final status = rawStatus.toLowerCase();
    if (status == 'arrived' && !_driverHasArrived) {
      setState(() => _driverHasArrived = true);
      _startWaitingTimer();
      if (!widget.isRental) {
        // Ensure map is ready before routing
        if (_mapController.isCompleted) {
          await _getPickupToDestinationRoute();
        }
      }
      if (_mapController.isCompleted) {
        _animateCameraToBounds();
      }
      if (mounted) {
        Get.snackbar(
          "Driver Arrived",
          "Your driver has reached the pickup location.",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.black.withValues(alpha: 0.6),
          colorText: Colors.white,
          margin: const EdgeInsets.all(10),
          borderRadius: 20,
          barBlur: 10,
          icon: const Icon(Icons.info_outline, color: Colors.white),
          duration: const Duration(seconds: 4),
        );
      }
    } else if (status == 'started' && !_isRideStarted) {
      setState(() => _isRideStarted = true);
      _waitingTimer?.cancel();
      // Ensure map is ready before routing
      if (_mapController.isCompleted) {
        // Clear pickup route first
        setState(() {
          _polylines.removeWhere((p) => p.polylineId.value == 'driver_route');
        });
        await _getDriverToDestinationRoute(); // Switch to destination route
        _animateCameraToBounds();
      }
      if (mounted) {
        Get.snackbar(
          "Ride Started",
          "Enjoy your ride! Tracking destination...",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.deepPurple,
          colorText: Colors.white,
          margin: const EdgeInsets.all(10),
          borderRadius: 20,
          icon: const Icon(Icons.local_taxi, color: Colors.white, size: 28),
          shouldIconPulse: true,
          duration: const Duration(seconds: 5),
          boxShadows: [
            BoxShadow(
              color: Colors.deepPurple.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        );
      }
    } else if (status == 'completed') {
      if (mounted) {
        displaySnackBar(context, "Ride Completed!", isError: false);
      }
      _navigateToHome(delaySeconds: 3);
    } else if (status == 'cancelled' || status == 'cancelled_by_driver') {
      if (mounted) {
        displaySnackBar(context, "Ride has been cancelled.");
      }
      _navigateToHome();
    }

    _fetchRideDetails();
  }

  Future<void> _fetchRideDetails() async {
    try {
      String collectionPath = widget.isRental
          ? 'rental_requests'
          : 'ride_requests';
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(widget.rideRequestId)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          if (widget.isRental) {
            _startRidePin = data['startRidePin'];
            _endRidePin = data['endRidePin'];
          } else {
            _dailySafetyPin = data['safetyPin'];
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching ride details: $e");
    }
  }

  void _updateDriverMarker(Driver driver) {
    if (!mounted) return;
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'driver');
      _markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: driver.currentLocation,
          icon: _rideController.getVehicleIcon(driver.vehicleType),
          rotation: driver.bearing,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          infoWindow: const InfoWindow(title: "Your Driver"),
        ),
      );
    });
    // Animate camera to include relevant points (Driver + Pickup/Destination)
    // Only if camera is locked
    if ((_isRideStarted || _driverHasArrived || _driver != null) &&
        _isCameraLocked) {
      _animateCameraToBounds();
    }
  }

  void _setupMarkers() {
    if (!mounted) return;
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _currentPickupLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(title: "Pickup", snippet: _pickupAddress),
        ),
      );

      if (_driver != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('driver'),
            position: _driver!.currentLocation,
            icon: _rideController.getVehicleIcon(_driver!.vehicleType),
            infoWindow: InfoWindow(
              title: "Your Driver",
              snippet: _driver!.carNumber,
            ),
            flat: true,
            anchor: const Offset(0.5, 0.5),
          ),
        );
      }

      if (widget.intermediateStops != null) {
        int stopNumber = 1;
        for (var stopData in widget.intermediateStops!) {
          try {
            final locationMap = stopData['location'] as Map<String, dynamic>;
            final lat = locationMap['latitude'] as double;
            final lng = locationMap['longitude'] as double;
            _markers.add(
              Marker(
                markerId: MarkerId('stop_$stopNumber'),
                position: LatLng(lat, lng),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange,
                ),
                infoWindow: InfoWindow(
                  title: "Stop $stopNumber",
                  snippet: stopData['address'],
                ),
              ),
            );
            stopNumber++;
          } catch (e) {
            debugPrint("Error adding intermediate stop marker: $e");
          }
        }
      }

      if (!widget.isRental) {
        _markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: widget.destinationPosition,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
            infoWindow: InfoWindow(
              title: "Drop-off",
              snippet: _destinationAddress,
            ),
          ),
        );
      }
    });
  }

  Future<void> _getDriverToPickupRoute() async {
    if (_driver == null || _apiKey.isEmpty) return;
    final RouteDetails? routeDetails = await _directionsService.getDirections(
      _driver!.currentLocation,
      _currentPickupLocation,
    );
    if (mounted && routeDetails != null) {
      setState(() {
        _routePointsToPickup = routeDetails.polylinePoints;
        _polylines.removeWhere((p) => p.polylineId.value == 'driver_route');
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('driver_route'),
            points: routeDetails.polylinePoints,
            color: Colors.amber,
            width: 5,
          ),
        );
      });
    }
  }

  Future<void> _getPickupToDestinationRoute() async {
    if (widget.isRental ||
        _currentPickupLocation == widget.destinationPosition ||
        _apiKey.isEmpty) {
      return;
    }

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

    final RouteDetails? routeDetails = await _directionsService.getDirections(
      _currentPickupLocation,
      widget.destinationPosition,
      intermediates: intermediateLatLngs,
    );

    if (mounted && routeDetails != null) {
      setState(() {
        _routePointsToDestination = routeDetails.polylinePoints;
        _polylines.removeWhere((p) => p.polylineId.value == 'ride_route');
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('ride_route'),
            points: routeDetails.polylinePoints,
            color: Colors.blueAccent,
            width: 5,
          ),
        );
      });
    }
  }

  Future<void> _animateDriverCamera() async {
    if (_liveMapController == null || _driver == null) return;
    final GoogleMapController controller = _liveMapController!;
    if (!mounted) return;
    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _driver!.currentLocation,
            zoom: 17.5,
            tilt: 30.0,
          ),
        ),
      );
    } catch (e) {
      debugPrint("Driver camera animation failed: $e");
    }
  }

  Future<void> _loadInitialAddresses() async {
    final results = await Future.wait([
      _locationService.getAddressFromLatLng(_currentPickupLocation),
      if (!widget.isRental)
        _locationService.getAddressFromLatLng(widget.destinationPosition)
      else
        Future.value("N/A for Rental"),
    ]);
    if (mounted) {
      setState(() {
        _pickupAddress = results[0];
        if (!widget.isRental) _destinationAddress = results[1];
      });
    }
  }

  void _onConfirmNewPickup() async {
    if (!mounted) return;
    LatLng oldPickup = _currentPickupLocation;
    setState(() {
      _currentPickupLocation = _newlyAdjustedPickup;
      _pickupLocation = _newlyAdjustedPickup; // Sync _pickupLocation
      _isEditingPickup = false;
      _markers.removeWhere((m) => m.markerId.value == 'pickup');
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _currentPickupLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
      _polylines.removeWhere((p) => p.polylineId.value == 'driver_route');
      _pickupAddress = "Fetching address...";
    });

    if (!_locationService.areLocationsClose(
      oldPickup,
      _currentPickupLocation,
      toleranceInMeters: 10,
    )) {
      await _getDriverToPickupRoute();
    } else {
      if (!widget.isRental && _routePointsToDestination.isNotEmpty) {
        setState(
          () => _polylines.add(
            Polyline(
              polylineId: const PolylineId('ride_route'),
              points: _routePointsToDestination,
              color: Colors.blueAccent,
              width: 5,
            ),
          ),
        );
      }
    }
    _animateCameraToBounds();

    final newAddress = await _locationService.getAddressFromLatLng(
      _currentPickupLocation,
    );
    if (mounted) {
      setState(() => _pickupAddress = newAddress);
    }

    try {
      String collectionPath = widget.isRental
          ? 'rental_requests'
          : 'ride_requests';
      await FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(widget.rideRequestId)
          .update({
            'pickupLocation': GeoPoint(
              _currentPickupLocation.latitude,
              _currentPickupLocation.longitude,
            ),
            'pickupAddress': newAddress,
          });
    } catch (e) {
      debugPrint("Error updating pickup location: $e");
    }
  }

  void _animateCameraToBounds() async {
    if (_liveMapController == null || _driver == null) return;
    final GoogleMapController controller = _liveMapController!;
    if (!mounted) return;

    List<LatLng> allPoints = [];
    allPoints.add(_driver!.currentLocation);

    if (_isRideStarted) {
      if (!widget.isRental) {
        allPoints.add(widget.destinationPosition);
        if (widget.intermediateStops != null) {
          for (var stopData in widget.intermediateStops!) {
            final locationMap = stopData['location'] as Map<String, dynamic>;
            allPoints.add(
              LatLng(
                locationMap['latitude'] as double,
                locationMap['longitude'] as double,
              ),
            );
          }
        }
      }
    } else {
      allPoints.add(_currentPickupLocation);
    }

    try {
      if (allPoints.length == 1) {
        _isAnimating = true;
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(allPoints[0], 16.0),
        );
        _isAnimating = false;
        return;
      }

      LatLng southwest = LatLng(
        allPoints.map((p) => p.latitude).reduce(min),
        allPoints.map((p) => p.longitude).reduce(min),
      );
      LatLng northeast = LatLng(
        allPoints.map((p) => p.latitude).reduce(max),
        allPoints.map((p) => p.longitude).reduce(max),
      );

      LatLngBounds bounds = LatLngBounds(
        southwest: southwest,
        northeast: northeast,
      );
      Future.delayed(const Duration(milliseconds: 100), () async {
        if (mounted) {
          try {
            _isAnimating = true;
            await controller.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 100.0),
            );
            _isAnimating = false;
          } catch (e) {
            try {
              LatLng center = LatLng(
                (southwest.latitude + northeast.latitude) / 2,
                (southwest.longitude + northeast.longitude) / 2,
              );
              await controller.animateCamera(
                CameraUpdate.newLatLngZoom(center, 16.0),
              );
              _isAnimating = false;
            } catch (e) {
              debugPrint("Map animation failed: $e");
              _isAnimating = false;
            }
          }
        }
      });
    } catch (e) {
      debugPrint("Immediate map animation failed: $e");
      _isAnimating = false;
    }
  }

  void _startWaitingTimer() {
    _waitingTimer?.cancel();
    _elapsedSeconds = 0;
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _elapsedSeconds++);
      if (_isRideStarted || _currentRideStatus.contains('cancelled')) {
        timer.cancel();
      }
    });
  }

  Future<void> _showCancelConfirmationDialog() async {
    if (_isRideStarted || _currentRideStatus == 'completed') {
      displaySnackBar(context, "Cannot cancel ride after it has started.");
      setState(() => _sliderKey = UniqueKey()); // Reset slider
      return;
    }

    String content = 'Are you sure you want to cancel this ride request?';
    if (_driverHasArrived) {
      content +=
          '\n\nSince the driver has arrived, a cancellation fee of ₹30 will be deducted from your wallet.';
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Ride?'),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('No'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () => Get.back(result: true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      if (_driverHasArrived) {
        await _deductCancellationFee();
      }
      _cancelRideByUser();
    } else {
      // Reset slider if cancelled or dismissed
      setState(() => _sliderKey = UniqueKey());
    }
  }

  Future<void> _cancelRideByUser() async {
    _waitingTimer?.cancel();
    _driverMoveTimer?.cancel();
    try {
      String collectionPath = widget.isRental
          ? 'rental_requests'
          : 'ride_requests';
      await FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(widget.rideRequestId)
          .update({'status': 'cancelled'});
      if (mounted) {
        displaySnackBar(
          context,
          "Ride cancelled successfully.",
          isError: false,
        );
      }
      _navigateToHome();
    } catch (e) {
      if (mounted) {
        displaySnackBar(context, "Error cancelling ride.");
      }
      _navigateToHome();
    }
  }

  Future<void> _getDriverToDestinationRoute() async {
    if (_driver == null || widget.isRental || _apiKey.isEmpty) return;

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

    final RouteDetails? routeDetails = await _directionsService.getDirections(
      _driver!.currentLocation,
      widget.destinationPosition,
      intermediates: intermediateLatLngs,
    );

    if (mounted && routeDetails != null) {
      setState(() {
        _routePointsToDestination = routeDetails.polylinePoints;
        // Clear pickup route
        _polylines.removeWhere((p) => p.polylineId.value == 'driver_route');
        // Update ride route
        _polylines.removeWhere((p) => p.polylineId.value == 'ride_route');
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('ride_route'),
            points: routeDetails.polylinePoints,
            color: Colors.blueAccent,
            width: 5,
          ),
        );
      });
    }
  }

  void _shareRide() async {
    final String message =
        "Track my ride with IndiCabs! \n"
        "Driver: ${_driver?.name ?? 'Assigned Driver'} (${_driver?.carNumber ?? ''})\n"
        "Vehicle: ${_driver?.carModel ?? ''}\n"
        "Status: ${_currentRideStatus.toUpperCase()}\n"
        "Pickup: $_pickupAddress\n"
        "Dropoff: $_destinationAddress\n\n"
        "Track Live: https://projecttaxi-df0d2.web.app/track?id=${widget.rideRequestId}${widget.isRental ? '&type=rental' : ''}";

    // ignore: deprecated_member_use
    await Share.share(message, subject: 'My Ride Details - IndiCabs');
  }

  void _navigateToHome({int delaySeconds = 0}) {
    if (!mounted) return;
    _waitingTimer?.cancel();
    _driverMoveTimer?.cancel();
    Future.delayed(Duration(seconds: delaySeconds), () {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Get.offAll(() => HomePage(user: widget.user));
          }
        });
      }
    });
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final status = _rideController.rideStatus.value;
      final driver = _rideController.assignedDriver.value;

      String displayOtp = "----";
      String otpLabel = "PIN";

      if (widget.isRental) {
        displayOtp = _isRideStarted
            ? (_endRidePin ?? "----")
            : (_startRidePin ?? "----");
        otpLabel = _isRideStarted ? "End Ride PIN" : "Start Ride PIN";
      } else {
        displayOtp = _dailySafetyPin ?? "----";
        otpLabel = "SAFETY PIN";
      }

      return Scaffold(
        backgroundColor: Colors.white,
        appBar: ProAppBar(
          title: Text(
            _isEditingPickup
                ? "Adjust Pickup Location"
                : (_driverHasArrived
                      ? (_isRideStarted
                            ? "Ride In Progress"
                            : "Driver has Arrived")
                      : "Driver is on the way"),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (status == 'accepted' ||
                  status == 'arrived' ||
                  status == 'started') {
                if (mounted) {
                  Get.snackbar(
                    "Ride Minimized",
                    "Ride continues in background. Resume from Ride History.",
                    snackPosition: SnackPosition.TOP,
                    backgroundColor: Colors.blueGrey.shade800,
                    colorText: Colors.white,
                    margin: const EdgeInsets.all(10),
                    borderRadius: 20,
                    icon: const Icon(
                      Icons.layers_outlined,
                      color: Colors.white,
                    ),
                    duration: const Duration(seconds: 4),
                    isDismissible: true,
                    forwardAnimationCurve: Curves.easeOutBack,
                  );
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      Get.offAll(() => HomePage(user: widget.user));
                    }
                  });
                }
              } else {
                _navigateToHome();
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareRide,
              tooltip: "Share Ride Details",
            ),
          ],
        ),
        body: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (status == 'accepted' ||
                status == 'arrived' ||
                status == 'started') {
              if (mounted) {
                Get.snackbar(
                  "Ride Minimized",
                  "Ride continues in background. Resume from Ride History.",
                  snackPosition: SnackPosition.TOP,
                  backgroundColor: Colors.blueGrey.shade800,
                  colorText: Colors.white,
                  margin: const EdgeInsets.all(10),
                  borderRadius: 20,
                  icon: const Icon(Icons.layers_outlined, color: Colors.white),
                  duration: const Duration(seconds: 4),
                  isDismissible: true,
                  forwardAnimationCurve: Curves.easeOutBack,
                );
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    Get.offAll(() => HomePage(user: widget.user));
                  }
                });
              }
            } else {
              _navigateToHome();
            }
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double availableHeight = constraints.maxHeight;
              return Stack(
                children: [
                  if (!_isMapReady)
                    const Center(child: CircularProgressIndicator())
                  else
                    // **MODIFIED:** Fixed map padding (CONST) preventing any zoom/shift effect
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: GoogleMap(
                        key: const ValueKey('google_map'),
                        padding: EdgeInsets.only(
                          // Fixed padding for collapsed sheet (approx 280) when not editing
                          bottom: _isEditingPickup ? 0 : 280,
                        ),
                        initialCameraPosition: CameraPosition(
                          target:
                              driver?.currentLocation ?? widget.pickupLocation,
                          zoom: 16,
                        ),
                        markers: _markers,
                        polylines: _polylines,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        scrollGesturesEnabled: true,
                        zoomGesturesEnabled: true,
                        tiltGesturesEnabled: true,
                        rotateGesturesEnabled: true,
                        onCameraMoveStarted: () {
                          if (!_isAnimating) {
                            setState(() => _isCameraLocked = false);
                          }
                        },
                        onMapCreated: (GoogleMapController controller) {
                          _liveMapController = controller;
                          if (!_mapController.isCompleted) {
                            _mapController.complete(controller);
                          }
                          _animateCameraToBounds();
                        },
                        onCameraMove: _isEditingPickup
                            ? (position) {
                                _newlyAdjustedPickup = position.target;
                                setState(() {
                                  _markers.removeWhere(
                                    (m) => m.markerId.value == 'pickup',
                                  );
                                  _markers.add(
                                    Marker(
                                      markerId: const MarkerId('pickup'),
                                      position: _newlyAdjustedPickup,
                                      icon:
                                          BitmapDescriptor.defaultMarkerWithHue(
                                            BitmapDescriptor.hueGreen,
                                          ),
                                    ),
                                  );
                                });
                              }
                            : null,
                        onCameraIdle: _isEditingPickup
                            ? () async {
                                final newAddress = await _locationService
                                    .getAddressFromLatLng(_newlyAdjustedPickup);
                                if (mounted) {
                                  setState(() => _pickupAddress = newAddress);
                                }
                              }
                            : null,
                      ),
                    ),
                  if (_isEditingPickup)
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

                  // **MODIFIED:** Wrap DraggableScrollableSheet in NotificationListener
                  if (!_isEditingPickup)
                    NotificationListener<DraggableScrollableNotification>(
                      onNotification: (notification) {
                        // Update the notifier with the current extent
                        _sheetExtentNotifier.value = notification.extent;
                        return true;
                      },
                      child: _buildDriverDetailsCard(displayOtp, otpLabel),
                    )
                  else
                    _buildConfirmNewPickupButton(),

                  if (!_isEditingPickup)
                    // **MODIFIED:** Position floating button relative to sheet top using ValueListenableBuilder
                    ValueListenableBuilder<double>(
                      valueListenable: _sheetExtentNotifier,
                      builder: (context, sheetExtent, child) {
                        return Positioned(
                          bottom: (availableHeight * sheetExtent) + 16,
                          right: 16,
                          child: FloatingActionButton(
                            mini: true,
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            onPressed: () {
                              setState(() => _isCameraLocked = true);
                              _animateCameraToBounds();
                            },
                            child: Icon(
                              _isCameraLocked
                                  ? Icons.gps_fixed
                                  : Icons.gps_not_fixed,
                              color: _isCameraLocked
                                  ? Colors.blue
                                  : Colors.black54,
                            ),
                          ),
                        );
                      },
                    ),

                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: LiftableBannerAd(),
                  ),
                ],
              );
            },
          ),
        ),
      );
    });
  }

  Widget _buildDriverDetailsCard(String displayOtp, String otpLabel) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor = isDark ? Colors.grey[900]! : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color subTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    if (_driver == null) {
      return Positioned(
        bottom: 30, // Above banner ad
        left: 0,
        right: 0,
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    String timerText = '';
    Color timerColor = textColor;
    if (_driverHasArrived && !_isRideStarted) {
      int remainingSeconds = _freeWaitingTimeSeconds - _elapsedSeconds;
      if (remainingSeconds > 0) {
        int minutes = remainingSeconds ~/ 60;
        int seconds = remainingSeconds % 60;
        timerText =
            "Free wait time ends in ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
        timerColor = Colors.green.shade700;
      } else {
        int overageSeconds = _elapsedSeconds - _freeWaitingTimeSeconds;
        int minutes = overageSeconds ~/ 60;
        int seconds = overageSeconds % 60;
        timerText =
            "Waiting charge applies: ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} (₹5/min)";
        timerColor = Colors.red.shade700;
      }
    }

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.45,
      minChildSize: 0.20,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              // Handle Bar
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Timer / Status Header
              if (_driverHasArrived)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _isRideStarted
                          ? Colors.blueAccent.withAlpha(30)
                          : timerColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _isRideStarted ? "Ride Started" : timerText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _isRideStarted ? Colors.blueAccent : timerColor,
                      ),
                    ),
                  ),
                ),

              // Ride ID
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: SelectableText(
                    "Ride ID: ${widget.rideRequestId}",
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Driver Info Row
                        Row(
                          children: [
                            // Driver Photo
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: _driver!.photoUrl.isNotEmpty
                                    ? NetworkImage(_driver!.photoUrl)
                                    : null,
                                child: _driver!.photoUrl.isEmpty
                                    ? const Icon(
                                        Icons.person,
                                        size: 30,
                                        color: Colors.grey,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Driver Details Column
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _driver!.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  // Vehicle Details: Brand Model (Number)
                                  Text(
                                    "${_driver!.vehicleBrand.isNotEmpty ? '${_driver!.vehicleBrand} ' : ''}${_driver!.vehicleModel.isNotEmpty ? _driver!.vehicleModel : _driver!.carModel} (${_driver!.carNumber})",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: subTextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  // Vehicle Class Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent.withAlpha(20),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.blueAccent.withAlpha(50),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Text(
                                      _driver!
                                          .vehicleType, // This now maps to vehicleClass (e.g. Sedan)
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Chat Button
                            Container(
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withAlpha(30),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.chat,
                                  color: Colors.blueAccent,
                                ),
                                onPressed: () {
                                  Get.to(
                                    () => ChatScreen(
                                      rideId: widget.rideRequestId,
                                      rideCollectionPath: widget.isRental
                                          ? 'rental_requests'
                                          : 'ride_requests',
                                      currentUserId: widget.user.uid,
                                      recipientId: _driver!.id,
                                      recipientName: _driver!.name,
                                    ),
                                  );
                                },
                              ),
                            ),
                            // Call Button
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.green.withAlpha(30),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.phone,
                                  color: Colors.green,
                                ),
                                onPressed: () async {
                                  final Uri launchUri = Uri(
                                    scheme: 'tel',
                                    path: _driver!.phoneNumber,
                                  );
                                  if (await canLaunchUrl(launchUri)) {
                                    await launchUrl(launchUri);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 10),

                        // OTP / PIN Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  otpLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: subTextColor,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  displayOtp,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                              ],
                            ),
                            // Vehicle Type Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withAlpha(20),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blueAccent.withAlpha(50),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _getVehicleIcon(widget.selectedVehicleType),
                                    size: 16,
                                    color: Colors.blueAccent,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.selectedVehicleType,
                                    style: const TextStyle(
                                      color: Colors.blueAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Rental Badge
                            if (widget.isRental)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withAlpha(20),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.orange.withAlpha(50),
                                    ),
                                  ),
                                  child: const Text(
                                    "Rental",
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        // **NEW:** Rental Timer Slider
                        if (widget.isRental && _isRideStarted)
                          Obx(() {
                            final rideData = _rideController.rideData;
                            final startedAt = rideData['startedAt'];
                            final durationHours =
                                rideData['durationHours'] as int? ?? 1;

                            // Distance Data (prioritize widget.rentalPackage, then rideData)
                            double maxDistanceKm = 80.0;
                            if (widget.rentalPackage != null) {
                              maxDistanceKm = widget.rentalPackage!.kmLimit
                                  .toDouble();
                            } else {
                              final maxDistVal =
                                  rideData['kmLimit'] ??
                                  rideData['maxDistanceKm'] ??
                                  rideData['packageDistance'];
                              if (maxDistVal != null) {
                                maxDistanceKm =
                                    double.tryParse(maxDistVal.toString()) ??
                                    80.0;
                              }
                            }

                            final currentDist =
                                (rideData['distanceTravelled'] ?? 0).toString();
                            final double currentDistanceKm =
                                double.tryParse(currentDist) ?? 0.0;

                            if (startedAt != null) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 12.0),
                                child: RentalProgressWidget(
                                  startedAt: startedAt,
                                  durationHours: durationHours,
                                  maxDistanceKm: maxDistanceKm,
                                  currentDistanceKm: currentDistanceKm,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          }),
                        const SizedBox(height: 10),
                        // Fare Display
                        Obx(() {
                          final fare = _rideController.rideData['fare'];
                          if (fare != null) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Total Fare",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  Text(
                                    "₹$fare",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }),
                        // Payment Method Display
                        Obx(() {
                          final paymentMethod =
                              _rideController.rideData['paymentMethod'] ??
                              'Cash';
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Payment Method",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight
                                        .w500, // Slightly less bold than Total Fare
                                    color: textColor,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withAlpha(20),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.blue.withAlpha(50),
                                    ),
                                  ),
                                  child: Text(
                                    paymentMethod.toString().toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 20),

                        // **NEW:** Add Stop Button for Active Rentals
                        if (widget.isRental && _isRideStarted)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _handleAddStop,
                                icon: const Icon(Icons.add_location_alt),
                                label: const Text("Add Stop"),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // **NEW:** Active Stop Display
                        if (widget.isRental && _isRideStarted)
                          Obx(() {
                            final rideData = _rideController.rideData;
                            final stops = rideData['stops'] as List<dynamic>?;

                            if (stops != null && stops.isNotEmpty) {
                              // Find the last pending stop
                              final pendingStops = stops
                                  .where((s) => s['status'] == 'pending')
                                  .toList();

                              if (pendingStops.isNotEmpty) {
                                final activeStop = pendingStops.last;
                                final address =
                                    activeStop['address'] as String? ??
                                    "Unknown Location";

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.3,
                                        ),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.05,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.stop_circle_outlined,
                                              color: AppColors.primary,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              "Current Stop",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          address,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                            }
                            return const SizedBox.shrink();
                          }),

                        // Location Info
                        if (!(widget.isRental && _isRideStarted))
                          _buildLocationRow(
                            Icons.my_location,
                            "Pickup",
                            _pickupAddress,
                            onEdit: () => _handleEditLocation(true),
                          ),
                        const SizedBox(height: 16),
                        if (!widget.isRental)
                          _buildLocationRow(
                            Icons.location_on,
                            "Drop-off",
                            _destinationAddress,
                            onEdit: () => _handleEditLocation(false),
                          ),
                        // Cancel Button (only if not started)
                        if (!_isRideStarted &&
                            _currentRideStatus != 'started' &&
                            _currentRideStatus != 'on_trip') ...[
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: SlideToCancel(
                              key: _sliderKey,
                              label: "Slide to Cancel Ride",
                              onCancelled: () {
                                _showCancelConfirmationDialog();
                              },
                            ),
                          ),
                        ],

                        // --- Placeholder for Future Ads ---
                        Container(
                          height: 300,
                          alignment: Alignment.center,
                          margin: const EdgeInsets.only(top: 40),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black12
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.ad_units_outlined,
                                size: 40,
                                color: subTextColor.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Ad Space Placeholder",
                                style: TextStyle(
                                  color: subTextColor.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Extra padding to ensure content isn't hidden by bottom insets
                        SizedBox(
                          height: 50 + MediaQuery.of(context).padding.bottom,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int _destinationEditCount = 0; // Track edits

  Future<void> _handleEditLocation(bool isPickup) async {
    // Check edit limit for destination
    if (!isPickup) {
      if (_destinationEditCount >= 3) {
        if (mounted) {
          displaySnackBar(
            context,
            "You can only edit the drop location 3 times.",
            isError: true,
          );
        }
        return;
      }
    }

    final initialLocation = isPickup
        ? pickupLocation // Getter is non-nullable
        : destinationLocation; // Use persistent state

    final result = await Get.to(
      () => EditLocationScreen(initialLocation: initialLocation),
    );

    if (result != null && result is Map) {
      final LatLng newLocation = result['location'];
      final String newAddress = result['address'];

      debugPrint("Edit Location Result: $newAddress, $newLocation");

      setState(() {
        if (isPickup) {
          _pickupAddress = newAddress;
          _pickupLocation = newLocation;
        } else {
          _destinationAddress = newAddress;
          _destinationLocation = newLocation; // Update persistent state
          _destinationEditCount++; // Increment count
        }
      });

      // Recalculate Fare (as per user request: based on pickup location)
      // Even if editing destination, we use the current pickup location.
      final LatLng currentPickup = pickupLocation;

      final LatLng targetPickup = isPickup ? newLocation : currentPickup;
      final LatLng targetDestination = isPickup
          ? destinationLocation
          : newLocation;

      // Handle the case where we edited pickup: destination remains widget.destination (or should we track _destinationLocation too? For now, ride_in_progress usually has fixed destination unless edited)
      // Actually, if we edit pickup, destination is widget.destinationPosition. // OLD logic (commented out explanation)
      // If we edit destination, pickup is currentPickup.

      // Removed duplicate definitions

      try {
        debugPrint(
          "Recalculating fare from $targetPickup to $targetDestination",
        );

        debugPrint("Calling calculateFares...");
        final newFares = await _rideController.calculateFare(
          pickup: targetPickup,
          destination: targetDestination,
        );

        debugPrint("Cloud Function response (newFares): $newFares");
        debugPrint("Selected Vehicle Type: '${widget.selectedVehicleType}'");

        if (newFares != null) {
          String vehicleType = widget.selectedVehicleType;

          // Debug keys available
          debugPrint("Available keys in newFares: ${newFares.keys.toList()}");

          // Fix: If type is generic "Ride" or not found, try to find correct type from live data
          if (vehicleType == 'Ride' || !newFares.containsKey(vehicleType)) {
            final rideData = _rideController.rideData;
            debugPrint(
              "Checking rideData for vehicle type... Current rideData keys: ${rideData.keys}",
            );

            final classFromData = rideData['vehicleClass'] as String?;
            final typeFromData = rideData['vehicleType'] as String?;

            if (classFromData != null && newFares.containsKey(classFromData)) {
              vehicleType = classFromData;
              debugPrint(
                "Recovered vehicle type from rideData (vehicleClass): $vehicleType",
              );
            } else if (typeFromData != null &&
                newFares.containsKey(typeFromData)) {
              vehicleType = typeFromData;
              debugPrint(
                "Recovered vehicle type from rideData (vehicleType): $vehicleType",
              );
            } else if (newFares.containsKey('Sedan')) {
              // Ultimate fallback if 'Ride' is completely ambiguous but likely basic car
              vehicleType = 'Sedan';
              debugPrint("Fallback to default 'Sedan'");
            }
          }

          // Try exact match, then case-insensitive match
          num? newFare = newFares[vehicleType];

          if (newFare == null) {
            debugPrint("Exact match failed. Trying case-insensitive...");
            final lowerType = vehicleType.toLowerCase();
            final entry = newFares.entries.firstWhere(
              (e) => e.key.toLowerCase() == lowerType,
              orElse: () => const MapEntry('', -1),
            );

            if (entry.value != -1) {
              newFare = entry.value;
              debugPrint(
                "Found case-insensitive match: '${entry.key}' -> $newFare",
              );
            }
          }

          if (newFare != null) {
            debugPrint("Updating fare to: $newFare");

            // Update Firestore
            final updateData = <String, dynamic>{'fare': newFare};

            if (isPickup) {
              updateData['pickup'] = {
                'latitude': newLocation.latitude,
                'longitude': newLocation.longitude,
              };
              updateData['pickupAddress'] = newAddress;
            } else {
              updateData['destination'] = {
                'latitude': newLocation.latitude,
                'longitude': newLocation.longitude,
              };
              updateData['destinationAddress'] = newAddress;
            }

            await FirebaseFirestore.instance
                .collection('ride_requests')
                .doc(widget.rideRequestId)
                .update(updateData);

            if (mounted) {
              displaySnackBar(
                context,
                "Location updated. New fare: ₹$newFare",
                isError: false,
              );
            }
          } else {
            debugPrint("Fare not found for vehicle type: $vehicleType");
          }
        }
      } catch (e) {
        debugPrint("Error updating location/fare: $e");
        if (mounted) {
          displaySnackBar(context, "Error updating fare: $e", isError: true);
        }
      }
    }
  }

  Future<void> _deductCancellationFee() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        if (!snapshot.exists) return;

        final double currentBalance =
            (snapshot.data()?['wallet_balance'] as num?)?.toDouble() ?? 0.0;
        final double newBalance = currentBalance - 30.0;

        transaction.update(userRef, {'wallet_balance': newBalance});

        // Optional: Add to payment history
        final historyRef = userRef.collection('payment_history').doc();
        transaction.set(historyRef, {
          'amount': 30.0,
          'type': 'debit',
          'description': 'Cancellation Fee',
          'createdAt': FieldValue.serverTimestamp(),
          'is_cancellation_fee': true,
        });
      });

      if (mounted) {
        displaySnackBar(
          context,
          "₹30 cancellation fee deducted.",
          isError: true,
        );
      }
    } catch (e) {
      debugPrint("Error deducting cancellation fee: $e");
    }
  }

  Widget _buildLocationRow(
    IconData icon,
    String label,
    String location, {
    VoidCallback? onEdit,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color subTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Row(
      children: [
        Icon(icon, color: subTextColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: subTextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                location,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(fontSize: 14, color: textColor),
              ),
            ],
          ),
        ),
        if (onEdit != null)
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              size: 20,
              color: Colors.blueAccent,
            ),
            onPressed: onEdit,
            tooltip: 'Edit Location',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }

  Widget _buildConfirmNewPickupButton() {
    return Positioned(
      bottom: 30, // Above banner ad
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: Text(
              "Confirm Pickup: $_pickupAddress",
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            onPressed: _onConfirmNewPickup,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getVehicleIcon(String type) {
    switch (type.toLowerCase()) {
      case 'bike':
        return Icons.two_wheeler;
      case 'auto':
        return Icons.electric_rickshaw;
      case 'sedan':
        return Icons.directions_car;
      case 'suv':
        return Icons.airport_shuttle;
      default:
        return Icons.directions_car;
    }
  }

  Future<void> _handleAddStop() async {
    final currentLocation = _rideController.currentPosition.value;
    if (currentLocation == null) {
      displaySnackBar(context, "Waiting for current location...");
      return;
    }

    final result = await Get.to(
      () => EditLocationScreen(initialLocation: currentLocation),
    );

    if (result != null && result is Map) {
      final location = result['location'] as LatLng;
      final address = result['address'] as String;

      try {
        await _rideController.addRentalStop(
          widget.rideRequestId,
          location,
          address,
        );
        if (mounted) {
          displaySnackBar(context, "Stop added successfully!");
        }
      } catch (e) {
        if (mounted) {
          displaySnackBar(context, "Failed to add stop: $e");
        }
      }
    }
  }
}
