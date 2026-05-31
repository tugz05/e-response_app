import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Fetches a driving route from the OSRM public demo server and provides
/// simple distance / ETA helpers.
///
/// For production, replace [_osrmBase] with your own OSRM instance or a
/// paid routing service to avoid rate-limit issues.
class RoutingService {
  RoutingService._();

  static const String _osrmBase = 'https://router.project-osrm.org';

  // ── Route ─────────────────────────────────────────────────────────────────

  /// Returns the ordered driving-route waypoints from [origin] to
  /// [destination].  Returns an empty list on any failure.
  static Future<List<LatLng>> fetchRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    // OSRM coordinate order: longitude,latitude
    final url = Uri.parse(
      '$_osrmBase/route/v1/driving/'
      '${origin.longitude},${origin.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?geometries=geojson&overview=full',
    );

    try {
      final response =
          await http.get(url).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return [];

      final geometry =
          (routes[0] as Map<String, dynamic>)['geometry']
              as Map<String, dynamic>?;
      final coords = geometry?['coordinates'] as List?;
      if (coords == null) return [];

      // GeoJSON coordinates: [longitude, latitude]
      return coords.map((c) {
        final pair = c as List;
        return LatLng(
          (pair[1] as num).toDouble(), // latitude
          (pair[0] as num).toDouble(), // longitude
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static const Distance _distance = Distance();

  /// Haversine distance in metres between two points.
  static double distanceMeters(LatLng a, LatLng b) => _distance(a, b);

  /// Human-readable distance string.
  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  /// Rough ETA assuming ~30 km/h average rescue-vehicle speed.
  static String estimateEta(double meters) {
    final minutes = (meters / 1000 / 30 * 60).round();
    if (minutes < 1) return 'Almost there';
    if (minutes == 1) return '~1 min';
    return '~$minutes mins';
  }
}
