import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:project_taxi_with_ai/widgets/data_models.dart';

class DirectionsService {
  final String apiKey;

  DirectionsService({required this.apiKey});

  // **MODIFIED:** Added optional 'intermediates' parameter
  Future<RouteDetails?> getDirections(
    LatLng origin, 
    LatLng destination, {
    List<LatLng>? intermediates,
  }) async {
    if (apiKey.isEmpty) {
      debugPrint("Directions Service: API Key is missing.");
      return null;
    }

    final String url = "https://routes.googleapis.com/directions/v2:computeRoutes";
    
    final Map<String, dynamic> body = {
      "origin": {"location": {"latLng": {"latitude": origin.latitude, "longitude": origin.longitude}}},
      "destination": {"location": {"latLng": {"latitude": destination.latitude, "longitude": destination.longitude}}},
      "travelMode": "DRIVE",
      "routingPreference": "TRAFFIC_AWARE",
      "computeAlternativeRoutes": false,
      "extraComputations": ["TOLLS"], 
      "routeModifiers": {
        "vehicleInfo": {"emissionType": "GASOLINE"},
        "tollPasses": ["IN_FASTAG"]
      },
      "languageCode": "en-US",
      "units": "METRIC",
    };

    // **NEW:** Add intermediate waypoints to the request body if they exist
    if (intermediates != null && intermediates.isNotEmpty) {
      body["intermediates"] = intermediates.map((latLng) => {
        "location": {
          "latLng": {
            "latitude": latLng.latitude,
            "longitude": latLng.longitude
          }
        }
      }).toList();
    }

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': apiKey,
      'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.travelAdvisory.tollInfo',
    };

    try {
      final response = await http.post(Uri.parse(url), headers: headers, body: jsonEncode(body));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];

          final int distanceMeters = route['distanceMeters'] ?? 0;
          final String durationString = route['duration'] ?? "0s";
          final int durationSeconds = int.tryParse(durationString.replaceAll('s', '')) ?? 0;
          final String encodedPolyline = route['polyline']?['encodedPolyline'] ?? "";

          num totalTollCost = 0;
          if (route['travelAdvisory'] != null && 
              route['travelAdvisory']['tollInfo'] != null && 
              route['travelAdvisory']['tollInfo']['estimatedPrice'] != null) {
                
            final List estimatedPrices = route['travelAdvisory']['tollInfo']['estimatedPrice'];
            for (var price in estimatedPrices) {
              totalTollCost += (price['units'] != null ? num.tryParse(price['units'].toString()) ?? 0 : 0);
              totalTollCost += (price['nanos'] != null ? (num.tryParse(price['nanos'].toString()) ?? 0) / 1000000000 : 0);
            }
          }
          debugPrint("Estimated Toll Cost: $totalTollCost");

          List<LatLng> polylinePoints = [];
          if (encodedPolyline.isNotEmpty) {
             List<PointLatLng> decodedPoints = PolylinePoints.decodePolyline(encodedPolyline);
             polylinePoints = decodedPoints.map((p) => LatLng(p.latitude, p.longitude)).toList();
          }

          return RouteDetails(
            distanceMeters: distanceMeters,
            durationSeconds: durationSeconds,
            polylinePoints: polylinePoints,
            tollCost: totalTollCost,
          );
        } else {
           debugPrint("Directions API: No routes found. ${data['error']?['message'] ?? ''}");
           return null;
        }
      } else {
        debugPrint("Directions API Error: ${response.statusCode} ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Error fetching directions: $e");
      return null;
    }
  }
}