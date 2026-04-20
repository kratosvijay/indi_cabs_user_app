import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:project_taxi_with_ai/widgets/data_models.dart';

class RewardController extends GetxController {
  static RewardController get instance => Get.find();

  final Rx<RideReward?> rewardStatus = Rx<RideReward?>(null);
  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    _bindRewardStatus();
  }

  void _bindRewardStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('user_rewards')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
        rewardStatus.value = RideReward.fromFirestore(snapshot);
        isLoading.value = false;
      }, onError: (e) {
        debugPrint("Error listening to rewards: $e");
        isLoading.value = false;
      });
    } else {
      isLoading.value = false;
    }
  }

  double get cycleProgress {
    if (rewardStatus.value == null) return 0.0;
    return rewardStatus.value!.currentCycleRides / 7.0;
  }

  String get remainingCyclesText {
    if (rewardStatus.value == null) return "4 cycles remaining";
    int remaining = 4 - rewardStatus.value!.completedCycles;
    return "$remaining cycles remaining this month";
  }

  bool get isMaxCyclesReached {
    if (rewardStatus.value == null) return false;
    return rewardStatus.value!.completedCycles >= 4;
  }
}
