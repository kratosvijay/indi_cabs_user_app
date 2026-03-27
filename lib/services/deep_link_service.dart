import 'package:app_links/app_links.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';

class DeepLinkService extends GetxService {
  static DeepLinkService get instance => Get.find();
  
  late final AppLinks _appLinks;
  final Rxn<LatLng> incomingLocation = Rxn<LatLng>();

  @override
  void onInit() {
    debugPrint("DeepLinkService: onInit called");
    super.onInit();
    _appLinks = AppLinks();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    debugPrint("DeepLinkService: _initDeepLinks started");
    // 1. Handle initial link (cold start)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint("DeepLinkService: SUCCESS - Initial link received: $initialUri");
        _handleUri(initialUri);
      } else {
        debugPrint("DeepLinkService: No initial link found.");
      }
    } catch (e) {
      debugPrint("DeepLinkService: Error getting initial link: $e");
    }

    // 2. Handle subsequent links (app already open)
    debugPrint("DeepLinkService: Listening to uriLinkStream...");
    _appLinks.uriLinkStream.listen((uri) {
      debugPrint("DeepLinkService: Stream link received: $uri");
      _handleUri(uri);
    });
  }

  void _handleUri(Uri uri) {
    debugPrint("DeepLinkService: _handleUri called with scheme: ${uri.scheme}, host: ${uri.host}, path: ${uri.path}");
    LatLng? location;

    // Handle geo: scheme
    if (uri.scheme == 'geo') {
      final path = uri.path;
      debugPrint("DeepLinkService: Handling 'geo' scheme with path: $path");
      if (path.isNotEmpty && path != '0,0') {
        final coords = path.split(',');
        if (coords.length >= 2) {
          try {
            location = LatLng(double.parse(coords[0]), double.parse(coords[1]));
            debugPrint("DeepLinkService: Parsed location from geo path: $location");
          } catch (e) {
            debugPrint("DeepLinkService: Error parsing geo path: $e");
          }
        }
      } 
      
      // Check query parameters for q=lat,lng
      if (location == null && uri.queryParameters.containsKey('q')) {
        final q = uri.queryParameters['q']!;
        debugPrint("DeepLinkService: Checking 'q' param: $q");
        final match = RegExp(r"([-+]?\d+\.\d+),([-+]?\d+\.\d+)").firstMatch(q);
        if (match != null) {
          location = LatLng(double.parse(match.group(1)!), double.parse(match.group(2)!));
          debugPrint("DeepLinkService: Parsed location from 'q' param: $location");
        }
      }
    } 
    // Handle Google Maps links
    else if (uri.host.contains('google.com') || uri.host.contains('goo.gl')) {
      debugPrint("DeepLinkService: Handling Google Maps host: ${uri.host}");
      if (uri.queryParameters.containsKey('query')) {
        final q = uri.queryParameters['query']!;
        debugPrint("DeepLinkService: Checking 'query' param: $q");
        final match = RegExp(r"([-+]?\d+\.\d+),([-+]?\d+\.\d+)").firstMatch(q);
        if (match != null) {
          location = LatLng(double.parse(match.group(1)!), double.parse(match.group(2)!));
        }
      } else if (uri.queryParameters.containsKey('q')) {
        final q = uri.queryParameters['q']!;
        debugPrint("DeepLinkService: Checking 'q' param: $q");
        final match = RegExp(r"([-+]?\d+\.\d+),([-+]?\d+\.\d+)").firstMatch(q);
        if (match != null) {
          location = LatLng(double.parse(match.group(1)!), double.parse(match.group(2)!));
        }
      }
      // Handle path-based coordinates like /maps/place/lat,lng
      else {
        debugPrint("DeepLinkService: Checking URL path for coordinates: ${uri.toString()}");
        final match = RegExp(r"@([-+]?\d+\.\d+),([-+]?\d+\.\d+)").firstMatch(uri.toString());
        if (match != null) {
          location = LatLng(double.parse(match.group(1)!), double.parse(match.group(2)!));
          debugPrint("DeepLinkService: Parsed location from @ placeholder: $location");
        } else {
          // Handle !3d and !4d format
          final latMatch = RegExp(r"!3d([-+]?\d+\.\d+)").firstMatch(uri.toString());
          final lngMatch = RegExp(r"!4d([-+]?\d+\.\d+)").firstMatch(uri.toString());
          if (latMatch != null && lngMatch != null) {
            location = LatLng(double.parse(latMatch.group(1)!), double.parse(lngMatch.group(1)!));
            debugPrint("DeepLinkService: Parsed location from !3d/!4d: $location");
          }
        }
      }
    }

    if (location != null) {
      debugPrint("DeepLinkService: SUCCESS - Resolved location: $location");
      incomingLocation.value = location;
    } else {
      debugPrint("DeepLinkService: FAILED - Could not resolve location from URI");
    }
  }

  void clearIncomingLocation() {
    debugPrint("DeepLinkService: Clearing incoming location");
    incomingLocation.value = null;
  }
}
