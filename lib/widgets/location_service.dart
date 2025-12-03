import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:project_taxi_with_ai/widgets/data_models.dart'; // Import models for chennaiBoundary

class LocationService {
  final String apiKey;
  static const LatLng defaultLocation = LatLng(
    13.0827,
    80.2707,
  ); // Default to Chennai

  LocationService({required this.apiKey});

  Future<bool> requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint("Location services are disabled.");
      // We can't request permission if services are off
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint("Location permissions are denied.");
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint("Location permissions are permanently denied.");
      return false;
    }

    // If we get here, permissions are granted
    return true;
  }

  /// **MODIFIED:** Now uses requestLocationPermission() first.
  Future<LatLng> getCurrentLocation() async {
    // 1. Check/request permission
    final bool hasPermission = await requestLocationPermission();

    if (!hasPermission) {
      return defaultLocation; // Return default if no permission
    }

    // 2. If permission is granted, get the position
    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint("Failed to get current location: $e");
      return defaultLocation; // Return default on error
    }
  }

  Future<String> getAddressFromLatLng(LatLng position) async {
    if (apiKey.isEmpty) return "API Key Missing";
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$apiKey',
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK' &&
            data['results'] != null &&
            (data['results'] as List).isNotEmpty) {
          final results = data['results'] as List;

          // 1. Check for Landmarks (Airport, Railway Station, etc.)
          for (var result in results) {
            final types = List<String>.from(result['types'] ?? []);
            if (types.contains('airport') ||
                types.contains('train_station') ||
                types.contains('transit_station') ||
                types.contains('bus_station')) {
              // Return the name of the landmark directly if available in formatted_address
              // Or better, check if 'name' exists (it usually doesn't in Geocoding API, but formatted_address is usually the name)
              return result['formatted_address'] ?? "Landmark";
            }
          }

          // 2. Parse Address Components for Apartments/Buildings
          // Use the first result (most specific)
          final firstResult = results[0];
          final components = firstResult['address_components'] as List;
          String? subpremise; // Flat/Unit #
          String? premise; // Building Name
          String? streetNumber; // Block/Door #
          String? route; // Street Name
          String? sublocality; // Area
          String? locality; // City

          for (var c in components) {
            final types = List<String>.from(c['types'] ?? []);
            final longName = c['long_name'] as String;

            if (types.contains('subpremise')) subpremise = longName;
            if (types.contains('premise')) premise = longName;
            if (types.contains('street_number')) streetNumber = longName;
            if (types.contains('route')) route = longName;
            if (types.contains('sublocality')) sublocality = longName;
            if (types.contains('locality')) locality = longName;
          }

          // Construct Specific Address
          List<String> parts = [];

          // Apartment/Building Logic
          if (subpremise != null && premise != null) {
            parts.add("$subpremise, $premise");
          } else if (premise != null) {
            parts.add(premise);
          } else if (subpremise != null) {
            parts.add("Unit $subpremise");
          }

          // Street/Block Logic
          if (streetNumber != null && route != null) {
            parts.add("$streetNumber, $route");
          } else if (route != null) {
            parts.add(route);
          }

          // Area/City Logic
          if (sublocality != null) parts.add(sublocality);
          if (locality != null && locality != sublocality) parts.add(locality);

          if (parts.isNotEmpty) {
            return parts.join(", ");
          }

          // Fallback
          return firstResult['formatted_address'] ?? "Address Format Error";
        } else {
          debugPrint(
            "Geocoding failed: ${data['status']} ${data['error_message'] ?? ''}",
          );
          return "Address not found";
        }
      } else {
        debugPrint("Geocoding HTTP error: ${response.statusCode}");
        return "Address lookup failed";
      }
    } catch (e) {
      debugPrint("Geocoding exception: $e");
      return "Could not fetch address";
    }
  }
  // --- Geofencing ---

  // **NEW:** A general-purpose polygon check
  bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.isEmpty) return false;
    int intersectCount = 0;
    for (int j = 0; j < polygon.length - 1; j++) {
      if (_rayCastIntersect(point, polygon[j], polygon[j + 1])) {
        intersectCount++;
      }
    }
    // Check the last segment connecting the last point to the first
    if (_rayCastIntersect(point, polygon[polygon.length - 1], polygon[0])) {
      intersectCount++;
    }
    return (intersectCount % 2) ==
        1; // Odd number of intersections means inside
  }

  // **MODIFIED:** This now uses the general-purpose isPointInPolygon
  bool isPointInServiceArea(LatLng point) {
    // Using chennaiBoundary constant from models.dart
    return isPointInPolygon(point, chennaiBoundary);
  }

  // Ray casting helper (remains private)
  bool _rayCastIntersect(LatLng point, LatLng vertA, LatLng vertB) {
    double aY = vertA.latitude, bY = vertB.latitude;
    double aX = vertA.longitude, bX = vertB.longitude;
    double pY = point.latitude, pX = point.longitude;

    if ((aY > pY && bY > pY) || (aY < pY && bY < pY)) {
      return false;
    }
    if (aX < pX && bX < pX) {
      return false;
    }
    if (aX > pX && bX > pX) {
      return true;
    }
    if (aX == bX) {
      return pX <= aX;
    }
    double intersectX = (pY - aY) * (bX - aX) / (bY - aY) + aX;
    return intersectX >= pX;
  }

  // Helper method to check if two locations are close
  bool areLocationsClose(
    LatLng? loc1,
    LatLng? loc2, {
    double toleranceInMeters = 10,
  }) {
    if (loc1 == null || loc2 == null) {
      return loc1 == null && loc2 == null;
    }
    double distance = Geolocator.distanceBetween(
      loc1.latitude,
      loc1.longitude,
      loc2.latitude,
      loc2.longitude,
    );
    return distance < toleranceInMeters;
  }
}
