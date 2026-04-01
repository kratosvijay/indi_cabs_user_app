import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:project_taxi_with_ai/controllers/metro_controller.dart';
import 'package:project_taxi_with_ai/screens/metro/metro_ticket_screen.dart';
import 'package:project_taxi_with_ai/app_colors.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';

class MetroCheckoutScreen extends GetView<MetroController> {
  const MetroCheckoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final option = controller.selectedRoute.value;

    return Scaffold(
      appBar: ProAppBar(
        titleText: 'Checkout'.tr,
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
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionHeader("Journey Summary", isDark),
                    const SizedBox(height: 16),
                    _buildSummaryCard(context, option),
                    const SizedBox(height: 32),
                    _buildSectionHeader("Fare Breakup", isDark),
                    const SizedBox(height: 16),
                    _buildFareBreakup(context, option),
                  ],
                ),
              ),
            ),

            // Confirm Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Obx(() => ProButton(
                onPressed: () async {
                  bool initSuccess = await controller.initOrder();
                  if (!initSuccess) {
                    Get.snackbar('Error', 'Failed to initialize order.');
                    return;
                  }

                  bool confirmSuccess = await controller.confirmBooking();
                  if (confirmSuccess) {
                    Get.off(() => const MetroTicketScreen());
                  } else {
                    Get.snackbar('Error', 'Payment confirmation failed.');
                  }
                },
                text: 'Proceed & Pay ${option?.totalPrice.formatted ?? ""}',
                isLoading: controller.isLoading.value,
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
    );
  }

  Widget _buildSummaryCard(BuildContext context, dynamic option) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.my_location, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PICKUP', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    Text(controller.sourceStation.value?.name ?? 'Current Location', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 17),
            child: SizedBox(
              height: 30, 
              child: VerticalDivider(
                thickness: 2, 
                color: isDark ? Colors.white10 : Colors.grey.shade100,
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on, color: Colors.redAccent, size: 18),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DESTINATION', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    Text(controller.destinationStation.value?.name ?? 'Indi Cabs Hub', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Divider(color: isDark ? Colors.white10 : Colors.grey.shade100),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.route_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PROVIDER', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    Text(option?.providerName ?? 'ONDC Multimodal', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'CONFIRMED', 
                  style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFareBreakup(BuildContext context, dynamic option) {
    if (option == null) return const SizedBox.shrink();
    
    return Column(
      children: [
        _buildFareRow('Base Fare', option.totalPrice.formatted),
        _buildFareRow('Taxes & Fees', '₹0.00'),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 12),
        _buildFareRow('Total Payble', option.totalPrice.formatted, isTotal: true),
      ],
    );
  }

  Widget _buildFareRow(String label, String amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label, 
            style: TextStyle(
              fontSize: isTotal ? 18 : 14, 
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal ? null : Colors.grey,
            ),
          ),
          Text(
            amount, 
            style: TextStyle(
              fontSize: isTotal ? 22 : 14, 
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600, 
              color: isTotal ? AppColors.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
