import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:project_taxi_with_ai/widgets/data_models.dart';
import 'package:project_taxi_with_ai/widgets/firestore_services.dart';
import 'package:project_taxi_with_ai/widgets/scheduler.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';

class RentalBottomSheet extends StatefulWidget {
  final List<RentalPackage> rentalPackages;
  final bool isLoadingRentals;
  final List<VehicleOption> rentalVehicleOptions;
  final User currentUser;
  final LatLng currentPosition;
  final bool isActingDriver;
  final PricingRules? pricingRules;

  const RentalBottomSheet({
    super.key,
    required this.rentalPackages,
    required this.isLoadingRentals,
    required this.rentalVehicleOptions,
    required this.currentUser,
    required this.currentPosition,
    this.isActingDriver = false,
    this.pricingRules,
  });

  @override
  State<RentalBottomSheet> createState() => _RentalBottomSheetState();
}

class _RentalBottomSheetState extends State<RentalBottomSheet> {
  RentalPackage? _selectedRentalPackage;
  String? _selectedRentalVehicleType;
  num _selectedRentalPrice = 0;

  DateTime? _scheduledTime;
  num _convenienceFee = 0;

  // Services
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    if (widget.isActingDriver) {
      _selectedRentalVehicleType = 'ActingDriver';
    }
  }

  // Helper to show the vehicle info bottom sheet
  void _showRentalVehicleInfoSheet(
    BuildContext context,
    VehicleOption vehicle,
    RentalPackage package,
    num rentalPrice,
  ) {
    final vehicleRules = widget.pricingRules?.vehiclePricing[vehicle.type];
    final bool isActing = vehicle.type == 'ActingDriver';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              // Title
              Text(
                isActing ? "Acting Driver" : vehicle.type,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // Marketing Text
              Text(
                isActing
                    ? (vehicleRules?.description ??
                          "A professional, verified driver for your personal car.")
                    : (vehicleRules?.description ??
                          "A dedicated ${vehicle.type.toLowerCase()} for your selected package."),
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 20),
              // Pricing Details
              Text(
                "Package Details",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(height: 20),

              _buildFareInfoRow("Package", package.displayName),
              _buildFareInfoRow(
                "Package Price",
                "₹${rentalPrice.toStringAsFixed(0)}",
              ),
              _buildFareInfoRow("Duration", "${package.durationHours} Hours"),

              if (!isActing)
                _buildFareInfoRow("Distance", "${package.kmLimit} km Included"),

              const Divider(height: 20),
              const Text(
                "Extra Charges:",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),

              if (isActing) ...[
                if (vehicleRules != null && vehicleRules.perMinute > 0)
                  _buildFareInfoRow(
                    "Extra Time",
                    "₹${vehicleRules.perMinute.toStringAsFixed(0)} / min",
                  ),
              ] else ...[
                _buildFareInfoRow(
                  "Extra Hour",
                  "₹${package.extraHourCharge.toStringAsFixed(0)} / hr",
                ),
                _buildFareInfoRow(
                  "Extra Kilometer",
                  "₹${package.extraKmCharge.toStringAsFixed(0)} / km",
                ),
              ],

              if (isActing) ...[
                const Divider(height: 20),
                const Text(
                  "Service Policy:",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                _buildFareInfoRow(
                  "Food & Night Stay",
                  "Food & accommodation (for trips > 10 hours) must be provided by the user.",
                ),
              ],

              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Get.back(),
                child: const Center(
                  child: Text(
                    "Got it",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFareInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 15, color: Colors.grey[800])),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
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
    final String title = widget.isActingDriver
        ? "Book an Acting Driver"
        : "Select Rental Package";

    final List<RentalPackage> packages = widget.isActingDriver
        ? widget.rentalPackages
              .where((pkg) => pkg.getPriceForVehicle('ActingDriver') > 0)
              .toList()
        : widget.rentalPackages;

    final List<VehicleOption> vehicleOptions = widget.isActingDriver
        ? widget.rentalVehicleOptions
              .where((v) => v.type == 'ActingDriver')
              .toList()
        : widget.rentalVehicleOptions
              .where((v) => v.type != 'ActingDriver')
              .toList();

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

          // --- Step 1: Package Selection ---
          if (_selectedRentalPackage == null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (widget.isLoadingRentals)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (packages.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    "No packages available for this service.",
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.black54,
                    ),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: packages.length,
                  itemBuilder: (context, index) {
                    final package = packages[index];
                    final num displayPrice = package.getPriceForVehicle(
                      widget.isActingDriver ? 'ActingDriver' : 'Hatchback',
                    );

                    if (displayPrice <= 0) return const SizedBox.shrink();

                    return Card(
                      color: isDark ? Colors.grey[800] : Colors.white,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(
                          package.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          widget.isActingDriver
                              ? "${package.durationHours} ${package.durationHours > 1 ? 'Hours' : 'Hour'} Duration"
                              : "${package.durationHours} ${package.durationHours > 1 ? 'Hours' : 'Hour'} / ${package.kmLimit} km",
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        trailing: Text(
                          widget.isActingDriver
                              ? "₹${package.getPriceForVehicle('ActingDriver').toStringAsFixed(0)}"
                              : "Starts ₹${displayPrice.toStringAsFixed(0)}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedRentalPackage = package;
                            if (widget.isActingDriver) {
                              _selectedRentalVehicleType = 'ActingDriver';
                              _selectedRentalPrice = package.getPriceForVehicle(
                                'ActingDriver',
                              );
                            } else {
                              _selectedRentalVehicleType = null;
                              _selectedRentalPrice = 0;
                            }
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
          ]
          // --- Step 2: Vehicle Selection ---
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                widget.isActingDriver
                    ? "Confirm Booking Details"
                    : "Select Vehicle for ${_selectedRentalPackage!.displayName}",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: vehicleOptions.length,
                itemBuilder: (context, index) {
                  final vehicle = vehicleOptions[index];
                  final num rentalPrice = _selectedRentalPackage!
                      .getPriceForVehicle(vehicle.type);
                  final bool isSelected =
                      _selectedRentalVehicleType == vehicle.type;

                  if (rentalPrice <= 0) return const SizedBox.shrink();

                  return GestureDetector(
                    onTap: () {
                      if (widget.isActingDriver) {
                        return; // Can't de-select acting driver
                      }
                      setState(() {
                        _selectedRentalVehicleType = vehicle.type;
                        _selectedRentalPrice = rentalPrice;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 3.0),
                      padding: const EdgeInsets.symmetric(
                        vertical: 6.0,
                        horizontal: 8.0,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark
                                  ? Colors.blue.shade900.withValues(alpha: 0.3)
                                  : Colors.blue.shade50)
                            : (isDark ? Colors.grey[800] : Colors.grey[50]),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(
                          color: isSelected
                              ? Colors.blueAccent
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
                            child: Text(
                              vehicle.type,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          Text(
                            "₹${rentalPrice.toStringAsFixed(0)}",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.info_outline,
                              color: Colors.blueAccent.shade200,
                            ),
                            tooltip: "View package details",
                            padding: const EdgeInsets.all(4.0),
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              _showRentalVehicleInfoSheet(
                                context,
                                vehicle,
                                _selectedRentalPackage!,
                                rentalPrice,
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

            OutlinedButton.icon(
              onPressed: _pickSchedule,
              icon: Icon(
                Icons.calendar_today_outlined,
                size: 20,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              label: Text(
                _scheduledTime == null
                    ? "Book Now"
                    : "Scheduled for ${DateFormat('dd MMM, hh:mm a').format(_scheduledTime!)}",
                style: TextStyle(
                  fontWeight: _scheduledTime == null
                      ? FontWeight.normal
                      : FontWeight.bold,
                  color: _scheduledTime == null
                      ? (isDark ? Colors.white70 : Colors.black87)
                      : Colors.blueAccent,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white70 : Colors.black87,
                side: BorderSide(
                  color: _scheduledTime == null
                      ? (isDark ? Colors.grey[600]! : Colors.grey[400]!)
                      : Colors.blueAccent,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),

            TextButton(
              onPressed: () => setState(() => _selectedRentalPackage = null),
              child: const Text("‹ Back to Packages"),
            ),
            const SizedBox(height: 8),
            ProButton(
              text: _selectedRentalVehicleType != null
                  ? 'Proceed (₹${(_selectedRentalPrice + _convenienceFee).toStringAsFixed(0)})'
                  : 'Select a Vehicle',
              onPressed: _selectedRentalVehicleType != null
                  ? () {
                      Get.back(); // Close sheet
                      _firestoreService.navigateToRentalConfirmPickup(
                        context,
                        currentUser: widget.currentUser,
                        currentPosition: widget.currentPosition,
                        rentalPackage: _selectedRentalPackage!,
                        rentalVehicleType: _selectedRentalVehicleType!,
                        rentalPrice: _selectedRentalPrice,
                        scheduledTime: _scheduledTime,
                        convenienceFee: _convenienceFee,
                      );
                    }
                  : null,
              backgroundColor: _selectedRentalVehicleType != null
                  ? null // Use default gradient
                  : (isDark ? Colors.grey[700] : Colors.grey),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
