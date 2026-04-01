import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:project_taxi_with_ai/controllers/metro_controller.dart';
import 'package:project_taxi_with_ai/screens/metro/metro_offers_screen.dart';
import 'package:project_taxi_with_ai/app_colors.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';

class MetroSearchScreen extends GetView<MetroController> {
  const MetroSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    controller.resetFlow();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: ProAppBar(
        titleText: 'metroTicket'.tr,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark 
                ? [AppColors.darkStart.withValues(alpha: 0.5), Colors.black] 
                : [Colors.white, Colors.grey.shade50],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FadeInSlide(
                      duration: Duration(milliseconds: 400),
                      child: Text(
                        "Where are you going?",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Station Selection Card
                    FadeInSlide(
                      delay: 0.1,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildStationSelector(
                              context,
                              label: 'Source Station',
                              icon: Icons.my_location,
                              isSource: true,
                            ),
                            const SizedBox(height: 8),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Divider(
                                  thickness: 1, 
                                  indent: 50, 
                                  endIndent: 20,
                                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                                ),
                                GestureDetector(
                                  onTap: () {
                                    final tmp = controller.sourceStation.value;
                                    controller.sourceStation.value = controller.destinationStation.value;
                                    controller.destinationStation.value = tmp;
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkStart : Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.primary.withValues(alpha: 0.3),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.2),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: Icon(Icons.swap_vert_rounded, color: AppColors.primary, size: 22),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildStationSelector(
                              context,
                              label: 'Destination Station',
                              icon: Icons.location_on,
                              isSource: false,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    Obx(() {
                      if (controller.errorMessage.value.isNotEmpty) {
                        return FadeInSlide(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    controller.errorMessage.value,
                                    style: const TextStyle(color: Colors.red, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                    
                    const FadeInSlide(
                      delay: 0.3,
                      child: Text(
                        "Quick Selection",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeInSlide(
                      delay: 0.4,
                      child: _buildStationList(context),
                    ),
                  ],
                ),
              ),
            ),

            // Search Button
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Obx(() {
                final bool canSearch = controller.sourceStation.value != null && 
                                     controller.destinationStation.value != null && 
                                     !controller.isLoading.value;
                return ProButton(
                  text: "Find Tickets",
                  isLoading: controller.isLoading.value,
                  onPressed: canSearch
                      ? () async {
                          final success = await controller.searchTickets();
                          if (success) {
                            Get.to(() => const MetroOffersScreen());
                          }
                        }
                      : null,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationSelector(BuildContext context, {required String label, required IconData icon, required bool isSource}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Obx(() {
      final station = isSource ? controller.sourceStation.value : controller.destinationStation.value;
      return InkWell(
        onTap: () => _showStationPicker(context, isSource),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      station?.name ?? 'Select Station',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: station != null 
                            ? (isDark ? Colors.white : Colors.black87)
                            : (isDark ? Colors.white24 : Colors.black26),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.keyboard_arrow_right_rounded, color: isDark ? Colors.white24 : Colors.black12),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildStationList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: controller.allStations.length > 4 ? 4 : controller.allStations.length,
        separatorBuilder: (context, index) => Divider(
          height: 1, 
          indent: 60,
          color: isDark ? Colors.white10 : Colors.grey.shade100,
        ),
        itemBuilder: (context, index) {
          final station = controller.allStations[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.train_rounded, color: AppColors.primary, size: 20),
            ),
            title: Text(
              station.name, 
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)
            ),
            subtitle: Text(
              station.code, 
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38)
            ),
            onTap: () {
              if (controller.sourceStation.value == null) {
                controller.sourceStation.value = station;
              } else if (controller.destinationStation.value == null && controller.sourceStation.value != station) {
                controller.destinationStation.value = station;
              }
            },
          );
        },
      ),
    );
  }

  void _showStationPicker(BuildContext context, bool isSource) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Get.bottomSheet(
      Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isSource ? 'Select Source' : 'Select Destination',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: controller.allStations.length,
                itemBuilder: (context, index) {
                  final station = controller.allStations[index];
                  final isSelected = (isSource && controller.sourceStation.value == station) ||
                                     (!isSource && controller.destinationStation.value == station);
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected 
                        ? AppColors.primary.withValues(alpha: 0.05) 
                        : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                      ),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : (isDark ? Colors.white10 : Colors.grey.shade100),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.train_rounded, 
                          color: isSelected ? Colors.white : AppColors.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        station.name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppColors.primary : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      subtitle: Text(station.code, style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
                      onTap: () {
                        if (isSource) {
                          controller.sourceStation.value = station;
                        } else {
                          controller.destinationStation.value = station;
                        }
                        Get.back();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
      enterBottomSheetDuration: const Duration(milliseconds: 300),
      exitBottomSheetDuration: const Duration(milliseconds: 200),
    );
  }
}

// Add a helper since it's missing in pro_library (will add it there too if needed)
class FadeInSlide extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final double delay;

  const FadeInSlide({
    super.key, 
    required this.child, 
    this.duration = const Duration(milliseconds: 500),
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return child; // Simplified for now since we have a version in pro_library
  }
}
