import 'package:e_response_app_nemsu/routes/route_manager.dart';
import 'package:e_response_app_nemsu/views/components/VButton.dart';
import 'package:e_response_app_nemsu/views/components/VStepIndicator.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import '../../services/image_upload_service.dart'; // Required for File operations

class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  File? _idImage; // Image for ID
  File? _selfieImage; // Image for Selfie
  final ImagePicker _picker = ImagePicker();
  String? userId;
  bool _isVerifying = false;
  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      userId = prefs.getString('id');
    });
  }

  // Function to open camera and take photo
  Future<void> _takePhoto(bool isIdImage) async {
    if (!_picker.supportsImageSource(ImageSource.camera)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera capture is not available on this device.'),
        ),
      );
      return;
    }

    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice:
            isIdImage ? CameraDevice.rear : CameraDevice.front,
      );

      if (pickedFile == null || !mounted) {
        return;
      }

      setState(() {
        if (isIdImage) {
          _idImage = File(pickedFile.path);
        } else {
          _selfieImage = File(pickedFile.path);
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to access the camera: $error')),
      );
    }
  }

  // Function to upload image from gallery
  Future<void> _uploadImage(bool isIdImage) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        if (isIdImage) {
          _idImage = File(pickedFile.path);
        } else {
          _selfieImage = File(pickedFile.path);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const VStepIndicator(accountState: AccountState.verification),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 35, vertical: 20),
              child: Column(
                children: [
                  Text(
                    "We need to verify your information.Please submit the documents below to process your registration.",
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'Roboto',
                      color: AppColors.primary,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 25),
                ],
              ),
            ),
            const Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(left: 30),
                  child: Row(
                    children: [
                      Text(
                        "1. Provide a photo of the front of your ID",
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Roboto',
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _idImage != null
                    ? Image.file(
                      _idImage!,
                      width: 150,
                      height: 120,
                      fit: BoxFit.cover,
                    )
                    : Image.asset(
                      "lib/assets/images/id_icons.png",
                      width: 150,
                      height: 120,
                    ),
                SizedBox(width: 20),
                Column(
                  children: [
                    VButton(
                      onPressed: () => _takePhoto(true),
                      text: "Take a Photo",
                      isOutlined: true,
                      width: 180,
                    ),
                    SizedBox(height: 15),
                    VButton(
                      onPressed: () => _uploadImage(true),
                      text: "Upload an Image",
                      width: 180,
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 15),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 30),
              child: Text(
                "2. Take a selfie to verify your face matches with your ID ",
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Roboto',
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.left,
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _selfieImage != null
                    ? Image.file(
                      _selfieImage!,
                      width: 150,
                      height: 120,
                      fit: BoxFit.cover,
                    )
                    : Image.asset(
                      "lib/assets/images/scan.png",
                      width: 150,
                      height: 120,
                    ),
                SizedBox(width: 20),
                Column(
                  children: [
                    VButton(
                      onPressed: () => _takePhoto(false),
                      text: "Take a Photo",
                      isOutlined: true,
                      width: 180,
                    ),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 50),
              child: VButton(
                onPressed: () async {
                  if (_idImage != null && _selfieImage != null) {
                    setState(() {
                      _isVerifying = true;
                    });
                    await ImageUploadService().uploadImages(
                      userId.toString(),
                      _idImage!,
                      _selfieImage!,
                    );
                    if (!context.mounted) {
                      return;
                    }
                    setState(() {
                      _isVerifying = false;
                    });
                    Navigator.pushNamed(context, RouteManager.success_screen);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Please select both images before verifying.",
                        ),
                      ),
                    );
                  }
                },
                text: "Verify Account",
                isLoading: _isVerifying,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
