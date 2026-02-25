import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:project_taxi_with_ai/widgets/data_models.dart';

class DirectionsService {
  final String apiKey;

  DirectionsService({required this.apiKey});

  // **MODIFIED:** Added optional 'intermediates' parameter and upgraded to Routes API
  Future<RouteDetails?> getDirections(
    LatLng origin,
    LatLng destination, {
    List<LatLng>? intermediates,
  }) async {
    if (apiKey.isEmpty) {
      debugPrint("Directions Service: API Key is missing.");
      return null;
    }

    final String url =
        "https://routes.googleapis.com/directions/v2:computeRoutes";

    // Build the request body
    Map<String, dynamic> requestBody = {
      "origin": {
        "location": {
          "latLng": {
            "latitude": origin.latitude,
            "longitude": origin.longitude,
          },
        },
      },
      "destination": {
        "location": {
          "latLng": {
            "latitude": destination.latitude,
            "longitude": destination.longitude,
          },
        },
      },
      "travelMode": "DRIVE",
      "routingPreference": "TRAFFIC_AWARE",
      "computeAlternativeRoutes": true,
      "extraComputations": ["TOLLS"],
      "routeModifiers": {
        "avoidTolls": false,
        "avoidHighways": false,
        "avoidFerries": false,
      },
    };

    if (intermediates != null && intermediates.isNotEmpty) {
      requestBody["intermediates"] = intermediates
          .map(
            (l) => {
              "location": {
                "latLng": {"latitude": l.latitude, "longitude": l.longitude},
              },
            },
          )
          .toList();
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "X-Goog-Api-Key": apiKey,
          "X-Goog-FieldMask":
              "routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.travelAdvisory.tollInfo.estimatedPrice,routes.routeLabels",
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic>? routes = data['routes'];

        if (routes != null && routes.isNotEmpty) {
          debugPrint("Routes API returned ${routes.length} total routes.");

          // The Routes API naturally sorts by the best route (index 0) based on `routingPreference`.
          // We will find the fastest route explicitly by parsing `duration`.
          dynamic fastestRoute = routes[0];
          int minDurationSeconds = 999999999;

          for (int i = 0; i < routes.length; i++) {
            final route = routes[i];

            // "123s" format
            String durationString = route['duration'] ?? "0s";
            int durationVal =
                int.tryParse(durationString.replaceAll('s', '')) ?? 0;

            int distanceVal = route['distanceMeters'] as int? ?? 0;

            debugPrint(
              "Route $i: Distance = $distanceVal meters, Duration (Traffic) = ${durationVal}s",
            );

            if (durationVal < minDurationSeconds) {
              minDurationSeconds = durationVal;
              fastestRoute = route;
            }
          }

          final route = fastestRoute;
          debugPrint(
            "Selected fastest route duration: $minDurationSeconds seconds",
          );

          int totalDistance = route['distanceMeters'] as int? ?? 0;
          int totalDuration = minDurationSeconds;

          // Extract Tolls
          num totalTollCost = 0;
          final travelAdvisory = route['travelAdvisory'];
          if (travelAdvisory != null) {
            final tollInfo = travelAdvisory['tollInfo'];
            if (tollInfo != null && tollInfo['estimatedPrice'] != null) {
              final prices = tollInfo['estimatedPrice'] as List;
              if (prices.isNotEmpty) {
                // Google Maps Route API might return multiple prices (e.g. for different payment methods).
                // We only take the first explicit unit price instead of summing them all up.
                totalTollCost = num.tryParse(prices.first['units'] ?? "0") ?? 0;
                debugPrint("Detected Single Toll Cost Option: ₹$totalTollCost");
              }
            }
          }

          final String encodedPolyline =
              route['polyline']?['encodedPolyline'] ?? "";

          List<LatLng> polylinePoints = [];
          if (encodedPolyline.isNotEmpty) {
            List<PointLatLng> decodedPoints = PolylinePoints.decodePolyline(
              encodedPolyline,
            );
            polylinePoints = decodedPoints
                .map((p) => LatLng(p.latitude, p.longitude))
                .toList();
          }

          return RouteDetails(
            distanceMeters: totalDistance,
            durationSeconds: totalDuration,
            polylinePoints: polylinePoints,
            tollCost: totalTollCost,
          );
        } else {
          debugPrint("Routes API: No routes found in response.");
          return null;
        }
      } else {
        debugPrint(
          "Routes API Error: ${response.statusCode} - ${response.body}",
        );
        return null;
      }
    } catch (e) {
      debugPrint("Error calling Routes API: $e");
      return null;
    }
  }
}
