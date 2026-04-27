import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:project_taxi_with_ai/widgets/data_models.dart';

// Callbacks
typedef ServiceTypeSelectedCallback = void Function(RideType rideType);
typedef PredefinedTapCallback =
    void Function(PredefinedDestination destination);

class BottomBarWidget extends StatefulWidget {
  final RideType selectedServiceType;
  final ServiceTypeSelectedCallback onServiceTypeSelected;
  final PredefinedTapCallback onPredefinedDestinationTap;

  const BottomBarWidget({
    super.key,
    required this.selectedServiceType,
    required this.onServiceTypeSelected,
    required this.onPredefinedDestinationTap,
  });

  @override
  State<BottomBarWidget> createState() => _BottomBarWidgetState();
}

class _BottomBarWidgetState extends State<BottomBarWidget> {
  final ScrollController _scrollController = ScrollController();
  bool _isAtBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      bool atBottom =
          _scrollController.offset >=
          _scrollController.position.maxScrollExtent - 20;
      if (atBottom != _isAtBottom) {
        setState(() {
          _isAtBottom = atBottom;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleScroll() {
    if (_isAtBottom) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

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
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.of(context).size.height *
                0.40, // Occupy at most 40% of screen height
          ),
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Service Type Cards ---
                SizedBox(
                  height:
                      120, // Increased height to prevent overflow and standardise card size
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildServiceTypeCard(
                          context: context,
                          icon: Icons.local_taxi_outlined,

                          label: "dailyRides".tr,
                          isSelected:
                              widget.selectedServiceType == RideType.daily,
                          onTap: () =>
                              widget.onServiceTypeSelected(RideType.daily),
                          isDark: isDark,
                        ),
                        _buildServiceTypeCard(
                          context: context,
                          icon: Icons.people_outline,
                          label: "Shared Rides".tr,
                          isSelected:
                              widget.selectedServiceType == RideType.sharedRides,
                          onTap: () =>
                              widget.onServiceTypeSelected(RideType.sharedRides),
                          isDark: isDark,
                        ),
                        _buildServiceTypeCard(
                          context: context,
                          icon: Icons.subway_rounded,
                          label: "Metro Ticket".tr,
                          isSelected:
                              widget.selectedServiceType == RideType.metro,
                          onTap: () {
                            Get.snackbar(
                              "Metro Ticket".tr,
                              "Metro Ticket coming soon!",
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.yellow,
                              colorText: Colors.black,
                            );
                          },
                          isDark: isDark,
                        ),
                        _buildServiceTypeCard(
                          context: context,
                          icon: Icons.person_add_alt_1_outlined,
                          label: "bookForGuest".tr,
                          isSelected:
                              widget.selectedServiceType ==
                              RideType.bookForOther,
                          onTap: () => widget.onServiceTypeSelected(
                            RideType.bookForOther,
                          ),
                          isDark: isDark,
                        ),
                        _buildServiceTypeCard(
                          context: context,
                          icon: Icons.multiple_stop,
                          label: "multiStop".tr,
                          isSelected:
                              widget.selectedServiceType == RideType.multiStop,
                          onTap: () =>
                              widget.onServiceTypeSelected(RideType.multiStop),
                          isDark: isDark,
                        ),
                        _buildServiceTypeCard(
                          context: context,
                          icon: Icons.timelapse_outlined,
                          label: "rentals".tr,
                          isSelected:
                              widget.selectedServiceType == RideType.rental,
                          onTap: () =>
                              widget.onServiceTypeSelected(RideType.rental),
                          isDark: isDark,
                        ),
                        _buildServiceTypeCard(
                          context: context,
                          icon: Icons.person_pin_outlined,
                          label: "actingDriver".tr,
                          isSelected:
                              widget.selectedServiceType == RideType.acting,
                          onTap: () {
                            Get.snackbar(
                              "comingSoon".tr,
                              "Feature coming soon!",
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.yellow,
                              colorText: Colors.black,
                            );
                          },
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ),
                // --- Popular Destinations (Only show for Daily Rides) ---
                if (widget.selectedServiceType == RideType.daily) ...[
                  const SizedBox(height: 20),
                  Text(
                    "popularDestinations".tr,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 135, // Increased height for better readability
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      scrollDirection: Axis.horizontal,
                      itemCount: predefinedDestinations.length,
                      itemBuilder: (context, index) {
                        final dest = predefinedDestinations[index];
                        return SizedBox(
                          width: 130, // Increased width for longer names
                          child: Card(
                            margin: const EdgeInsets.only(right: 8),
                            clipBehavior: Clip.antiAlias,
                            color: isDark ? Colors.grey[800] : Colors.grey[100],
                            elevation: isDark ? 6 : 4,
                            shadowColor: isDark
                                ? const Color(0xFFFFD700).withValues(alpha: 0.6)
                                : Colors.black.withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: isDark
                                  ? const BorderSide(
                                      color: Color(0xFFFFD700),
                                      width: 1.5,
                                    )
                                  : BorderSide.none,
                            ),
                            child: InkWell(
                              onTap: () =>
                                  widget.onPredefinedDestinationTap(dest),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      dest.icon,
                                      size: 30,
                                      color: isDark
                                          ? const Color(0xFFFFD700)
                                          : Colors.blueAccent,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      dest.name,
                                      textAlign: TextAlign.center,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black87,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 11,
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
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "shoppingEntertainment".tr,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _toggleScroll,
                        icon: Icon(
                          _isAtBottom
                              ? Icons.keyboard_double_arrow_up
                              : Icons.keyboard_double_arrow_down,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        tooltip: _isAtBottom ? 'Scroll Up' : 'Scroll Down',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 135,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      scrollDirection: Axis.horizontal,
                      itemCount: PredefinedDestination
                          .entertainmentDestinations
                          .length,
                      itemBuilder: (context, index) {
                        final dest = PredefinedDestination
                            .entertainmentDestinations[index];
                        return SizedBox(
                          width: 130, // Consistently sized width
                          child: Card(
                            margin: const EdgeInsets.only(right: 8),
                            clipBehavior: Clip.antiAlias,
                            color: isDark ? Colors.grey[800] : Colors.grey[100],
                            elevation: isDark ? 6 : 4,
                            shadowColor: isDark
                                ? const Color(0xFFFFD700).withValues(alpha: 0.6)
                                : Colors.black.withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: isDark
                                  ? const BorderSide(
                                      color: Color(0xFFFFD700),
                                      width: 1.5,
                                    )
                                  : BorderSide.none,
                            ),
                            child: InkWell(
                              onTap: () =>
                                  widget.onPredefinedDestinationTap(dest),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      dest.icon,
                                      size: 30,
                                      color: isDark
                                          ? const Color(0xFFFFD700)
                                          : Colors.blueAccent,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      dest.name,
                                      textAlign: TextAlign.center,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black87,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 11,
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
    final selectedColor = isDark ? const Color(0xFFFFD700) : Colors.blueAccent;
    final unselectedColor = isDark
        ? Colors.grey.shade400
        : Colors.grey.shade600;

    // Background color
    final backgroundColor = isSelected
        ? (isDark
              ? const Color(0xFFFFD700).withValues(alpha: 0.15)
              : Colors.blue.shade50)
        : (isDark ? Colors.grey[800] : Colors.white);

    final textColor = isSelected
        ? selectedColor
        : (isDark ? Colors.white70 : Colors.black87);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedScale(
        scale: isSelected ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          width: 115,
          height: 110,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? selectedColor : Colors.transparent,
              width: 2.0, // Constant width to prevent layout jitter inside
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isSelected ? 0.2 : 0.05),
                blurRadius: isSelected ? 8 : 4,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
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
                  maxLines: 2,
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
