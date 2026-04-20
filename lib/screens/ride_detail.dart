// ignore_for_file: unnecessary_to_list_in_spreads

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project_taxi_with_ai/config/env_config.dart';
import 'package:project_taxi_with_ai/widgets/data_models.dart';
import 'package:project_taxi_with_ai/widgets/directions_service.dart';
import 'package:project_taxi_with_ai/widgets/map_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

class RideDetailScreen extends StatefulWidget {
  final Ride ride;

  const RideDetailScreen({super.key, required this.ride});

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  final MapService _mapService = MapService();
  late final DirectionsService _directionsService;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isLoadingRoute = true;
  LatLngBounds? _routeBounds;
  Driver? _driver;
  bool _isLoadingDriver = false;
  String? _rideDistance;
  String? _rideDuration;

  @override
  void initState() {
    super.initState();
    final apiKey = EnvConfig.instance.googleMapsKey;
    _directionsService = DirectionsService(apiKey: apiKey);
    _buildMapElements();
    if (widget.ride.driverId != null && widget.ride.driverId!.isNotEmpty) {
      _fetchDriverDetails();
    }
  }

  Future<void> _fetchDriverDetails() async {
    setState(() => _isLoadingDriver = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(widget.ride.driverId)
          .get();
      if (doc.exists) {
        if (mounted) {
          setState(() {
            _driver = Driver.fromFirestore(doc);
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching driver details: $e");
    } finally {
      if (mounted) setState(() => _isLoadingDriver = false);
    }
  }

  Future<void> _buildMapElements() async {
    final destinationLocation =
        widget.ride.actualDropoffLocation ?? widget.ride.dropoffLocation;
    final destinationAddress =
        widget.ride.actualDropoffAddress ?? widget.ride.dropoffAddress;

    final markers = _mapService.createMarkers(
      pickupLocation: widget.ride.pickupLocation,
      pickupAddress: widget.ride.pickupAddress,
      destinationLocation: destinationLocation,
      destinationAddress: destinationAddress,
    );

    int stopNumber = 1;
    List<LatLng> intermediateLatLngs = [];
    for (var stopData in widget.ride.intermediateStops) {
      try {
        final locationMap = stopData['location'] as Map<dynamic, dynamic>;
        final lat = locationMap['latitude'] as double;
        final lng = locationMap['longitude'] as double;
        final stopLatLng = LatLng(lat, lng);
        intermediateLatLngs.add(stopLatLng);

        markers.add(
          Marker(
            markerId: MarkerId('stop_$stopNumber'),
            position: stopLatLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
            infoWindow: InfoWindow(
              title: "Stop $stopNumber",
              snippet: stopData['address'] as String?,
            ),
          ),
        );
        stopNumber++;
      } catch (e) {
        debugPrint("Error parsing stop marker in ride detail: $e");
      }
    }

    List<LatLng>? routePoints;

    if (widget.ride.pickupLocation != destinationLocation) {
      final routeDetails = await _directionsService.getDirections(
        widget.ride.pickupLocation,
        destinationLocation,
        intermediates: intermediateLatLngs.isNotEmpty
            ? intermediateLatLngs
            : null,
      );
      routePoints = routeDetails?.polylinePoints;

      if (routeDetails != null) {
        // Use actual stats if available, otherwise use route estimates
        if (widget.ride.actualDistance != null) {
          // Always format actual distance in km for consistency and to handle small values gracefully
          _rideDistance =
              "${(widget.ride.actualDistance! / 1000).toStringAsFixed(2)} km";
        } else {
          // Format route distance
          if (routeDetails.distanceMeters >= 1000) {
            _rideDistance =
                "${(routeDetails.distanceMeters / 1000).toStringAsFixed(1)} km";
          } else {
            _rideDistance = "${routeDetails.distanceMeters} m";
          }
        }

        if (widget.ride.actualDuration != null) {
          final duration = Duration(
            seconds: widget.ride.actualDuration!.toInt(),
          );
          if (duration.inHours > 0) {
            _rideDuration =
                "${duration.inHours} hr ${duration.inMinutes % 60} min";
          } else {
            _rideDuration = "${duration.inMinutes} min";
          }
        } else {
          // Format route duration
          final duration = Duration(seconds: routeDetails.durationSeconds);
          if (duration.inHours > 0) {
            _rideDuration =
                "${duration.inHours} hr ${duration.inMinutes % 60} min";
          } else {
            _rideDuration = "${duration.inMinutes} min";
          }
        }
      }
    }

    final polylines = _mapService.createPolylines(routePoints);

    List<LatLng> allPoints = [widget.ride.pickupLocation, destinationLocation];
    if (routePoints != null) {
      allPoints.addAll(routePoints);
    }
    allPoints.addAll(intermediateLatLngs);
    final bounds = _mapService.calculateBoundsForAll(allPoints);

    if (mounted) {
      setState(() {
        _markers = markers;
        _polylines = polylines;
        _routeBounds = bounds;
        _isLoadingRoute = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Get.back(),
        ),
        title: Text(
          "Ride Details",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Date & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat(
                        'EEE, dd MMM yyyy',
                      ).format(widget.ride.timestamp),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      DateFormat('hh:mm a').format(widget.ride.timestamp),
                      style: TextStyle(fontSize: 14, color: subTextColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "ID: ${widget.ride.rideId}",
                      style: TextStyle(
                        fontSize: 12,
                        color: subTextColor,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                _buildStatusChip(widget.ride.status),
              ],
            ),
            const SizedBox(height: 20),

            // Map Card
            Container(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _isLoadingRoute
                    ? Center(child: CircularProgressIndicator(color: textColor))
                    : GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: widget.ride.pickupLocation,
                          zoom: 14,
                        ),
                        markers: _markers,
                        polylines: _polylines,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapType: MapType.normal,
                        onMapCreated: (controller) {
                          _mapService.onMapCreated(controller);
                          Future.delayed(const Duration(milliseconds: 300), () {
                            if (_routeBounds != null && mounted) {
                              _mapService.animateCameraToBounds(
                                _routeBounds!,
                                padding: 40.0,
                              );
                            }
                          });
                        },
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // **NEW:** Metro Ticket QR Code
            if (widget.ride.rideType == 'Metro' && widget.ride.qrCodeData != null)
              _buildMetroTicket(cardColor, textColor, subTextColor),

            if (widget.ride.rideType == 'Metro' && widget.ride.qrCodeData != null)
              const SizedBox(height: 24),

            // Stats Row (Distance & Duration)
            if (_rideDistance != null && _rideDuration != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      Icons.directions_car,
                      _rideDistance!,
                      "Distance",
                      textColor,
                      subTextColor!,
                    ),
                    Container(
                      height: 30,
                      width: 1,
                      color: Colors.grey.withAlpha(50),
                    ),
                    _buildStatItem(
                      Icons.access_time,
                      _rideDuration!,
                      "Duration",
                      textColor,
                      subTextColor,
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Driver Info Card (if available)
            if (_driver != null || _isLoadingDriver)
              _buildDriverCard(cardColor, textColor, subTextColor),

            if (_driver != null || _isLoadingDriver) const SizedBox(height: 24),

            // Route Timeline
            Text(
              "Route",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildTimelineItem(
                    icon: Icons.my_location,
                    iconColor: Colors.green,
                    title: "Pickup",
                    address: widget.ride.pickupAddress,
                    isFirst: true,
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),
                  ...widget.ride.intermediateStops.asMap().entries.map((entry) {
                    return _buildTimelineItem(
                      icon: Icons.circle,
                      iconColor: Colors.orange,
                      title: "Stop ${entry.key + 1}",
                      address: entry.value['address'] ?? 'Intermediate Stop',
                      textColor: textColor,
                      subTextColor: subTextColor,
                    );
                  }),
                  _buildTimelineItem(
                    icon: Icons.location_on,
                    iconColor: Colors.red,
                    title: "Drop-off",
                    address:
                        widget.ride.actualDropoffAddress ??
                        widget.ride.dropoffAddress,
                    isLast: true,
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Fare Breakdown
            Text(
              "Payment Details",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  if (widget.ride.status != 'completed') ...[
                    _buildFareRow("Ride Fare", widget.ride.baseFare, textColor),
                    if (widget.ride.surcharge > 0)
                      _buildFareRow(
                        "Surcharge",
                        widget.ride.surcharge,
                        textColor,
                      ),
                    if (widget.ride.toll > 0)
                      _buildFareRow("Tolls", widget.ride.toll, textColor),
                    if (widget.ride.tip > 0)
                      _buildFareRow("Tip", widget.ride.tip, textColor),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Divider(),
                    ),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Total Amount",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        widget.ride.formattedTotalFare,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Help Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Get.snackbar("Support", "Support feature coming soon!");
                },
                icon: const Icon(Icons.help_outline),
                label: const Text("Need Help with this Ride?"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: subTextColor!),
                  foregroundColor: textColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    switch (status.toLowerCase()) {
      case 'completed':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'cancelled':
      case 'cancelled_by_driver':
      case 'cancelled_by_user':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            status.replaceAll('_', ' ').toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard(
    Color? cardColor,
    Color textColor,
    Color? subTextColor,
  ) {
    if (_isLoadingDriver) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_driver == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey[200],
            backgroundImage: _driver!.photoUrl.isNotEmpty
                ? NetworkImage(_driver!.photoUrl)
                : null,
            child: _driver!.photoUrl.isEmpty
                ? const Icon(Icons.person, size: 30, color: Colors.grey)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _driver!.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${_driver!.carModel} • ${_driver!.carNumber}",
                  style: TextStyle(fontSize: 14, color: subTextColor),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      "4.8", // Placeholder rating
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String address,
    bool isFirst = false,
    bool isLast = false,
    required Color textColor,
    required Color? subTextColor,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: iconColor),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.withAlpha(50),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: subTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFareRow(String label, num amount, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 15, color: textColor.withAlpha(180)),
          ),
          Text(
            NumberFormat.currency(
              locale: 'en_IN',
              symbol: '₹',
              decimalDigits: 0,
            ).format(amount),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String value,
    String label,
    Color textColor,
    Color subTextColor,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blueAccent),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            Text(label, style: TextStyle(fontSize: 12, color: subTextColor)),
          ],
        ),
      ],
    );
  }

  Widget _buildMetroTicket(Color? cardColor, Color textColor, Color? subTextColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent.withAlpha(50)),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withAlpha(10),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.train, color: Colors.blueAccent, size: 40),
          const SizedBox(height: 12),
          Text(
            "Metro E-Ticket",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: widget.ride.qrCodeData!,
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Scan this at the entry/exit gate",
            style: TextStyle(fontSize: 14, color: subTextColor),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTicketInfo("ORDER ID", widget.ride.orderId ?? "N/A", subTextColor, textColor),
              _buildTicketInfo("TXN ID", widget.ride.transactionId ?? "N/A", subTextColor, textColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTicketInfo(String label, String value, Color? subTextColor, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: subTextColor, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          value.length > 15 ? "${value.substring(0, 12)}..." : value,
          style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
