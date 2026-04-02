enum Environment { dev, prod }

class EnvConfig {
  final Environment environment;
  final String appName;
  final String googleMapsKey;
  final String serverClientId;
  final String ondcSubscriberId;
  final String ondcSigningPublicKey;
  final String ondcEncryptionPublicKey;
  final String ondcUniqueKeyId;
  final String ondcDomain;
  final String ondcCityCode;
  final String trackingUrl;

  EnvConfig({
    required this.environment,
    required this.appName,
    required this.googleMapsKey,
    required this.serverClientId,
    required this.ondcSubscriberId,
    required this.ondcSigningPublicKey,
    required this.ondcEncryptionPublicKey,
    required this.ondcUniqueKeyId,
    required this.ondcDomain,
    required this.ondcCityCode,
    required this.trackingUrl,
  });

  static EnvConfig? _instance;
  static EnvConfig get instance {
    if (_instance == null) {
      throw Exception('EnvConfig not initialized. Call setConfig first.');
    }
    return _instance!;
  }

  static bool get isSet => _instance != null;

  static void setConfig(EnvConfig config) {
    _instance = config;
  }
}
