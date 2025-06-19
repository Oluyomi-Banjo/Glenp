import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:attendance_app/models/course.dart';
import 'package:attendance_app/models/attendance_session.dart';
import 'package:attendance_app/services/auth_service.dart';
import 'package:attendance_app/services/face_detection_service.dart';
import 'package:attendance_app/utils/permission_utils.dart';

enum CheckInStep {
  initial,
  faceRecognition,
  completed,
  failed
}

class AttendanceCheckInScreen extends StatefulWidget {
  final Course course;
  final AttendanceSession session;

  const AttendanceCheckInScreen({
    super.key,
    required this.course,
    required this.session,
  });

  @override
  State<AttendanceCheckInScreen> createState() =>
      _AttendanceCheckInScreenState();
}

class _AttendanceCheckInScreenState extends State<AttendanceCheckInScreen>
    with WidgetsBindingObserver {
  late FaceDetectionService _faceService;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  String? _errorMessage;
  String _statusMessage = 'Preparing camera...';
  CheckInStep _currentStep = CheckInStep.initial;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _faceService = FaceDetectionService();
    // Initialize after frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeCamera();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _faceService.cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Re-init camera on resume
      if (_faceService.cameraController == null || 
          !_faceService.cameraController!.value.isInitialized) {
        _initializeCamera();
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      // Check camera and photos permissions
      final permissionResult =
          await PermissionUtils.checkCameraAndPhotosPermissions(context);

      if (permissionResult == true) {
        // Permissions granted, initialize camera
        await _faceService.initializeCamera();

        if (!mounted) return;

        setState(() {
          _isCameraInitialized = true;
          _currentStep = CheckInStep.initial;
          _statusMessage = 'Ready for attendance check-in';
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
          _currentStep = CheckInStep.failed;
          _statusMessage = 'Camera error';
        });
      }

      if (kDebugMode) {
        print('Error initializing camera: $e');
      }
    }
  }

  void _startFaceRecognition() {
    setState(() {
      _currentStep = CheckInStep.faceRecognition;
      _statusMessage = 'Position your face for recognition';
      _errorMessage = null;
    });

    // Wait a moment then perform face recognition
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _performFaceRecognition();
      }
    });
  }

  Future<void> _performFaceRecognition() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Recognizing face...';
    });

    try {
      // Capture image
      final imageBytes = await _faceService.captureImage();

      if (imageBytes == null) {
        setState(() {
          _errorMessage = 'Failed to capture image';
          _currentStep = CheckInStep.failed;
          _statusMessage = 'Face recognition failed';
          _isProcessing = false;
        });
        return;
      }
      
      // Convert to base64
      final base64Image = _faceService.imageToBase64(imageBytes);

      // Get auth token before async gap
      final authService = Provider.of<AuthService>(context, listen: false);
      final authToken = authService.token;

      // Perform face recognition
      if (authToken == null) {
        setState(() {
          _errorMessage = 'You are not authenticated';
          _currentStep = CheckInStep.failed;
          _statusMessage = 'Authentication error';
          _isProcessing = false;
        });
        return;
      }

      final result = await _faceService.checkInWithFace(
        authService.token!,
        base64Image,
        widget.session.id,
      );

      if (result['success']) {
        setState(() {
          _currentStep = CheckInStep.completed;
          _statusMessage =
              result['message'] ?? 'Attendance recorded successfully!';
        });
      } else {
        setState(() {
          _currentStep = CheckInStep.failed;
          _errorMessage = result['message'] ?? 'Face not recognized';
          _statusMessage = 'Check-in failed';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _currentStep = CheckInStep.failed;
        _statusMessage = 'Face recognition error';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentStep == CheckInStep.faceRecognition && _isProcessing) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please wait while processing your attendance'),
            ),
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Attendance Check-in'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_currentStep == CheckInStep.faceRecognition && _isProcessing) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please wait while processing your attendance'),
                  ),
                );
                return;
              }
              Navigator.of(context).pop();
            },
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Course and session info
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.course.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Course Code: ${widget.course.code}',
                      style: const TextStyle(
                        fontSize: 16,
                      ),                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Session: ${widget.session.openedAt.toString().substring(0, 16)}',
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

              // Status message
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              // Main content
              Expanded(
                child: _buildMainContent(),
              ),

              // Bottom controls
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Start button - only show on initial screen
                    if (_currentStep == CheckInStep.initial)
                      ElevatedButton.icon(
                        onPressed: _startFaceRecognition,
                        icon: const Icon(Icons.face),
                        label: const Text('Start Face Recognition'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),

                    // Retry button - only show on failed screen
                    if (_currentStep == CheckInStep.failed)
                      ElevatedButton.icon(
                        onPressed: _startFaceRecognition,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Again'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),

                    // Done button - only show on completed screen
                    if (_currentStep == CheckInStep.completed)
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.check),
                        label: const Text('Done'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_currentStep) {
      case CheckInStep.initial:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.face,
                size: 64,
                color: Colors.blue,
              ),
              SizedBox(height: 16),
              Text(
                'Ready for Attendance Check-in',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Face recognition will be used to verify your identity.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );

      case CheckInStep.faceRecognition:
        if (!_isCameraInitialized) {
          return const Center(child: CircularProgressIndicator());
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            // Camera preview
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CameraPreview(_faceService.cameraController!),
              ),
            ),

            // Face positioning guide
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.blue,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            // Status message
            Positioned(
              top: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Processing indicator
            if (_isProcessing)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
          ],
        );

      case CheckInStep.completed:
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
                'Attendance Recorded!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );

      case CheckInStep.failed:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'Check-in Failed',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'An error occurred during check-in',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
    }
  }
}
