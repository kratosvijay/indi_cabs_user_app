import 'dart:async';
import 'dart:math'; // For min/max
import 'package:flutter/material.dart'; // For Color
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapService {
  final Completer<GoogleMapController> _mapControllerCompleter = Completer();

  // Initial map position (e.g., center of service area)
  static const CameraPosition initialPosition = CameraPosition(
    target: LatLng(13.0827, 80.2707), // Default to Chennai
    zoom: 12.0, // Zoom out slightly for initial view
  );

  // Callback when the map is created
  void onMapCreated(GoogleMapController controller) {
    if (!_mapControllerCompleter.isCompleted) {
      _mapControllerCompleter.complete(controller);
      // You could apply custom map styles here if desired
      // controller.setMapStyle(_mapStyleJson);
    }
  }

  // Animates the camera to a specific LatLng
  Future<void> animateCamera(LatLng target, {double zoom = 16.0}) async {
    if (!_mapControllerCompleter.isCompleted) return; // Map not ready
    try {
      final GoogleMapController controller =
          await _mapControllerCompleter.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: zoom, tilt: 30.0), // Add tilt
        ),
      );
    } catch (e) {
      debugPrint("Error animating camera: $e");
    }
  }

  // Animates the camera to fit a given LatLngBounds
  Future<void> animateCameraToBounds(
    LatLngBounds bounds, {
    double padding = 100.0,
  }) async {
    if (!_mapControllerCompleter.isCompleted) return; // Map not ready
    // Handle case where bounds are identical (single point)
    if (bounds.southwest.latitude == bounds.northeast.latitude &&
        bounds.southwest.longitude == bounds.northeast.longitude) {
      animateCamera(
        bounds.southwest,
        zoom: 16.0,
      ); // Zoom in on the single point
      return;
    }

    try {
      final GoogleMapController controller =
          await _mapControllerCompleter.future;
      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, padding));
    } catch (e) {
      // Bounds animation can sometimes fail if map isn't fully loaded or bounds are invalid
      debugPrint("Error animating camera to bounds: $e");
      // Fallback: Animate to center of bounds with a reasonable zoom
      LatLng center = LatLng(
        (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
        (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
      );
      animateCamera(center, zoom: 14.0);
    }
  }

  // Helper method to calculate LatLngBounds for two points
  LatLngBounds calculateBounds(LatLng pos1, LatLng pos2) {
    return LatLngBounds(
      southwest: LatLng(
        min(pos1.latitude, pos2.latitude),
        min(pos1.longitude, pos2.longitude),
      ),
      northeast: LatLng(
        max(pos1.latitude, pos2.latitude),
        max(pos1.longitude, pos2.longitude),
      ),
    );
  }

  // **NEW:** Helper method to calculate LatLngBounds for a list of points
  LatLngBounds calculateBoundsForAll(List<LatLng> points) {
    if (points.isEmpty) {
      return LatLngBounds(
        southwest: initialPosition.target,
        northeast: initialPosition.target,
      );
    }
    if (points.length == 1) {
      return LatLngBounds(southwest: points[0], northeast: points[0]);
    }

    double minLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLat = points[0].latitude;
    double maxLng = points[0].longitude;

    for (LatLng point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  // Creates the set of markers based on current locations
  // Creates the set of markers based on current locations
  Set<Marker> createMarkers({
    LatLng? pickupLocation,
    String? pickupAddress,
    LatLng? destinationLocation,
    String? destinationAddress,
    LatLng? driverLocation, // Optional: Add driver location later
    String? driverInfo, // Optional: Driver snippet
    BitmapDescriptor? pickupIcon,
    BitmapDescriptor? destinationIcon,
  }) {
    final Set<Marker> markers = {};

    if (pickupLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickupLocation,
          infoWindow: InfoWindow(title: "Pickup", snippet: pickupAddress ?? ''),
          icon:
              pickupIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          anchor: const Offset(0.5, 1.0), // Anchor at bottom center
        ),
      );
    }

    if (destinationLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: destinationLocation,
          infoWindow: InfoWindow(
            title: "Drop-off",
            snippet: destinationAddress ?? '',
          ),
          icon:
              destinationIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          anchor: const Offset(0.5, 1.0), // Anchor at bottom center
        ),
      );
    }

    if (driverLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: driverLocation,
          infoWindow: InfoWindow(title: "Driver", snippet: driverInfo ?? ''),
          icon: BitmapDescriptor.defaultMarker, // Placeholder icon
          anchor: const Offset(0.5, 0.5), // Center anchor for rotation
          flat: true, // Allows rotation with bearing
          // rotation: driverBearing, // Pass bearing if available
        ),
      );
    }

    return markers;
  }

  // Creates the set of polylines (currently only one route)
  Set<Polyline> createPolylines(List<LatLng>? routePoints) {
    final Set<Polyline> polylines = {};
    if (routePoints != null && routePoints.isNotEmpty) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: routePoints,
          color: Colors.blueAccent,
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round, // Smoother joints
        ),
      );
    }
    return polylines;
  }

  // --- Optional: Custom Map Style ---
  // final String _mapStyleJson = '''
  // [
  //   { "featureType": "...", ... },
  //   ...
  // ]
  // ''';
}
