import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:project_taxi_with_ai/widgets/data_models.dart';
import 'package:project_taxi_with_ai/widgets/directions_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:project_taxi_with_ai/widgets/ride_confirm_sheet.dart';
import '../widgets/snackbar.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';
import 'package:project_taxi_with_ai/screens/edit_location.dart';

class BookForOtherScreen extends StatefulWidget {
  final User user;
  final LatLng currentPosition;
  final PricingRules? pricingRules;
  final num walletBalance;

  const BookForOtherScreen({
    super.key,
    required this.user,
    required this.currentPosition,
    required this.pricingRules,
    required this.walletBalance,
  });

  @override
  State<BookForOtherScreen> createState() => _BookForOtherScreenState();
}

class _BookForOtherScreenState extends State<BookForOtherScreen> {
  // Services
  late final DirectionsService _directionsService;
  final HttpsCallable _calculateFaresCallable = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  ).httpsCallable('calculateFares');

  // Controllers
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();

  // State
  String? _guestName;
  String? _guestPhone;
  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;

  // **NEW:** Reactive state
  final ValueNotifier<BookingState> _bookingState = ValueNotifier(
    BookingState(),
  );

  @override
  void initState() {
    super.initState();
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    _directionsService = DirectionsService(apiKey: apiKey);
  }

  @override
  void dispose() {
    _contactController.dispose();
    _pickupController.dispose();
    _dropoffController.dispose();
    _bookingState.dispose();
    super.dispose();
  }

  Future<void> _pickContact() async {
    try {
      // 1. Prominent Disclosure for Contacts
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.contacts, color: Colors.orange),
              SizedBox(width: 10),
              Text("Contacts Access"),
            ],
          ),
          content: const Text(
            "Indi Cabs needs access to your contacts to let you quickly find and select "
            "friends or family members you are booking for. Their name and phone number "
            "will be used only to create the ride request.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Not Now"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text("I Understand"),
            ),
          ],
        ),
      );

      if (proceed != true) return;

      final status = await Permission.contacts.request();

      if (status.isPermanentlyDenied) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Contacts Permission Required"),
              content: const Text(
                "You have permanently denied contact access. Please open your app settings and enable Contacts to use this feature.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    openAppSettings();
                  },
                  child: const Text("Open Settings"),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (status.isGranted) {
        final contactId = await FlutterContacts.native.showPicker();
        if (contactId != null) {
          final contact = await FlutterContacts.get(
            contactId,
            properties: {ContactProperty.name, ContactProperty.phone},
          );
          if (contact != null) {
            String name = contact.displayName ?? '';
            String phone = '';
            if (contact.phones.isNotEmpty) {
              // Pick the first available phone number
              phone = contact.phones.first.number;
            }

            setState(() {
              _guestName = name;
              _guestPhone = phone;
              _contactController.text = "$name ($phone)";
            });
          }
        }
      } else {
        if (mounted) {
          displaySnackBar(context, "Permission denied to access contacts.");
        }
      }
    } catch (e) {
      debugPrint("Error picking contact: $e");
      if (mounted) displaySnackBar(context, "Failed to pick contact.");
    }
  }

  Future<void> _openMapPicker(int index, {bool recalculate = false}) async {
    LatLng initial = widget.currentPosition;
    if (index == 0 && _pickupLocation != null) initial = _pickupLocation!;
    if (index == 1 && _dropoffLocation != null) initial = _dropoffLocation!;

    final result = await Get.to<Map<String, dynamic>>(
      () => EditLocationScreen(initialLocation: initial),
    );

    if (result != null && mounted) {
      setState(() {
        if (index == 0) {
          _pickupLocation = result['location'];
          _pickupController.text = result['address'];
        } else {
          _dropoffLocation = result['location'];
          _dropoffController.text = result['address'];
        }
      });

      // **NEW:** Trigger recalculation if needed
      if (recalculate && _pickupLocation != null && _dropoffLocation != null) {
        _calculateFaresAndRoute();
      }
    }
  }

  // **NEW:** Separated logic
  Future<({Map<String, num> fares, num appliedSurcharge})?>
  _calculateFaresAndRoute() async {
    _bookingState.value = _bookingState.value.copyWith(
      isLoading: true,
      fares: null,
    );

    // Get Route
    final routeDetails = await _directionsService.getDirections(
      _pickupLocation!,
      _dropoffLocation!,
    );

    if (routeDetails == null) {
      _bookingState.value = _bookingState.value.copyWith(isLoading: false);
      if (mounted) displaySnackBar(context, "Could not find a route.");
      return null;
    }

    // Update route immediately so UI shows distance/time
    _bookingState.value = _bookingState.value.copyWith(route: routeDetails);

    try {
      final result = await _calculateFaresCallable.call<Map<dynamic, dynamic>>({
        'distanceMeters': routeDetails.distanceMeters,
        'durationSeconds': routeDetails.durationSeconds,
        'tollCost': routeDetails.tollCost,
        'pickupLocation': {
          'latitude': _pickupLocation!.latitude,
          'longitude': _pickupLocation!.longitude,
        },
        'destinationLocation': {
          'latitude': _dropoffLocation!.latitude,
          'longitude': _dropoffLocation!.longitude,
        },
        'routePolyline': routeDetails.polylinePoints
            .map((p) => {'latitude': p.latitude, 'longitude': p.longitude})
            .toList(),
      });
      
      final data = result.data;
      if (data['fares'] == null) {
        throw Exception("Invalid response from fare calculation.");
      }

      final fares = data['fares'] as Map<dynamic, dynamic>? ?? {};
      final appliedSurcharge = data['appliedSurcharge'] as num? ?? 0;
      final appliedToll = data['appliedToll'] as num? ?? 0;
      final totalExtras = appliedSurcharge + appliedToll;

      final typedFares = fares.map(
        (key, value) => MapEntry(key.toString(), value as num),
      );

      return (fares: typedFares, appliedSurcharge: totalExtras);
    } catch (e) {
      debugPrint("Error calculating fares: $e");
      _bookingState.value = _bookingState.value.copyWith(isLoading: false);
      if (mounted) {
        displaySnackBar(context, "Could not calculate fares: ${e.toString()}");
      }
      return null;
    }
  }

  Future<void> _confirmBooking() async {
    if (_guestName == null || _guestName!.isEmpty) {
      displaySnackBar(context, "Please select a contact.");
      return;
    }
    if (_pickupLocation == null) {
      displaySnackBar(context, "Please enter pickup location.");
      return;
    }
    if (_dropoffLocation == null) {
      displaySnackBar(context, "Please enter drop-off location.");
      return;
    }

    // Start calculation immediately
    final calculationResult = await _calculateFaresAndRoute();

    if (calculationResult != null) {
      final fares = calculationResult.fares;
      final appliedSurcharge = calculationResult.appliedSurcharge;

      // Update the routeDetails with the new toll cost (appliedSurcharge)
      final updatedRouteDetails = _bookingState.value.route?.copyWith(
        tollCost: appliedSurcharge,
      );

      _bookingState.value = _bookingState.value.copyWith(
        isLoading: false,
        fares: fares,
        route: updatedRouteDetails, // Update route with new toll cost
      );
    } else {
      // If calculation failed, ensure loading is off and fares are null
      _bookingState.value = _bookingState.value.copyWith(
        isLoading: false,
        fares: null,
      );
      return; // Do not proceed if fares calculation failed
    }

    final availability = {
      'Auto': true,
      'Hatchback': true,
      'Sedan': true,
      'SUV': true,
      'ActingDriver': true,
    };

    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) {
          return ValueListenableBuilder<BookingState>(
            valueListenable: _bookingState,
            builder: (context, state, _) {
              final duration = state.route != null
                  ? (state.route!.durationSeconds / 60).round()
                  : 0;
              final etaString = "$duration min";

              return RideConfirmationBottomSheet(
                currentUser: widget.user,
                currentPosition: _pickupLocation!,
                destinationPosition: _dropoffLocation!,
                pickupAddress: _pickupController.text,
                destinationAddress: _dropoffController.text,
                isDropoffInServiceArea: true,
                vehicleOptions: VehicleOption.defaultOptions,
                polylines: state.route != null
                    ? {
                        Polyline(
                          polylineId: const PolylineId("route"),
                          points: state.route!.polylinePoints,
                          color: Colors.black,
                          width: 5,
                        ),
                      }
                    : {},
                isLoadingFares: state.isLoading,
                calculatedFares: state.fares,
                eta: etaString,
                routeDetails: state.route,
                pricingRules: widget.pricingRules,
                walletBalance: widget.walletBalance,
                rideType: RideType.bookForOther,
                availability: availability,
                // **NEW:** Pass recalculate: true
                onEditPickup: () => _openMapPicker(0, recalculate: true),
                onEditDropoff: () => _openMapPicker(1, recalculate: true),
                onSaveDropoffFavorite: () {},
                onSavePickupFavorite: () {},
                guestName: _guestName,
                guestPhone: _guestPhone,
              );
            },
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: ProAppBar(
        titleText: "Book for Guest",
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Contact Selection
                  _buildSectionHeader("Who is riding?"),
                  const SizedBox(height: 8),
                  _buildContactField(isDark),

                  const SizedBox(height: 24),

                  // Route Selection
                  _buildSectionHeader("Route Details"),
                  const SizedBox(height: 8),
                  _buildLocationField(
                    0,
                    "Enter pickup location",
                    _pickupController,
                    isDark,
                    Icons.my_location,
                  ),
                  const SizedBox(height: 12),
                  _buildLocationField(
                    1,
                    "Enter drop-off location",
                    _dropoffController,
                    isDark,
                    Icons.location_on,
                  ),
                ],
              ),
            ),
          ),

          // Confirm Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ProButton(
              text: "Confirm Booking",
              isLoading: false, // UI no longer blocks
              onPressed: _confirmBooking,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    );
  }

  Widget _buildContactField(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
        ),
      ),
      child: TextField(
        controller: _contactController,
        readOnly: true,
        onTap: _pickContact,
        decoration: InputDecoration(
          hintText: "Select from contacts",
          hintStyle: TextStyle(
            color: isDark ? Colors.grey[500] : Colors.grey[400],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          prefixIcon: const Icon(Icons.contacts),
          suffixIcon: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }

  Widget _buildLocationField(
    int index,
    String hint,
    TextEditingController controller,
    bool isDark,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
        ),
      ),
      child: TextField(
        controller: controller,
        readOnly: true,
        onTap: () => _openMapPicker(index),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? Colors.grey[500] : Colors.grey[400],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          prefixIcon: Icon(icon, size: 20, color: Colors.grey),
          suffixIcon: Icon(Icons.chevron_right, color: Colors.grey),
        ),
      ),
    );
  }
}
