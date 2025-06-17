import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:attendance_app/models/course.dart';
import 'package:attendance_app/services/auth_service.dart';
import 'package:attendance_app/services/face_detection_service.dart';

class FaceEnrollmentScreen extends StatefulWidget {
  final Course course;

  const FaceEnrollmentScreen({
    super.key,
    required this.course,
  });

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen>
    with WidgetsBindingObserver {
  late FaceDetectionService _faceService;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _isEnrolled = false;
  String? _errorMessage;
  String _statusMessage = 'Position your face in the frame';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _faceService = FaceDetectionService();
    // Use post-frame callback to initialize camera after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCamera();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _faceService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App state changed before we got the chance to initialize the camera
    if (!_isCameraInitialized) return;

    // Handle app lifecycle changes to properly manage camera resources
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _faceService.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (!mounted) return;

    setState(() {
      _errorMessage = null;
      _statusMessage = 'Initializing camera...';
    });

    try {
      if (kDebugMode) {
        print('Requesting camera permission...');
      }

      // Request camera permission
      final status = await Permission.camera.request();
      if (kDebugMode) {
        print('Camera permission status: $status');
      }

      if (status != PermissionStatus.granted) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Camera permission is required for face enrollment';
            _statusMessage = 'Camera access denied';
          });
        }

        // Try to open app settings if permission denied
        if (status == PermissionStatus.denied ||
            status == PermissionStatus.permanentlyDenied) {
          if (kDebugMode) {
            print('Camera permission denied or permanently denied');
          }

          final shouldOpenSettings = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Camera Permission Required'),
                  content: const Text(
                      'This app needs camera access to enroll your face for attendance. Please grant camera permission in settings.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Open Settings'),
                    ),
                  ],
                ),
              ) ??
              false;

          if (shouldOpenSettings) {
            if (kDebugMode) {
              print('Opening app settings...');
            }
            await openAppSettings();
          }
        }
        return;
      } // Initialize camera
      if (kDebugMode) {
        print('Initializing camera through face service...');
      }
      await _faceService.initializeCamera();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _statusMessage = 'Position your face in the frame';
        });
        if (kDebugMode) {
          print('Camera initialized successfully');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _errorMessage = 'Failed to initialize camera: $e';
          _statusMessage = 'Camera error';
        });
      }
    }
  }

  Future<void> _captureAndEnrollFace() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Capturing face...';
      _errorMessage = null;
    });

    try {
      // Capture image
      final imageBytes = await _faceService.captureImage();

      if (imageBytes == null) {
        setState(() {
          _errorMessage = 'Failed to capture image';
          _isProcessing = false;
          _statusMessage = 'Capture failed';
        });
        return;
      }

      // Convert to base64
      final base64Image = _faceService.imageToBase64(imageBytes);

      // Enroll face
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.token == null) {
        setState(() {
          _errorMessage = 'You are not authenticated';
          _isProcessing = false;
          _statusMessage = 'Authentication error';
        });
        return;
      }

      final result = await _faceService.enrollFace(
        authService.token!,
        base64Image,
        widget.course.id,
      );

      if (mounted) {
        if (result['success']) {
          setState(() {
            _isEnrolled = true;
            _statusMessage = 'Face enrolled successfully!';
          });
        } else {
          setState(() {
            _errorMessage = result['message'] ?? 'Unknown error';
            _isProcessing = false;
            _statusMessage = 'Enrollment failed';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isProcessing = false;
          _statusMessage = 'Error occurred';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Enrollment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Instructions
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withAlpha(26), // Equivalent to opacity 0.1
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enroll for ${widget.course.name}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please position your face in the center of the frame. '
                  'Ensure good lighting and a neutral expression.',
                ),
              ],
            ),
          ),

          // Camera preview or status messages
          Expanded(
            child: _buildCameraSection(),
          ),

          // Bottom controls
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildCameraSection() {
    if (_isEnrolled) {
      // Success UI
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              size: 64,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            const Text(
              'Face Enrolled Successfully!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You can now use facial recognition for attendance.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Course'),
            ),
          ],
        ),
      );
    } else if (_isCameraInitialized &&
        _faceService.cameraController != null &&
        _faceService.cameraController!.value.isInitialized) {
      // Camera UI
      return Stack(
        alignment: Alignment.center,
        children: [
          // Camera preview with padding for better UI
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CameraPreview(_faceService.cameraController!),
              ),
            ),
          ),

          // Face guide circle
          Positioned.fill(
            child: Center(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      );
    } else if (_errorMessage != null) {
      // Error UI
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: _initializeCamera,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Loading UI
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing camera...'),
          ],
        ),
      );
    }
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Status message
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 16),

          // Capture button - only show when camera is ready and not already enrolled
          if (_isCameraInitialized && !_isEnrolled && _errorMessage == null)
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _captureAndEnrollFace,
              icon: const Icon(Icons.camera_alt),
              label: Text(_isProcessing ? 'Processing...' : 'Capture Face'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}
