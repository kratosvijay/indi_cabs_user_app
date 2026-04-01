
enum RouteStepType { walk, cab, metro }

class OndcPrice {
  final String currency;
  final String value;

  OndcPrice({required this.currency, required this.value});

  factory OndcPrice.fromJson(Map<String, dynamic> json) {
    return OndcPrice(
      currency: json['currency'] ?? 'INR',
      value: json['value']?.toString() ?? '0',
    );
  }

  String get formatted => "$currency $value";
}

class OndcDuration {
  final String label;
  final int minutes;

  OndcDuration({required this.label, required this.minutes});

  factory OndcDuration.fromIso8601(String iso) {
    // Basic parser for ONDC 'PTxMxS' durations
    final regExp = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    final match = regExp.firstMatch(iso);
    int h = int.parse(match?.group(1) ?? '0');
    int m = int.parse(match?.group(2) ?? '0');
    return OndcDuration(
      label: iso,
      minutes: (h * 60) + m,
    );
  }
}

class RouteStep {
  final RouteStepType type;
  final String title;
  final String subtitle;
  final String? icon;
  final OndcDuration duration;

  RouteStep({
    required this.type,
    required this.title,
    required this.subtitle,
    this.icon,
    required this.duration,
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    String typeStr = (json['type'] ?? 'walk').toString().toLowerCase();
    RouteStepType type = RouteStepType.walk;
    if (typeStr.contains('metro')) type = RouteStepType.metro;
    if (typeStr.contains('cab') || typeStr.contains('taxi')) type = RouteStepType.cab;

    return RouteStep(
      type: type,
      title: json['title'] ?? 'Step',
      subtitle: json['subtitle'] ?? '',
      duration: OndcDuration.fromIso8601(json['duration'] ?? 'PT0M'),
    );
  }
}

class RouteOption {
  final String id;
  final String providerName;
  final List<RouteStep> steps;
  final OndcPrice totalPrice;
  final OndcPrice? savings;
  final String estimatedTime;

  RouteOption({
    required this.id,
    required this.providerName,
    required this.steps,
    required this.totalPrice,
    this.savings,
    required this.estimatedTime,
  });

  factory RouteOption.fromJson(Map<String, dynamic> json) {
    var stepsJson = json['steps'] as List? ?? [];
    return RouteOption(
      id: json['id'] ?? '',
      providerName: json['provider_name'] ?? 'ONDC Provider',
      steps: stepsJson.map((s) => RouteStep.fromJson(s)).toList(),
      totalPrice: OndcPrice.fromJson(json['price'] ?? {}),
      savings: json['savings'] != null ? OndcPrice.fromJson(json['savings']) : null,
      estimatedTime: json['estimated_time'] ?? '',
    );
  }

  bool get isMultimodal => steps.any((s) => s.type == RouteStepType.metro);
}

class OndcSearchResponse {
  final List<RouteOption> options;
  final String transactionId;

  OndcSearchResponse({required this.options, required this.transactionId});
}
