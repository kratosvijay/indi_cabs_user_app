import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:project_taxi_with_ai/config/env_config.dart';

class OndcService {
  String get baseUrl => 'https://${EnvConfig.instance.ondcSubscriberId}/ondc';
  final _uuid = const Uuid();

  // ─── Buyer Actions ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> search({
    required double pickupLat,
    required double pickupLng,
    required double dropLat,
    required double dropLng,
    String? sourceName,
    String? destName,
  }) async {
    final body = {
      "context": _buildContext("search"),
      "message": {
        "intent": {
          "fulfillment": {
            "stops": [
              {
                "type": "START",
                "location": {
                  "gps": "$pickupLat,$pickupLng",
                  "address": {"name": sourceName ?? "Pickup"}
                }
              },
              {
                "type": "END",
                "location": {
                  "gps": "$dropLat,$dropLng",
                  "address": {"name": destName ?? "Destination"}
                }
              }
            ]
          }
        }
      }
    };

    return _post('/search', body);
  }

  Future<Map<String, dynamic>> select(String itemId, String transactionId) async {
    final body = {
      "context": _buildContext("select", transactionId: transactionId),
      "message": {
        "order": {
          "items": [{"id": itemId}]
        }
      }
    };
    return _post('/select', body);
  }

  Future<Map<String, dynamic>> init(Map<String, dynamic> selectedOrder, String transactionId) async {
    final body = {
      "context": _buildContext("init", transactionId: transactionId),
      "message": {
        "order": selectedOrder
      }
    };
    return _post('/init', body);
  }

  Future<Map<String, dynamic>> confirm(Map<String, dynamic> initializedOrder, String transactionId) async {
    final body = {
      "context": _buildContext("confirm", transactionId: transactionId),
      "message": {
        "order": initializedOrder
      }
    };
    return _post('/confirm', body);
  }

  Future<Map<String, dynamic>> status(String orderId, String transactionId) async {
    final body = {
      "context": _buildContext("status", transactionId: transactionId),
      "message": {
        "order_id": orderId
      }
    };
    return _post('/status', body);
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  Map<String, dynamic> _buildContext(String action, {String? transactionId}) {
    final config = EnvConfig.instance;
    return {
      "domain": config.ondcDomain,
      "country": "IND",
      "city": config.ondcCityCode,
      "action": action,
      "core_version": "1.2.0",
      "bap_id": config.ondcSubscriberId,
      "bap_uri": "https://${config.ondcSubscriberId}/ondc",
      "transaction_id": transactionId ?? _uuid.v4(),
      "message_id": _uuid.v4(),
      "timestamp": DateTime.now().toIso8601String(),
      "ttl": "PT30S"
    };
  }

  Future<Map<String, dynamic>> _post(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('ONDC API Error: ${response.statusCode} - ${response.body}');
    }
  }
}
