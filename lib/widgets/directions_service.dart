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

    // Use Legacy Directions API
    final String baseUrl =
        "https://maps.googleapis.com/maps/api/directions/json";

    String originStr = "${origin.latitude},${origin.longitude}";
    String destinationStr = "${destination.latitude},${destination.longitude}";

    // Helper to build URL
    String buildUrl({bool avoidHighways = false}) {
      String params =
          "origin=$originStr&destination=$destinationStr&mode=driving&alternatives=true&key=$apiKey";
      if (avoidHighways) {
        params += "&avoid=highways";
      }
      if (intermediates != null && intermediates.isNotEmpty) {
        String waypoints = intermediates
            .map((l) => "${l.latitude},${l.longitude}")
            .join('|');
        params += "&waypoints=$waypoints";
      }
      return "$baseUrl?$params";
    }

    try {
      // Strategy 1: Standard Driving
      final urlStandard = buildUrl(avoidHighways: false);
      // Strategy 2: Avoid Highways (Forces query to look at city roads/shorter paths)
      final urlAvoidHighways = buildUrl(avoidHighways: true);

      // Run both requests in parallel
      final responses = await Future.wait([
        http.get(Uri.parse(urlStandard)),
        http.get(Uri.parse(urlAvoidHighways)),
      ]);

      List<dynamic> allRoutes = [];

      for (var response in responses) {
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'OK' && data['routes'] != null) {
            allRoutes.addAll(data['routes']);
          }
        }
      }

      if (allRoutes.isNotEmpty) {
        debugPrint(
          "Multi-Strategy Routing returned ${allRoutes.length} total routes.",
        );

        // Find shortest route
        dynamic shortestRoute = allRoutes[0];
        int minDistance = 999999999;

        for (int i = 0; i < allRoutes.length; i++) {
          final route = allRoutes[i];
          int routeDistance = 0;
          if (route['legs'] != null) {
            for (var leg in route['legs']) {
              routeDistance += (leg['distance']?['value'] as int? ?? 0);
            }
          }

          final int durationVal =
              route['legs'] != null && route['legs'].isNotEmpty
              ? (route['legs'][0]['duration']?['value'] as int? ?? 0)
              : 0;

          final String summary = route['summary'] ?? "";

          debugPrint(
            "Route $i ($summary): Distance = $routeDistance meters, Duration = ${durationVal}s",
          );

          if (routeDistance < minDistance) {
            minDistance = routeDistance;
            shortestRoute = route;
          }
        }

        final route = shortestRoute;
        debugPrint("Selected shortest route: $minDistance meters");

        int totalDistance = 0;
        int totalDuration = 0;
        if (route['legs'] != null) {
          for (var leg in route['legs']) {
            totalDistance += (leg['distance']?['value'] as int? ?? 0);
            totalDuration += (leg['duration']?['value'] as int? ?? 0);
          }
        }

        final String encodedPolyline =
            route['overview_polyline']?['points'] ?? "";

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
          tollCost: 0, // Legacy API default
        );
      } else {
        debugPrint("Directions Service: No routes found in any strategy.");
        return null;
      }
    } catch (e) {
      debugPrint("Error fetching directions strategies: $e");
      return null;
    }
  }
}
