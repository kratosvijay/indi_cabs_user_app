import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:project_taxi_with_ai/models/metro_models.dart';
import 'package:project_taxi_with_ai/models/ondc_model.dart';
import 'package:project_taxi_with_ai/services/ondc_service.dart';
import 'package:project_taxi_with_ai/repositories/ondc_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project_taxi_with_ai/controllers/ride_controller.dart';

class MetroController extends GetxController {
  static MetroController get instance => Get.find();

  // API & Repository
  final OndcRepository _ondcRepository = OndcRepository(OndcService());

  // State Variables
  final RxList<MetroStation> allStations = <MetroStation>[].obs;
  final Rxn<MetroStation> sourceStation = Rxn<MetroStation>();
  final Rxn<MetroStation> destinationStation = Rxn<MetroStation>();

  final RxList<RouteOption> multimodalOptions = <RouteOption>[].obs;
  final Rxn<RouteOption> selectedRoute = Rxn<RouteOption>();

  // Legacy state for backward compatibility (standard metro only)
  final RxList<MetroTicketOffer> availableOffers = <MetroTicketOffer>[].obs;
  final Rxn<MetroTicketOffer> selectedOffer = Rxn<MetroTicketOffer>();

  final Rxn<MetroOrder> currentOrder = Rxn<MetroOrder>();

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString transactionId = ''.obs;

  @override
  void onInit() {
    super.onInit();
    // Load default stations
    allStations.assignAll(MetroStation.defaultStations);
  }

  void resetFlow() {
    sourceStation.value = null;
    destinationStation.value = null;
    multimodalOptions.clear();
    selectedRoute.value = null;
    availableOffers.clear();
    selectedOffer.value = null;
    currentOrder.value = null;
    transactionId.value = '';
    errorMessage.value = '';
    isLoading.value = false;
  }

  // ─── ONDC Multimodal Actions ─────────────────────────────────────────────

  Future<bool> searchTickets() async {
    if (sourceStation.value == null || destinationStation.value == null) {
      Get.snackbar('Selection Required', 'Please select both source and destination stations.');
      return false;
    }

    try {
      isLoading.value = true;
      errorMessage.value = '';
      multimodalOptions.clear();

      final searchResponse = await _ondcRepository.searchMultimodal(
        pickupLat: sourceStation.value!.location.latitude,
        pickupLng: sourceStation.value!.location.longitude,
        dropLat: destinationStation.value!.location.latitude,
        dropLng: destinationStation.value!.location.longitude,
      );

      if (searchResponse.options.isEmpty) {
        errorMessage.value = 'No routes found. Please try again later.';
        return false;
      }

      transactionId.value = searchResponse.transactionId;
      multimodalOptions.assignAll(searchResponse.options);
      return true;
    } catch (e) {
      debugPrint('ERROR: searchTickets failed: $e');
      errorMessage.value = 'Server Error: Could not fetch tickets.';
      Get.snackbar('Service Unavailable', 'The ONDC metro service is currently unreachable.');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> selectRouteAction(RouteOption option) async {
    try {
      isLoading.value = true;
      selectedRoute.value = option;
      final success = await _ondcRepository.selectOption(option.id, transactionId.value);
      return success;
    } catch (e) {
      errorMessage.value = 'Selection failed: $e';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Order Lifecycle Actions ──────────────────────────────────────────

  Future<bool> initOrder() async {
    if (selectedRoute.value == null) return false;
    
    try {
      isLoading.value = true;
      // In a real flow, we would call _ondcRepository.initializeOrder(..., transactionId.value)
      await Future.delayed(const Duration(seconds: 1));
      return true;
    } catch (e) {
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> confirmBooking() async {
    if (selectedRoute.value == null) return false;

    try {
      isLoading.value = true;
      // In a real flow, we would call _ondcRepository.confirmBooking(..., transactionId.value)
      await Future.delayed(const Duration(seconds: 1));
      
      final price = double.parse(selectedRoute.value!.totalPrice.value);
      
      final order = MetroOrder(
        orderId: 'ONDC-ORD-${DateTime.now().millisecondsSinceEpoch}',
        transactionId: transactionId.value.isNotEmpty ? transactionId.value : 'TXN-${DateTime.now().millisecondsSinceEpoch}',
        status: 'CONFIRMED',
        source: sourceStation.value!,
        destination: destinationStation.value!,
        ticketType: MetroTicketOffer(
          id: 'SJT-1', 
          name: 'Single Journey', 
          description: 'Multimodal Journey', 
          price: price, 
          currency: 'INR', 
          type: 'SJT'
        ),
        totalFare: price,
        qrCodeData: 'https://indicabs.net/ticket/ORD-${DateTime.now().millisecondsSinceEpoch}',
        createdAt: DateTime.now(),
      );

      currentOrder.value = order;
      
      // Save to Ride History (Firestore)
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await RideController.instance.firestoreService.createSyncedMetroBooking(
          userId: user.uid,
          orderId: order.orderId,
          transactionId: transactionId.value,
          status: 'confirmed',
          sourceStation: order.source.name,
          sourceLocation: order.source.location,
          destStation: order.destination.name,
          destLocation: order.destination.location,
          totalFare: order.totalFare,
          qrCodeData: order.qrCodeData,
          ticketType: order.ticketType.name,
        );
      }
      
      return true;
    } catch (e) {
      errorMessage.value = 'Payment confirmation failed: $e';
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
