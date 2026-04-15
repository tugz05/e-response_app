class ApiUrl {
  static const bool isOnline = false;

  static String get baseUrl {
    return isOnline 
      ? "https://cdrrmo-tandag.com" // Online URL
      : "http://127.0.0.1:8000";     // Offline/Localhost URL
  }

  static String getServiceUrl(String servicePath) {
    return "$baseUrl/$servicePath";
  }}
