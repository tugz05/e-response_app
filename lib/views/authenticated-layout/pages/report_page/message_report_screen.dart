import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:e_response_app_nemsu/services/location_service.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:e_response_app_nemsu/views/components/VButton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../../../../controllers/message_report_controller.dart';
import '../../../../services/shared_preferences/SharedPreferencesService.dart';
import 'package:shimmer/shimmer.dart';


class MessageReportScreen extends StatefulWidget {
  @override
  _MessageReportScreenState createState() => _MessageReportScreenState();
}

class _MessageReportScreenState extends State<MessageReportScreen> {
  final MessageReportController controller = MessageReportController();
  final SharedPreferencesService _prefsService = SharedPreferencesService();
  String? _id;
  bool _isLoading = true;
  String _selectedLocation = '';
  final List<XFile> selectedImages = [];

  @override
  void initState() {
    super.initState();
    _loadCredentialsAndInitialize();
    _setCurrentLocation();
  }

  void removeImage(int index) {
    setState(() {
      selectedImages.removeAt(index);
    });
  }

  Future<void> _setCurrentLocation() async {
    try {
      final currentAddress = await LocationService.getCurrentAddress();
      final locationDetails = await controller.getLocationDetails(currentAddress);
      setState(() {
        _selectedLocation = currentAddress;
        controller.locationController.text = currentAddress;
      });
      print('Current Location: $currentAddress');
      print('Latitude: ${locationDetails['latitude']}');
      print('Longitude: ${locationDetails['longitude']}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching current location: $e')),
      );
    }
  }

  Future<void> pickImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile>? images = await picker.pickMultiImage();
      if (images != null && images.isNotEmpty) {
        setState(() {
          selectedImages.addAll(images);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting images: $e')),
      );
    }
  }

  Future<void> _loadCredentialsAndInitialize() async {
    try {
      await controller.initialize();
      final credentials = await _prefsService.getCredentials();
      setState(() {
        _id = credentials['id'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _id = null;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading credentials: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Message Report'),
      ),
      body: _isLoading
          ? Padding(
        padding: const EdgeInsets.all(16.0),
        child: Shimmer.fromColors(
          baseColor: AppColors.skeletonBase,
          highlightColor: AppColors.skeletonHighlight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Shimmer for the TypeAheadField
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: EdgeInsets.only(bottom: 12),
              ),
              // Shimmer for the Selected Location field
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: EdgeInsets.only(bottom: 15),
              ),
              // Shimmer for the Details Input Field
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: EdgeInsets.only(bottom: 15),
              ),
              // Shimmer for image previews row
              Row(
                children: List.generate(
                  4,
                  (index) => Container(
                    width: 55,
                    height: 55,
                    margin: EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 30),
              // Shimmer for the Submit button
              Container(
                height: 48,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: EdgeInsets.only(top: 32),
              ),
            ],
          ),
        ),
      )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Location Input Field (TypeAhead)
                  TypeAheadField<String>(
                    suggestionsCallback: (query) {
                      return controller.getSuggestions(query);
                    },
                    builder: (context, textEditingController, focusNode) {
                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        autofocus: false,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          hintText: 'Enter incident location...',
                          prefixIcon: Icon(Icons.location_on, color: AppColors.primary),
                          hintStyle: TextStyle(color: AppColors.textMuted),
                        ),
                        style: TextStyle(color: AppColors.textPrimary),
                      );
                    },
                    itemBuilder: (context, suggestion) {
                      return ListTile(
                        title: Text(suggestion),
                      );
                    },
                    onSelected: (suggestion) async {
                      setState(() {
                        _selectedLocation = suggestion;
                      });
                      controller.locationController.text = suggestion;
                      try {
                        final locationDetails = await controller.getLocationDetails(suggestion);
                        print('Selected Location: ${locationDetails['address']}');
                        print('Latitude: ${locationDetails['latitude']}');
                        print('Longitude: ${locationDetails['longitude']}');
                      } catch (error) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error fetching location details: $error')),
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 10),

                  // Selected Location Field (Read Only)
                  TextField(
                    readOnly: true,
                    controller: TextEditingController(text: _selectedLocation),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      labelText: 'Selected Location',
                      labelStyle: TextStyle(color: AppColors.textMuted),
                      prefixIcon: Icon(Icons.check_circle, color: AppColors.primary),
                    ),
                    style: TextStyle(color: AppColors.textPrimary),
                  ),

                  const SizedBox(height: 15),

                  // Details Input Field
                  Expanded(
                    flex: 0,
                    child: TextField(
                      controller: controller.detailsController,
                      decoration: InputDecoration(
                        hintText: 'What happend?',
                        hintStyle: TextStyle(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      style: TextStyle(color: AppColors.textPrimary),
                      maxLines: 5,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Images Preview Row
                  Row(
                    children: [
                      ...List.generate(
                        3,
                        (i) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: (i < selectedImages.length)
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8.0),
                                      child: Image.file(
                                        File(selectedImages[i].path),
                                        width: 55,
                                        height: 55,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      right: -10,
                                      top: -10,
                                      child: IconButton(
                                        icon: Icon(Icons.cancel, color: Colors.white, size: 20),
                                        onPressed: () => removeImage(i),
                                        padding: EdgeInsets.zero,
                                        constraints: BoxConstraints(),
                                      ),
                                    ),
                                  ],
                                )
                              : Container(
                                  width: 55,
                                  height: 55,
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundAlt,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                        ),
                      ),
                      // Camera Button (for uploading)
                      Padding(
                        padding: const EdgeInsets.only(left: 0),
                        child: GestureDetector(
                          onTap: pickImages,
                          child: Container(
                            width: 55,
                            height: 55,
                            decoration: BoxDecoration(
                              color: AppColors.backgroundAlt,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.camera_alt, color: AppColors.primary),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Submit Button
                  VButton(
                    text: "Submit to CDRRMO",
                    isLoading: _isLoading,
                    onPressed: (_id != null && controller.locationController.text.isNotEmpty)
                        ? () async {
                            setState(() => _isLoading = true);
                            try {
                              await controller.submitReport(context, _id!, selectedImages);
                            } catch (error) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $error')),
                              );
                            } finally {
                              setState(() => _isLoading = false);
                            }
                          }
                        : () {},
                  ),
                ],
              ),
            ),
    );
  }
}
