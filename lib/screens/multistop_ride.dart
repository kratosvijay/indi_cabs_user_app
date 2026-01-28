import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:project_taxi_with_ai/widgets/data_models.dart';
import 'package:project_taxi_with_ai/widgets/directions_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:project_taxi_with_ai/widgets/map_service.dart';
import 'package:project_taxi_with_ai/widgets/ride_confirm_sheet.dart';
import '../widgets/snackbar.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';
import 'package:project_taxi_with_ai/screens/edit_location.dart';

class MultiStopScreen extends StatefulWidget {
  final User user;
  final LatLng currentPosition;
  final PricingRules? pricingRules;
  final num walletBalance; // **NEW:** Add wallet balance

  const MultiStopScreen({
    super.key,
    required this.user,
    required this.currentPosition,
    required this.pricingRules,
    required this.walletBalance, // **NEW:** Add to constructor
  });

  @override
  State<MultiStopScreen> createState() => _MultiStopScreenState();
}

class _MultiStopScreenState extends State<MultiStopScreen>
    with SingleTickerProviderStateMixin {
  // Services
  late final DirectionsService _directionsService;
  late final MapService _mapService;
  final HttpsCallable _calculateFaresCallable = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  ).httpsCallable('calculateFares');

  // Animation
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  // State for stops
  final TextEditingController _pickupController = TextEditingController();
  final FocusNode _pickupFocusNode = FocusNode();
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];

  // Locations map:
  // -1: Pickup
  // 0..N-1: Stops/Dropoff (matching _controllers index)
  final Map<int, LatLng> _locations = {};
  final Map<int, String> _addresses = {};

  // NOTE: Removed inline predictions logic per request.

  bool _isCalculating = false;

  @override
  void initState() {
    super.initState();
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    // _placesService removed
    _directionsService = DirectionsService(apiKey: apiKey);
    _mapService = MapService();

    // Initialize Pickup
    _locations[-1] = widget.currentPosition;
    _pickupController.text = "Current Location";
    _getAddressForPickup();

    // Initialize with 1 stop (Final Drop-off)
    _addNewStopField(isRemovable: false);

    // Initialize Animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    // Start animation after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _animationController.forward();
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _pickupController.dispose();
    _pickupFocusNode.dispose();
    // _placesService.cancelDebounce(); // No longer needed
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _getAddressForPickup() async {
    if (_pickupController.text.isEmpty ||
        _pickupController.text == "Current Location") {
      if (mounted) {
        setState(() {
          _pickupController.text = "Current Location";
        });
      }
    }
  }

  /// **NEW:** Helper to add listeners to a text field and focus node
  void _addListeners(int index) {
    // No extra listeners needed for now since we rely on onTap
  }

  Future<void> _openMapPicker(int index) async {
    // index -1 for Pickup
    LatLng initialLocation = widget.currentPosition;
    if (_locations.containsKey(index)) {
      initialLocation = _locations[index]!;
    }

    final result = await Get.to<Map<String, dynamic>>(
      () => EditLocationScreen(initialLocation: initialLocation),
    );

    if (result != null && mounted) {
      final LatLng location = result['location'];
      final String address = result['address'];

      setState(() {
        _locations[index] = location;
        _addresses[index] = address;
        if (index == -1) {
          _pickupController.text = address;
        } else {
          _controllers[index].text = address;
        }
      });
    }
  }

  void _addNewStopField({bool isRemovable = true}) {
    final controller = TextEditingController();
    final focusNode = FocusNode();

    int insertIndex = _controllers.length;
    if (isRemovable && _controllers.isNotEmpty) {
      insertIndex =
          _controllers.length - 1; // Insert before the last one (final drop)
    }

    _controllers.insert(insertIndex, controller);
    _focusNodes.insert(insertIndex, focusNode);

    // Shift keys in _locations and _addresses maps if inserting in the middle
    if (isRemovable && _controllers.length > 1) {
      final Map<int, LatLng> newLocations = {};
      final Map<int, String> newAddresses = {};

      _locations.forEach((key, value) {
        if (key >= insertIndex) {
          newLocations[key + 1] = value;
        } else {
          newLocations[key] = value;
        }
      });
      _addresses.forEach((key, value) {
        if (key >= insertIndex) {
          newAddresses[key + 1] = value;
        } else {
          newAddresses[key] = value;
        }
      });

      _locations.clear();
      _locations.addAll(newLocations);
      _addresses.clear();
      _addresses.addAll(newAddresses);
    }

    // Add listener to the new fields
    _addListeners(insertIndex);

    setState(() {});
  }

  void _addStop() {
    if (_controllers.length >= 3) {
      // Max 1 pickup + 2 stops + 1 final drop = 4 locations total, 3 dynamic fields
      displaySnackBar(context, "Maximum 3 stops allowed.");
      return;
    }
    _addNewStopField(isRemovable: true);
  }

  void _removeStop(int index) {
    // Don't allow removing the final drop-off (which is the last item in _controllers)
    if (index == _controllers.length - 1) return;

    setState(() {
      _controllers[index].dispose();
      _focusNodes[index].dispose();
      _controllers.removeAt(index);
      _focusNodes.removeAt(index);
      _locations.remove(index);
      _addresses.remove(index);

      // Shift down keys > index
      final Map<int, LatLng> newLocations = {};
      final Map<int, String> newAddresses = {};

      _locations.forEach((key, value) {
        if (key > index) {
          newLocations[key - 1] = value;
        } else if (key < index) {
          newLocations[key] = value;
        }
      });
      _addresses.forEach((key, value) {
        if (key > index) {
          newAddresses[key - 1] = value;
        } else if (key < index) {
          newAddresses[key] = value;
        }
      });

      _locations.clear();
      _locations.addAll(newLocations);
      _addresses.clear();
      _addresses.addAll(newAddresses);
    });
  }

  Widget _buildPickupNode() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Timeline
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    const SizedBox(height: 24), // Center icon with text field
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? Colors.grey[800]! : Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.my_location,
                          size: 8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                      ],
                      border: Border.all(
                        color: isDark
                            ? Colors.grey[800]!
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: TextField(
                      controller: _pickupController,
                      focusNode: _pickupFocusNode,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      decoration: InputDecoration(
                        hintText: "Pickup Location",
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        suffixIcon: null, // Removed map button
                      ),
                      readOnly: true, // **MODIFIED**
                      onTap: () => _openMapPicker(-1), // **MODIFIED**
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBox(int index, String label) {
    bool isLast = index == _controllers.length - 1;
    bool canRemove = !isLast;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Timeline
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    // Top line (always present to connect to previous)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                      ),
                    ),
                    // Icon
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: isLast ? Colors.red : Colors.grey[400],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? Colors.grey[800]! : Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Center(
                        child: isLast
                            ? const Icon(
                                Icons.stop,
                                size: 8,
                                color: Colors.white,
                              )
                            : Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                      ),
                    ),
                    // Bottom line (only if not last)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isLast
                            ? Colors.transparent
                            : (isDark ? Colors.grey[700] : Colors.grey[300]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Input Field
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                      ],
                      border: Border.all(
                        color: isDark
                            ? Colors.grey[800]!
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      decoration: InputDecoration(
                        hintText: label,
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (canRemove)
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                tooltip: "Remove Stop",
                                onPressed: () => _removeStop(index),
                              ),
                            // Removed Map Button
                          ],
                        ),
                      ),
                      readOnly: true, // **MODIFIED**
                      onTap: () => _openMapPicker(index), // **MODIFIED**
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmBooking() async {
    if (_isCalculating) return;

    // 1. Validate all stops are selected
    // Check Pickup
    if (!_locations.containsKey(-1)) {
      displaySnackBar(context, "Please select a pickup location.");
      return;
    }
    // Check Stops
    for (int i = 0; i < _controllers.length; i++) {
      if (!_locations.containsKey(i)) {
        displaySnackBar(context, "Please select all destinations.");
        return;
      }
    }

    setState(() => _isCalculating = true);

    // Collect waypoints (Stops + Final Drop)
    final List<LatLng> waypoints = [];
    for (int i = 0; i < _controllers.length; i++) {
      waypoints.add(_locations[i]!);
    }

    final LatLng pickup = _locations[-1]!;
    final LatLng finalDrop = waypoints
        .removeLast(); // Remove final drop from waypoints
    final List<LatLng> intermediateLatLngs =
        waypoints; // Remaining are intermediates

    // 2. Get route details (total distance, duration, tolls)
    final routeDetails = await _directionsService.getDirections(
      pickup,
      finalDrop,
      intermediates: intermediateLatLngs,
    );

    if (routeDetails == null) {
      if (mounted) {
        displaySnackBar(context, "Could not find a route for these stops.");
      }
      setState(() => _isCalculating = false);
      return;
    }

    // 3. Calculate fare using Cloud Function
    final faresResult = await _calculateFares(
      distanceMeters: routeDetails.distanceMeters,
      durationSeconds: routeDetails.durationSeconds,
      tollCost: routeDetails.tollCost,
      pickupLocation: pickup,
    );

    if (faresResult == null) {
      if (mounted) {
        displaySnackBar(context, "Could not calculate fares for this route.");
      }
      setState(() => _isCalculating = false);
      return;
    }

    // 4. Add multi-stop surcharge (₹30 per stop, *not* including final drop)
    final multiStopFee = intermediateLatLngs.length * 30;
    final finalFares = faresResult.map(
      (key, value) => MapEntry(key, value + multiStopFee),
    );

    // **NEW:** Create the data structure for intermediate stops
    final List<Map<String, dynamic>> intermediateStopsData = [];
    for (int i = 0; i < intermediateLatLngs.length; i++) {
      intermediateStopsData.add({
        'address': _controllers[i].text, // Stop 1 is at index 0
        'location': {
          // Send as a map, not a GeoPoint
          'latitude': intermediateLatLngs[i].latitude,
          'longitude': intermediateLatLngs[i].longitude,
        },
      });
    }
    final Map<String, bool> availability = {
      'Auto': true,
      'Hatchback': true,
      'Sedan': true,
      'SUV': true,
      'ActingDriver': true,
    };

    setState(() => _isCalculating = false);

    // 5. Show the Ride Confirmation Sheet
    if (mounted) {
      final etaString = "${(routeDetails.durationSeconds / 60).round()} min";
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => RideConfirmationBottomSheet(
          currentUser: widget.user,
          currentPosition: pickup, // Use selected pickup
          destinationPosition: finalDrop, // Show final drop as destination
          pickupAddress: _pickupController.text, // Use edited pickup address
          destinationAddress:
              _controllers.last.text, // Use text from final drop
          isDropoffInServiceArea: true,
          vehicleOptions: VehicleOption.defaultOptions,
          polylines: _mapService.createPolylines(routeDetails.polylinePoints),
          isLoadingFares: false,
          calculatedFares: finalFares,
          eta: etaString,
          routeDetails: routeDetails,
          pricingRules: widget.pricingRules,
          walletBalance: widget.walletBalance, // **NEW:** Pass wallet balance
          intermediateStops: intermediateStopsData, // **NEW:** Pass the stops
          // Multi-stop sheet doesn't support editing/saving this way
          onEditPickup: () => Get.back(), // Allow closing sheet to edit
          onEditDropoff: () => Get.back(),
          onSaveDropoffFavorite: () => displaySnackBar(
            context,
            "Cannot save multi-stop route as favorite.",
            isError: true,
          ),
          onSavePickupFavorite: () => displaySnackBar(
            context,
            "Cannot save pickup as favorite here.",
            isError: true,
          ),
          rideType: RideType.multiStop,
          availability: availability,
        ),
      );
    }
  }

  // --- Cloud Function Call Helper ---
  Future<Map<String, num>?> _calculateFares({
    required int distanceMeters,
    required int durationSeconds,
    required num tollCost,
    required LatLng pickupLocation,
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
      });
      final fares = result.data['fares'] as Map<dynamic, dynamic>?;
      if (fares != null) {
        return fares.map(
          (key, value) => MapEntry(key.toString(), value as num),
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

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Multi-Stop Ride",
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Pickup Location (Static) ---
                  _buildPickupNode(),

                  // --- Dynamic Stops List ---
                  ListView.builder(
                    itemCount: _controllers.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      String label;
                      if (index == _controllers.length - 1) {
                        label = "Final Drop-off";
                      } else {
                        label = "Stop ${index + 1}";
                      }
                      return _buildSearchBox(index, label);
                    },
                  ),

                  // --- Add Stop Button ---
                  if (_locations.length < 4)
                    Padding(
                      padding: const EdgeInsets.only(left: 36.0, top: 8.0),
                      child: TextButton.icon(
                        icon: const Icon(Icons.add_circle, size: 20),
                        label: const Text("Add Stop"),
                        onPressed: _addStop,
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          backgroundColor: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),

                  // --- Predictions List Removed (Moved inline) ---
                  const SizedBox(height: 80), // Bottom padding for FAB/Button
                ],
              ),
            ),
          ),

          // --- Confirm Button ---
          SlideTransition(
            position: _slideAnimation,
            child: Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: ProButton(
                  text: "Confirm Booking",
                  onPressed: _confirmBooking,
                  isLoading: _isCalculating,
                  // backgroundColor: isDark
                  //     ? Theme.of(context).primaryColor
                  //     : Colors.black,
                  // textColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
