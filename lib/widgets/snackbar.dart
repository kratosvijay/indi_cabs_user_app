import 'package:flutter/material.dart';
import 'package:get/get.dart';

void displaySnackBar(
  BuildContext context,
  String message, {
  bool isError = true,
}) {
  Get.snackbar(
    isError ? "Error" : "Success",
    message,
    snackPosition: SnackPosition.TOP,
    backgroundColor: isError ? Colors.redAccent : Colors.green,
    colorText: Colors.white,
    margin: const EdgeInsets.all(10),
    borderRadius: 10,
    duration: const Duration(seconds: 3),
  );
}
