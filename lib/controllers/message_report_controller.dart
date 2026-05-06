import 'dart:convert';

import 'package:e_response_app_nemsu/services/location_service.dart';
import 'package:e_response_app_nemsu/services/send_message_service.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';

/// Result of submitting a written report to the API.
class MessageReportSubmitResult {
  final bool success;
  final String message;
  final String? reference;

  const MessageReportSubmitResult._({
    required this.success,
    required this.message,
    this.reference,
  });

  factory MessageReportSubmitResult.ok({String? reference}) {
    return MessageReportSubmitResult._(
      success: true,
      message: 'Your report was submitted successfully.',
      reference: reference,
    );
  }

  factory MessageReportSubmitResult.fail(String message) {
    return MessageReportSubmitResult._(success: false, message: message);
  }
}

class MessageReportController {
  final TextEditingController detailsController = TextEditingController();
  List<String> allLocations = [];

  void dispose() {
    detailsController.dispose();
  }

  Future<void> initialize() async {
    try {
      allLocations = await LocationService.fetchPhilippineLocations();
    } catch (e) {
      allLocations = [];
    }
  }

  List<String> getSuggestions(String query) {
    if (query.trim().isEmpty) return [];
    return allLocations
        .where(
          (location) => location.toLowerCase().contains(query.toLowerCase()),
        )
        .take(24)
        .toList();
  }

  Future<Map<String, dynamic>> getLocationDetails(String address) async {
    if (address.trim().isEmpty) {
      throw Exception('Address cannot be empty.');
    }

    final List<Location> locations = await locationFromAddress(address.trim());
    if (locations.isEmpty) {
      throw Exception(
        'Could not resolve that address to coordinates. Try refining the location or picking a suggestion from the list.',
      );
    }

    final Location location = locations.first;
    return {
      'latitude': location.latitude,
      'longitude': location.longitude,
      'address': address.trim(),
    };
  }

  String? _parseReferenceFromBody(String body) {
    if (body.trim().isEmpty) return null;
    try {
      final decoded = json.decode(body);
      if (decoded is! Map<String, dynamic>) return null;
      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        final id = data['report_id'] ?? data['id'];
        if (id != null) return id.toString();
      }
      final id = decoded['report_id'] ?? decoded['id'];
      if (id != null) return id.toString();
    } catch (_) {}
    return null;
  }

  Future<MessageReportSubmitResult> submitReport({
    required String locationText,
    required String userId,
    required List<XFile> images,
    String? bearerToken,
  }) async {
    if (locationText.trim().isEmpty) {
      return MessageReportSubmitResult.fail('Please enter the incident location.');
    }
    if (detailsController.text.trim().length < 8) {
      return MessageReportSubmitResult.fail(
        'Please describe what happened in at least 8 characters.',
      );
    }

    try {
      final Map<String, dynamic> locationDetails =
          await getLocationDetails(locationText);

      final SendMessageService service = SendMessageService();
      final response = await service.sendMessageWithImages(
        userId: userId,
        address: locationDetails['address'] as String,
        latitude: locationDetails['latitude'].toString(),
        longitude: locationDetails['longitude'].toString(),
        details: detailsController.text.trim(),
        type: 'Message',
        images: images,
        bearerToken: bearerToken,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final ref = _parseReferenceFromBody(response.body);
        return MessageReportSubmitResult.ok(reference: ref);
      }

      String err = 'Server returned HTTP ${response.statusCode}.';
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map && decoded['message'] != null) {
          err = decoded['message'].toString();
        }
      } catch (_) {
        if (response.body.isNotEmpty && response.body.length < 400) {
          err = response.body;
        }
      }
      return MessageReportSubmitResult.fail(err);
    } catch (e) {
      return MessageReportSubmitResult.fail(
        e is Exception ? e.toString().replaceFirst('Exception: ', '') : '$e',
      );
    }
  }

  void clearAfterSuccess() {
    detailsController.clear();
  }
}
