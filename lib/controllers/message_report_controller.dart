import 'package:e_response_app_nemsu/routes/route_manager.dart';
import 'package:flutter/material.dart';
import '../services/send_message_service.dart';
import '../services/location_service.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';

class MessageReportController {
  final TextEditingController locationController = TextEditingController();
  final TextEditingController detailsController = TextEditingController();
  List<String> allLocations = [];

  /// Initialize the controller by fetching the current location and predefined locations.
  Future<void> initialize() async {
    try {
      // Get the current location and set it as the default.
      String currentAddress = await LocationService.getCurrentAddress();
      locationController.text = currentAddress;
    } catch (e) {
      locationController.text = 'Unable to fetch location. Please enter manually.';
    }

    try {
      // Fetch all predefined Philippine locations.
      allLocations = await LocationService.fetchPhilippineLocations();
    } catch (e) {
      allLocations = []; // Use an empty list if fetching fails.
    }
  }

  /// Get location suggestions based on the user's query.
  List<String> getSuggestions(String query) {
    return allLocations
        .where((location) => location.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  /// Fetch latitude and longitude for the selected address.
Future<Map<String, dynamic>> getLocationDetails(String address) async {
  try {
    if (address.isEmpty) {
      throw Exception("Address cannot be empty.");
    }

    // Use locationFromAddress to fetch locations
    List<Location>? locations = await locationFromAddress(address);

    // if (locations == null || locations.isEmpty) {
    //   throw Exception("No locations found for the provided address.");
    // }

    // Safely get the first location
    Location location = locations.first;
    return {
      'latitude': location.latitude,
      'longitude': location.longitude,
      'address': address,
    };
  } catch (e) {
    // Log error to help debugging
    print('Error in getLocationDetails: $e');
    throw Exception('Error fetching location details: $e');
  }
}


  /// Submit the report to the CDRRMO API.
Future<void> submitReport(BuildContext context, String id, List<XFile> images) async {
  if (locationController.text.isEmpty || detailsController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please fill in all fields.')),
    );
    return;
  }

  try {
    final locationDetails = await getLocationDetails(locationController.text);

    final service = SendMessageService();
    final response = await service.sendMessageWithImages(
      id: id,
      userId: id,
      address: locationDetails['address'],
      latitude: locationDetails['latitude'].toString(),
      longitude: locationDetails['longitude'].toString(),
      details: detailsController.text,
      type: 'Message',
      images: images,
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message submitted successfully.')),
      );
      locationController.clear();
      detailsController.clear();
      Navigator.pushNamed(context, RouteManager.ambulance_confirmation_screen);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit message: ${response.body}')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}

}
