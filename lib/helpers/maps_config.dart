/// Browser / Places REST API key from [Google Cloud Console](https://console.cloud.google.com/apis/credentials).
///
/// **Optional.** If unset, address suggestions use **OpenStreetMap Nominatim**
/// instead (no key — see [OpenStreetMapConfig] for `User-Agent` / fair-use).
///
/// Enable **Places API** (and billing). Restrict the key by Android/iOS app id + SHA-256
/// fingerprints for production.
///
/// Pass at build time:
/// `flutter run --dart-define=GOOGLE_MAPS_API_KEY=your_key`
class MapsConfig {
  MapsConfig._();

  /// Optional embedded fallback (same pattern as [GoogleSignInConfig]); prefer env.
  static const String _embeddedKey = '';

  static String get mapsApiKey {
    const fromEnv = String.fromEnvironment(
      'GOOGLE_MAPS_API_KEY',
      defaultValue: '',
    );
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    return _embeddedKey;
  }

  static bool get hasMapsApiKey => mapsApiKey.isNotEmpty;
}
