import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:project_taxi_with_ai/controllers/metro_controller.dart';
import 'package:project_taxi_with_ai/models/ondc_model.dart';
import 'package:project_taxi_with_ai/screens/metro/metro_checkout_screen.dart';
import 'package:project_taxi_with_ai/app_colors.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';

class MetroOffersScreen extends GetView<MetroController> {
  const MetroOffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: ProAppBar(
        titleText: 'Available Routes'.tr,
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
            _buildRouteHeader(context),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (controller.multimodalOptions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.route_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        const Text(
                          'No routes found for this selection.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: 200,
                          child: ProButton(
                            text: "Try Again", 
                            onPressed: () => Get.back(),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: controller.multimodalOptions.length,
                  itemBuilder: (context, index) {
                    final option = controller.multimodalOptions[index];
                    return FadeInSlide(
                      delay: index * 0.1,
                      child: _buildRouteCard(context, option, index == 0),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildStationPoint(controller.sourceStation.value?.name ?? 'Start', isDark, true),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: List.generate(5, (index) => Expanded(
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        color: AppColors.primary.withValues(alpha: 0.2 + (index * 0.1)),
                      ),
                    )),
                  ),
                ),
              ),
              _buildStationPoint(controller.destinationStation.value?.name ?? 'End', isDark, false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStationPoint(String name, bool isDark, bool isStart) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isStart ? AppColors.primary : Colors.redAccent,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(
            isStart ? Icons.my_location : Icons.location_on, 
            color: Colors.white, 
            size: 14,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildRouteCard(BuildContext context, RouteOption option, bool isBest) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isBest ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isBest 
              ? AppColors.primary.withValues(alpha: 0.1) 
              : Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final success = await controller.selectRouteAction(option);
            if (success) {
              Get.to(() => const MetroCheckoutScreen());
            }
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isBest)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.star, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              "BEST VALUE",
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        option.providerName,
                        style: TextStyle(
                          fontSize: 12, 
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          option.totalPrice.formatted,
                          style: TextStyle(
                            fontSize: 22, 
                            fontWeight: FontWeight.bold, 
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (option.savings != null)
                          Text(
                            "Save ${option.savings!.formatted}",
                            style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Route Visualizer (Steps)
                Row(
                  children: [
                    for (int i = 0; i < option.steps.length; i++) ...[
                      _buildStepIcon(option.steps[i]),
                      if (i < option.steps.length - 1)
                        Expanded(
                          child: Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            color: isDark ? Colors.white10 : Colors.grey.shade200,
                          ),
                        ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time_filled, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          option.estimatedTime,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    Text(
                      "Details ›",
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIcon(RouteStep step) {
    IconData iconData;
    Color color;

    switch (step.type) {
      case RouteStepType.cab:
        iconData = Icons.local_taxi_rounded;
        color = Colors.amber;
        break;
      case RouteStepType.metro:
        iconData = Icons.train_rounded;
        color = AppColors.primary;
        break;
      case RouteStepType.walk:
        iconData = Icons.directions_walk_rounded;
        color = Colors.blueGrey;
        break;
    }

    return Tooltip(
      message: "${step.title}: ${step.subtitle}",
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: color, size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            "${step.duration.minutes}m",
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
