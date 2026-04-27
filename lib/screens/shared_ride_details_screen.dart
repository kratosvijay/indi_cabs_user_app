
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:project_taxi_with_ai/controllers/shared_rides_controller.dart';
import 'package:project_taxi_with_ai/screens/shared_ride_booking_screen.dart';
import 'package:project_taxi_with_ai/widgets/data_models.dart';

class SharedRideDetailsScreen extends StatefulWidget {
  final SharedRide ride;

  const SharedRideDetailsScreen({super.key, required this.ride});

  @override
  State<SharedRideDetailsScreen> createState() => _SharedRideDetailsScreenState();
}

class _SharedRideDetailsScreenState extends State<SharedRideDetailsScreen> {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _buildMapOverlays();
  }

  void _buildMapOverlays() {
    final ride = widget.ride;

    // Decode polyline points if available
    List<LatLng> polylinePoints = [];
    if (ride.routePolyline.isNotEmpty) {
      try {
        polylinePoints = _decodePolyline(ride.routePolyline);
      } catch (_) {
        polylinePoints = [ride.startLatLng, ride.destinationLatLng];
      }
    } else {
      polylinePoints = [ride.startLatLng, ride.destinationLatLng];
    }

    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: polylinePoints,
          color: Colors.indigo.shade600,
          width: 4,
        ),
      };
      _markers = {
        Marker(
          markerId: const MarkerId('start'),
          position: ride.startLatLng,
          infoWindow: InfoWindow(title: 'Pickup', snippet: ride.startLocation),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
        Marker(
          markerId: const MarkerId('destination'),
          position: ride.destinationLatLng,
          infoWindow: InfoWindow(title: 'Drop', snippet: ride.destination),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      };
    });
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  LatLngBounds _getBounds() {
    final lats = [widget.ride.startLatLng.latitude, widget.ride.destinationLatLng.latitude];
    final lngs = [widget.ride.startLatLng.longitude, widget.ride.destinationLatLng.longitude];
    return LatLngBounds(
      southwest: LatLng(lats.reduce((a, b) => a < b ? a : b), lngs.reduce((a, b) => a < b ? a : b)),
      northeast: LatLng(lats.reduce((a, b) => a > b ? a : b), lngs.reduce((a, b) => a > b ? a : b)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white60 : Colors.grey.shade600;
    final controller = Get.find<SharedRidesController>();
    final isBooked = controller.hasBookedRide(ride.rideId);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E0E13) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Ride Details', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.indigo.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Map
          SizedBox(
            height: 220,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  (ride.startLatLng.latitude + ride.destinationLatLng.latitude) / 2,
                  (ride.startLatLng.longitude + ride.destinationLatLng.longitude) / 2,
                ),
                zoom: 10,
              ),
              polylines: _polylines,
              markers: _markers,
              onMapCreated: (c) {
                _mapController = c;
                Future.delayed(const Duration(milliseconds: 300), () {
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngBounds(_getBounds(), 60),
                  );
                });
              },
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
            ),
          ),
          // Details
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Route card
                  _buildCard(
                    isDark: isDark,
                    cardColor: cardColor,
                    child: Column(
                      children: [
                        _routePoint(
                          icon: Icons.radio_button_checked,
                          iconColor: Colors.green,
                          label: 'Pickup',
                          address: ride.startLocation,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 11),
                          child: Column(
                            children: List.generate(
                              3,
                              (_) => Container(
                                width: 2,
                                height: 6,
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                color: Colors.grey.shade300,
                              ),
                            ),
                          ),
                        ),
                        _routePoint(
                          icon: Icons.location_on,
                          iconColor: Colors.red.shade400,
                          label: 'Drop',
                          address: ride.destination,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Ride info grid
                  _buildCard(
                    isDark: isDark,
                    cardColor: cardColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ride Info',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _infoTile(
                                icon: Icons.access_time,
                                label: 'Departure',
                                value: DateFormat('dd MMM\nhh:mm a').format(ride.departureTime),
                                color: Colors.blue,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                              ),
                            ),
                            Expanded(
                              child: _infoTile(
                                icon: Icons.event_seat,
                                label: 'Total Seats',
                                value: '${ride.totalSeats}',
                                color: Colors.purple,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                              ),
                            ),
                            Expanded(
                              child: _infoTile(
                                icon: Icons.airline_seat_recline_normal,
                                label: 'Available',
                                value: '${ride.availableSeats}',
                                color: ride.availableSeats <= 1 ? Colors.red : Colors.green,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                              ),
                            ),
                            Expanded(
                              child: _infoTile(
                                icon: Icons.currency_rupee,
                                label: 'Per Seat',
                                value: '₹${ride.pricePerSeat.toStringAsFixed(0)}',
                                color: Colors.indigo,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Driver card
                  _buildCard(
                    isDark: isDark,
                    cardColor: cardColor,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.indigo.shade100,
                          backgroundImage: ride.driverPhotoUrl != null
                              ? NetworkImage(ride.driverPhotoUrl!)
                              : null,
                          child: ride.driverPhotoUrl == null
                              ? Text(
                                  ride.driverName.isNotEmpty ? ride.driverName[0].toUpperCase() : 'D',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo.shade700,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ride.driverName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${ride.vehicleModel} • ${ride.vehicleNumber}',
                                style: TextStyle(fontSize: 13, color: textSecondary),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.star, size: 14, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${ride.driverRating.toStringAsFixed(1)} rating',
                                    style: TextStyle(fontSize: 13, color: textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Price per seat', style: TextStyle(fontSize: 12, color: textSecondary)),
                Text(
                  '₹${ride.pricePerSeat.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: isBooked || ride.availableSeats == 0
                    ? null
                    : () => Get.to(() => SharedRideBookingScreen(ride: ride)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isBooked ? Colors.green.shade600 : Colors.indigo.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: Text(
                  isBooked
                      ? 'Already Booked'
                      : ride.availableSeats == 0
                          ? 'Fully Booked'
                          : 'Book Seats',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required bool isDark, required Color cardColor, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _routePoint({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: textSecondary)),
              Text(
                address,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
