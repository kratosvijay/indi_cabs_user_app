enum Environment { dev, prod }

class EnvConfig {
  final Environment environment;
  final String appName;
  final String googleMapsKey;
  final String serverClientId;

  EnvConfig({
    required this.environment,
    required this.appName,
    required this.googleMapsKey,
    required this.serverClientId,
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
