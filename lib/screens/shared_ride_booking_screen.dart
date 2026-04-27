import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:project_taxi_with_ai/controllers/shared_rides_controller.dart';
import 'package:project_taxi_with_ai/widgets/data_models.dart';

class SharedRideBookingScreen extends StatefulWidget {
  final SharedRide ride;

  const SharedRideBookingScreen({super.key, required this.ride});

  @override
  State<SharedRideBookingScreen> createState() => _SharedRideBookingScreenState();
}

class _SharedRideBookingScreenState extends State<SharedRideBookingScreen> {
  int _selectedSeats = 1;

  double get _totalPrice => _selectedSeats * widget.ride.pricePerSeat;

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white60 : Colors.grey.shade600;
    final controller = Get.find<SharedRidesController>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E0E13) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Book Seats', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.indigo.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trip summary card
            _buildSectionCard(
              isDark: isDark,
              cardColor: cardColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trip Summary',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _tripRow(
                    Icons.radio_button_checked,
                    Colors.green,
                    ride.startLocation,
                    textPrimary,
                    textSecondary,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 11),
                    child: Container(width: 2, height: 24, color: Colors.grey.shade300),
                  ),
                  _tripRow(
                    Icons.location_on,
                    Colors.red.shade400,
                    ride.destination,
                    textPrimary,
                    textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Divider(color: isDark ? Colors.white12 : Colors.grey.shade200),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: Colors.blue.shade600),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('dd MMM yyyy, hh:mm a').format(ride.departureTime),
                            style: TextStyle(fontSize: 13, color: textSecondary),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.airline_seat_recline_normal,
                              size: 16, color: Colors.green.shade600),
                          const SizedBox(width: 6),
                          Text(
                            '${ride.availableSeats} seats available',
                            style: TextStyle(fontSize: 13, color: textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Seat selector card
            _buildSectionCard(
              isDark: isDark,
              cardColor: cardColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Seats',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Number of seats',
                        style: TextStyle(fontSize: 14, color: textSecondary),
                      ),
                      Row(
                        children: [
                          _counterButton(
                            icon: Icons.remove,
                            onTap: _selectedSeats > 1
                                ? () => setState(() => _selectedSeats--)
                                : null,
                            isDark: isDark,
                          ),
                          Container(
                            width: 48,
                            alignment: Alignment.center,
                            child: Text(
                              '$_selectedSeats',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          _counterButton(
                            icon: Icons.add,
                            onTap: _selectedSeats < ride.availableSeats
                                ? () => setState(() => _selectedSeats++)
                                : null,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Price breakdown card
            _buildSectionCard(
              isDark: isDark,
              cardColor: cardColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Price Breakdown',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _priceRow(
                    '₹${ride.pricePerSeat.toStringAsFixed(0)} × $_selectedSeats seat${_selectedSeats > 1 ? 's' : ''}',
                    '₹${_totalPrice.toStringAsFixed(0)}',
                    textPrimary,
                    textSecondary,
                  ),
                  _priceRow('GST', 'None', textPrimary, textSecondary),
                  Divider(color: isDark ? Colors.white12 : Colors.grey.shade200),
                  _priceRow(
                    'Total Amount',
                    '₹${_totalPrice.toStringAsFixed(0)}',
                    textPrimary,
                    textSecondary,
                    isTotal: true,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Full amount goes directly to the driver. No platform fee.',
                            style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // No OTP note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_mode, size: 18, color: Colors.blue.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ride starts automatically at departure time. No OTP required.',
                      style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
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
        child: Obx(() => ElevatedButton(
              onPressed: controller.isBooking.value
                  ? null
                  : () => _confirmBooking(controller, ride),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade600,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              child: controller.isBooking.value
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      'Confirm Booking — ₹${_totalPrice.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            )),
      ),
    );
  }

  Future<void> _confirmBooking(SharedRidesController controller, SharedRide ride) async {
    final success = await controller.bookRide(
      rideId: ride.rideId,
      seatsToBook: _selectedSeats,
      pricePerSeat: ride.pricePerSeat,
    );
    if (success) {
      Get.back(); // close booking screen
      Get.back(); // close details screen
      Get.snackbar(
        'Booking Confirmed!',
        '$_selectedSeats seat${_selectedSeats > 1 ? 's' : ''} booked for ₹${_totalPrice.toStringAsFixed(0)}. Ride starts at ${DateFormat('hh:mm a, dd MMM').format(ride.departureTime)}.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade900,
        duration: const Duration(seconds: 4),
        icon: const Icon(Icons.check_circle, color: Colors.green),
      );
    }
  }

  Widget _buildSectionCard({
    required bool isDark,
    required Color cardColor,
    required Widget child,
  }) {
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

  Widget _tripRow(
    IconData icon,
    Color iconColor,
    String address,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            address,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _counterButton({
    required IconData icon,
    required VoidCallback? onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: onTap != null
              ? Colors.indigo.shade600
              : (isDark ? Colors.white12 : Colors.grey.shade200),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap != null ? Colors.white : Colors.grey,
        ),
      ),
    );
  }

  Widget _priceRow(
    String label,
    String value,
    Color textPrimary,
    Color textSecondary, {
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 15 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? textPrimary : textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal ? Colors.indigo.shade600 : textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
