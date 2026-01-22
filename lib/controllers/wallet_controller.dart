import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:project_taxi_with_ai/widgets/data_models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WalletController extends GetxController {
  static WalletController get instance => Get.find();

  final RxDouble balance = 0.0.obs;
  final RxList<WalletTransaction> transactions = <WalletTransaction>[].obs;
  final RxBool isLoading = false.obs;

  late Razorpay _razorpay;
  int _amountToVerify = 0;

  final HttpsCallable _createOrderCallable = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  ).httpsCallable('createWalletOrder');
  final HttpsCallable _verifyPaymentCallable = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  ).httpsCallable('verifyWalletPayment');

  @override
  void onInit() {
    super.onInit();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    _bindUserWallet();
  }

  @override
  void onClose() {
    _razorpay.clear();
    super.onClose();
  }

  void _bindUserWallet() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Listen to balance
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
            if (snapshot.exists) {
              final data = snapshot.data() as Map<String, dynamic>;
              balance.value =
                  (data['wallet_balance'] as num?)?.toDouble() ?? 0.0;
            }
          });

      // Listen to transactions
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('payment_history')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots()
          .listen((snapshot) {
            transactions.value = snapshot.docs
                .map((doc) => WalletTransaction.fromFirestore(doc))
                .where(
                  (t) => t.status == 'success',
                ) // Only show successful transactions
                .toList();
          });
    }
  }

  Future<void> addMoney(double amount) async {
    if (amount < 100) {
      Get.snackbar(
        "Error",
        "Minimum recharge amount is ₹100",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    final int amountInPaise = (amount * 100).round();
    _amountToVerify = amountInPaise;
    isLoading.value = true;

    try {
      final result = await _createOrderCallable.call<Map<dynamic, dynamic>>({
        'amount': amountInPaise,
        'currency': 'INR',
      });

      final orderId = result.data['orderId'] as String?;
      if (orderId == null) throw Exception("Failed to create order");

      final user = FirebaseAuth.instance.currentUser;
      final options = {
        'key': 'rzp_test_rG5fHn4V3K7A8z',
        'amount': amountInPaise,
        'name': 'TaxiApp Wallet',
        'order_id': orderId,
        'description': 'Add funds to wallet',
        'prefill': {
          'email': user?.email ?? '',
          'contact': user?.phoneNumber ?? '',
        },
        'theme': {'color': '#0000FF'},
      };

      _razorpay.open(options);
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to initiate payment: $e",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      isLoading.value = false;
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      await _verifyPaymentCallable.call({
        'razorpay_order_id': response.orderId,
        'razorpay_payment_id': response.paymentId,
        'razorpay_signature': response.signature,
        'amount': _amountToVerify,
      });
      Get.snackbar(
        "Success",
        "Funds added successfully!",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Payment verification failed: $e",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    Get.snackbar(
      "Payment Failed",
      response.message ?? "Unknown error",
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
    isLoading.value = false;
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    Get.snackbar(
      "External Wallet",
      "Opening ${response.walletName}...",
      snackPosition: SnackPosition.TOP,
    );
  }
}
