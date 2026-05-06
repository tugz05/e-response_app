/// Geographic bias for Google Places Autocomplete (Tandag City, Surigao del Sur).
///
/// Center point + radius work with `strictbounds` on the legacy Places endpoint so
/// predictions are limited to the circular area; results are additionally filtered
/// client-side for descriptions containing "Tandag".
///
/// [viewMinLon], [viewMaxLat], [viewMaxLon], [viewMinLat] define the Nominatim
/// `viewbox` (`left,top,right,bottom` = min lon, max lat, max lon, min lat).
class TandagPlacesBias {
  TandagPlacesBias._();

  static const double latitude = 9.0784;
  static const double longitude = 126.1986;

  /// Circle radius used with [strictbounds] (meters).
  static const int radiusMeters = 12000;

  /// Bounding box for OpenStreetMap Nominatim `viewbox` (soft bias; do not use
  /// `bounded=1` here — it often returns no rows for partial street queries).
  static const double viewMinLon = 126.08;
  static const double viewMaxLat = 9.16;
  static const double viewMaxLon = 126.32;
  static const double viewMinLat = 9.00;

  static String get nominatimViewbox =>
      '$viewMinLon,$viewMaxLat,$viewMaxLon,$viewMinLat';

  /// True when [lat]/[lon] fall inside the Tandag-area rectangle (WGS84).
  static bool containsLatLon(double lat, double lon) {
    return lon >= viewMinLon &&
        lon <= viewMaxLon &&
        lat >= viewMinLat &&
        lat <= viewMaxLat;
  }
}
