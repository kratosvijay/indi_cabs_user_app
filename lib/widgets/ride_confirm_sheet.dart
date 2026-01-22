import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';

import 'package:project_taxi_with_ai/widgets/data_models.dart';
import 'package:project_taxi_with_ai/widgets/firestore_services.dart';
import 'package:project_taxi_with_ai/widgets/home_page_tour.dart';
import 'package:project_taxi_with_ai/widgets/scheduler.dart';
import 'package:project_taxi_with_ai/screens/wallet.dart'; // **NEW** // For EditLocationScreen
import 'package:project_taxi_with_ai/widgets/pro_library.dart'; // Import ProButton
import 'package:project_taxi_with_ai/app_colors.dart';

// Define the callback type as a simple function
typedef EditLocationCallback = void Function();

class RideConfirmationBottomSheet extends StatefulWidget {
  final User currentUser;
  final LatLng currentPosition;
  final LatLng destinationPosition;
  final String pickupAddress;
  final String destinationAddress;
  final bool isDropoffInServiceArea;
  final List<VehicleOption> vehicleOptions;
  final Set<Polyline> polylines;
  final EditLocationCallback onEditPickup; // Expects void Function()
  final EditLocationCallback onEditDropoff; // Expects void Function()
  final VoidCallback onSaveDropoffFavorite;
  final VoidCallback onSavePickupFavorite;

  // Parameters for calculated fares
  final bool isLoadingFares;
  final Map<String, num>? calculatedFares;
  final String? eta; // Estimated Time of Arrival string
  final RouteDetails? routeDetails;
  final PricingRules? pricingRules;
  final List<Map<String, dynamic>>? intermediateStops;
  final num walletBalance;
  final RideType rideType; // **NEW:** Accept ride type
  final bool showScheduleTour; // **NEW:** Add tour flag
  final Map<String, bool> availability; // **NEW:** Accept availability

  const RideConfirmationBottomSheet({
    super.key,
    required this.currentUser,
    required this.currentPosition,
    required this.destinationPosition,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.isDropoffInServiceArea,
    required this.vehicleOptions,
    required this.polylines,
    required this.onEditPickup,
    required this.onEditDropoff,
    required this.onSaveDropoffFavorite,
    required this.onSavePickupFavorite,
    this.isLoadingFares = false,
    this.calculatedFares,
    this.eta,
    this.routeDetails,
    this.pricingRules,
    this.intermediateStops,
    required this.walletBalance,
    required this.rideType, // **NEW:** Add to constructor
    this.showScheduleTour = false, // **NEW:** Add to constructor
    required this.availability, // **NEW:** Add to constructor
    this.guestName,
    this.guestPhone,
  });

  final String? guestName;
  final String? guestPhone;

  @override
  State<RideConfirmationBottomSheet> createState() =>
      _RideConfirmationBottomSheetState();
}

