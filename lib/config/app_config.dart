class AppConfig {
  // Set once via --dart-define at run/build time
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.13.74:5000',
  );
}
