import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:project_taxi_with_ai/widgets/data_models.dart';
import 'package:uuid/uuid.dart';
import 'package:project_taxi_with_ai/app_colors.dart';
import 'package:geolocator/geolocator.dart';
import 'package:project_taxi_with_ai/widgets/snackbar.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';

class EditLocationScreen extends StatefulWidget {
  final LatLng initialLocation;

  const EditLocationScreen({super.key, required this.initialLocation});

  @override
  State<EditLocationScreen> createState() => _EditLocationScreenState();
}

class _EditLocationScreenState extends State<EditLocationScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late LatLng _selectedLocation;
  String _selectedAddress = "Loading...";

  // --- Places API State ---
  late final String _apiKey;
  Timer? _debounce;
  final Uuid _uuid = const Uuid();
  String? _sessionToken;
  List<PlaceAutocompletePrediction> _predictions = [];

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;

    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (apiKey == null) {
      throw Exception("API Key not found in .env file");
    }
    _apiKey = apiKey;
    _sessionToken = _uuid.v4();

    _searchController.addListener(_onSearchChanged);
    _getAddressFromLatLng(_selectedLocation);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    // No setState here to avoid rebuilding map while typing
    if (!_searchFocusNode.hasFocus) return;
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.isNotEmpty) {
        _fetchAutocompleteResults(_searchController.text);
      } else {
        setState(() => _predictions = []);
      }
    });
  }

  Future<void> _fetchAutocompleteResults(String input) async {
    if (_sessionToken == null) return;
    final Uri uri = Uri.parse(
      'https://places.googleapis.com/v1/places:autocomplete',
    );
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': _apiKey,
    };
    final Map<String, dynamic> body = {
      'input': input,
      'sessionToken': _sessionToken,
      'includedRegionCodes': ['in'],
    };
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['suggestions'] != null && mounted) {
        setState(() {
          _predictions = (data['suggestions'] as List)
              .map((p) => PlaceAutocompletePrediction.fromJson(p))
              .toList();
        });
      }
    }
  }

  Future<void> _onPlaceSelected(String placeId) async {
    if (_sessionToken == null) return;
    final Uri uri = Uri.parse(
      'https://places.googleapis.com/v1/places/$placeId',
    );
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': _apiKey,
      'X-Goog-FieldMask': 'displayName,location',
    };
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final location = data['location'];
      if (location != null) {
        final newLocation = LatLng(location['latitude'], location['longitude']);
        setState(() {
          _selectedLocation = newLocation;
          _selectedAddress = data['displayName']?['text'] ?? 'Unknown place';
          // Update text only if we selected a place
          _searchController.text = _selectedAddress;
          _predictions = [];
        });
        final controller = await _mapController.future;
        controller.animateCamera(CameraUpdate.newLatLng(newLocation));
        _sessionToken = _uuid.v4();
      }
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$_apiKey',
    );
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        if (mounted) {
          final address = data['results'][0]['formatted_address'];
          setState(() {
            _selectedAddress = address;
            // CRITICAL: Do NOT update text field if user is typing/searching
            if (!_searchFocusNode.hasFocus) {
              _searchController.text = address;
            }
          });
        }
      }
    }
  }

  void _saveLocation() {
    Get.back(
      result: {'location': _selectedLocation, 'address': _selectedAddress},
    );
  }

  Future<void> _goToCurrentLocation() async {
    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final LatLng currentLatLng = LatLng(
        position.latitude,
        position.longitude,
      );
      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(currentLatLng, 17));
      setState(() {
        _selectedLocation = currentLatLng;
      });
      _getAddressFromLatLng(currentLatLng);
    } catch (e) {
      debugPrint("Error getting current location: $e");
      if (mounted) {
        displaySnackBar(context, "Could not fetch current location.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Colors.black54 : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: () => Get.back(),
          ),
        ),
      ),
      body: Stack(
        children: [
          // 1. Google Map
          // IMPORTANT: Removed setState from onCameraMove to prevent rebuilds during drag.
          GoogleMap(
            myLocationEnabled: true,
            initialCameraPosition: CameraPosition(
              target: widget.initialLocation,
              zoom: 17,
            ),
            myLocationButtonEnabled: false,
            mapType: MapType.normal,
            onMapCreated: (controller) {
              _mapController.complete(controller);
            },
            onCameraMove: (position) {
              // Update local variable ONLY, no setState
              _selectedLocation = position.target;
            },
            onCameraIdle: () {
              // Only fetch address on idle
              _getAddressFromLatLng(_selectedLocation);
            },
          ),

          // 2. Center Pin
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40.0),
              child: Icon(
                Icons.location_on,
                color: Colors.redAccent,
                size: 50,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
            ),
          ),

          // 3. Floating Search Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 60, // Space for back button
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search location...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                // Ensure focus remains or is regained
                                if (!_searchFocusNode.hasFocus) {
                                  _searchFocusNode.requestFocus();
                                }
                                setState(() {
                                  _predictions = [];
                                });
                              },
                              child: Icon(
                                Icons.clear,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            )
                          : const SizedBox.shrink(),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {}); // Rebuild to toggle clear button
                    },
                  ),
                ),
                // Autocomplete Predictions
                if (_predictions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _predictions.length,
                      separatorBuilder: (ctx, i) => Divider(
                        height: 1,
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                      ),
                      itemBuilder: (context, index) {
                        final prediction = _predictions[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.location_on_outlined,
                            size: 20,
                          ),
                          title: Text(
                            prediction.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            _onPlaceSelected(prediction.placeId);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // 4. "Locate Me" Button
          Positioned(
            bottom: 300, // Above the bottom sheet
            right: 20,
            child: FloatingActionButton(
              heroTag: 'locate_me_fab',
              onPressed: _goToCurrentLocation,
              backgroundColor: isDark ? Colors.grey[800] : Colors.white,
              child: Icon(Icons.my_location, color: AppColors.primary),
            ),
          ),

          // 5. Bottom Details Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[700] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      "Select Location",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.location_on,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedAddress,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ProButton(
                        text: "Confirm Location",
                        onPressed: _saveLocation,
                        // backgroundColor: AppColors.primary,
                        textColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
