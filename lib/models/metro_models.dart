import 'package:google_maps_flutter/google_maps_flutter.dart';

class MetroStation {
  final String id;
  final String name;
  final String code;
  final LatLng location;

  MetroStation({
    required this.id,
    required this.name,
    required this.code,
    required this.location,
  });

  factory MetroStation.fromJson(Map<String, dynamic> json) {
    // Extract GPS: "13.1506,80.3058"
    final gps = json['location']?['gps'] as String? ?? '0,0';
    final latLng = gps.split(',');
    final lat = double.parse(latLng[0]);
    final lng = double.parse(latLng[1]);

    return MetroStation(
      id: json['id'] ?? '',
      name: json['descriptor']?['name'] ?? 'Unknown Station',
      code: json['descriptor']?['code'] ?? '',
      location: LatLng(lat, lng),
    );
  }

  // Static list of stations (mocked, until ONDC registry lookup is integrated)
  static List<MetroStation> get defaultStations => [
    MetroStation(
      id: 'CMRL-WMSTN',
      name: 'Wimco Nagar',
      code: 'WMSTN',
      location: const LatLng(13.1506, 80.3058),
    ),
    MetroStation(
      id: 'CMRL-TLC',
      name: 'Thiruvottiyur',
      code: 'TLC',
      location: const LatLng(13.1610, 80.3021),
    ),
    MetroStation(
      id: 'CMRL-WAS',
      name: 'Washermanpet',
      code: 'WAS',
      location: const LatLng(13.1098, 80.2882),
    ),
    MetroStation(
      id: 'CMRL-CTR',
      name: 'Chennai Central',
      code: 'CTR',
      location: const LatLng(13.0825, 80.2760),
    ),
    MetroStation(
      id: 'CMRL-EG',
      name: 'Egmore',
      code: 'EG',
      location: const LatLng(13.0781, 80.2620),
    ),
    MetroStation(
      id: 'CMRL-ARPT',
      name: 'Chennai Airport',
      code: 'ARPT',
      location: const LatLng(12.9941, 80.1709),
    ),
    MetroStation(
      id: 'CMRL-STT',
      name: 'Saidapet',
      code: 'STT',
      location: const LatLng(13.0232, 80.2223),
    ),
    MetroStation(
      id: 'CMRL-KMB',
      name: 'Koyambedu',
      code: 'KMB',
      location: const LatLng(13.0700, 80.2052),
    ),
  ];
}

class MetroTicketOffer {
  final String id;
  final String name;
  final String description;
  final double price;
  final String currency;
  final String type; // SJT, RJT

  MetroTicketOffer({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.type,
  });

  factory MetroTicketOffer.fromJson(Map<String, dynamic> json) {
    return MetroTicketOffer(
      id: json['id'] ?? '',
      name: json['descriptor']?['name'] ?? 'Single Journey Trip',
      description: json['descriptor']?['short_desc'] ?? 'One-way metro ticket',
      price: double.parse(json['price']?['value']?.toString() ?? '0'),
      currency: json['price']?['currency'] ?? 'INR',
      type: json['descriptor']?['code'] ?? 'SJT',
    );
  }
}

class MetroOrder {
  final String orderId;
  final String transactionId;
  final String status;
  final MetroStation source;
  final MetroStation destination;
  final MetroTicketOffer ticketType;
  final double totalFare;
  final String qrCodeData;
  final DateTime createdAt;

  MetroOrder({
    required this.orderId,
    required this.transactionId,
    required this.status,
    required this.source,
    required this.destination,
    required this.ticketType,
    required this.totalFare,
    required this.qrCodeData,
    required this.createdAt,
  });

  factory MetroOrder.fromJson(Map<String, dynamic> json, MetroStation src, MetroStation dest, MetroTicketOffer offer) {
    final order = json['message']?['order'] ?? {};
    return MetroOrder(
      orderId: order['id'] ?? 'TKT-${DateTime.now().millisecondsSinceEpoch}',
      transactionId: json['context']?['transaction_id'] ?? '',
      status: order['state'] ?? 'CONFIRMED',
      source: src,
      destination: dest,
      ticketType: offer,
      totalFare: double.parse(order['quote']?['price']?['value']?.toString() ?? offer.price.toString()),
      qrCodeData: order['id'] ?? 'UNAVAILABLE',
      createdAt: DateTime.parse(order['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}
