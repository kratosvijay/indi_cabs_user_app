import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:project_taxi_with_ai/controllers/shared_rides_controller.dart';
import 'package:project_taxi_with_ai/screens/shared_ride_details_screen.dart';
import 'package:project_taxi_with_ai/widgets/data_models.dart';

class SharedRidesScreen extends StatelessWidget {
  const SharedRidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SharedRidesController());
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E0E13) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Shared Rides', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.indigo.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.rides.isEmpty) {
          return _buildEmptyState(isDark);
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: controller.rides.length,
          itemBuilder: (context, index) {
            final ride = controller.rides[index];
            return _RideCard(
              ride: ride,
              isBooked: controller.hasBookedRide(ride.rideId),
              isDark: isDark,
              onTap: () => Get.to(() => SharedRideDetailsScreen(ride: ride)),
            );
          },
        );
      }),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car_outlined,
            size: 80,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No rides available right now',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for upcoming shared rides',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  final SharedRide ride;
  final bool isBooked;
  final bool isDark;
  final VoidCallback onTap;

  const _RideCard({
    required this.ride,
    required this.isBooked,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white60 : Colors.grey.shade600;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Driver info row
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.indigo.shade100,
                    backgroundImage: ride.driverPhotoUrl != null
                        ? NetworkImage(ride.driverPhotoUrl!)
                        : null,
                    child: ride.driverPhotoUrl == null
                        ? Text(
                            ride.driverName.isNotEmpty ? ride.driverName[0].toUpperCase() : 'D',
                            style: TextStyle(
                              color: Colors.indigo.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ride.driverName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ride.vehicleModel,
                          style: TextStyle(fontSize: 13, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  // Rating badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 3),
                        Text(
                          ride.driverRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Route section
              _buildRouteRow(textPrimary, textSecondary),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // Bottom info row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _infoChip(
                    icon: Icons.access_time,
                    label: DateFormat('dd MMM, hh:mm a').format(ride.departureTime),
                    color: Colors.blue,
                    isDark: isDark,
                  ),
                  _infoChip(
                    icon: Icons.event_seat,
                    label: '${ride.availableSeats} seats left',
                    color: ride.availableSeats <= 1 ? Colors.red : Colors.green,
                    isDark: isDark,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isBooked ? Colors.green.shade600 : Colors.indigo.shade600,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isBooked ? 'Booked' : '₹${ride.pricePerSeat.toStringAsFixed(0)}/seat',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteRow(Color textPrimary, Color textSecondary) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            Container(width: 2, height: 28, color: Colors.grey.shade300),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.red.shade400,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ride.startLocation,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
              ),
              const SizedBox(height: 16),
              Text(
                ride.destination,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white70 : Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
