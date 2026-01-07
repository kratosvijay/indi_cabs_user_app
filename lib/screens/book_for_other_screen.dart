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

import 'package:project_taxi_with_ai/widgets/places_service.dart';
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
  late final PlacesService _placesService;
  late final DirectionsService _directionsService;
  final HttpsCallable _calculateFaresCallable = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  ).httpsCallable('calculateFares');

  // Controllers
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();

  final FocusNode _pickupFocusNode = FocusNode();
  final FocusNode _dropoffFocusNode = FocusNode();

  // State
  String? _guestName;
  String? _guestPhone;
  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;

  List<PlaceAutocompletePrediction> _predictions = [];
  int? _currentlyFocusedIndex; // 0: Pickup, 1: Dropoff
  Timer? _debounce;
  bool _isCalculating = false;

  @override
  void initState() {
    super.initState();
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    _placesService = PlacesService(apiKey: apiKey);
    _directionsService = DirectionsService(apiKey: apiKey);

    // Initial Empty State
    _addListeners();
  }

  @override
  void dispose() {
    _contactController.dispose();
    _pickupController.dispose();
    _dropoffController.dispose();
    _pickupFocusNode.dispose();
    _dropoffFocusNode.dispose();
    _placesService.cancelDebounce();
    _debounce?.cancel();
    super.dispose();
  }

  void _addListeners() {
    _pickupFocusNode.addListener(() {
      if (_pickupFocusNode.hasFocus) {
        setState(() => _currentlyFocusedIndex = 0);
        if (_pickupController.text.isNotEmpty) {
          _onSearchChanged(_pickupController.text, 0);
        }
      } else {
        // Delay clearing to allow tap
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && _currentlyFocusedIndex == 0) {
            setState(() {
              _currentlyFocusedIndex = null;
              _predictions = [];
            });
          }
        });
      }
    });

    _dropoffFocusNode.addListener(() {
      if (_dropoffFocusNode.hasFocus) {
        setState(() => _currentlyFocusedIndex = 1);
        if (_dropoffController.text.isNotEmpty) {
          _onSearchChanged(_dropoffController.text, 1);
        }
      } else {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && _currentlyFocusedIndex == 1) {
            setState(() {
              _currentlyFocusedIndex = null;
              _predictions = [];
            });
          }
        });
      }
    });
  }

  void _onSearchChanged(String query, int index) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isNotEmpty) {
        final results = await _placesService.getAutocompleteResults(
          query,
          widget.currentPosition,
        );
        if (mounted && _currentlyFocusedIndex == index) {
          setState(() => _predictions = results);
        }
      } else {
        if (mounted && _currentlyFocusedIndex == index) {
          setState(() => _predictions = []);
        }
      }
    });
  }

  Future<void> _pickContact() async {
    try {
      if (await FlutterContacts.requestPermission(readonly: true)) {
        final contact = await FlutterContacts.openExternalPick();
        if (contact != null) {
          String name = contact.displayName;
          String phone = '';
          if (contact.phones.isNotEmpty) {
            phone = contact.phones.first.number;
          }

          setState(() {
            _guestName = name;
            _guestPhone = phone;
            _contactController.text = "$name ($phone)";
          });
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

  Future<void> _onPredictionTapped(
    PlaceAutocompletePrediction prediction,
    int index,
  ) async {
    FocusScope.of(context).unfocus();
    final placeDetails = await _placesService.getPlaceDetails(
      prediction.placeId,
    );

    if (mounted && placeDetails != null) {
      setState(() {
        if (index == 0) {
          _pickupLocation = placeDetails.location;
          _pickupController.text = prediction.description;
        } else {
          _dropoffLocation = placeDetails.location;
          _dropoffController.text = prediction.description;
        }
        _predictions = [];
        _currentlyFocusedIndex = null;
      });
    }
  }

  Future<void> _openMapPicker(int index) async {
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

    setState(() => _isCalculating = true);

    // Get Route
    final routeDetails = await _directionsService.getDirections(
      _pickupLocation!,
      _dropoffLocation!,
    );

    if (routeDetails == null) {
      if (mounted) displaySnackBar(context, "Could not find a route.");
      setState(() => _isCalculating = false);
      return;
    }

    // Calculate Fare
    // For now, we proceed with standard fare calculation
    Future<Map<String, num>?> calculateFares() async {
      try {
        final result = await _calculateFaresCallable
            .call<Map<dynamic, dynamic>>({
              'distanceMeters': routeDetails.distanceMeters,
              'tollCost': routeDetails.tollCost,
              'pickupLocation': {
                'latitude': _pickupLocation!.latitude,
                'longitude': _pickupLocation!.longitude,
              },
            });
        final fares = result.data['fares'] as Map<dynamic, dynamic>?;
        return fares?.map(
          (key, value) => MapEntry(key.toString(), value as num),
        );
      } catch (e) {
        debugPrint("Error calculating fares: $e");
        return null;
      }
    }

    final calculatedFares = await calculateFares();

    setState(() => _isCalculating = false);

    if (calculatedFares == null) {
      if (mounted) displaySnackBar(context, "Could not calculate fares.");
      return;
    }

    final availability = {
      'Auto': true,
      'Hatchback': true,
      'Sedan': true,
      'SUV': true,
      'ActingDriver': true,
    };

    final duration = (routeDetails.durationSeconds / 60).round();
    final etaString = "$duration min";

    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => RideConfirmationBottomSheet(
          currentUser: widget.user,
          currentPosition: _pickupLocation!,
          destinationPosition: _dropoffLocation!,
          pickupAddress: _pickupController.text,
          destinationAddress: _dropoffController.text,
          isDropoffInServiceArea: true, // Assuming true for now or add check
          vehicleOptions: VehicleOption.defaultOptions, // Or filtered
          polylines: {
            Polyline(
              polylineId: const PolylineId("route"),
              points: routeDetails.polylinePoints,
              color: Colors.black,
              width: 5,
            ),
          },
          isLoadingFares: false,
          calculatedFares: calculatedFares,
          eta: etaString,
          routeDetails: routeDetails,
          pricingRules: widget.pricingRules,
          walletBalance: widget.walletBalance,
          rideType: RideType.bookForOther,
          availability: availability,
          onEditPickup: () => _openMapPicker(0),
          onEditDropoff: () => _openMapPicker(1),
          onSaveDropoffFavorite: () {},
          onSavePickupFavorite: () {},

          guestName: _guestName,
          guestPhone: _guestPhone,
        ),
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
                    _pickupFocusNode,
                    isDark,
                    Icons.my_location,
                  ),
                  const SizedBox(height: 12),
                  _buildLocationField(
                    1,
                    "Enter drop-off location",
                    _dropoffController,
                    _dropoffFocusNode,
                    isDark,
                    Icons.location_on,
                  ),

                  if (_predictions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildPredictionsList(isDark),
                  ],
                ],
              ),
            ),
          ),

          // Confirm Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ProButton(
              text: "Confirm Booking",
              isLoading: _isCalculating,
              onPressed: _isCalculating ? null : _confirmBooking,
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
    FocusNode focusNode,
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
        focusNode: focusNode,
        onChanged: (val) => _onSearchChanged(val, index),
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
          suffixIcon: IconButton(
            icon: Icon(Icons.map, color: Theme.of(context).primaryColor),
            onPressed: () => _openMapPicker(index),
          ),
        ),
      ),
    );
  }

  Widget _buildPredictionsList(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 200),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: _predictions.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final prediction = _predictions[index];
            return ListTile(
              leading: const Icon(
                Icons.location_on_outlined,
                color: Colors.grey,
                size: 20,
              ),
              title: Text(prediction.description),
              dense: true,
              onTap: () =>
                  _onPredictionTapped(prediction, _currentlyFocusedIndex!),
            );
          },
        ),
      ),
    );
  }
}
