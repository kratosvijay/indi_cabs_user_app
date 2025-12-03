import 'package:flutter/material.dart';
import 'package:project_taxi_with_ai/widgets/data_models.dart';

// Callbacks
typedef ServiceTypeSelectedCallback = void Function(RideType rideType);
typedef PredefinedTapCallback =
    void Function(PredefinedDestination destination);

class BottomBarWidget extends StatelessWidget {
  final RideType selectedServiceType;
  final ServiceTypeSelectedCallback onServiceTypeSelected;
  final PredefinedTapCallback onPredefinedDestinationTap;

  // **REMOVED:** Keys are no longer needed here,
  // we will highlight the whole bar using the key from HomePage.

  const BottomBarWidget({
    super.key, // This key is what we use (passed from HomePage)
    required this.selectedServiceType,
    required this.onServiceTypeSelected,
    required this.onPredefinedDestinationTap,
  });

  @override
  Widget build(BuildContext context) {
    // Use the static list from the model
    final predefinedDestinations = PredefinedDestination.defaultDestinations;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 6,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Service Type Cards ---
            SizedBox(
              height: 90, // Give the row a fixed height
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildServiceTypeCard(
                      context: context,
                      icon: Icons.local_taxi_outlined,
                      label: "Daily Rides",
                      isSelected: selectedServiceType == RideType.daily,
                      onTap: () => onServiceTypeSelected(RideType.daily),
                      isDark: isDark,
                    ),
                    _buildServiceTypeCard(
                      context: context,
                      icon: Icons.multiple_stop,
                      label: "Multi-Stop",
                      isSelected: selectedServiceType == RideType.multiStop,
                      onTap: () => onServiceTypeSelected(RideType.multiStop),
                      isDark: isDark,
                    ),
                    _buildServiceTypeCard(
                      context: context,
                      icon: Icons.timelapse_outlined,
                      label: "Rentals",
                      isSelected: selectedServiceType == RideType.rental,
                      onTap: () => onServiceTypeSelected(RideType.rental),
                      isDark: isDark,
                    ),
                    _buildServiceTypeCard(
                      context: context,
                      icon: Icons.person_pin_outlined,
                      label: "Acting Driver",
                      isSelected: selectedServiceType == RideType.acting,
                      onTap: () => onServiceTypeSelected(RideType.acting),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
            // --- Popular Destinations (Only show for Daily Rides) ---
            if (selectedServiceType == RideType.daily) ...[
              const SizedBox(height: 20),
              Text(
                "Popular Destinations",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 115,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  scrollDirection: Axis.horizontal,
                  itemCount: predefinedDestinations.length,
                  itemBuilder: (context, index) {
                    final dest = predefinedDestinations[index];
                    return SizedBox(
                      width: 110,
                      child: Card(
                        margin: const EdgeInsets.only(right: 8),
                        clipBehavior: Clip.antiAlias,
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: InkWell(
                          onTap: () => onPredefinedDestinationTap(dest),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  dest.icon,
                                  size: 30,
                                  color: isDark
                                      ? Colors.blueAccent.shade100
                                      : Colors.blueAccent,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  dest.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper for Service Type Cards
  Widget _buildServiceTypeCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final selectedColor = isDark
        ? Colors.blueAccent.shade100
        : Colors.blueAccent;
    final unselectedColor = isDark
        ? Colors.grey.shade400
        : Colors.grey.shade600;
    final backgroundColor = isSelected
        ? (isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade50)
        : (isDark ? Colors.grey[800] : Colors.white);
    final textColor = isSelected
        ? selectedColor
        : (isDark ? Colors.white70 : Colors.black87);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 100, // Give each card a fixed width
        child: Card(
          elevation: isSelected ? 4 : 1.5,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: isSelected
                ? BorderSide(color: selectedColor, width: 1.5)
                : BorderSide.none,
          ),
          color: backgroundColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: isSelected ? selectedColor : unselectedColor,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
