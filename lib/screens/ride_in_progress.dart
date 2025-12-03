// ignore_for_file: unused_field, unused_element, unnecessary_to_list_in_spreads, use_build_context_synchronously

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart' hide Route;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:project_taxi_with_ai/widgets/data_models.dart';
import 'package:project_taxi_with_ai/widgets/directions_service.dart';
import 'package:project_taxi_with_ai/widgets/location_service.dart';

import '../widgets/snackbar.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';
import 'package:project_taxi_with_ai/app_colors.dart';
import 'home_page.dart';
import 'chat_box.dart';
import 'package:project_taxi_with_ai/controllers/ride_controller.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:project_taxi_with_ai/widgets/slide_to_cancel.dart';
import 'edit_location.dart';

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
  bool _isEditingPickup = false;
  late LatLng _newlyAdjustedPickup;
  String _pickupAddress = "Fetching address...";
  String _destinationAddress = "Fetching address...";

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
  @override
  void initState() {
    super.initState();
    _currentPickupLocation = widget.pickupLocation;
    _pickupLocation = widget.pickupLocation; // Initialize _pickupLocation
    _newlyAdjustedPickup = widget.pickupLocation;
    _apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    _locationService = LocationService(apiKey: _apiKey);
    _directionsService = DirectionsService(apiKey: _apiKey);
    _startRidePin = widget.rideRequestId.substring(0, 4);

    // Defer heavy initialization and map rendering
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _isMapReady = true);
        _setupInitialMapState();
      }
    });

    _rideController.listenToRideStatus(widget.rideRequestId);
    _rideController.listenToDriverLocation(widget.driverId);

    _statusSub = _rideController.rideStatus.listen(_handleRideStatusChange);
    _driverSub = _rideController.assignedDriver.listen((d) {
      if (d != null) _updateDriverMarker(d);
    });
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
    super.dispose();
  }

  void _handleRideStatusChange(String status) async {
    if (!mounted) return;
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
        displaySnackBar(context, "Driver has arrived at pickup location.");
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
        displaySnackBar(context, "Ride started!");
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
    if (!_mapController.isCompleted || _driver == null) return;
    final GoogleMapController controller = await _mapController.future;
    if (!mounted) return;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _driver!.currentLocation,
          zoom: 17.5,
          tilt: 30.0,
        ),
      ),
    );
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
    if (!_mapController.isCompleted || _driver == null) return;
    final GoogleMapController controller = await _mapController.future;
    if (!mounted) return;

    List<LatLng> allPoints = [];
    allPoints.add(_driver!.currentLocation);

    if (_isRideStarted) {
      // If ride started, focus on Driver -> Destination
      if (!widget.isRental) {
        allPoints.add(widget.destinationPosition);
        if (widget.intermediateStops != null) {
          // Optionally add intermediate stops if needed, or just focus on final destination
          // for now let's keep them to ensure they are in view if close
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
      // If ride not started (on way to pickup or arrived), focus on Driver -> Pickup
      allPoints.add(_currentPickupLocation);
    }

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
          LatLng center = LatLng(
            (southwest.latitude + northeast.latitude) / 2,
            (southwest.longitude + northeast.longitude) / 2,
          );
          await controller.animateCamera(
            CameraUpdate.newLatLngZoom(center, 16.0),
          );
          _isAnimating = false;
        }
      }
    });
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

  void _shareRide() {
    final String message =
        "Track my ride with IndiCabs! \n"
        "Driver: ${_driver?.name ?? 'Assigned Driver'} (${_driver?.carNumber ?? ''})\n"
        "Vehicle: ${_driver?.carModel ?? ''}\n"
        "Status: ${_currentRideStatus.toUpperCase()}\n"
        "Pickup: $_pickupAddress\n"
        "Dropoff: $_destinationAddress";

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.message),
                title: const Text('Share via SMS'),
                onTap: () async {
                  Navigator.pop(context);
                  final Uri smsUri = Uri(
                    scheme: 'sms',
                    path: '',
                    queryParameters: <String, String>{'body': message},
                  );
                  if (await canLaunchUrl(smsUri)) {
                    await launchUrl(smsUri);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy to Clipboard'),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: message));
                  displaySnackBar(context, "Ride details copied to clipboard!");
                },
              ),
            ],
          ),
        );
      },
    );
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
                  displaySnackBar(
                    context,
                    "Ride continues in background. Resume from Ride History.",
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
                displaySnackBar(
                  context,
                  "Ride continues in background. Resume from Ride History.",
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
          child: Stack(
            children: [
              if (!_isMapReady)
                const Center(child: CircularProgressIndicator())
              else
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: driver?.currentLocation ?? widget.pickupLocation,
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
                    // Google Maps Flutter 2.x onCameraMoveStarted callback doesn't provide reason in some versions or I might be using it wrong.
                    // Actually, looking at the docs, it might be `void Function()?`.
                    // Let's assume any move start is a gesture for now if we can't get the reason,
                    // BUT `onCameraMoveStarted` usually doesn't pass arguments.
                    // `onCameraMove` passes position.
                    // If we can't distinguish, we might need another way.
                    // However, usually `onCameraMoveStarted` is void.
                    // Let's check if we can use `onCameraMove` to detect user interaction? No.
                    // Let's just set locked to false on ANY camera move start?
                    // That would break auto-zoom.
                    // Wait, `google_maps_flutter` usually supports `CameraMoveStartedReason` in `onCameraMoveStarted`?
                    // No, it seems `onCameraMoveStarted` is `VoidCallback`.
                    // `onCameraIdle` is `VoidCallback`.
                    // The `reason` is not passed.
                    // So we can't easily distinguish gesture vs animation.
                    // WORKAROUND: We know when WE start an animation (in `_animateCameraToBounds`).
                    // We can set a flag `_isAnimating` = true before animating, and false after.
                    // If `onCameraMoveStarted` triggers and `_isAnimating` is false, it's a gesture.
                    if (!_isAnimating) {
                      setState(() => _isCameraLocked = false);
                    }
                  },
                  onMapCreated: (GoogleMapController controller) {
                    _mapController.complete(controller);
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
                                icon: BitmapDescriptor.defaultMarkerWithHue(
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
              if (!_isEditingPickup)
                _buildDriverDetailsCard(displayOtp, otpLabel)
              else
                _buildConfirmNewPickupButton(),

              // GPS / Recenter Button
              if (!_isEditingPickup)
                Positioned(
                  bottom: 550, // Adjusted to be above the bottom sheet
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
                      _isCameraLocked ? Icons.gps_fixed : Icons.gps_not_fixed,
                      color: _isCameraLocked ? Colors.blue : Colors.black54,
                    ),
                  ),
                ),
            ],
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
    final Color carNumberBgColor = isDark
        ? Colors.grey[800]!
        : Colors.grey[200]!;

    if (_driver == null) {
      return Positioned(
        bottom: 0,
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

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20.0),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
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

            // Driver Info Row
            Row(
              children: [
                // Driver Photo
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _driver!.photoUrl.isNotEmpty
                        ? NetworkImage(_driver!.photoUrl)
                        : null,
                    child: _driver!.photoUrl.isEmpty
                        ? const Icon(Icons.person, size: 30, color: Colors.grey)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                // Driver Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _driver!.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            "${_driver!.carModel} • ",
                            style: TextStyle(color: subTextColor, fontSize: 14),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: carNumberBgColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _driver!.carNumber,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            "4.8",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: textColor,
                            ),
                          ),
                        ],
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
                    icon: const Icon(Icons.chat, color: Colors.blueAccent),
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
                    icon: const Icon(Icons.phone, color: Colors.green),
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
                    border: Border.all(color: Colors.blueAccent.withAlpha(50)),
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
              ],
            ),
            const SizedBox(height: 10),
            // Fare Display
            Obx(() {
              final fare = _rideController.rideData['fare'];
              if (fare != null) {
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            const SizedBox(height: 20),

            // Location Info
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
            if (!_isRideStarted) ...[
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
          ],
        ),
      ),
    );
  }

  Future<void> _handleEditLocation(bool isPickup) async {
    final initialLocation = isPickup
        ? widget.pickupLocation
        : widget.destinationPosition;

    final result = await Get.to(
      () => EditLocationScreen(initialLocation: initialLocation),
    );

    if (result != null && result is Map) {
      final LatLng newLocation = result['location'];
      final String newAddress = result['address'];

      setState(() {
        if (isPickup) {
          _pickupAddress = newAddress;
          _pickupLocation = newLocation;
        } else {
          _destinationAddress = newAddress;
        }
      });

      if (!isPickup) {
        // Recalculate Fare
        final newFares = await _rideController.calculateFare(
          pickup: pickupLocation,
          destination: newLocation,
        );

        if (newFares != null) {
          final newFare = newFares[widget.selectedVehicleType];
          if (newFare != null) {
            // Update Firestore
            await FirebaseFirestore.instance
                .collection('ride_requests')
                .doc(widget.rideRequestId)
                .update({
                  'destination': {
                    'latitude': newLocation.latitude,
                    'longitude': newLocation.longitude,
                  },
                  'destinationAddress': newAddress,
                  'fare': newFare,
                });
            if (mounted) {
              displaySnackBar(
                context,
                "Destination updated. New fare: ₹$newFare",
                isError: false,
              );
            }
          }
        }
      } else {
        // Update Pickup in Firestore
        await FirebaseFirestore.instance
            .collection('ride_requests')
            .doc(widget.rideRequestId)
            .update({
              'pickup': {
                'latitude': newLocation.latitude,
                'longitude': newLocation.longitude,
              },
              'pickupAddress': newAddress,
            });
        if (mounted) {
          displaySnackBar(context, "Pickup location updated.", isError: false);
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
      bottom: 0,
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
}
