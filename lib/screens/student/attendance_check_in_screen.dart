import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:attendance_app/models/course.dart';
import 'package:attendance_app/models/attendance_session.dart';
import 'package:attendance_app/services/auth_service.dart';
import 'package:attendance_app/services/face_detection_service.dart';
import 'package:attendance_app/utils/constants.dart';
import 'package:attendance_app/utils/permission_utils.dart';

enum CheckInStep {
  initial,
  livenessDetection,
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
  String _livenessAction = '';
  int _livenessAttemptsRemaining = 3;
  int _countdownSeconds = 0;
  Timer? _countdownTimer;
  bool _livenessCheckPassed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _faceService = FaceDetectionService();
    _checkAndInitializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _faceService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If camera not initialized but returning from settings, check permissions again
    if (!_isCameraInitialized) {
      if (state == AppLifecycleState.resumed) {
        _checkAndInitializeCamera();
      }
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _faceService.cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _checkAndInitializeCamera() async {
    if (!mounted) return;

    setState(() {
      _errorMessage = null;
      _statusMessage = 'Checking camera permission...';
    });

    try {
      // Check camera and photos permissions using the utility
      final permissionResult =
          await PermissionUtils.checkCameraAndPhotosPermissions(context);

      if (permissionResult == true) {
        // Permissions granted, initialize camera
        await _initializeCamera();
      } else if (permissionResult == false) {
        // Permissions permanently denied, show settings dialog
        if (mounted) {
          setState(() {
            _errorMessage =
                'Camera permission is required for attendance check-in';
            _statusMessage = 'Camera access denied';
            _currentStep = CheckInStep.failed;
          });

          await PermissionUtils.showPermissionSettingsDialog(context,
              content:
                  'This app needs camera access to verify your attendance. Please grant camera permission in settings.');
        }
      } else {
        // Permission denied but not permanently
        if (mounted) {
          setState(() {
            _errorMessage =
                'Camera permission is required for attendance check-in';
            _statusMessage = 'Camera access denied';
            _currentStep = CheckInStep.failed;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error checking permissions: $e';
          _statusMessage = 'Permission error';
          _currentStep = CheckInStep.failed;
        });
      }
      if (kDebugMode) {
        print('Error checking permissions: $e');
      }
    }
  }

  Future<void> _initializeCamera() async {
    if (!mounted) return;

    setState(() {
      _statusMessage = 'Initializing camera...';
      _errorMessage = null;
    });

    try {
      await _faceService.initializeCamera();
      if (mounted) {
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

  void _startLivenessDetection() {
    setState(() {
      _currentStep = CheckInStep.livenessDetection;
      _livenessAction = _getRandomLivenessAction();
      _livenessAttemptsRemaining = 3;
      _countdownSeconds = AppConstants.livenessCheckDuration;
      _statusMessage = 'Please $_livenessAction';
    });

    _startCountdown();
  }

  String _getRandomLivenessAction() {
    final random = Random();
    return AppConstants
        .livenessActions[random.nextInt(AppConstants.livenessActions.length)];
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 0) {
        setState(() {
          _countdownSeconds--;
        });
      } else {
        timer.cancel();
        _performLivenessCheck();
      }
    });
  }

  Future<void> _performLivenessCheck() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Verifying...';
    });

    try {
      // Capture image
      final imageBytes = await _faceService.captureImage();

      if (imageBytes == null) {
        _handleLivenessFailure('Failed to capture image');
        return;
      }
      // Convert to base64
      final base64Image = _faceService.imageToBase64(imageBytes);

      // Get auth token before async gap
      final authService = Provider.of<AuthService>(context, listen: false);
      final authToken = authService.token;

      // Perform liveness check
      if (authToken == null) {
        _handleLivenessFailure('You are not authenticated');
        return;
      }

      final result = await _faceService.performLivenessCheck(
        authToken,
        base64Image,
        widget.course.id,
      );

      if (result['success']) {
        setState(() {
          _livenessCheckPassed = true;
          _statusMessage = 'Liveness check passed!';
        });

        // Wait a moment before proceeding to face recognition
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _proceedToFaceRecognition();
          }
        });
      } else {
        _handleLivenessFailure(result['message'] ?? 'Liveness check failed');
      }
    } catch (e) {
      _handleLivenessFailure('Error: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _handleLivenessFailure(String message) {
    setState(() {
      _livenessAttemptsRemaining--;
      _errorMessage = message;

      if (_livenessAttemptsRemaining > 0) {
        _statusMessage = 'Try again. Please $_livenessAction';
        _countdownSeconds = AppConstants.livenessCheckDuration;
        _startCountdown();
      } else {
        _currentStep = CheckInStep.failed;
        _statusMessage = 'Liveness check failed';
      }
    });
  }

  void _proceedToFaceRecognition() {
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

    // Check if liveness check has been passed
    if (!_livenessCheckPassed) {
      setState(() {
        _errorMessage = 'Liveness check must be passed first';
        _currentStep = CheckInStep.failed;
        _statusMessage = 'Authentication failed';
      });
      return;
    }

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
        widget.course.id,
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
        _currentStep = CheckInStep.failed;
        _errorMessage = 'Error: $e';
        _statusMessage = 'An error occurred';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Check-in'),
      ),
      body: Column(
        children: [
          // Course info
          Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.course.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Course Code: ${widget.course.code}'),
                    const SizedBox(height: 4),
                    Text('Session ID: ${widget.session.id}'),
                  ],
                ),
              ),
            ),
          ),

          // Camera/status area
          Expanded(
            child: _buildMainContent(),
          ),

          // Actions area
          Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Column(
              children: [
                // Status message
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                // Error message
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),

                const SizedBox(height: 16),

                // Action button
                _buildActionButton(),
              ],
            ),
          ),
        ],
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
                'You will need to complete a liveness check\nfollowed by face recognition.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );

      case CheckInStep.livenessDetection:
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

            // Liveness instruction
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Please $_livenessAction',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: Text(
                        '$_countdownSeconds',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
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

            // Face guide
            Positioned.fill(
              child: Center(
                child: Container(
                  width: 200,
                  height: 200,
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

  Widget _buildActionButton() {
    switch (_currentStep) {
      case CheckInStep.initial:
        return ElevatedButton(
          onPressed: _startLivenessDetection,
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.blue,
          ),
          child: const Text('Start Check-in'),
        );

      case CheckInStep.livenessDetection:
        // No button during liveness detection
        return const SizedBox.shrink();

      case CheckInStep.faceRecognition:
        // No button during face recognition
        return const SizedBox.shrink();

      case CheckInStep.completed:
        return ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.green,
          ),
          child: const Text('Return to Course'),
        );

      case CheckInStep.failed:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentStep = CheckInStep.initial;
                  _errorMessage = null;
                  _statusMessage = 'Ready for check-in';
                  _livenessCheckPassed = false;
                });
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blue,
              ),
              child: const Text('Try Again'),
            ),
          ],
        );
    }
  }
}
