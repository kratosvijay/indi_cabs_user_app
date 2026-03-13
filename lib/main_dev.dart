import 'package:project_taxi_with_ai/config/env_config.dart';
import 'package:project_taxi_with_ai/main.dart' as app;

void main() {
  EnvConfig.setConfig(
    EnvConfig(
      environment: Environment.dev,
      appName: 'Indi Cabs Dev',
      googleMapsKey: 'AIzaSyDxGUTTcU-yMjVfqbhSPeg8GGvfSrqtmSo',
      serverClientId: '854114457795-d0hns7g6jnhnoba53v178lomsvop234i.apps.googleusercontent.com',
    ),
  );
  
  app.main();
}
