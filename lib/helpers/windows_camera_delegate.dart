import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart'
    as image_picker;

class WindowsImagePickerCameraDelegate
    extends image_picker.ImagePickerCameraDelegate {
  WindowsImagePickerCameraDelegate(this.navigatorKey);

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Future<XFile?> takePhoto({
    image_picker.ImagePickerCameraDelegateOptions options =
        const image_picker.ImagePickerCameraDelegateOptions(),
  }) {
    return _openCamera(mode: _CaptureMode.photo, options: options);
  }

  @override
  Future<XFile?> takeVideo({
    image_picker.ImagePickerCameraDelegateOptions options =
        const image_picker.ImagePickerCameraDelegateOptions(),
  }) {
    return _openCamera(mode: _CaptureMode.video, options: options);
  }

  Future<XFile?> _openCamera({
    required _CaptureMode mode,
    required image_picker.ImagePickerCameraDelegateOptions options,
  }) async {
    final NavigatorState? navigator = navigatorKey.currentState;
    if (navigator == null) {
      throw StateError('App navigator is not ready for camera capture.');
    }

    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showMessage('No camera detected on this Windows device.');
        return null;
      }

      final CameraDescription initialCamera = _selectCamera(
        cameras,
        options.preferredCameraDevice,
      );

      return navigator.push<XFile>(
        MaterialPageRoute<XFile>(
          fullscreenDialog: true,
          builder:
              (_) => _WindowsCameraCapturePage(
                cameras: cameras,
                initialCamera: initialCamera,
                mode: mode,
                maxVideoDuration: options.maxVideoDuration,
              ),
        ),
      );
    } on CameraException catch (error) {
      _showMessage(error.description ?? error.code);
      return null;
    } catch (error) {
      _showMessage('Unable to open the Windows camera: $error');
      return null;
    }
  }

  CameraDescription _selectCamera(
    List<CameraDescription> cameras,
    image_picker.CameraDevice preferredCameraDevice,
  ) {
    final CameraLensDirection targetDirection =
        preferredCameraDevice == image_picker.CameraDevice.front
            ? CameraLensDirection.front
            : CameraLensDirection.back;

    for (final CameraDescription camera in cameras) {
      if (camera.lensDirection == targetDirection) {
        return camera;
      }
    }

    return cameras.first;
  }

  void _showMessage(String message) {
    final BuildContext? context = navigatorKey.currentContext;
    final messenger =
        context != null ? ScaffoldMessenger.maybeOf(context) : null;
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _CaptureMode { photo, video }

class _WindowsCameraCapturePage extends StatefulWidget {
  const _WindowsCameraCapturePage({
    required this.cameras,
    required this.initialCamera,
    required this.mode,
    this.maxVideoDuration,
  });

  final List<CameraDescription> cameras;
  final CameraDescription initialCamera;
  final _CaptureMode mode;
  final Duration? maxVideoDuration;

  @override
  State<_WindowsCameraCapturePage> createState() =>
      _WindowsCameraCapturePageState();
}

class _WindowsCameraCapturePageState extends State<_WindowsCameraCapturePage> {
  CameraController? _controller;
  late CameraDescription _selectedCamera;
  bool _isInitializing = true;
  bool _isBusy = false;
  bool _isRecording = false;
  String? _errorMessage;
  Timer? _maxVideoTimer;

  @override
  void initState() {
    super.initState();
    _selectedCamera = widget.initialCamera;
    _initializeCamera(_selectedCamera);
  }

  @override
  void dispose() {
    _maxVideoTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera(CameraDescription camera) async {
    final CameraController? previousController = _controller;

    final CameraController controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    setState(() {
      _controller = controller;
      _selectedCamera = camera;
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await previousController?.dispose();
      setState(() {
        _isInitializing = false;
      });
    } on CameraException catch (error) {
      await controller.dispose();
      if (!mounted) {
        return;
      }
      setState(() {
        _controller = previousController;
        if (previousController != null) {
          _selectedCamera = previousController.description;
        }
        _isInitializing = false;
        _errorMessage = error.description ?? error.code;
      });
    }
  }

  Future<void> _switchCamera() async {
    if (widget.cameras.length < 2 || _isBusy || _isRecording) {
      return;
    }

    final int currentIndex = widget.cameras.indexOf(_selectedCamera);
    final int nextIndex = (currentIndex + 1) % widget.cameras.length;
    await _initializeCamera(widget.cameras[nextIndex]);
  }

  Future<void> _capture() async {
    final CameraController? controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isBusy ||
        _isInitializing) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      if (widget.mode == _CaptureMode.photo) {
        final XFile image = await controller.takePicture();
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop(image);
        return;
      }

      if (_isRecording) {
        _maxVideoTimer?.cancel();
        final XFile video = await controller.stopVideoRecording();
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop(video);
        return;
      }

      await controller.startVideoRecording();
      _startVideoTimeout();
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = true;
      });
    } on CameraException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.description ?? error.code)));
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _startVideoTimeout() {
    _maxVideoTimer?.cancel();
    final Duration? maxVideoDuration = widget.maxVideoDuration;
    if (maxVideoDuration == null) {
      return;
    }

    _maxVideoTimer = Timer(maxVideoDuration, () {
      if (mounted && _isRecording) {
        _capture();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final CameraController? controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.mode == _CaptureMode.photo ? 'Take Photo' : 'Record Video',
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child:
                  _errorMessage != null
                      ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      )
                      : controller == null || _isInitializing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : AspectRatio(
                        aspectRatio: controller.value.aspectRatio,
                        child: CameraPreview(controller),
                      ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _isBusy ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _capture,
                  child: Text(
                    widget.mode == _CaptureMode.photo
                        ? 'Capture'
                        : _isRecording
                        ? 'Stop'
                        : 'Record',
                  ),
                ),
                IconButton(
                  onPressed: widget.cameras.length > 1 ? _switchCamera : null,
                  color: Colors.white,
                  icon: const Icon(Icons.cameraswitch_outlined),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
