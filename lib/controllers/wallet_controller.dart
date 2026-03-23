import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfexceptions.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:project_taxi_with_ai/widgets/data_models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WalletController extends GetxController {
  static WalletController get instance => Get.find();

  final RxDouble balance = 0.0.obs;
  final RxList<WalletTransaction> transactions = <WalletTransaction>[].obs;
  final RxBool isLoading = false.obs;

  var cfPaymentGatewayService = CFPaymentGatewayService();

  final HttpsCallable _createOrderCallable = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  ).httpsCallable('createWalletOrder');
  final HttpsCallable _verifyPaymentCallable = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  ).httpsCallable('verifyWalletPayment');

  @override
  void onInit() {
    super.onInit();
    cfPaymentGatewayService.setCallback(_verifyPayment, _onError);
    _bindUserWallet();
  }

  @override
  void onClose() {
    // any needed cleanup
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
                  (t) =>
                      t.status ==
                      'successful', // Status logic remains or changes to "successful"
                )
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
    isLoading.value = true;

    try {
      final result = await _createOrderCallable.call<Map<dynamic, dynamic>>({
        'amount': amountInPaise,
        'currency': 'INR',
      });

      final orderId = result.data['orderId'] as String?;
      final paymentSessionId = result.data['paymentSessionId'] as String?;

      if (orderId == null || paymentSessionId == null) {
        throw Exception("Failed to fetch Cashfree payment session.");
      }

      var session = CFSessionBuilder()
          .setEnvironment(CFEnvironment.PRODUCTION) // Set to PRODUCTION when live
          .setOrderId(orderId)
          .setPaymentSessionId(paymentSessionId)
          .build();

      var cfWebCheckoutPayment = CFWebCheckoutPaymentBuilder()
          .setSession(session)
          .build();

      cfPaymentGatewayService.doPayment(cfWebCheckoutPayment);
    } on CFException catch (e) {
      Get.snackbar(
        "Error",
        "Failed to configure payment: ${e.message}",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      isLoading.value = false;
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

  void _verifyPayment(String orderId) async {
    try {
      await _verifyPaymentCallable.call({'order_id': orderId});
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

  void _onError(CFErrorResponse errorResponse, String orderId) {
    Get.snackbar(
      "Payment Failed",
      errorResponse.getMessage() ?? "Unknown error occurred.",
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
    isLoading.value = false;
  }
}
