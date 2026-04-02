import 'package:project_taxi_with_ai/config/env_config.dart';
import 'package:project_taxi_with_ai/main.dart' as app;

void main() {
  EnvConfig.setConfig(
    EnvConfig(
      environment: Environment.dev,
      appName: 'Indi Cabs Dev',
      googleMapsKey: 'AIzaSyDxGUTTcU-yMjVfqbhSPeg8GGvfSrqtmSo',
      serverClientId: '854114457795-d0hns7g6jnhnoba53v178lomsvop234i.apps.googleusercontent.com',
      ondcSubscriberId: 'api.indicabs.net',
      ondcSigningPublicKey: '5z256FcRsaWzX8ngCo1tbx0QjrtFC7q0cBeAFifDrRA=',
      ondcEncryptionPublicKey: 'MCowBQYDK2VuAyEAMNf/3bNxKAYlvBWnS7xeRLsn+dJ1IUyAGvP8EDtMDR8=',
      ondcUniqueKeyId: '0b35d6b4-ed03-478f-9ad3-a8b3528026ef',
      ondcDomain: 'ONDC:TRV11',
      ondcCityCode: '*', // All Cities
      trackingUrl: 'https://projecttaxi-df0d2.web.app/track',
    ),
  );
  
  app.main();
}
