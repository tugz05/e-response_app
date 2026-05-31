import 'dart:convert';

import 'package:e_response_app_nemsu/helpers/maps_config.dart';
import 'package:e_response_app_nemsu/helpers/tandag_places_bias.dart';
import 'package:e_response_app_nemsu/services/nominatim_autocomplete_service.dart';
import 'package:http/http.dart' as http;

/// Address suggestions for Tandag City: **Google Places** when a Maps API key is
/// set, otherwise **OpenStreetMap Nominatim** (no key; follow OSM usage policy).
class PlacesAutocompleteService {
  PlacesAutocompleteService._();
  static final PlacesAutocompleteService instance = PlacesAutocompleteService._();

  static final RegExp _tandagWord = RegExp(r'tandag', caseSensitive: false);

  Future<List<String>> fetchTandagSuggestions(String input) async {
    final query = input.trim();
    if (query.length < 2) {
      return [];
    }
    if (MapsConfig.hasMapsApiKey) {
      return _fetchGooglePlaces(query);
    }
    return NominatimAutocompleteService.instance.fetchTandagSuggestions(query);
  }

  Future<List<String>> _fetchGooglePlaces(String query) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      <String, String>{
        'input': query,
        'key': MapsConfig.mapsApiKey,
        'components': 'country:ph',
        'location':
            '${TandagPlacesBias.latitude},${TandagPlacesBias.longitude}',
        'radius': '${TandagPlacesBias.radiusMeters}',
        'strictbounds': 'true',
      },
    );

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        return [];
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        return [];
      }
      final status = decoded['status']?.toString() ?? '';
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        return [];
      }
      final list = decoded['predictions'];
      if (list is! List) {
        return [];
      }

      final out = <String>[];
      for (final p in list) {
        if (p is! Map) {
          continue;
        }
        final desc = p['description']?.toString().trim() ?? '';
        if (desc.isEmpty) {
          continue;
        }
        if (!_tandagWord.hasMatch(desc)) {
          continue;
        }
        out.add(desc);
        if (out.length >= 8) {
          break;
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }
}
