import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A class that provides iOS-specific optimizations for camera and face detection
class IOSCameraHelper {
  /// Configures camera for optimal face detection on iOS
  static Future<CameraController> setupOptimizedCamera() async {
    try {
      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras available on device');
      }
      
      // Always use the front camera for face detection
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      
      // iOS-specific camera settings for face detection
      final controller = CameraController(
        frontCamera,
        // Use medium resolution for better performance on iOS
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888, // Better for iOS face detection
      );
      
      // Initialize the controller
      await controller.initialize();
      
      // Apply iOS-specific optimizations
      await optimizeCameraForFaceDetection(controller);
      
      return controller;
    } on CameraException catch (e) {
      debugPrint('Camera initialization error: ${e.description}');
      throw Exception('Failed to initialize camera: ${e.description}');
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      throw Exception('Failed to initialize camera: $e');
    }
  }
  
  /// Optimizes the camera stream for face detection on iOS
  static Future<void> optimizeCameraForFaceDetection(CameraController controller) async {
    if (!Platform.isIOS) return;
    
    try {
      // Set the flash mode to off for better processing
      if (controller.value.flashMode != FlashMode.off) {
        await controller.setFlashMode(FlashMode.off);
      }
      
      // Lock orientation to portrait for face detection
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      
      // Set exposure and focus modes for face detection
      await controller.setExposureMode(ExposureMode.auto);
      await controller.setFocusMode(FocusMode.auto);
    } catch (e) {
      debugPrint('Error optimizing camera for iOS: $e');
    }
  }
  
  /// Helper method to convert image formats between platforms
  static Future<Uint8List> processImageForPlatform(Uint8List imageData) async {
    return imageData; // Direct passthrough - preprocessing can be added if needed
  }
}
