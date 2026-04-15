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
        desiredAccuracy: LocationAccuracy.high);

    print('Current Latitude: ${position.latitude}');
    print('Current Longitude: ${position.longitude}');

    List<Placemark> placemarks =
        await placemarkFromCoordinates(position.latitude, position.longitude);

    if (placemarks.isNotEmpty) {
      Placemark place = placemarks[0];
      return '${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}';
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
