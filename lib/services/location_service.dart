import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationService {
  // Fetch current address using geolocation
  static Future<String> getCurrentAddress() async {
  try {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }

    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    List<Placemark> placemarks =
        await placemarkFromCoordinates(position.latitude, position.longitude);

    if (placemarks.isNotEmpty) {
      Placemark place = placemarks[0];
      final parts = <String>[
        if (place.street != null && place.street!.trim().isNotEmpty)
          place.street!.trim(),
        if (place.subLocality != null && place.subLocality!.trim().isNotEmpty)
          place.subLocality!.trim(),
        if (place.locality != null && place.locality!.trim().isNotEmpty)
          place.locality!.trim(),
        if (place.administrativeArea != null &&
            place.administrativeArea!.trim().isNotEmpty)
          place.administrativeArea!.trim(),
        if (place.country != null && place.country!.trim().isNotEmpty)
          place.country!.trim(),
      ];
      if (parts.isEmpty) {
        return '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }
      return parts.join(', ');
    } else {
      throw Exception('No address available for current location.');
    }
  } catch (e) {
    throw Exception('Error getting current address: $e');
  }
}


  // Fetch predefined Philippine locations from PSGC API
  static Future<List<String>> fetchPhilippineLocations() async {
    final response = await http.get(Uri.parse('https://psgc.gitlab.io/api/cities/166819000/barangays/'));

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      List<String> locations =
          data.map((region) => region['name'] as String).toList();
      return locations;
    } else {
      throw Exception('Failed to load locations');
    }
  }
}
