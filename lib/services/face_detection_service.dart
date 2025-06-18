import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:attendance_app/utils/constants.dart';
import 'package:attendance_app/utils/network_utils.dart';
import 'package:attendance_app/services/liveness_detection_manager.dart'
    as liveness;

enum LivenessAction { blink, turnLeft, turnRight }

class FaceDetectionService {
  CameraController? _cameraController;
  final FaceDetector _faceDetector;
  liveness.LivenessDetectionManager? _livenessManager;
  bool _isProcessing = false;

  // Default constructor
  FaceDetectionService()
      : _faceDetector = FaceDetector(
          options: FaceDetectorOptions(
            enableContours: true,
            enableLandmarks: true,
            enableClassification: true,
            minFaceSize: 0.15,
            performanceMode: FaceDetectorMode.accurate,
          ),
        );

  CameraController? get cameraController => _cameraController;

  // Initialize camera
  Future<void> initializeCamera() async {
    // Get available cameras
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw Exception('No cameras available');
    }

    // Find front camera
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    // Initialize camera controller
    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );

    // Initialize camera
    await _cameraController!.initialize();

    // Set fixed orientation to portrait
    await _cameraController!.lockCaptureOrientation(
        DeviceOrientation.portraitUp); // Initialize liveness detection manager
    _livenessManager = liveness.LivenessDetectionManager(
      cameraController: _cameraController!,
      faceDetector: _faceDetector,
    );
  }

  Future<void> dispose() async {
    if (_livenessManager != null) {
      _livenessManager!.dispose();
    }

    try {
      await _faceDetector.close();
      await _cameraController?.dispose();
      _cameraController = null;
    } catch (e) {
      debugPrint('Error disposing camera resources: $e');
    }
  }

  Future<Uint8List?> captureImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      if (kDebugMode) {
        print('Camera controller is not initialized');
      }
      return null;
    }

    // Ensure the camera is not taking a picture already
    if (_cameraController!.value.isTakingPicture) {
      if (kDebugMode) {
        print('Camera is already taking a picture');
      }
      return null;
    }

    try {
      if (kDebugMode) {
        print('Preparing to capture image...');
      }

      // Prepare the camera for taking a picture
      await _cameraController!.setFlashMode(FlashMode.off);

      // Take the picture
      if (kDebugMode) {
        print('Taking picture...');
      }
      final XFile file = await _cameraController!.takePicture();

      // Read the file as bytes
      if (kDebugMode) {
        print('Reading image data...');
      }
      final bytes = await file.readAsBytes();

      if (kDebugMode) {
        print('Image captured successfully: ${bytes.length} bytes');
      }
      return bytes;
    } on CameraException catch (e) {
      if (kDebugMode) {
        print('Error capturing image: ${e.description}');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error capturing image: $e');
      }
      return null;
    }
  }

  String imageToBase64(Uint8List bytes) {
    return base64Encode(bytes);
  }

  Future<bool> detectFace(CameraImage image) async {
    if (_isProcessing) return false;
    _isProcessing = true;

    try {
      // Create platform-specific input image
      final inputImage = Platform.isIOS
          ? _createIOSInputImage(image)
          : _createAndroidInputImage(image);

      final List<Face> faces = await _faceDetector.processImage(inputImage);
      _isProcessing = false;
      return faces.isNotEmpty;
    } catch (e) {
      _isProcessing = false;
      debugPrint('Error detecting face: $e');
      return false;
    }
  }

  InputImage _createIOSInputImage(CameraImage image) {
    const inputImageFormat = InputImageFormat.bgra8888;

    final inputImageData = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: InputImageRotation.rotation0deg,
      format: inputImageFormat,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(
      bytes: image.planes[0].bytes,
      metadata: inputImageData,
    );
  }

  InputImage _createAndroidInputImage(CameraImage image) {
    const inputImageFormat = InputImageFormat.nv21;

    final inputImageData = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: InputImageRotation.rotation0deg,
      format: inputImageFormat,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(
      bytes: image.planes[0].bytes,
      metadata: inputImageData,
    );
  }

  Future<Map<String, dynamic>> enrollFace(
      String token, String imageBase64, int courseId) async {
    try {
      if (kDebugMode) {
        print('Preparing to enroll face for course ID: $courseId');
        print('Image data size: ${imageBase64.length} characters');
      }

      final Map<String, dynamic> payload = {
        'face_image': imageBase64,
        'course_id': courseId,
      };

      if (kDebugMode) {
        print(
            'Sending face enrollment request to: ${ApiConstants.baseUrl}${ApiConstants.faceEnroll}');
      }

      final response = await NetworkUtils.authenticatedPost(
        '${ApiConstants.baseUrl}${ApiConstants.faceEnroll}',
        token,
        payload,
      );

      if (kDebugMode) {
        print('Face enrollment response status: ${response.statusCode}');
        print('Face enrollment response body: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true};
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['detail'] ?? 'Failed to enroll face',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error enrolling face: $e');
      }
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> performLivenessCheck(
      String token, String imageBase64, int courseId) async {
    try {
      // Add platform info for server-side optimizations
      final Map<String, dynamic> payload = {
        'face_image': imageBase64,
        'course_id': courseId,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'device_info': {
          'os_version': Platform.operatingSystemVersion,
          'model': Platform.isIOS ? 'iOS Device' : 'Android Device',
        }
      };

      final response = await NetworkUtils.authenticatedPost(
        '${ApiConstants.baseUrl}${ApiConstants.livenessCheck}',
        token,
        payload,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message':
              'Failed to verify liveness: ${jsonDecode(response.body)['detail']}',
        };
      }
    } catch (e) {
      debugPrint('Error performing liveness check: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> verifyFace(
      String token, String imageBase64, int sessionId) async {
    try {
      final Map<String, dynamic> payload = {
        'face_image': imageBase64,
        'session_id': sessionId,
      };

      final response = await NetworkUtils.authenticatedPost(
        '${ApiConstants.baseUrl}${ApiConstants.faceCheckIn}',
        token,
        payload,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'message':
              'Failed to verify face: ${jsonDecode(response.body)['detail']}',
        };
      }
    } catch (e) {
      debugPrint('Error verifying face: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> checkInWithFace(
      String token, String imageBase64, int sessionId) async {
    try {
      final Map<String, dynamic> payload = {
        'face_image': imageBase64,
        'session_id': sessionId,
      };

      final response = await NetworkUtils.authenticatedPost(
        '${ApiConstants.baseUrl}${ApiConstants.faceCheckIn}',
        token,
        payload,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Attendance recorded successfully',
          'data': jsonDecode(response.body),
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['detail'] ?? 'Failed to check in',
        };
      }
    } catch (e) {
      debugPrint('Error checking in with face: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Perform real-time liveness check with action detection
  Future<Map<String, dynamic>> performRealTimeLivenessCheck(
      String token, LivenessAction action, int courseId) async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _livenessManager == null) {
      return {
        'success': false,
        'message': 'Camera not initialized',
      };
    }

    try {
      if (kDebugMode) {
        print('Starting real-time liveness check for action: $action');
      }

      // Set timeout duration for liveness detection
      const int livenessCheckDuration = 5; // seconds

      // Map our LivenessAction enum to the library's enum
      final livenessAction = _mapToLivenessManagerAction(action);

      // Perform real-time action detection
      final actionDetected = await _livenessManager!
          .detectAction(livenessAction, livenessCheckDuration);

      if (!actionDetected) {
        return {
          'success': false,
          'message': 'Liveness check failed: Action not detected',
        };
      }

      // If we got here, the action was detected
      // Now capture a final image for server verification
      final imageBytes = await captureImage();
      if (imageBytes == null) {
        return {
          'success': false,
          'message': 'Failed to capture verification image',
        };
      }

      // Convert to base64
      final base64Image = imageToBase64(imageBytes);

      // Send to server for verification (use the original API for now)
      return await performLivenessCheck(token, base64Image, courseId);
    } catch (e) {
      if (kDebugMode) {
        print('Error in real-time liveness check: $e');
      }
      return {
        'success': false,
        'message': 'Liveness check error: $e',
      };
    }
  }

  // Map our LivenessAction enum to the LivenessDetectionManager's enum
  liveness.LivenessAction _mapToLivenessManagerAction(LivenessAction action) {
    switch (action) {
      case LivenessAction.blink:
        return liveness.LivenessAction.blink;
      case LivenessAction.turnLeft:
        return liveness.LivenessAction.turnLeft;
      case LivenessAction.turnRight:
        return liveness.LivenessAction.turnRight;
      default:
        return liveness.LivenessAction.blink;
    }
  }
}
