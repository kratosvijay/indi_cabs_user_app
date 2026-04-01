import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';

import 'package:project_taxi_with_ai/widgets/data_models.dart';
import 'package:project_taxi_with_ai/widgets/firestore_services.dart';
import 'package:project_taxi_with_ai/widgets/scheduler.dart';
import 'package:project_taxi_with_ai/screens/wallet.dart'; // **NEW** // For EditLocationScreen
import 'package:project_taxi_with_ai/widgets/pro_library.dart'; // Import ProButton
import 'package:project_taxi_with_ai/widgets/equalizer_loading.dart'; // **NEW**
import 'package:project_taxi_with_ai/app_colors.dart';
import 'package:project_taxi_with_ai/widgets/custom_showcase.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final Map<String, bool> availability; // **NEW:** Accept availability
  final GlobalKey? showcaseKey; // **NEW:** Key for showcase tour
  final bool showScheduleTour; // **NEW:** Whether to show the tour
  final String? pickupPlaceName; // **NEW**
  final String? destinationPlaceName; // **NEW**

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
    required this.availability, // **NEW:** Add to constructor
    this.showcaseKey, // **NEW:** Key for showcase tour
    this.showScheduleTour = false, // **NEW:** Whether to show the tour
    this.pickupPlaceName, // **NEW**
    this.destinationPlaceName, // **NEW**
    this.guestName,
    this.guestPhone,
    this.scrollController, // **NEW:** Support for DraggableScrollableSheet
  });

  final String? guestName;
  final String? guestPhone;
  final ScrollController? scrollController; // **NEW**

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

    if (widget.showScheduleTour && widget.showcaseKey != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final prefs = await SharedPreferences.getInstance();
        final hasSeen = prefs.getBool('hasSeenScheduleTour') ?? false;
        if (!hasSeen && mounted) {
          ShowcaseView.get().startShowCase([widget.showcaseKey!]);
          await prefs.setBool('hasSeenScheduleTour', true);
        }
      });
    }

    // **MODIFIED:** Filter by type AND availability
    _filteredVehicleOptions = widget.vehicleOptions.where((option) {
      // Check if this vehicle type is available
      final bool isAvailable = widget.availability[option.type] ?? false;

      if (widget.rideType == RideType.acting) {
        return option.type == 'ActingDriver' && isAvailable;
      }

      // **NEW:** Exclude Auto from MultiStop rides
      if (widget.rideType == RideType.multiStop && option.type == 'Auto') {
        return false;
      }

      // For Daily and MultiStop, show all *except* ActingDriver
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
  }

  // **NEW:** Handle updates from parent (e.g. when fares load)
  @override
  void didUpdateWidget(RideConfirmationBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If we just finished loading fares, try to select a default vehicle
    if (oldWidget.isLoadingFares &&
        !widget.isLoadingFares &&
        widget.calculatedFares != null) {
      final availableVehicles = _filteredVehicleOptions.where((v) {
        return (widget.calculatedFares?[v.type] ?? 0) > 0;
      }).toList();

      if (availableVehicles.isNotEmpty) {
        // Keep current selection if valid, otherwise pick first available
        if (_selectedVehicle == null ||
            (widget.calculatedFares?[_selectedVehicleType] ?? 0) <= 0) {
          setState(() {
            _selectedVehicle = availableVehicles.first;
            _selectedVehicleType = availableVehicles.first.type;
          });
        }
      }
    }
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
                "Fare Details".tr,
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
                  "baseFare".tr,
                  "₹${vehicleRules.baseFare.toStringAsFixed(0)}",
                  isDark,
                ),
                // **MODIFIED:** Don't show per/km if it's 0 (for Acting Driver)
                if (vehicleRules.perKilometer > 0)
                  _buildFareInfoRow(
                    "perKilometer".tr,
                    "₹${vehicleRules.perKilometer.toStringAsFixed(0)} / km",
                    isDark,
                  ),
                // **MODIFIED:** Show per/min if it's > 0 (for Acting Driver)
                if (vehicleRules.perMinute > 0)
                  _buildFareInfoRow(
                    "perMinute".tr,
                    "₹${vehicleRules.perMinute.toStringAsFixed(0)} / min",
                    isDark,
                  ),

                _buildFareInfoRow(
                  "minimumFare".tr,
                  "₹${vehicleRules.minimumFare.toStringAsFixed(0)}",
                  isDark,
                ),
                _buildFareInfoRow(
                  "tollsIfAny".tr,
                  "+ ₹${tollCost.toStringAsFixed(0)}",
                  isDark,
                ),

                // **NEW:** Show 10hr policy for Acting Driver
                if (vehicle.type == 'ActingDriver') ...[
                  const Divider(height: 20),
                  Text(
                    "servicePolicy".tr,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  _buildFareInfoRow(
                    "foodAndNightStay".tr,
                    "foodAndNightStayDesc".tr,
                    isDark,
                  ),
                ],

                const Divider(height: 20),
                Text(
                  "otherCharges".tr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                _buildFareInfoRow(
                  "waitingCharge".tr,
                  "waitingChargeValue".tr,
                  isDark,
                ),
                _buildFareInfoRow("nightCharge".tr, "+ ₹50", isDark),

                const Divider(height: 20),
                // **NEW:** Explicitly show the final calculated total so users know toll is included
                _buildFareInfoRow(
                  "totalEstimatedFare".tr,
                  "₹${calculatedPrice?.toStringAsFixed(0) ?? 'N/A'}",
                  isDark,
                  isBold: true,
                ),
              ] else ...[
                // Fallback if pricing rules didn't load
                _buildFareInfoRow(
                  "totalEstimatedFare".tr,
                  "₹${calculatedPrice?.toStringAsFixed(0) ?? 'N/A'}",
                  isDark,
                  isBold: true,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    "fareBreakdownUnavailable".tr,
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
                        "fareNote".tr,
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
              ProButton(text: "gotIt".tr, onPressed: () => Get.back()),
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
  Widget _buildFareInfoRow(
    String title,
    String value,
    bool isDark, {
    bool isBold = false,
  }) {
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
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight:
                  FontWeight.bold, // Keep value bold, or adjust if needed
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
        children: [
          // Drag Handle (Static)
          Center(
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[600] : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Text(
            "selectARide".tr,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Scrollable Content
          Flexible(
            child: ListView(
              controller: widget.scrollController,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                // **NEW:** Show Distance and Time below Drop-off
                if (widget.routeDetails != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 2),
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
                                  "totalDistance".tr,
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
                                  "timeToTravel".tr,
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
                (widget.calculatedFares == null && !widget.isLoadingFares)
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            "couldNotCalculateFares".tr,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      )
                    : _filteredVehicleOptions.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            "noVehiclesAvailable".tr,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
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

                            // Only hide if NOT loading AND price is invalid
                            if (!widget.isLoadingFares &&
                                (calculatedPrice == null || calculatedPrice <= 0)) {
                              return const SizedBox.shrink();
                            }

                            final String displayPrice = calculatedPrice != null
                                ? "₹${calculatedPrice.toStringAsFixed(0)}"
                                : "";

                            return GestureDetector(
                              onTap: () => setState(() {
                                _selectedVehicleType = vehicle.type;
                                _selectedVehicle = vehicle;
                              }),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 2.0),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
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
                                      height: 35,
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
                                              Flexible(
                                                child: Text(
                                                  vehicle.type,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark
                                                        ? Colors.white
                                                        : Colors.black87,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
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
                                                  "${_getPassengerCount(vehicle.type)} ${'max'.tr}",
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
                                            "${'driverEta'.tr}: ${vehicle.eta}",
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
                                    // **MODIFIED:** Show Equalizer or Price
                                    widget.isLoadingFares
                                        ? EqualizerLoading(isDark: isDark)
                                        : Text(
                                            displayPrice,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.info_outline,
                                        color: AppColors.primary,
                                      ),
                                      tooltip: "viewFareDetails".tr,
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
              ],
            ),
          ),

          // Static Footer (Schedule & Confirm Buttons)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomShowcase(
                  showcaseKey: widget.showcaseKey ?? GlobalKey(),
                  title: "Ride Later",
                  description: "Schedule your ride for a later time or date",
                  isLastStep: true,
                  child: SizedBox(
                    key: _scheduleButtonKey,
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickSchedule,
                      icon: Icon(
                        Icons.calendar_today_outlined,
                        size: 20,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      label: Text(
                         _scheduledTime == null
                             ? "rideLater".tr
                             : "${'scheduledFor'.tr} ${DateFormat('dd MMM, hh:mm a').format(_scheduledTime!)}",
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
                ),
                const SizedBox(height: 8),

                // Confirmation Button
                ProButton(
                  text: widget.isLoadingFares
                      ? "calculatingFares".tr
                      : !widget.isDropoffInServiceArea
                      ? 'dropoffOutsideServiceArea'.tr
                      : _filteredVehicleOptions.isEmpty
                      ? "noVehiclesAvailableBtn".tr
                      : '${'confirm'.tr} ${_selectedVehicle?.type ?? 'Ride'}',
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
                                title: Text("lowWalletBalance".tr),
                                content: Text(
                                  "lowWalletBalanceDesc".tr,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Get.back(),
                                    child: Text("cancel".tr),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Get.back(); // Close dialog
                                      Get.back(); // Close bottom sheet
                                      Get.to(
                                        () => WalletScreen(user: widget.currentUser),
                                      );
                                    },
                                    child: Text("recharge".tr),
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
                              pickupPlaceName: widget.pickupPlaceName, // **NEW**
                              destinationPosition: widget.destinationPosition,
                              destinationPlaceName: widget.destinationPlaceName, // **NEW**
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
                const SizedBox(height: 8),
              ],
            ),
          ),
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
