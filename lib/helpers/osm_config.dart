/// OpenStreetMap Nominatim — **no API key**, but you must follow the
/// [usage policy](https://operations.osmfoundation.org/policies/nominatim/)
/// (identifiable `User-Agent`, modest request rate). For heavy traffic, run your
/// own Nominatim instance or use a paid geocoder.
class OpenStreetMapConfig {
  OpenStreetMapConfig._();

  /// Required by Nominatim. Prefer `--dart-define=OSM_NOMINATIM_USER_AGENT=App/1.0 (you@domain)`
  /// with a reachable contact for production.
  static String get nominatimUserAgent {
    const fromEnv = String.fromEnvironment(
      'OSM_NOMINATIM_USER_AGENT',
      defaultValue: '',
    );
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    return 'NEMSUEmergencyResponse/1.0 (Flutter app; configure OSM_NOMINATIM_USER_AGENT)';
  }
}
