import 'package:project_taxi_with_ai/models/ondc_model.dart';
import 'package:project_taxi_with_ai/services/ondc_service.dart';

class OndcRepository {
  final OndcService _service;

  OndcRepository(this._service);

  Future<OndcSearchResponse> searchMultimodal({
    required double pickupLat,
    required double pickupLng,
    required double dropLat,
    required double dropLng,
  }) async {
    final response = await _service.search(
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      dropLat: dropLat,
      dropLng: dropLng,
    );

    final transactionId = response['context']?['transaction_id'] ?? '';
    final providers = response['message']?['catalog']?['bpp/providers'] as List? ?? [];
    List<RouteOption> options = [];

    for (var provider in providers) {
      final items = provider['items'] as List? ?? [];
      for (var item in items) {
        options.add(RouteOption.fromJson(item));
      }
    }

    return OndcSearchResponse(options: options, transactionId: transactionId);
  }

  Future<bool> selectOption(String itemId, String transactionId) async {
    await _service.select(itemId, transactionId);
    return true;
  }

  Future<bool> initializeOrder(Map<String, dynamic> order, String transactionId) async {
    await _service.init(order, transactionId);
    return true;
  }

  Future<bool> confirmBooking(Map<String, dynamic> order, String transactionId) async {
    await _service.confirm(order, transactionId);
    return true;
  }
}
