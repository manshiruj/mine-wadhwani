class ApiConstants {
  ApiConstants._();

  // Override for local dev: --dart-define=API_BASE_URL=http://localhost:1425
  // or API_BASE_URL=origin (web): call the API on the same host that served the page.
  static const String _envBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://mine-wadhwani-4.onrender.com',
  );
  static String get baseUrl =>
      _envBaseUrl == 'origin' ? Uri.base.origin : _envBaseUrl;
  static const Duration connectTimeout = Duration(seconds: 90);
  static const Duration receiveTimeout = Duration(seconds: 90);
}

//'https://mine-wadhwani-4.onrender.com';
