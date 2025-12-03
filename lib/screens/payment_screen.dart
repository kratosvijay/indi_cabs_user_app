// payment_screen.dart
// ignore_for_file: unused_element_parameter

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';
import 'package:project_taxi_with_ai/app_colors.dart';

class PaymentScreen extends StatefulWidget {
  final String currentPaymentMethod;
  final num currentBalance;
  final num totalFare;

  const PaymentScreen({
    super.key,
    required this.currentPaymentMethod,
    this.currentBalance = 0,
    this.totalFare = 0,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late String _selectedPaymentMethod;

  final currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  // Payment options (display title, internal key, icon data, optional asset)
  final List<_PaymentOption> _options = [
    _PaymentOption(
      key: 'Wallet',
      title: 'Wallet',
      icon: Icons.account_balance_wallet_outlined,
    ),
    _PaymentOption(key: 'Cash', title: 'Cash', icon: Icons.money),
    // PayLater group
    _PaymentOption(key: 'LazyPay', title: 'LazyPay', icon: Icons.payments),
    _PaymentOption(key: 'Simpl', title: 'Simpl', icon: Icons.credit_card),
    _PaymentOption(
      key: 'Postpaid',
      title: 'Postpaid',
      icon: Icons.account_balance,
    ),
    _PaymentOption(
      key: 'AmazonPayLater',
      title: 'Amazon Pay Later',
      icon: Icons.shopping_bag,
    ),
    // UPI
    _PaymentOption(key: 'GPay', title: 'Google Pay', icon: Icons.qr_code),
    _PaymentOption(key: 'PhonePe', title: 'PhonePe', icon: Icons.phone_android),
    _PaymentOption(key: 'Paytm', title: 'Paytm', icon: Icons.payments_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _selectedPaymentMethod = widget.currentPaymentMethod;
  }

  void _selectMethod(String key) {
    setState(() {
      _selectedPaymentMethod = key;
    });

    // pop with result (if this screen was opened via Navigator)
    Get.back(result: _selectedPaymentMethod);
  }

  bool _canUseWallet() => widget.currentBalance >= widget.totalFare;

  @override
  Widget build(BuildContext context) {
    // final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // gradient AppBar (choice 1B)
      appBar: const ProAppBar(titleText: 'Select Payment Method'),
      body: SafeArea(
        child: FadeInSlide(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fare summary
                _buildFareSummary(context),

                const SizedBox(height: 16),

                // Wallet section
                _sectionHeader('My Wallet'),
                _buildPaymentTile(
                  option: _options.firstWhere((o) => o.key == 'Wallet'),
                  subtitle:
                      'Balance: ${currencyFormatter.format(widget.currentBalance)}',
                  isEnabled: _canUseWallet(),
                  disabledMessage: _canUseWallet()
                      ? null
                      : 'Insufficient balance for this ride',
                ),

                const SizedBox(height: 12),
                const Divider(),

                // Cash
                _sectionHeader('Cash'),
                _buildPaymentTile(
                  option: _options.firstWhere((o) => o.key == 'Cash'),
                  isEnabled: true,
                ),
                const SizedBox(height: 12),
                const Divider(),

                // PayLater group
                _sectionHeader('Pay Later'),
                _buildPaymentTile(
                  option: _options.firstWhere((o) => o.key == 'LazyPay'),
                  isEnabled: true,
                  small: true,
                ),
                _buildPaymentTile(
                  option: _options.firstWhere((o) => o.key == 'Simpl'),
                  isEnabled: true,
                  small: true,
                ),
                _buildPaymentTile(
                  option: _options.firstWhere((o) => o.key == 'Postpaid'),
                  isEnabled: true,
                  small: true,
                ),
                _buildPaymentTile(
                  option: _options.firstWhere((o) => o.key == 'AmazonPayLater'),
                  isEnabled: true,
                  small: true,
                ),
                const SizedBox(height: 12),
                const Divider(),

                // UPI
                _sectionHeader('UPI'),
                _buildPaymentTile(
                  option: _options.firstWhere((o) => o.key == 'GPay'),
                  isEnabled: true,
                ),
                _buildPaymentTile(
                  option: _options.firstWhere((o) => o.key == 'PhonePe'),
                  isEnabled: true,
                ),
                _buildPaymentTile(
                  option: _options.firstWhere((o) => o.key == 'Paytm'),
                  isEnabled: true,
                ),

                const SizedBox(height: 28),

                // Confirm button
                _buildConfirmButton(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFareSummary(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: Theme.of(context).brightness == Brightness.dark
              ? [Colors.grey.shade800, Colors.grey.shade900]
              : [Colors.white, Colors.grey.shade100],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.local_taxi, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Fare',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  currencyFormatter.format(widget.totalFare),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Current selected
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Selected',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                _selectedPaymentMethod,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  // Glassmorphic tile builder (choice 2B)
  Widget _buildPaymentTile({
    required _PaymentOption option,
    String? subtitle,
    bool isEnabled = true,
    String? disabledMessage,
    bool small = false,
  }) {
    final bool isSelected = _selectedPaymentMethod == option.key;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    // colors adapt to dark/light
    final baseColor = dark
        ? Colors.white.withAlpha(60)
        : Colors.white.withAlpha(60);
    final borderColor = isSelected
        ? AppColors.primary.withAlpha(230)
        : (dark ? Colors.white12 : Colors.grey.withAlpha(90));

    final titleColor = isEnabled
        ? (dark ? Colors.white70 : Colors.black87)
        : Colors.grey[500];
    final subtitleColor = isEnabled
        ? (dark ? Colors.white60 : Colors.grey[700])
        : Colors.grey[500];

    // tile height variant for compact/small tiles
    final tileHeight = small ? 62.0 : 82.0;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isEnabled ? 1.0 : 0.6,
      child: GestureDetector(
        onTap: isEnabled ? () => _selectMethod(option.key) : null,
        child: Container(
          height: tileHeight,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Stack(
            children: [
              // Glassmorphic blurred background
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: borderColor,
                        width: isSelected ? 1.6 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(60),
                          blurRadius: isSelected ? 12 : 6,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Content
              Positioned.fill(
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    // Icon / logo
                    _buildLeadingIcon(option, isEnabled),
                    const SizedBox(width: 12),
                    // Title + subtitle
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.title,
                            style: TextStyle(
                              fontSize: small ? 14 : 16,
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (!isEnabled && disabledMessage != null)
                            Text(
                              disabledMessage,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.redAccent,
                              ),
                            )
                          else if (subtitle != null)
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: subtitleColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Animated "radio" indicator
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _AnimatedSelectionIndicator(
                        isSelected: isSelected,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(_PaymentOption option, bool isEnabled) {
    // If you have asset logos, prefer them:
    // example: if (option.logoAssetPath != null) return Image.asset(...)
    // For now we fallback to Icon widget.
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: isEnabled
            ? Colors.white.withAlpha(120)
            : Colors.grey.withAlpha(120),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          option.icon,
          size: 20,
          color: isEnabled ? AppColors.primary : Colors.grey[500],
        ),
      ),
    );
  }

  Widget _buildConfirmButton(BuildContext context) {
    final canConfirm = _selectedPaymentMethod.isNotEmpty;
    return ProButton(
      text:
          'Confirm — ${_selectedPaymentMethod.isEmpty ? '' : _selectedPaymentMethod}',
      onPressed: canConfirm
          ? () {
              // Return the chosen method
              Get.back(result: _selectedPaymentMethod);
            }
          : null,
    );
  }
}

// Small model for options
class _PaymentOption {
  final String key;
  final String title;
  final IconData icon;
  final String? logoAssetPath;

  _PaymentOption({
    required this.key,
    required this.title,
    required this.icon,
    this.logoAssetPath,
  });
}

// Animated circular selection indicator (custom radio)
class _AnimatedSelectionIndicator extends StatelessWidget {
  final bool isSelected;
  const _AnimatedSelectionIndicator({required this.isSelected, super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.grey.shade400,
          width: isSelected ? 2.2 : 1.3,
        ),
        color: isSelected
            ? AppColors.primary.withAlpha(30)
            : Colors.transparent,
      ),
      child: Center(
        child: AnimatedScale(
          scale: isSelected ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Icon(
            Icons.check,
            size: 14,
            color: isSelected ? AppColors.primary : Colors.transparent,
          ),
        ),
      ),
    );
  }
}
