import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:project_taxi_with_ai/controllers/metro_controller.dart';
import 'package:project_taxi_with_ai/app_colors.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';

class MetroTicketScreen extends GetView<MetroController> {
  const MetroTicketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final order = controller.currentOrder.value;

    if (order == null) {
      return Scaffold(
        appBar: ProAppBar(titleText: 'Your Ticket'.tr),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.airplane_ticket_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              const Text('No active ticket found.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ProButton(text: 'Go Home', onPressed: () => Get.back()),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: ProAppBar(
        titleText: 'E-Ticket'.tr,
        automaticallyImplyLeading: false,
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: FadeInSlide(
                  child: _buildTicketCard(context, order),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Get.snackbar('Processing', 'Generating PDF receipt...');
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.download_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Receipt'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ProButton(
                      onPressed: () {
                        Get.until((route) => Get.currentRoute == '/HomePage' || Get.currentRoute == '/');
                      },
                      text: 'Go Home',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketCard(BuildContext context, dynamic order) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTicketHeader(context, order),
          _buildTicketDivider(context),
          _buildTicketBody(context, order),
          const SizedBox(height: 24),
          _buildQRSection(context, order),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTicketHeader(BuildContext context, dynamic order) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TICKET ID', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  Text(order.orderId.split('-').last, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'ISSUED', 
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              _buildStationCol(order.source.code, order.source.name, CrossAxisAlignment.start),
              Expanded(
                child: Column(
                  children: [
                    Icon(Icons.directions_transit_rounded, color: AppColors.primary, size: 28),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: List.generate(8, (index) => Expanded(
                          child: Container(
                            height: 2,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            color: AppColors.primary.withValues(alpha: 0.1 * (index + 2)),
                          ),
                        )),
                      ),
                    ),
                  ],
                ),
              ),
              _buildStationCol(order.destination.code, order.destination.name, CrossAxisAlignment.end),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStationCol(String code, String name, CrossAxisAlignment alignment) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(code, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: -1)),
        Text(
          name, 
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildTicketDivider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black.withValues(alpha: 0.5) : Colors.grey.shade50;
    
    return Row(
      children: [
        SizedBox(
          width: 12,
          height: 24,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Flex(
                  direction: Axis.horizontal,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    (constraints.constrainWidth() / 12).floor(),
                    (index) => SizedBox(
                      width: 6,
                      height: 1,
                      child: DecoratedBox(decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey.shade200)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(
          width: 12,
          height: 24,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTicketBody(BuildContext context, dynamic order) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoCol('PASSENGER', 'Indicabs User'),
              _buildInfoCol('TYPE', order.ticketType.name),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoCol('VALID UNTIL', 'Today 11:59 PM'),
              _buildInfoCol('PRICE', '₹${order.totalFare}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildQRSection(BuildContext context, dynamic order) {
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade100, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: QrImageView(
            data: order.qrCodeData,
            version: QrVersions.auto,
            size: 160.0,
            gapless: false,
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Scan this at the metro gate',
            style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
