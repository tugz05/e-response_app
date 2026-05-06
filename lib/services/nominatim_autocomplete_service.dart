import 'dart:convert';

import 'package:e_response_app_nemsu/helpers/osm_config.dart';
import 'package:e_response_app_nemsu/helpers/tandag_places_bias.dart';
import 'package:http/http.dart' as http;

/// OpenStreetMap [Nominatim](https://nominatim.org/) search — no API key.
///
/// Uses several query passes: soft [viewbox] bias, then nationwide search with
/// strict bbox / “Tandag” filtering, then an explicit “… Tandag Philippines” query.
/// Short fragments (e.g. `Mab`) may not match OSM names — users need a few letters
/// of the real place name (e.g. `Mabua`).
class NominatimAutocompleteService {
  NominatimAutocompleteService._();
  static final NominatimAutocompleteService instance =
      NominatimAutocompleteService._();

  static final RegExp _tandagWord = RegExp(r'tandag', caseSensitive: false);

  Future<List<String>> fetchTandagSuggestions(String input) async {
    final query = input.trim();
    if (query.length < 2) {
      return [];
    }

    final phases = <({String q, bool viewbox})>[
      (q: query, viewbox: true),
      (q: query, viewbox: false),
      (q: '$query Tandag Philippines', viewbox: false),
    ];

    for (final phase in phases) {
      final decoded = await _search(phase.q, useViewbox: phase.viewbox);
      final picked = _pickSuggestions(decoded);
      if (picked.isNotEmpty) {
        return picked;
      }
    }
    return [];
  }

  Future<List<dynamic>> _search(String q, {required bool useViewbox}) async {
    final params = <String, String>{
      'q': q,
      'format': 'json',
      'limit': '25',
      'countrycodes': 'ph',
      'addressdetails': '0',
    };
    if (useViewbox) {
      params['viewbox'] = TandagPlacesBias.nominatimViewbox;
    }

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', params);

    try {
      final res = await http
          .get(
            uri,
            headers: <String, String>{
              'User-Agent': OpenStreetMapConfig.nominatimUserAgent,
              'Accept': 'application/json',
              'Accept-Language': 'en',
            },
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) {
        return [];
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! List) {
        return [];
      }
      return decoded;
    } catch (_) {
      return [];
    }
  }

  List<String> _pickSuggestions(List<dynamic> decoded) {
    final out = <String>[];
    final seen = <String>{};
    for (final item in decoded) {
      if (item is! Map) {
        continue;
      }
      final name = item['display_name']?.toString().trim() ?? '';
      if (name.isEmpty) {
        continue;
      }
      final lat = double.tryParse(item['lat']?.toString() ?? '');
      final lon = double.tryParse(item['lon']?.toString() ?? '');
      final inTandagBox =
          lat != null &&
          lon != null &&
          TandagPlacesBias.containsLatLon(lat, lon);
      final mentionsTandag = _tandagWord.hasMatch(name);
      if (!inTandagBox && !mentionsTandag) {
        continue;
      }
      if (seen.add(name)) {
        out.add(name);
      }
      if (out.length >= 8) {
        break;
      }
    }
    return out;
  }
}
