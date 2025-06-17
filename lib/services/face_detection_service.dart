import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:attendance_app/utils/constants.dart';
import 'package:attendance_app/utils/network_utils.dart';

enum LivenessAction { blink, turnLeft, turnRight }

class FaceDetectionService {
  late final FaceDetector _faceDetector;
  CameraController? _cameraController;
  bool _isProcessing = false;
  
  FaceDetectionService() {
    final options = FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
    );
    _faceDetector = FaceDetector(options: options);
  }
  
  Future<void> initializeCamera() async {
    try {
      // Dispose of any existing controller
      await _cameraController?.dispose();
      
      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('NoCameraAvailable', 'No cameras found on device.');
      }
      
      // Find front camera
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      
      // Create new controller with appropriate settings
      _cameraController = CameraController(
        frontCamera,
        // Use lower resolution on web/iOS for better performance
        kIsWeb || Platform.isIOS ? ResolutionPreset.medium : ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS 
            ? ImageFormatGroup.bgra8888  // Better for iOS face detection
            : ImageFormatGroup.yuv420,
      );
      
      // Initialize the controller
      await _cameraController!.initialize();
      
      // Apply platform-specific optimizations
      if (Platform.isIOS) {
        await _optimizeForIOS();
      } else if (Platform.isAndroid) {
        await _optimizeForAndroid();
      }
      
      debugPrint('Camera initialized successfully');
    } on CameraException catch (e) {
      debugPrint('Camera initialization error: ${e.description}');
      throw CameraException('CameraInitError', 'Failed to initialize camera: ${e.description}');
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      throw Exception('Failed to initialize camera: $e');
    }
  }
  
  Future<void> _optimizeForIOS() async {
    if (_cameraController == null) return;
    
    try {
      await _cameraController!.setFlashMode(FlashMode.off);
      await _cameraController!.setExposureMode(ExposureMode.auto);
      await _cameraController!.setFocusMode(FocusMode.auto);
      await _cameraController!.lockCaptureOrientation(DeviceOrientation.portraitUp);
    } catch (e) {
      debugPrint('Error optimizing camera for iOS: $e');
    }
  }
  
  Future<void> _optimizeForAndroid() async {
    if (_cameraController == null) return;
    
    try {
      await _cameraController!.setFlashMode(FlashMode.off);
      await _cameraController!.setExposureMode(ExposureMode.auto);
      await _cameraController!.setFocusMode(FocusMode.auto);
    } catch (e) {
      debugPrint('Error optimizing camera for Android: $e');
    }
  }
  
  CameraController? get cameraController => _cameraController;
  
  Future<void> dispose() async {
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
      debugPrint('Camera controller is not initialized');
      return null;
    }
    
    // Ensure the camera is not taking a picture already
    if (_cameraController!.value.isTakingPicture) {
      debugPrint('Camera is already taking a picture');
      return null;
    }
    
    try {
      // Prepare the camera for taking a picture
      await _cameraController!.setFlashMode(FlashMode.off);
      
      // Take the picture
      final XFile file = await _cameraController!.takePicture();
      
      // Read the file as bytes
      final bytes = await file.readAsBytes();
      return bytes;
    } on CameraException catch (e) {
      debugPrint('Error capturing image: ${e.description}');
      return null;
    } catch (e) {
      debugPrint('Error capturing image: $e');
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
    final inputImageFormat = InputImageFormat.bgra8888;
    
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
    final inputImageFormat = InputImageFormat.nv21;
    
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
  
  Future<Map<String, dynamic>> enrollFace(String token, String imageBase64, int courseId) async {
    try {
      final Map<String, dynamic> payload = {
        'face_image': imageBase64,
        'course_id': courseId,
      };
      
      final response = await NetworkUtils.authenticatedPost(
        '${ApiConstants.baseUrl}${ApiConstants.faceEnroll}',
        token,
        payload,
      );
      
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
      debugPrint('Error enrolling face: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }
  
  Future<Map<String, dynamic>> performLivenessCheck(String token, String imageBase64, int courseId) async {
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
          'message': 'Failed to verify liveness: ${jsonDecode(response.body)['detail']}',
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
  
  Future<Map<String, dynamic>> verifyFace(String token, String imageBase64, int sessionId) async {
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
          'message': 'Failed to verify face: ${jsonDecode(response.body)['detail']}',
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
  
  Future<Map<String, dynamic>> checkInWithFace(String token, String imageBase64, int sessionId) async {
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
}
