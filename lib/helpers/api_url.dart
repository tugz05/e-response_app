class ApiUrl {
  /// Set to `true` for production / staging deployment base URL.
  static const bool isOnline = true;

  static String get baseUrl {
    return isOnline
        ? 'https://cdrrmo-tandag.com'
        : 'http://127.0.0.1:8000';
  }

  /// Fallback route arg only; real outbound `To` comes from `twilio_dial_identity` / `dial_to` APIs.
  static const String defaultTwilioOperatorIdentity = 'admin_user';

  static String getServiceUrl(String servicePath) {
    return '$baseUrl/$servicePath';
  }
}
