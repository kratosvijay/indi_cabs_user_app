import 'package:project_taxi_with_ai/config/env_config.dart';
import 'package:project_taxi_with_ai/main.dart' as app;

void main() {
  EnvConfig.setConfig(
    EnvConfig(
      environment: Environment.prod,
      appName: 'Indi Cabs',
      googleMapsKey: 'AIzaSyBnMfTqInBrDqPnq06CbMkIyGomOwboFto',
      serverClientId: '404641872366-iu3c35ku51jp9mt85a1j0ult661tnvot.apps.googleusercontent.com',
    ),
  );
  
  app.main();
}
