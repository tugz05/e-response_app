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

  Widget _previewSurface({required Widget child}) {
    return Container(
      width: double.infinity,
      height: 132,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Widget idPreview =
        _idImage != null
            ? Image.file(_idImage!, fit: BoxFit.cover, width: double.infinity)
            : Padding(
              padding: const EdgeInsets.all(12),
              child: Image.asset(
                'lib/assets/images/id_icons.png',
                fit: BoxFit.contain,
              ),
            );

    final Widget selfiePreview =
        _selfieImage != null
            ? Image.file(
              _selfieImage!,
              fit: BoxFit.cover,
              width: double.infinity,
            )
            : Padding(
              padding: const EdgeInsets.all(12),
              child: Image.asset(
                'lib/assets/images/scan.png',
                fit: BoxFit.contain,
              ),
            );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const VStepIndicator(accountState: AccountState.verification),
              const SizedBox(height: 14),
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 4,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primaryAlt,
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'IDENTITY VERIFICATION',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.85,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Verify your information',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Submit the documents below so we can process your '
                            'registration and activate your responder access.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textMuted,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _VerificationStepSection(
                stepLabel: 'Step 1',
                title: 'Government-issued ID',
                description:
                    'Provide a clear, well-lit photo of the front of your valid ID.',
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 400;
                    final preview = _previewSurface(child: idPreview);
                    final actions = Column(
                      children: [
                        VButton(
                          onPressed: () => _takePhoto(true),
                          text: 'Take photo',
                          isOutlined: true,
                          icon: Icons.photo_camera_outlined,
                        ),
                        const SizedBox(height: 10),
                        VButton(
                          onPressed: () => _uploadImage(true),
                          text: 'Upload from gallery',
                          icon: Icons.photo_library_outlined,
                        ),
                      ],
                    );
                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          preview,
                          const SizedBox(height: 14),
                          actions,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: preview),
                        const SizedBox(width: 14),
                        Expanded(flex: 6, child: actions),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              _VerificationStepSection(
                stepLabel: 'Step 2',
                title: 'Live selfie',
                description:
                    'Take a selfie so we can confirm your face matches your ID.',
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 400;
                    final preview = _previewSurface(child: selfiePreview);
                    final actions = VButton(
                      onPressed: () => _takePhoto(false),
                      text: 'Take selfie',
                      isOutlined: true,
                      icon: Icons.face_retouching_natural_outlined,
                    );
                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          preview,
                          const SizedBox(height: 14),
                          actions,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: preview),
                        const SizedBox(width: 14),
                        Expanded(flex: 6, child: actions),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              VButton(
                onPressed: () async {
                  if (_idImage != null && _selfieImage != null) {
                    setState(() {
                      _isVerifying = true;
                    });
                    final uploaded = await ImageUploadService().uploadImages(
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
                    if (uploaded) {
                      Navigator.pushNamed(context, RouteManager.success_screen);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Upload failed. Check your connection and try again.',
                          ),
                        ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please add both your ID photo and selfie before submitting.',
                        ),
                      ),
                    );
                  }
                },
                text: 'Submit verification',
                isLoading: _isVerifying,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerificationStepSection extends StatelessWidget {
  const _VerificationStepSection({
    required this.stepLabel,
    required this.title,
    required this.description,
    required this.child,
  });

  final String stepLabel;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    stepLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