class _RideConfirmationBottomSheetState
    extends State<RideConfirmationBottomSheet> {
  String? _selectedVehicleType;
  VehicleOption? _selectedVehicle;

  // **NEW:** State for scheduling
  DateTime? _scheduledTime;
  num _convenienceFee = 0;

  // Services
  final FirestoreService _firestoreService = FirestoreService();

  // **NEW:** Filtered list of vehicles
  late List<VehicleOption> _filteredVehicleOptions;

  // **NEW:** Key for the schedule button
  final GlobalKey _scheduleButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    // **MODIFIED:** Filter by type AND availability
    _filteredVehicleOptions = widget.vehicleOptions.where((option) {
      // Check if this vehicle type is available
      final bool isAvailable = widget.availability[option.type] ?? false;

      if (widget.rideType == RideType.acting) {
        return option.type == 'ActingDriver' && isAvailable;
      }
      // For Daily and MultiStop, show all *except* ActingDriver
      // **MODIFIED:** MultiStop should also hide Auto
      if (widget.rideType == RideType.multiStop && option.type == 'Auto') {
        return false;
      }
      return option.type != 'ActingDriver' && isAvailable;
    }).toList();

    // Default to first vehicle if available and fares are loaded
    if (_filteredVehicleOptions.isNotEmpty &&
        !widget.isLoadingFares &&
        widget.calculatedFares != null) {
      for (var vehicle in _filteredVehicleOptions) {
        if ((widget.calculatedFares?[vehicle.type] ?? 0) > 0) {
          _selectedVehicleType = vehicle.type;
          _selectedVehicle = vehicle;
          break;
        }
      }
      if (_selectedVehicle == null && _filteredVehicleOptions.isNotEmpty) {
        _selectedVehicleType = _filteredVehicleOptions.first.type;
        _selectedVehicle = _filteredVehicleOptions.first;
      }
    } else if (_filteredVehicleOptions.isNotEmpty) {
      _selectedVehicleType = _filteredVehicleOptions.first.type;
      _selectedVehicle = _filteredVehicleOptions.first;
    }

    // **NEW:** Check if we need to show the schedule tour
    if (widget.showScheduleTour) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showScheduleTour());
    }
  }

  // **NEW:** Function to show the schedule button tour
  void _showScheduleTour() {
    // Add a small delay to make sure the bottom sheet has finished animating up
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        ContextualFeatureTour.showTourStep(
          context: context,
          key: _scheduleButtonKey,
          prefKey: kHasSeenScheduleTour,
          title: "Book Now or Schedule",
          description:
              "Tap here to book your ride immediately, or press to select a future date and time. A ₹100 convenience fee applies for scheduled rides.",
        );
      }
    });
  }

  // **MODIFIED:** Helper to build the location row
  Widget _buildEditableLocationRow({
    required BuildContext context,
    required String label,
    required String address,
    required IconData icon,
    VoidCallback? onTap, // Made optional
    VoidCallback? onSaveFavorite,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      // Changed from InkWell
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: label == "Pickup"
                ? Colors.green.shade600
                : Colors.red.shade600,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  address,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),

          // **NEW** Button Row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onSaveFavorite != null) // Only show if callback is provided
                IconButton(
                  icon: Icon(
                    Icons.favorite_border,
                    color: Colors.pinkAccent.shade200,
                    size: 22,
                  ),
                  tooltip: "Save as Favorite",
                  padding: const EdgeInsets.all(4.0),
                  constraints: const BoxConstraints(),
                  onPressed: onSaveFavorite,
                ),
              if (onSaveFavorite != null) // Add spacing if fav button exists
                const SizedBox(width: 8),
              if (onTap != null) // Only show edit button if callback provided
                IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  tooltip: "Edit Location",
                  padding: const EdgeInsets.all(4.0),
                  constraints: const BoxConstraints(),
                  onPressed: onTap,
                ),
            ],
          ),
        ],
      ),
    );
  }

  // **MODIFIED:** Helper to show the vehicle info bottom sheet
  void _showVehicleInfoSheet(
    BuildContext context,
    VehicleOption vehicle,
    num? calculatedPrice,
  ) {
    // Find the specific pricing rules for this vehicle
    final vehicleRules = widget.pricingRules?.vehiclePricing[vehicle.type];
    // **NEW:** Get the toll cost from the route details
    final num tollCost = widget.routeDetails?.tollCost ?? 0;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows sheet to be smaller
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[600] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              // Title
              Text(
                vehicle.type,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              // Marketing Text
              Text(
                _getVehicleDescription(vehicle.type),
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 20),
              // Pricing Details
              Text(
                "Fare Details",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Divider(height: 20),
              // Show breakdown if rules are available
              if (vehicleRules != null) ...[
                _buildFareInfoRow(
                  "Base Fare",
                  "₹${vehicleRules.baseFare.toStringAsFixed(0)}",
                  isDark,
                ),
                // **MODIFIED:** Don't show per/km if it's 0 (for Acting Driver)
                if (vehicleRules.perKilometer > 0)
                  _buildFareInfoRow(
                    "Per Kilometer",
                    "₹${vehicleRules.perKilometer.toStringAsFixed(0)} / km",
                    isDark,
                  ),
                // **MODIFIED:** Show per/min if it's > 0 (for Acting Driver)
                if (vehicleRules.perMinute > 0)
                  _buildFareInfoRow(
                    "Per Minute",
                    "₹${vehicleRules.perMinute.toStringAsFixed(0)} / min",
                    isDark,
                  ),

                _buildFareInfoRow(
                  "Minimum Fare",
                  "₹${vehicleRules.minimumFare.toStringAsFixed(0)}",
                  isDark,
                ),
                _buildFareInfoRow(
                  "Tolls (if any)",
                  "+ ₹${tollCost.toStringAsFixed(0)}",
                  isDark,
                ),

                // **NEW:** Show 10hr policy for Acting Driver
                if (vehicle.type == 'ActingDriver') ...[
                  const Divider(height: 20),
                  Text(
                    "Service Policy:",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  _buildFareInfoRow(
                    "Food & Night Stay",
                    "Food & accommodation (for trips > 10 hours) must be provided by the user.",
                    isDark,
                  ),
                ],

                const Divider(height: 20),
                Text(
                  "Other Charges (applied by server):",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                _buildFareInfoRow(
                  "Waiting Charge",
                  "₹5/min (after 3 free mins)",
                  isDark,
                ),
                _buildFareInfoRow("Night Charge (10pm-6am)", "+ ₹50", isDark),
              ] else ...[
                // Fallback if pricing rules didn't load
                _buildFareInfoRow(
                  "Estimated Fare",
                  "₹${calculatedPrice?.toStringAsFixed(0) ?? 'N/A'}",
                  isDark,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    "Detailed fare breakdown is unavailable at this time.",
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.grey[700]! : Colors.amber.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: isDark ? Colors.grey[400] : Colors.amber.shade800,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Note: This is an estimated fare. The final fare may vary based on the actual route taken, traffic conditions, and any additional stops or waiting time.",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[300] : Colors.black87,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 24),
              ProButton(text: "Got it", onPressed: () => Get.back()),
              SizedBox(
                height: MediaQuery.of(context).padding.bottom + 8,
              ), // Padding for safe area
            ],
          ),
        );
      },
    );
  }

  // Helper for the info sheet's rows
  Widget _buildFareInfoRow(String title, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String _getVehicleDescription(String type) {
    switch (type) {
      case 'Auto':
        return "Affordable and quick auto ride for your daily commute.";
      case 'Hatchback':
        return "Comfortable AC hatchback for city rides.";
      case 'Sedan':
        return "Premium AC sedan for a smooth and spacious journey.";
      case 'SUV':
        return "Spacious AC SUV, perfect for groups and luggage.";
      case 'ActingDriver':
        return "Professional driver to drive your car safely.";
      default:
        return "A comfortable ride for your trip.";
    }
  }

  int? _getPassengerCount(String type) {
    switch (type.toLowerCase().trim()) {
      case 'auto':
        return 3;
      case 'hatchback':
      case 'sedan':
        return 4;
      case 'suv':
        return 6;
      default:
        return null;
    }
  }

  // **NEW:** Function to open schedule picker
  Future<void> _pickSchedule() async {
    final DateTime? result = await Get.to<DateTime>(
      () => const SchedulePickerScreen(),
    );

    if (result != null) {
      setState(() {
        _scheduledTime = result;
        _convenienceFee = 100; // Add ₹100 flat fee
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // **MODIFIED:** Re-check logic with filtered list
    if (!widget.isLoadingFares &&
        widget.calculatedFares != null &&
        _selectedVehicleType != null) {
      if ((widget.calculatedFares?[_selectedVehicleType!] ?? 0) <= 0) {
        VehicleOption? newDefault;
        for (var vehicle in _filteredVehicleOptions) {
          // Use filtered list
          if ((widget.calculatedFares?[vehicle.type] ?? 0) > 0) {
            newDefault = vehicle;
            break;
          }
        }
        if (newDefault != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _selectedVehicleType = newDefault!.type;
                _selectedVehicle = newDefault;
              });
            }
          });
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[600] : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Text(
            "Select a Ride",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Pickup/Dropoff Rows
          _buildEditableLocationRow(
            context: context,
            label: "Pickup",
            address: widget.pickupAddress,
            icon: Icons.my_location,
            onTap: widget.onEditPickup,
            onSaveFavorite: widget.onSavePickupFavorite,
          ),
          const SizedBox(height: 8),

          // Intermediate Stops
          if (widget.intermediateStops != null)
            for (int i = 0; i < widget.intermediateStops!.length; i++) ...[
              _buildEditableLocationRow(
                context: context,
                label: "Stop ${i + 1}",
                address:
                    widget.intermediateStops![i]['address'] as String? ??
                    "Unknown",
                icon: Icons.stop_circle_outlined,
                onTap: null, // Read-only in this sheet
                onSaveFavorite: null,
              ),
              const SizedBox(height: 8),
            ],

          _buildEditableLocationRow(
            context: context,
            label: "Drop-off",
            address: widget.destinationAddress,
            icon: Icons.location_on_outlined,
            onTap: widget.onEditDropoff,
            onSaveFavorite: widget.onSaveDropoffFavorite,
          ),

          // **NEW:** Show Distance and Time below Drop-off
          if (widget.routeDetails != null)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  children: [
                    // Total Distance
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "TOTAL DISTANCE",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.directions_car_filled,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "${(widget.routeDetails!.distanceMeters / 1000).toStringAsFixed(1)} km",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Divider
                    Container(
                      height: 30,
                      width: 1,
                      color: isDark ? Colors.grey[600] : Colors.grey[300],
                    ),
                    const SizedBox(width: 16),
                    // Time to Travel
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "TIME TO TRAVEL",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_filled,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatDuration(
                                  widget.routeDetails!.durationSeconds,
                                ),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Vehicle Options List
          SizedBox(
            height: 250,
            child: widget.isLoadingFares
                ? const Center(child: CircularProgressIndicator())
                : (widget.calculatedFares == null ||
                      widget.calculatedFares!.isEmpty)
                ? const Center(
                    child: Text(
                      "Could not calculate fares.",
                      style: TextStyle(color: Colors.red),
                    ),
                  )
                // **MODIFIED:** Use _filteredVehicleOptions
                : _filteredVehicleOptions.isEmpty
                // **NEW:** Show "No vehicle" message
                ? const Center(
                    child: Text(
                      "No vehicles are available for this service right now. Please try again soon.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.redAccent),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _filteredVehicleOptions.length,
                    itemBuilder: (context, index) {
                      final vehicle = _filteredVehicleOptions[index];
                      final isSelected = _selectedVehicleType == vehicle.type;

                      // **MODIFIED:** Add convenience fee to calculated price
                      final num? basePrice =
                          widget.calculatedFares?[vehicle.type];
                      final num? calculatedPrice = (basePrice != null)
                          ? basePrice + _convenienceFee
                          : null;

                      if (calculatedPrice == null || calculatedPrice <= 0) {
                        return const SizedBox.shrink();
                      }

                      final String displayPrice =
                          "₹${calculatedPrice.toStringAsFixed(0)}";

                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedVehicleType = vehicle.type;
                          _selectedVehicle = vehicle;
                        }),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          padding: const EdgeInsets.symmetric(
                            vertical: 6.0,
                            horizontal: 8.0,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark
                                      ? Colors.blue.withValues(alpha: 0.2)
                                      : Colors.blue.shade50)
                                : (isDark ? Colors.grey[800] : Colors.grey[50]),
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark
                                        ? Colors.grey[700]!
                                        : Colors.grey.shade300),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Image.asset(
                                vehicle.imagePath,
                                width: 45,
                                height: 45,
                                errorBuilder: (c, o, s) => const Icon(
                                  Icons.error_outline,
                                  size: 30,
                                  color: Colors.redAccent,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          vehicle.type,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                        if (_getPassengerCount(vehicle.type) !=
                                            null) ...[
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.person,
                                            size: 16,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black54,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            "${_getPassengerCount(vehicle.type)} Max",
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black54,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      "Driver ETA: ${vehicle.eta}",
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[700],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                displayPrice,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.info_outline,
                                  color: AppColors.primary,
                                ),
                                tooltip: "View fare details",
                                padding: const EdgeInsets.all(4.0),
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  _showVehicleInfoSheet(
                                    context,
                                    vehicle,
                                    calculatedPrice,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),

          // **NEW:** Schedule Button
          Container(
            key: _scheduleButtonKey,
            child: OutlinedButton.icon(
              onPressed: _pickSchedule,
              icon: Icon(
                Icons.calendar_today_outlined,
                size: 20,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              label: Text(
                _scheduledTime == null
                    ? "Ride Later"
                    : "Scheduled for ${DateFormat('dd MMM, hh:mm a').format(_scheduledTime!)}",
                style: TextStyle(
                  fontWeight: _scheduledTime == null
                      ? FontWeight.normal
                      : FontWeight.bold,
                  color: _scheduledTime == null
                      ? (isDark ? Colors.white70 : Colors.black87)
                      : AppColors.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : Colors.black87,
                side: BorderSide(
                  color: _scheduledTime == null
                      ? (isDark ? Colors.grey[600]! : Colors.grey[400]!)
                      : AppColors.primary,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Confirmation Button
          // Confirmation Button
          ProButton(
            text: widget.isLoadingFares
                ? "Calculating Fares..."
                : !widget.isDropoffInServiceArea
                ? 'Drop-off outside service area'
                : _filteredVehicleOptions.isEmpty
                ? "No Vehicles Available"
                : 'Confirm ${_selectedVehicle?.type ?? 'Ride'}',
            isLoading: widget.isLoadingFares,
            backgroundColor:
                (_filteredVehicleOptions.isEmpty ||
                    !widget.isDropoffInServiceArea)
                ? (isDark ? Colors.grey[700] : Colors.grey)
                : null, // Use default gradient
            onPressed:
                _filteredVehicleOptions.isEmpty ||
                    widget.isDropoffInServiceArea == false ||
                    _selectedVehicle == null ||
                    widget.isLoadingFares
                ? null
                : () {
                    // **NEW:** Check Wallet Balance
                    if (widget.walletBalance < -50) {
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
                                Get.back(); // Close bottom sheet
                                Get.to(
                                  () => WalletScreen(user: widget.currentUser),
                                );
                              },
                              child: const Text("Recharge"),
                            ),
                          ],
                        ),
                      );
                      return;
                    }

                    Get.back(); // Close this sheet
                    // **MODIFIED:** Add fee to selected fare
                    final num baseFare =
                        widget.calculatedFares![_selectedVehicle!.type]!;
                    final num selectedFare = baseFare + _convenienceFee;

                    _firestoreService.navigateToConfirmPickup(
                      context,
                      currentUser: widget.currentUser,
                      currentPosition: widget.currentPosition,
                      destinationPosition: widget.destinationPosition,
                      selectedVehicle: _selectedVehicle!,
                      polylines: widget.polylines,
                      calculatedFare: selectedFare,
                      routeDetails: widget.routeDetails,
                      intermediateStops: widget.intermediateStops,
                      walletBalance: widget.walletBalance,
                      scheduledTime: _scheduledTime, // **NEW**
                      convenienceFee: _convenienceFee, // **NEW**
                      guestName: widget.guestName,
                      guestPhone: widget.guestPhone,
                    );
                  },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return "1 min";
    final int minutes = (seconds / 60).round();
    if (minutes < 60) {
      return "$minutes min";
    } else {
      final int hours = minutes ~/ 60;
      final int remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return "$hours hr";
      } else {
        return "$hours hr $remainingMinutes min";
      }
    }
  }
}
